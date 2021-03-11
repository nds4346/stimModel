%% load file
filename = 'Han_201603015_RW_SmoothKin_50ms.mat';

%Nathan's mac path
  pathname = '~/Documents/Documents/Thesis_Seminar/Model/data/';

%Joe's windows path
%pathname = 'D:\Lab\Data\StimModel';

load([pathname filesep filename]);

rel= version('-release');
is_old_matlab = str2num(rel(1:4)) < 2018;

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
% perform dropout reguralization
lr = 0.01;
dec = rand(size(fr_lagged,2),2)-0.5;
bias = [0,0];
num_iters = 400;
dropout_rate = 0.8;

vaf_list_drop = zeros(num_iters,2);
vaf_list_mdl = zeros(num_iters,2);
n_neurons = size(fr_lagged,2);
for i_iter = 1:num_iters
    % dropout inputs
    keep_mask = zeros(n_neurons,1);
    keep_mask(datasample(1:1:n_neurons,ceil(n_neurons*(1-dropout_rate)))) = 1;
    x = (fr_lagged.*keep_mask');
    
    vel_pred = x*dec + bias;
    
    d_dec = -2*x'*(hand_vel-vel_pred)/length(dec);
    d_bias = mean(-2*(hand_vel-vel_pred));
    
    bias = bias - lr*d_bias;
    dec = dec - lr*d_dec;
    
    vaf_list_drop(i_iter,:) = compute_vaf(hand_vel,vel_pred);
    vaf_list_mdl(i_iter,:) = compute_vaf(hand_vel,(fr_lagged*dec)*(1-dropout_rate) + bias);
end
% adjust dec to deal with dropout rate
dec = dec*(1-dropout_rate);

%% predict hand velocity and get vaf

hand_vel_hat = fr_lagged*dec;  % + bias;
vaf_pred = compute_vaf(hand_vel,hand_vel_hat);
b = hand_vel_hat\hand_vel;
%% find predicted hand velocities using firing rates
% A*dec = b, A\b = dec
td.hand_vel_hat = hand_vel_hat;

figure();set(gcf,'Color','White')
subplot(1,2,1)
plot(hand_vel(:,1),hand_vel_hat(:,1),'.')
hold on;
plot([-30,30],[-30,30],'k--');
ylabel('Decoded hand x-velocity (cm/s)')
xlabel('Hand -velocity (cm/s)')
subplot(1,2,2)
plot(hand_vel(:,2),hand_vel_hat(:,2),'.')
hold on;
plot([-30,30],[-30,30],'k--');
ylabel('Decoded hand y-velocity (cm/s)')
xlabel('Hand y-velocity (cm/s)')

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
% params.out_signals = 'VAE_firing_rates';
% params.in_signals = {'vel'};
% params.num_boots = 0;
% pdtable = getTDPDs(td_trim, params);
% 
% pdtable =rad2deg(pdtable.velPD);
% pdtable(pdtable<0) = pdtable(pdtable<0)+360;
% figure();
% hist(pdtable);
% pdtable =reshape(pdtable, map);

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
    PDdiff(x) = angleDiff(pdtable(x),pdtable_decoded(x),0);
end
figure();set(gcf,'Color','White')
hist(PDdiff,20)
title('Difference between actual PDs and decoder PDs')
xticks([-180 0 180])
xlabel('Angular difference (actual - decoded = difference)')

%% Circular Histogram of PDs
figure();set(gcf,'Color','White');
theta = deg2rad(pdtable_decoded);
theta = reshape((theta).', 1, []);
his = polarhistogram(theta, 36);
title('Histogram of PDs')

%% Put PDs in 30x30 heatmap
figure();set(gcf,'Color','White');
if(~is_old_matlab)
    fig = heatmap(pdtable_decoded);set(gcf,'Color','White');
    fig.CellLabelColor = 'none';
    % jet_wrap = vertcat(jet,flipud(jet));
    fig.Colormap = hsv;
    fig.Title='Heatmap of PDs from 40x40 area 2 neurons';
    fig.GridVisible = 'off';
else
    fig = imagesc(pdtable_decoded);
    colormap(hsv);
    colorbar;
end
%% Get grid of X and Y coords for 30
clear neuron_location
num_rows = map(1);
num_cols = map(2);
[i,j] = ind2sub([num_rows,num_cols],1:num_rows*num_cols);
neuron_location(:,1) = i';
neuron_location(:,2) = j';


%% divide neurons into sections based on closest PDs
clear PD
pdDirs = [ 0 45 90 135 180 225 270 315 360];
for neur = 1:numel(pdtable_decoded)
    for dir = 1:numel(pdDirs)
        if pdtable_decoded(neur) > (pdDirs(dir) - 12.5) && pdtable_decoded(neur) < (pdDirs(dir) + 12.5)
            PD(dir, neur) = pdtable_decoded(neur);
        else
            PD(dir, neur) = 0;
        end
    end
end
PD= PD';

pd0 = find(PD(:,1) | PD(:,9));
pd45 = find(PD(:,2));
pd90 = find(PD(:,3));
pd135 = find(PD(:,4));
pd180 = find(PD(:,5));
pd225 = find(PD(:,6));
pd270 = find(PD(:,7));
pd315 = find(PD(:,8));

%% Select neuron to stim and calculate radius of activation
% select random neurons based on PD

neuron = [randsample(pd135,1)]; % randsample(pd0,1),randsample(pd45,1),randsample(pd90,1),,randsample(pd180,1),randsample(pd225,1),randsample(pd270,1),randsample(pd315,1)];

%select stim params
current = [15 50 100]; %current in �A
k = [0.100, 0.325,   0.500]; %space constant in mm
clear rad;

%% activate using stoney circle activation
k = 1296; %space constant in mm
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

%% activate using probabalistic exponential decay

clear P_act
clear activate
for x =1:numel(current)
    for n = 1:numel(neuron_location(:,1))
        for ns = 1:numel(neuron)
            dis(n) = (sqrt((neuron_location(n,1) - i(ns))^2 + (neuron_location(n,2)-j(ns))^2)/10);
            P_act(ns,x).spaceP(1,n) = exp(-dis(n)/k(x));
        end
    end
end


for x =1:numel(current) 
    for n = 1:numel(neuron_location(:,1)) %total neuron number
        for ns = 1:numel(neuron) %stim neuron number
            activator = rand(1);
            if activator < P_act(ns,x).spaceP(n)
                activate(x,ns).neuron(n) = 1;
            else
                activate(x,ns).neuron(n) = 0;
            end
        end
    end
end

clear activated
for x=1:numel(current)
    for ns = 1:numel(neuron)
        activated(x,ns).rad= find(activate(x,ns).neuron);
    end
end
              
                



%% activate neurons for a specific movement to a certain Hz
trial =[ 30 ]; %chose trial 
hz = 0.65; %firing rates from file (x spikes per bin)
binSize = 0.050; %bin size in seconds
rates_inHz = hz/binSize; %converting to firing rate to Hz  ~15 Hz for now
startMove_idx = 18; %time you want to start movement 3
stimStart_idx = startMove_idx + 1; %time you want to start stim at 4
stimLength_idx =stimStart_idx + 4; %how many bins you want to stim to last (4 bins @ 50 ms = 200 ms)
stimEnd_idx = stimLength_idx + 1; %time of start post-stim movement 
endMove_idx = stimEnd_idx + 1 ; %time you want to end movement 10

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

%% Plot radius of activation of different stim currents during movements

for x = 1:numel(trial)
    for n = 1:numel(activated)
        td_stim = td_trim; % resets previous stim
        for p = 1:numel(activated(n).rad)
            td_stim(trial(x)).VAE_firing_rates(stimStart_idx:stimLength_idx,activated(n).rad(p)) = hz;
        end
        during_stim = reshape(td_stim(trial(x)).VAE_firing_rates(stimStart_idx,:), map);
        figure();set(gcf,'Color','White');
        if(~is_old_matlab)
            heatmap(during_stim, 'GridVisible', 'off','Colormap', parula);
        else
            imagesc(during_stim);
            colorbar;
        end
        title('Firing Rates during stim for different activation currents ')
    end
end
%% heatmap of pre-stim firing rates, stim firing rates, and post-stim firing rates using best current 
% Make sure to redo above section with best current if multiple (pick one in current array)
for t = 1:numel(trial)
    pre_stim = reshape(td_stim(trial(t)).VAE_firing_rates(startMove_idx,:), map);
    during_stim = reshape(td_stim(trial(t)).VAE_firing_rates(stimStart_idx,:), map);
    post_stim = reshape(td_stim(trial(t)).VAE_firing_rates(stimEnd_idx,:), map);
    
    figure();set(gcf,'Color','White');
    if(~is_old_matlab)
        heatmap(pre_stim,'GridVisible', 'off','Colormap', parula);
    else
        imagesc(pre_stim);
    end
    title('Firing rates before stim')
    caxis([0 hz])
    figure();set(gcf,'Color','White');
    if(~is_old_matlab)
        heatmap(during_stim, 'GridVisible', 'off','Colormap', parula);
    else
        imagesc(during_stim);
    end
    title('Firing rates during stim')
    caxis([0 hz])
    figure();set(gcf,'Color','White');
    if(~is_old_matlab)
        heatmap(post_stim, 'GridVisible', 'off','Colormap', parula);
    else
        imagesc(post_stim);
    end
    title('Firing rates after stim')
    caxis([0 hz])
end


%% plot decoded movement
td_ex = td_trim; %example td

for x = 1:numel(trial)
    figure;
%     td_ex(trial(x)).vel(startMove_idx:endMove_idx,:) = td_ex(trial(x)).VAE_firing_rates(startMove_idx:endMove_idx,:) * dec + bias; %regular decoded hand vel
    plot(td_trim(trial(x)).pos(startMove_idx:endMove_idx,1),td_trim(trial(x)).pos(startMove_idx:endMove_idx,2), 'k') %plot actual movement
    hold on;
    for time = startMove_idx+1:endMove_idx
        td_ex(trial(x)).pos(time,1) = td_ex(trial(x)).pos(time-1,1) + (td_ex(trial(x)).hand_vel_hat(time-1,1)*binSize);%stim effect on hand pos in x dir
        td_ex(trial(x)).pos(time,2) = td_ex(trial(x)).pos(time-1,2) + (td_ex(trial(x)).hand_vel_hat(time-1,2)*binSize);%stim effect on hand pos in y dir
    end
    plot(td_ex(trial(x)).pos(startMove_idx:endMove_idx,1),td_ex(trial(x)).pos(startMove_idx:endMove_idx,2), 'r') %plot decoded movement
    legend('actual movement', 'decoded movement', 'Location', 'northwest')
end

%% Use decoder predictors to change velocity, compute movement output from velocities
td_ex = td_trim; %example td
close all
for x = 1:numel(trial) %number of trials
    hold off
    for ns = 1:numel(activated(1,:)) %number of neuron inputs
            figure();set(gcf,'Color','White');
        for n = 1:numel(activated(:,1)) %number of current inputs
            td_stim = td_trim; % resets previous stim
            for p = 1:numel(activated(n,ns).rad)
                td_stim(trial(x)).VAE_firing_rates(stimStart_idx:stimLength_idx,activated(n,ns).rad(p)) = hz;
            end
%             td_ex(trial(x)).vel(startMove_idx:endMove_idx,:) = td_ex(trial(x)).VAE_firing_rates(startMove_idx:endMove_idx,:) * dec +bias; %regular decoded hand vel
            td_stim(trial(x)).hand_vel_hat(startMove_idx:endMove_idx,:) = td_stim(trial(x)).VAE_firing_rates(startMove_idx:endMove_idx,:)* dec + bias; %stim decoded hand vel
            for time = startMove_idx:endMove_idx
                td_stim(trial(x)).pos(time,1) = td_stim(trial(x)).pos(time-1,1) + (td_stim(trial(x)).hand_vel_hat(time-1,1)*binSize);%stim effect on hand pos in x dir
                td_stim(trial(x)).pos(time,2) = td_stim(trial(x)).pos(time-1,2) + (td_stim(trial(x)).hand_vel_hat(time-1,2)*binSize);%stim effect on hand pos in y dir
                td_ex(trial(x)).pos(time,1) = td_ex(trial(x)).pos(time-1,1) + (td_ex(trial(x)).hand_vel_hat(time-1,1)*binSize);%stim effect on hand pos in x dir
                td_ex(trial(x)).pos(time,2) = td_ex(trial(x)).pos(time-1,2) + (td_ex(trial(x)).hand_vel_hat(time-1,2)*binSize);%stim effect on hand pos in y dir
            end
            plot(td_stim(trial(x)).pos(startMove_idx:endMove_idx,1),td_stim(trial(x)).pos(startMove_idx:endMove_idx,2)) %plot stim of decoded movement
            hold on
            title('Hand Position and the Effect of ICMS neuron ' + string(neuron(ns)))
            moveDir(ns, n).stim(1:numel(startMove_idx:endMove_idx),1) = td_stim(trial(x)).pos(startMove_idx:endMove_idx,1); %set up for calculating move direction
            moveDir(ns,n).stim(1:numel(startMove_idx:endMove_idx),2) = td_stim(trial(x)).pos(startMove_idx:endMove_idx,2); %set up for calculating move direction
            moveDir(ns, n).decMove(1:numel(startMove_idx:endMove_idx),1) = td_ex(trial(x)).pos(startMove_idx:endMove_idx,1); %set up for calculating move direction
            moveDir(ns,n).decMove(1:numel(startMove_idx:endMove_idx),2) = td_ex(trial(x)).pos(startMove_idx:endMove_idx,2); %set up for calculating move direction
        end
        plot(td_trim(trial(x)).pos(startMove_idx:endMove_idx,1),td_trim(trial(x)).pos(startMove_idx:endMove_idx,2), 'k') %plot actual movement
        plot(td_ex(trial(x)).pos(startMove_idx:endMove_idx,1),td_ex(trial(x)).pos(startMove_idx:endMove_idx,2), 'g') %plot decoded movement
        legend(string(current(n-2)) + ' �A',string(current(n-1)) + ' �A',string(current(n)) + ' �A',  'actual movement', 'decoded movement', 'Location', 'northeastoutside')
        xlabel('X-hand position (cm)')
        ylabel('Y-hand position (cm)')
    end
end

%% compare PDs of activated neurons with evoked movement direction of stim

str = '#0072BD';
r = sscanf(str(2:end),'%2x%2x%2x',[1 3])/255;
str = '#D95319';
b = sscanf(str(2:end),'%2x%2x%2x',[1 3])/255;
str = '#EDB120';
g = sscanf(str(2:end),'%2x%2x%2x',[1 3])/255;
color = [r,b,g];

for ns = 1:numel(activated(1,:)) %number of neuron inputs
    figure();set(gcf,'Color','White');
    for n = 1:numel(activated(:,1)) %number of current inputs
        moveDir(ns,n).direction = atan2d((mean(moveDir(ns, n).stim(:,2))) - mean(moveDir(ns, n).decMove(:,2)),mean(moveDir(ns, n).stim(:,1)) - mean(moveDir(ns, n).decMove(:,1)));
        moveDir(ns,n).directionMove = atan2d((mean(moveDir(ns, n).stim(:,2))) ,mean(moveDir(ns, n).stim(:,1))) - atan2d(mean(moveDir(ns, n).decMove(:,2)), mean(moveDir(ns, n).decMove(:,1)));
        if moveDir(ns,n).direction < 0
            moveDir(ns,n).direction = moveDir(ns,n).direction + 360;
        end
%         if moveDir(ns,n).directionMove < 0
%             moveDir(ns,n).directionMove = moveDir(ns,n).directionMove + 360;
%         end
        for p = 1:numel(activated(n,ns).rad)
            PDcomp(ns,n).dirs(p) = pdtable_decoded(activated(n,ns).rad(p));
            PDcomp(ns,n).diff(p) = moveDir(ns,n).direction - PDcomp(ns,n).dirs(p);
            if PDcomp(ns,n).diff(p) < 0
                PDcomp(ns,n).diff(p) = PDcomp(ns,n).diff(p) + 360;
            end
        end
        histogram(PDcomp(ns,n).diff, 'BinWidth', 10, 'BinLimits', [0 360], 'FaceAlpha', 0, 'EdgeColor', color(((3*n)-2):((3*n)-2)+(numel(r)-1)), 'LineWidth', 2);
        title( 'Difference between direction of stimulation effect on decoded movement and PDs of activated neurons')
        xlabel('Difference in angles (stim - PD of neuron) in degrees')
        hold on
    end
    legend(string(current(n-2)) + ' �A', string(current(n-1)) + ' �A', string(current(n)) + ' �A')
end
for ns = 1:numel(activated(1,:)) %number of neuron inputs
    figure();set(gcf,'Color','White');
    for n = 1:numel(activated(:,1)) %number of current inputs
        plot(current(n), abs(moveDir(ns,n).directionMove),'*', 'MarkerEdgeColor', color(((3*n)-2):((3*n)-2)+(numel(r)-1)), 'MarkerSize', 50)
        title( 'Difference between decoded movement with stimulation and decoded movement without stimulation')
        xlabel('Different stimulation currents')
        ylabel('Difference in angles (stim movement - decoded movement) in degrees')
        xlim([0 120])
        hold on
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









