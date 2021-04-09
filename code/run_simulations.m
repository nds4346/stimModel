%% load file
    pathname = 'D:\Lab\Data\StimModel';
    td_filename = 'Han_201603015_RW_SmoothKin_50ms.mat';
    fr_file = 'vae_rates_Han_20160325_RW_dropout91_lambda20_learning1e-05_n-epochs600_n-neurons1600_rate6.0_2021-03-13-184825.csv';

    load([pathname filesep td_filename]);
    firing_rates = readtable([pathname,filesep, fr_file]);
    firing_rates = firing_rates{:,:};

    rel= version('-release');
    is_old_matlab = str2num(rel(1:4)) < 2018;

    %add to td
    bin_size = 0.05;
    td.VAE_firing_rates = firing_rates(:,:)/bin_size;
    map_dim = sqrt(numel(firing_rates(1,:)) + [0,0]);

    locs = zeros(map_dim(1)*map_dim(2),2);
    [locs(:,1), locs(:,2)] = ind2sub([map_dim(1), map_dim(2)],1:map_dim(1)*map_dim(2)); % get location of each neurons
    
    
% match up data lengths

    field_len = length(td.vel);
    td_fieldnames = fieldnames(td);
    [~,mask] = rmmissing(td.vel);

    for i_field = 1:numel(td_fieldnames)
        if(length(td.(td_fieldnames{i_field})) == field_len)
            td.(td_fieldnames{i_field}) = td.(td_fieldnames{i_field})(mask==0,:);
        end
    end    

    
%% analyze firing rates
    % plot histogram of firing rates (and compare to real thing at some
    % point). Also plot firing rate during reaches in different directions
    % heatmap showing neuron firing rate against speed and movement
    % direction
    
    % for each neuron, build a glm predicting firing rate from cosine(dir) + speed
    td=getSpeed(td);
    n_neurons = size(td.VAE_firing_rates,2);
    n_params = 6; %constant, hand(x,y) position, hand (x,y) vel, speed
    glm_fits = nan(n_neurons,n_params);
    pr2_fits = nan(n_neurons,2); % train, test
    state = [td.pos, td.vel, td.speed]; % offset term automatically included
    
    for i_unit = 1:size(td.VAE_firing_rates,2)
        fr = td.VAE_firing_rates(:,i_unit);
        train_idx = datasample(1:1:length(state),ceil(0.9*length(state)),'Replace',false);
        test_idx =setdiff(1:1:length(state),train_idx);
        mdl = fitglm(state(train_idx,:),fr(train_idx),'Distribution','Poisson');
        
        glm_fits(i_unit,:) = mdl.Coefficients.Estimate;
        
        % get pR2 for each neuron
        pr2_fits(i_unit,2) = compute_pseudo_R2(fr(test_idx,:), predict(mdl,state(test_idx,:)),mean(fr(test_idx,:)));
        pr2_fits(i_unit,1) = compute_pseudo_R2(fr(train_idx,:), predict(mdl,state(train_idx,:)),mean(fr(train_idx,:)));
    end
    
%% get histogram of pr2 and heatmap of predicted firing rates for an example neuron (speed and direction vs FR)
    figure();
    histogram(pr2_fits(:,2)) % pr2_fits is (train, test)
    xlabel('Pseudo R2');
    ylabel('Proportion of neurons');
    formatForLee(gcf); set(gca,'fontsize',14);
    
    i_unit = 1530;
    speed_grid = 0:1:max(td.speed);
    dir_grid = -180:10:180;
    fr_grid = zeros(numel(speed_grid),numel(dir_grid));
    
    for i_speed = 1:numel(speed_grid)
        for i_dir = 1:numel(dir_grid)
            % constant, hand(x,y) position, hand (x,y) vel, speed
            curr_vel = speed_grid(i_speed)*[cos(deg2rad(dir_grid(i_dir))), sin(deg2rad(dir_grid(i_dir)))];
            curr_state = [median(td.pos(:,:)), curr_vel, speed_grid(i_speed)];
            fr_grid(i_speed,i_dir) = glmval(glm_fits(i_unit,:)',curr_state,'log','Constant','on');
        end
    end
    
    figure();
    imagesc(fr_grid);
    xlabel('Direction (degrees)');
    ylabel('Speed (cm/s)');
    b=colorbar;
    b.Label.String = 'Firing rate (sp/s)';
    formatForLee(gcf);
    set(gca,'fontsize',14);
    
    
%% analyze structure of map
    % get PDs
    pd_params = [];
    pd_params.out_signals = 'VAE_firing_rates';
    pd_params.in_signals = {'vel'};
    pd_params.num_boots = 0;
    splitParams.split_idx_name = 'idx_startTime';
    splitParams.linked_fields = {'trialID','result'};
    bin_edges = [0:0.2:2*pi];
    
    td_reward = splitTD(td,splitParams);
    td_reward = td_reward([td_reward.result]=='R');
    pd_table = getTDPDs(td_reward, pd_params);

    
% plot polar histogram of PDs and map of PDs
    figure();
    polarhistogram(pd_table.velPD,bin_edges,'DisplayStyle','bar') % bar or stair. Stair is useful if plotting multiple
    title('PDs (degrees)');

    figure();
    pd_map = rad2deg(reshape(pd_table.velPD,map_dim));
    pd_map(pd_map<0) = pd_map(pd_map<0)+360; % convert to same limits as polarhistogram
    imagesc(pd_map);
    colormap(colorcet('C3'));
    b=colorbar;
    b.Label.String = 'PD (degrees)';
    b.Label.FontSize = 14;
    
    
%% get and plot PD differences for neighboring neurons and distant neurons -- TO DO
    shuffle_map_slightly = 0;
    % test PD neighborhood 
    nbor_input = [];
    nbor_input.nbor_max_r = 2.5; % blocks (or neurons away). Not a um distance
    % currently, r=2.5 makes the histogram match Weber et. al well. That
    % means 2.5 corresponds to ~150 um. 1 block ~= 0.06 mm
    
    nbor_input.nbor_min_r = 0;
    nbor_input.num_sample = 1000;
    % I wrote this function to handle arbitrary metrics instead of just PDs
    % if metric has multiple columns, function defaults to taking mean
    % difference across columns
    nbor_input.metric = pd_table.velPD; % if angle, assumes radians
    nbor_input.metric_is_angle = 1; % if the metric is an angle, flag this
    nbor_input.locs = locs;

    if(shuffle_map_slightly)
        n_swap = 200;
        for i = 1:n_swap
            swap_idx = datasample(1:1:numel(pd_table.velPD),2,'Replace',false);
            
            nbor_input.metric(swap_idx) = nbor_input.metric(flip(swap_idx),:);
        end
        
        figure();
        pd_map = rad2deg(reshape(nbor_input.metric,map_dim));
        pd_map(pd_map<0) = pd_map(pd_map<0)+360; % convert to same limits as polarhistogram
        imagesc(pd_map);
        colormap(colorcet('C3'));
        b=colorbar;
        b.Label.String = 'PD (degrees)';
        b.Label.FontSize = 14;
    end

    nbor_output = getNeighborMetric(nbor_input);

    bin_edges = [0:10:180];
    
    figure(); hold on;
    histogram(rad2deg(abs(nbor_output.diff(nbor_output.is_neigh==1))),bin_edges,...
        'EdgeColor',getColorFromList(1,1),'DisplayStyle','stairs','Normalization','probability','Linewidth',2);
    histogram(rad2deg(abs(nbor_output.diff(nbor_output.is_neigh==0))),bin_edges,...
        'EdgeColor',getColorFromList(1,0),'DisplayStyle','stairs','Normalization','probability','Linewidth',2);
    formatForLee(gcf);
    xlabel('PD Diff (degrees)');
    ylabel('Proportion of data');
    l=legend('Neighbor','Non-neighbor'); set(l,'box','off');
    set(gca,'fontsize',14)
    xlim([0,180]);
    
%% build decoder or load one in (Building can take awhile)
    build_decoder = 0;
    % if loading a decoder, fill these out. Otherwise ignore
    dec_path = 'D:\Lab\Data\StimModel'; % no file sep afterwards
    dec_fname = 'Han_20160315_RW_dec_bias_dropout91_fr6_5000iter_uniformTrain_dropout93_FR.mat';
    
    if(build_decoder==1)
        dec_input_data = [];
        dec_input_data.lr = 0.00001;
        dec_input_data.num_iters = 7500;
        dec_input_data.dropout_rate = 0.93;
        
        train_idx = datasample(1:1:size(td.VAE_firing_rates,1),ceil(0.85*size(td.VAE_firing_rates,1)),'Replace',false);
        
        dec_input_data.fr = td.VAE_firing_rates(train_idx,:);
        dec_input_data.hand_vel = td.vel(train_idx,:);
        
        dec_output_data = buildDecoderDropout(dec_input_data);
        dec = dec_output_data.dec; bias = dec_output_data.bias;
    else
        load([dec_path filesep dec_fname]);
    end
    
        td.pred_vel = predictData(td.VAE_firing_rates, dec, bias);
    vaf_pred = compute_vaf(td.vel, td.pred_vel)
%% use decoder to get predicted hand velocities
    figure();
    ax1=subplot(1,2,1); hold on;
    plot(td.vel(:,1), td.pred_vel(:,1),'.');
    plot([-30,30],[-30,30],'k--','linewidth',2);
    xlabel('Hand vel (cm/s)');
    ylabel('Pred hand vel (cm/s)');
    formatForLee(gcf); set(gca,'fontsize',14);
    
    ax2=subplot(1,2,2); hold on;
    plot(td.vel(:,2), td.pred_vel(:,2),'.');
    plot([-30,30],[-30,30],'k--','linewidth',2);
    formatForLee(gcf); set(gca,'fontsize',14);
    xlabel('Hand vel (cm/s)');
    ylabel('Pred hand vel (cm/s)');
    linkaxes([ax1,ax2],'xy');
    
%% compare decoder PD to PDs found using movement and an encoder
    if(exist('pd_table')==0)
        error('nothing was done. Need to compute PDs from above');
    end

    PD_dec_diff = rad2deg(angleDiff(pd_table.velPD, atan2(dec(:,2),dec(:,1)),1));
    bin_edges = [0:10:180];

    figure();
    histogram(abs(PD_dec_diff),bin_edges,'Normalization','probability')
    xlabel('Absolute difference between PDs (degrees)');
    ylabel('Proportion of neurons');
    formatForLee(gcf);
    set(gca,'fontsize',14);

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% run stimulation experiments %%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Experiment 1 : 
% How does the direction of stim effect compare to the PD of the stimulated
% location during single electrode stimulation?

    % Independent Variables: Amplitude, Activation Function, Frequency. 

    % Dependent Variables : Direction and magnitude of stim effect,
    % measured from predicted hand velocity from the linear decoder

    % Will do simulations for multiple locations, can then sanity check
    % with a neighborhood metric.
    % Will also do simulations for multiple hand kinematics, which will
    % affect firing rate of neurons, and thus the effect of stim.
    
    amp_input_data = [];
    amp_input_data.amps_test = [15,30,50,100]; % uA
    amp_input_data.acts_test = {'exp_decay'};
    amp_input_data.freqs_test = [100,200]; % Hz
    amp_input_data.train_length = [1.0]; % in s 

    amp_input_data.n_locs = 40;
    amp_input_data.n_moves = 40;
    
    amp_input_data.td = td;
    amp_input_data.locs = locs*0.06; % block size is 0.06 mm currently.
    amp_input_data.dec = dec;
    
    amp_output_data = runSingleElectrodeLocationExperiment(amp_input_data);
    
%% look at how activated population compares to stimulation location PD
    % compare across amplitudes and activation functions. 
    
    % get neuron idx for each stimulation
    stim_idx = getStimLocationIdx(amp_output_data.stim_loc,amp_output_data.locs);
    
    stim_PD = pd_table.velPD(stim_idx);
    PD_diff_stim_loc = stim_PD - pd_table.velPD';
    
    % remove stimulation location
    PD_diff_stim_loc = makeStimLocationNan(PD_diff_stim_loc,stim_idx, size(locs,1));

    % mask PD diff for neurons that were active only.
    PD_diff_act = PD_diff_stim_loc.*(amp_output_data.num_pulses_active > 0);

    figure('Position',[680 558 900 420]);
    for i_act = 1:numel(amp_input_data.acts_test)
        subplot(1,numel(amp_input_data.acts_test),i_act); hold on;
        for i_amp = 1:numel(amp_input_data.amps_test)
            act_func_mask = strcmpi(amp_output_data.act_func,amp_input_data.acts_test{i_act})==1;
            amp_mask = amp_output_data.amp_list == amp_input_data.amps_test(i_amp);
            num_pulses_active_cond = amp_output_data.num_pulses_active(act_func_mask & amp_mask, :);
            PD_diff_cond = PD_diff_act(act_func_mask & amp_mask, :);
                        
            PD_diff_list = rad2deg(abs(PD_diff_cond(num_pulses_active_cond > 0)));
            num_active_list = num_pulses_active_cond(num_pulses_active_cond > 0);
            
            PD_diff_list = repelem(PD_diff_list,num_active_list);
            
            histogram(PD_diff_list,0:10:180,'DisplayStyle','stairs','EdgeColor',getColorFromList(1,i_amp-1),'linewidth',2,'Normalization','Probability');
        end
        formatForLee(gcf);
        set(gca,'fontsize',14);
        if(i_act==1)
            xlabel('|Activated PD - Stimulated PD| (degrees)');
            ylabel('Proportion of activated neurons');
            l=legend(num2str(amp_input_data.amps_test'));
            set(l,'box','off');
        end
    end
    
    clear PD_diff_list; clear act_func_mask; clear amp_mask; clear num_pulses_active_cond; clear PD_diff_cond; clear num_active_list;
 
    %%
    % compare similarity between activated population against some neighborhood
    % metric. The goal here is to simply show that being in the middle of a
    % cluster is better than being near the edge. Also, some variance among
    % the similarity of the activated population would be nice.
    
    % for each sim, compute a similarity between activated population and
    % stim location. Also compute a similarity between neighbors and stim
    % location
    
    sim_input_data = amp_output_data;
    sim_input_data.metric_name = 'PD';
    sim_input_data.PD = pd_table.velPD; % PD must be in radians!
    sim_input_data.is_ang = 1;
    
    act_pop_similarity = getActivatedPopulationSimilarity(sim_input_data);
   
    sim_input_data.nbor_max_r = 0.3; % in mm
    sim_input_data.nbor_min_r = 0;
    
    neighbor_similarity = getNeighborsSimilarity(sim_input_data);
    
    subplot_counter = 1;
    figure();
    ax_list = [];
    for i_act = 1:numel(amp_input_data.acts_test)
        for i_amp = 1:numel(amp_input_data.amps_test)
            ax_list(end+1)=subplot(numel(amp_input_data.acts_test),numel(amp_input_data.amps_test),subplot_counter); hold on;
            act_func_mask = strcmpi(amp_output_data.act_func,amp_input_data.acts_test{i_act})==1;
            amp_mask = amp_output_data.amp_list == amp_input_data.amps_test(i_amp);
            
            plot(neighbor_similarity(act_func_mask & amp_mask), act_pop_similarity(act_func_mask & amp_mask),'.');
            
            subplot_counter = subplot_counter + 1;
            
            if(i_amp == 1 && i_act == 1)
                xlabel('Neighbor Similarity');
                ylabel('Activated Population Similarity');
            end
            formatForLee(gcf);
            set(gca,'fontsize',14);
        end
    end
    
    linkaxes(ax_list,'xy');
%% look at how effect of stimulation compares to PDs of stimulation location
    
    stim_idx = getStimLocationIdx(amp_output_data.stim_loc,amp_output_data.locs);
    stim_PD = pd_table.velPD(stim_idx);
    
    stim_vel = squeeze(mean(amp_output_data.stim_vel,2));
    stim_ang = atan2(stim_vel(:,2),stim_vel(:,1));
    
    figure();

    subplot_counter = 1;
    ax = [];
    max_edge = pi;
    for i_act = 1:numel(amp_input_data.acts_test)
        for i_amp = 1:numel(amp_input_data.amps_test)
            ax(end+1) = subplot(numel(amp_input_data.acts_test),numel(amp_input_data.amps_test),subplot_counter); hold on;
            act_func_mask = strcmpi(amp_output_data.act_func,amp_input_data.acts_test{i_act})==1;
            amp_mask = amp_output_data.amp_list == amp_input_data.amps_test(i_amp); 
            mask = act_func_mask & amp_mask;
            
            h=histogram(angleDiff(stim_PD(mask),stim_ang(mask),1,0));
            max_edge = max(h.BinEdges);
            subplot_counter = subplot_counter + 1;
            
            if(i_act==1 && i_amp == 1)
                xlabel('Stim direction relative to PD (radians)');
                ylabel('Number of trials');
            end
            formatForLee(gcf);
            set(gca,'fontsize',14);
        end
    end
    
    linkaxes(ax,'xy');
    xlim([0,max_edge]);
    
    
%% Experiment 2 : Classify movements in one of two directions (can rotate axis)
% then stimulate and look at bias in classification 
% this is pretty close to recreating Tucker's experiments
    shuffle_map = 0;
    class_input = [];

    class_input.n_stim_elec = 4;
    class_input.amps_test = [30]; % uA
    class_input.act_func = 'exp_decay';
    class_input.freq = [100]; % Hz
    class_input.n_locs = 1; % number of different stimulation sets per target axis
    class_input.n_runs = 10; % number of target axes per array
    class_input.use_array = 0; % 1 to drop a fake array; 0 to use all blocks
    class_input.elec_spacing = 0.4; % mm, electrode spacing for the array
    class_input.block_size = 0.06; % mm
    class_input.locs = locs*class_input.block_size; 
    class_input.bias = bias;
    
    pd_table_use = pd_table.velPD;
    dec_use = dec;
    td_use = td;
    if(shuffle_map)
        n_swap = 200;
        for i = 1:n_swap
            swap_idx = datasample(1:1:numel(pd_table.velPD),2,'Replace',false);
            pd_table_use(swap_idx) = pd_table_use(flip(swap_idx),:);
            dec_use(swap_idx,:) = dec_use(flip(swap_idx),:);
            td_use.VAE_firing_rates(:,swap_idx) = td_use.VAE_firing_rates(:,flip(swap_idx));
        end
        
    end
    
    class_input.dec = dec_use;
    class_input.td = td_use;
    class_input.PD = pd_table_use;
    class_input.PD_tol = 22.5; % degrees
    
    class_input.move_len = 0.5; % s
    class_input.in_sig = 'pred_vel';
    class_input.min_sig = 1;
    class_input.max_sig = 20;
    class_input.n_train = 75;
    class_input.n_test = 1000;
    class_input.classifier_name = 'bayes';
        
    
    [class_output_data] = simulatePerceptualEffectStimulation(class_input);
    


% make psychophysical curves for each run
    class_plot.bin_edges = 0:10:180; % in degrees
    
    figs = makePsychCurves(class_output_data,class_plot);
    
    
        
    
    
    
    
    
    
    
    