%% load file
filename = 'Han_201603015_RW_SmoothKin_50ms.mat';

%Nathan's mac path
pathname = '~/Documents/Documents/Thesis_Seminar/Model/data/';

%Joe's windows path
%pathname = 'D:\Lab\Data\StimModel';

load([pathname filesep filename]);



%% load in firing rates
%fr_file = 'vae_rates_Han_20160325_RW_dropout90_lambda1_learning5e-05_n-epochs1500_n-neurons1600_2021-03-02-032351.csv';
fr_file = 'vae_rates_Han_20160325_RW_dropout95_lambda1_learning5e-05_n-epochs1500_n-neurons1600_2021-03-02-032351.csv';
%fr_file = 'firing_rates_20210223.csv';
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

figure();
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

%% Circular Histogram of PDs
figure();set(gcf,'Color','White');
theta = deg2rad(pdtable);
theta = reshape((theta).', 1, []);
his = polarhistogram(theta, 36);
title('Histogram of PDs')

%% Put PDs in 30x30 heatmap


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
neuron = 435; %number from 1-900
current = [100]; %current in �A
k = 1292; %space constant in �A/mm^2
clear rad;
for i = 1:numel(current)
    r(i) = sqrt(current(i)/k); %radius in mm
    rad(i) = round(r(i)*10); %arbitrary radius of neural squares activated - given each neuron is 0.1 mm from each other 
end

i = neuron_location(neuron,1);
j = neuron_location(neuron,2);

for x =1:numel(rad)
    for n = 1:numel(neuron_location(:,1))
        if sqrt((neuron_location(n,1) - i)^2 + (neuron_location(n,2)-j)^2) < rad(x)
            activate(x,n) = 1;
        else
            activate(x,n) = 0;
        end
    end
end
clear activated
for x=1:numel(rad)
    activated(x).rad= find(activate(x,:));
end


%% activate neurons for a specific movement to a certain Hz
trial =[1]; %chose trial 
hz = 0.04; %firing rates from file (x spikes per bin)
binSize = 0.050; %bin size in seconds
rates_inHz = hz/binSize; %converting to firing rate to Hz 
startMove_idx = 10; %time you want to start movement
stimStart_idx = 20; %time you want to start stim at
stimLength_idx =stimStart_idx + 4; %how many bins you want to stim to last (4 bins @ 50 ms = 200 ms)
stimEnd_idx = stimLength_idx + 1; %time of start post-stim movement 
endMove_idx = 30; %time you want to end movement

% plot movement reach
for x = 1:numel(trial)
    figure();
    plot(td_trim(trial(x)).pos(startMove_idx:endMove_idx,1),td_trim(trial(x)).pos(startMove_idx:endMove_idx,2));
    title('Hand Position During Movement Window')
    xlabel('x-hand position')
    ylabel('y-hand position')
end

td_stim = td_trim; % resets previous stim
for x = 1:numel(trial)
    for n = 1:numel(activated)
        for p = 1:numel(activated(n).rad)
            td_stim(trial(x)).VAE_firing_rates(stimStart_idx:stimLength_idx,activated(n).rad(p)) = hz;
        end
         during_stim = reshape(td_stim(trial).VAE_firing_rates(stimStart_idx,:), map);
         figure
         heatmap(during_stim);
         title('Firing Rates during stim for different activation currents ' + string(current(n)) + ' �A')
    end
end
%% heatmap of pre-stim firing rates, stim firing rates, and post-stim firing rates using best current 
% Make sure to redo above section with best current if multiple (pick one in current array)

pre_stim = reshape(td_stim(trial).VAE_firing_rates(startMove_idx,:), map);
during_stim = reshape(td_stim(trial).VAE_firing_rates(stimStart_idx,:), map);
post_stim = reshape(td_stim(trial).VAE_firing_rates(stimEnd_idx,:), map);

figure();
heatmap(pre_stim);
title('Firing rates before stim')
caxis([0 0.04])
figure();
heatmap(during_stim);
title('Firing rates during stim')
caxis([0 0.04])
figure();
heatmap(post_stim);
title('Firing rates after stim')
caxis([0 0.04])

%% Use decoder predictors to change velocity
td_stim(trial).vel(startMove_idx:endMove_idx,:) = td_stim(trial).VAE_firing_rates(startMove_idx:endMove_idx,:)*dec;


%% compare movement output using new vel
figure();
plot(td_trim(trial).vel(startMove_idx:endMove_idx,1), 'r')
hold on
plot(td_stim(trial).vel(startMove_idx:endMove_idx,1), 'b')
plot((stimStart_idx-startMove_idx+1):(stimLength_idx - startMove_idx+1),td_stim(trial).vel(stimStart_idx:stimLength_idx,1),'*')
title('Hand x-velocity (cm/s)')
legend('without stim', 'with stim', 'stim period')

figure();
plot(td_trim(trial).vel(startMove_idx:endMove_idx,2), 'r')
hold on
plot(td_stim(trial).vel(startMove_idx:endMove_idx,2), 'b')
plot((stimStart_idx-startMove_idx+1):(stimLength_idx - startMove_idx+1),td_stim(trial).vel(stimStart_idx:stimLength_idx,2),'*')
title('Hand y-velocity(cm/s)')
legend('without stim', 'with stim', 'stim period')




