%% load file
filename = 'Han_201603015_RW_SmoothKin_50ms.mat';

%Nathan's mac path
pathname = '~/Documents/Documents/Thesis_Seminar/Model/data/';

%Joe's windows path
%pathname = 'D:\Lab\Data\StimModel';

load([pathname filesep filename]);



%% load in firing rates
%fr_file = 'vae_rates_Han_20160325_RW_dropout90_lambda1_learning5e-05_n-epochs1500_n-neurons1600_2021-03-02-032351.csv';
%fr_file = 'vae_rates_Han_20160325_RW_dropout95_lambda1_learning5e-05_n-epochs1500_n-neurons1600_2021-03-02-032351.csv';
%fr_file = 'firing_rates_20210223.csv';
fr_file = 'vae_rates_Han_20160325_RW_dropout70_lambda1.0_learning1e-06_n-epochs5000_n-neurons1600_2021-03-07-142347.csv';
%make firing rate array
firing_rates = readtable([pathname,filesep, fr_file]);
firing_rates = firing_rates{:,:};

%add to td
td.VAE_firing_rates = firing_rates(:,:);

% map dimensions
map = sqrt(numel(firing_rates(1,:)));
map = [map map];

%% IF USING PARTIAL DATA SET: cut off first elements of td to match td time bins with firing_rates
% td.acc(1:30000,:) = [];
% td.pos(1:30000,:) = [];
% td.vel(1:30000,:) = [];
% td.joint_vel(1:30000,:) = [];
% td.S1_spikes(1:30000,:) = [];
% td.speed(1:30000,:) = [];
% td.vel_rect(1:30000,:) = [];
%% match up data lengths

field_len = length(td.vel);
td_fieldnames = fieldnames(td);
[~,mask] = rmmissing(td.vel);

for i_field = 1:numel(td_fieldnames)
    if(length(td.(td_fieldnames{i_field})) == field_len)
        td.(td_fieldnames{i_field}) = td.(td_fieldnames{i_field})(mask==0,:);
    end
end


%% find lagged firing rates 
fr = td.VAE_firing_rates;
fr_lagged = fr;
num_lags = 0;
for i=1:num_lags
    fr_lag = circshift(fr,i);
    fr_lagged = [fr_lagged,fr_lag];
end
%% find decoder predictors of hand velocities from firing rates
hand_vel = td.vel;

dec = fr_lagged\hand_vel;
%% find predicted hand velocities using firing rates
% A*dec = b, A\b = dec
hand_vel_hat = fr_lagged*dec;
td.hand_vel_hat = td.dec_vel;

figure();set(gcf,'Color','White')
plot(hand_vel(:,1),hand_vel_hat(:,1),'.')
ylabel('Decoded hand velocity (cm/s)')
xlabel('Hand velocity (cm/s)')

%% split tds
%Split TD
splitParams.split_idx_name = 'idx_startTime';
splitParams.linked_fields = {'trialID','result'};
td_trim = splitTD(td,splitParams);

% trim tds
% td_trim = trimTD(td_trim,{'idx_startTime',15},{'idx_startTime',30});

%% get rid of non-reward trials
x=[td_trim.result]=='R';
td_trim = td_trim(x);

%% plot reaches
% for trial= 1:length(td_trim)
%     reach = plot(td_trim(trial).pos(:,1),td_trim(trial).pos(:,2));
%     hold on
% end
% hold off

%% calculate PDs for signals
%call model output signals for this
params.out_signals = 'VAE_firing_rates';
params.in_signals = {'vel'};
params.num_boots = 0;
pdtable = getTDPDs(td_trim, params);

pdtable =rad2deg(pdtable.velPD);
pdtable(pdtable<0) = pdtable(pdtable<0)+360;
figure();
hist(pdtable);
pdtable =reshape(pdtable, map);

for n = 1:numel(dec(:,1))
    pdtable_decoded(n) = atan2(dec(n,2), dec(n,1));
end

pdtable_decoded =rad2deg(pdtable_decoded);
pdtable_decoded(pdtable_decoded<0) = pdtable_decoded(pdtable_decoded<0)+360;
figure();
hist(pdtable_decoded);
pdtable_decoded =reshape(pdtable_decoded, map);

%% histogram of angular differences
for x = 1:numel(pdtable)
    PDdiff(x) = pdtable(x)-pdtable_decoded(x);
end
figure();set(gcf,'Color','White')
hist(PDdiff)
title('Difference between actual PDs and decoder PDs')
xticks([-180 0 180])
xlabel('Angular difference (actual - decoded = difference)')

%% Circular Histogram of PDs
figure();set(gcf,'Color','White');
theta = deg2rad(pdtable);
theta = reshape((theta).', 1, []);
his = polarhistogram(theta, 36);
title('Histogram of PDs')

%% Put PDs in 30x30 heatmap
figure();set(gcf,'Color','White');
fig = heatmap(pdtable);set(gcf,'Color','White');
fig.CellLabelColor = 'none';
% jet_wrap = vertcat(jet,flipud(jet));
fig.Colormap = hsv;
fig.Title='Heatmap of PDs from 40x40 area 2 neurons';
fig.GridVisible = 'off';

%% Get grid of X and Y coords for 30
clear neuron_location
num_rows = map(1);
num_cols = map(2);
[i,j] = ind2sub([num_rows,num_cols],1:num_rows*num_cols);
neuron_location(:,1) = i';
neuron_location(:,2) = j';

%% Select neuron to stim and calculate radius of activation

%select stim params
neuron = [338]; %number from 1-900
current = [20 60 100]; %current in µA
k = 1292; %space constant in µA/mm^2
clear rad;
for i = 1:numel(current)
    r(i) = sqrt(current(i)/k); %radius in mm
    rad(i) = round(r(i)*10); %arbitrary radius of neural squares activated - given each neuron is 0.1 mm from each other 
end

for ns = 1:numel(neuron)
    i(ns) = neuron_location(neuron(ns),1);
    j(ns) = neuron_location(neuron(ns),2);
end
clear activate
for x =1:numel(rad)
    for n = 1:numel(neuron_location(:,1))
        for ns = 1:numel(neuron)
            if sqrt((neuron_location(n,1) - i(ns))^2 + (neuron_location(n,2)-j(ns))^2) <= rad(x)
                activate(x,ns).neuron(n) = 1;
            else
                activate(x,ns).neuron(n) = 0;
            end
        end
    end
end
clear activated
for x=1:numel(rad)
    for ns = 1:numel(neuron)
        activated(x,ns).rad= find(activate(x,ns).neuron);
    end
end


%% activate neurons for a specific movement to a certain Hz
trial =[222 830 27]; %chose trial 
hz = 0.65; %firing rates from file (x spikes per bin)
binSize = 0.050; %bin size in seconds
rates_inHz = hz/binSize; %converting to firing rate to Hz  ~15 Hz for now
startMove_idx = 10; %time you want to start movement
stimStart_idx = 12; %time you want to start stim at
stimLength_idx =stimStart_idx + 4; %how many bins you want to stim to last (4 bins @ 50 ms = 200 ms)
stimEnd_idx = stimLength_idx + 1; %time of start post-stim movement 
endMove_idx = 23; %time you want to end movement

% plot movement reach
for x = 1:numel(trial)
    figure();set(gcf,'Color','White');
    plot(td_trim(trial(x)).pos(startMove_idx:endMove_idx,1),td_trim(trial(x)).pos(startMove_idx:endMove_idx,2));
    hold on
    plot(td_trim(trial(x)).pos(startMove_idx, 1),td_trim(trial(x)).pos(startMove_idx,2), '*')
    plot(td_trim(trial(x)).pos(stimStart_idx, 1),td_trim(trial(x)).pos(stimStart_idx,2), '*')
    plot(td_trim(trial(x)).pos(stimEnd_idx, 1),td_trim(trial(x)).pos(stimEnd_idx,2), '*')
    plot(td_trim(trial(x)).pos(endMove_idx, 1),td_trim(trial(x)).pos(endMove_idx,2), '*')
    title('Hand Position During Movement Window')
    xlabel('x-hand position')
    ylabel('y-hand position')
    legend('movement', 'starting point', 'stim start', 'stim end' , 'end point', 'Location', 'northwest')
end

%%
current = [current current current];
for x = 1:numel(trial)
    for n = 1:numel(activated)
        td_stim = td_trim; % resets previous stim
        for p = 1:numel(activated(n).rad)
            td_stim(trial(x)).VAE_firing_rates(stimStart_idx:stimLength_idx,activated(n).rad(p)) = hz;
        end
        during_stim = reshape(td_stim(trial(x)).VAE_firing_rates(stimStart_idx,:), map);
        figure();set(gcf,'Color','White');
        heatmap(during_stim, 'GridVisible', 'off');
        title('Firing Rates during stim for different activation currents ' + string(current(n)) + ' µA')
    end
end
%% heatmap of pre-stim firing rates, stim firing rates, and post-stim firing rates using best current 
% Make sure to redo above section with best current if multiple (pick one in current array)
for t = 1:numel(trial)
    pre_stim = reshape(td_stim(trial(t)).VAE_firing_rates(startMove_idx,:), map);
    during_stim = reshape(td_stim(trial(t)).VAE_firing_rates(stimStart_idx,:), map);
    post_stim = reshape(td_stim(trial(t)).VAE_firing_rates(stimEnd_idx,:), map);
    
    figure();set(gcf,'Color','White');
    heatmap(pre_stim,'GridVisible', 'off');
    title('Firing rates before stim')
    caxis([0 hz])
    figure();set(gcf,'Color','White');
    heatmap(during_stim, 'GridVisible', 'off');
    title('Firing rates during stim')
    caxis([0 hz])
    figure();set(gcf,'Color','White');
    heatmap(post_stim, 'GridVisible', 'off');
    title('Firing rates after stim')
    caxis([0 hz])
end




%% Use decoder predictors to change velocity, compute movement output from velocities
td_ex = td_trim; %example td
for x = 1:numel(trial)
    hold off
    for ns = 1:numel(activated(1,:))
            figure();set(gcf,'Color','White');
        for n = 1:numel(activated(:,1))
            td_stim = td_trim; % resets previous stim
            for p = 1:numel(activated(n,ns).rad)
                td_stim(trial(x)).VAE_firing_rates(stimStart_idx:stimLength_idx,activated(n,ns).rad(p)) = hz;
            end
            td_ex(trial(x)).vel(startMove_idx:endMove_idx,:) = td_trim(trial(x)).VAE_firing_rates(startMove_idx:endMove_idx,:)*dec; %regular decoded hand vel
            td_stim(trial(x)).vel(startMove_idx:endMove_idx,:) = td_stim(trial(x)).VAE_firing_rates(startMove_idx:endMove_idx,:)*dec; %stim decoded hand vel
            for time = stimStart_idx:stimLength_idx
                td_stim(trial(x)).pos(time,1) = td_stim(trial(x)).pos(time-1,1) + (td_stim(trial(x)).vel(time,1)*binSize);%stim effect on hand pos in x dir
                td_stim(trial(x)).pos(time,2) = td_stim(trial(x)).pos(time-1,2) + (td_stim(trial(x)).vel(time,2)*binSize);%stim effect on hand pos in y dir
                td_ex(trial(x)).pos(time,1) = td_ex(trial(x)).pos(time-1,1) + (td_ex(trial(x)).vel(time,1)*binSize);%stim effect on hand pos in x dir
                td_ex(trial(x)).pos(time,2) = td_ex(trial(x)).pos(time-1,2) + (td_ex(trial(x)).vel(time,2)*binSize);%stim effect on hand pos in y dir
            end
            plot(td_stim(trial(x)).pos(startMove_idx:endMove_idx,1),td_stim(trial(x)).pos(startMove_idx:endMove_idx,2)) %plot stim of decoded movement
            hold on
            title('Hand Position and the Effect of ICMS neuron ' + string(neuron(ns)))
        end
        plot(td_trim(trial(x)).pos(startMove_idx:endMove_idx,1),td_trim(trial(x)).pos(startMove_idx:endMove_idx,2), 'k') %plot actual movement
        plot(td_ex(trial(x)).pos(startMove_idx:endMove_idx,1),td_ex(trial(x)).pos(startMove_idx:endMove_idx,2), 'r') %plot decoded movement
        legend('effect of stim on movement ' + string(current(n-2)) + ' µA)','effect of stim on movement ' + string(current(n-1)) + ' µA','effect of stim on movement ' + string(current(n)) + ' µA',  'actual movement', 'decoded movement', 'Location', 'northwestoutside')
        xlabel('X-hand position (cm)')
        ylabel('Y-hand position (cm)')
    end
end

  

% Plots of hand vel
% figure();
% plot(td_trim(trial).vel(startMove_idx:endMove_idx,1), 'r')
% hold on
% plot(td_stim(trial).vel(startMove_idx:endMove_idx,1), 'b')
% plot((stimStart_idx-startMove_idx+1):(stimLength_idx - startMove_idx+1),td_stim(trial).vel(stimStart_idx:stimLength_idx,1),'*')
% title('Hand x-velocity (cm/s)')
% legend('without stim', 'with stim', 'stim period')
% 
% figure();
% plot(td_trim(trial).vel(startMove_idx:endMove_idx,2), 'r')
% hold on
% plot(td_stim(trial).vel(startMove_idx:endMove_idx,2), 'b')
% plot((stimStart_idx-startMove_idx+1):(stimLength_idx - startMove_idx+1),td_stim(trial).vel(stimStart_idx:stimLength_idx,2),'*')
% title('Hand y-velocity(cm/s)')
% legend('without stim', 'with stim', 'stim period')




