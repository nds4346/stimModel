%% import data files
filename = 'Chips_20151211_RW_td.mat';
pathname = 'D:\Lab\Data\StimModel';
load([pathname filesep filename]);

% Smooth kinematic variables
smoothParams.signals = {'joint_vel'};
smoothParams.width = 0.10;
smoothParams.calc_rate = false;
td = smoothSignals(td,smoothParams);

firing_rates = readtable([pathname,filesep,'vae_rates_Chips_20151211_RW_50ms.csv']);

%%
firing_rates = firing_rates{:,:};
%%

field_len = length(td.vel);
td_fieldnames = fieldnames(td);
[~,mask] = rmmissing(td.joint_vel);

for i_field = 1:numel(td_fieldnames)
    if(length(td.(td_fieldnames{i_field})) == field_len)
        td.(td_fieldnames{i_field}) = td.(td_fieldnames{i_field})(mask==0,:);
    end
end

%% add new firing rates to td
td.firing_rates = firing_rates;


%% IF USING PARTIAL DATA SET: cut off first elements of td to match td time bins with firing_rates
td.acc(1:30000,:) = [];
td.pos(1:30000,:) = [];
td.vel(1:30000,:) = [];
td.joint_vel(1:30000,:) = [];
td.S1_spikes(1:30000,:) = [];
td.speed(1:30000,:) = [];
td.vel_rect(1:30000,:) = [];


%% split tds
%Split TD
splitParams.split_idx_name = 'idx_startTime';
splitParams.linked_fields = {'trialID','result'};
td_trim = splitTD(td,splitParams);

% trim tds
% td_trim = trimTD(td_trim,{'idx_startTime',15},{'idx_startTime',30});
%% Get movement onset
% td(isnan([td.idx_startTime])) = [];
% 
% moveOnsetParams.start_idx = 'idx_startTime';
% moveOnsetParams.end_idx = 'idx_endTime';
% td = getMoveOnsetAndPeak(td,moveOnsetParams);
% 
% td(isnan([td.idx_movement_on])) = [];

%% get rid of non-reward trials
x=[td_trim.result]=='R';
td_trim = td_trim(x);

%% plot reaches
for trial= 1:length(td_trim)
    reach = plot(td_trim(trial).pos(:,1),td_trim(trial).pos(:,2));
    hold on
end
hold off

%% calculate PDs for signals
%call model output signals for this
params.out_signals = 'firing_rates';
params.in_signals = {'vel'};
params.num_boots = 0;
pdtable = getTDPDs(td_trim, params);

pdtable =rad2deg(pdtable.velPD);
pdtable(pdtable<0) = pdtable(pdtable<0)+360;
figure();
hist(pdtable);
pdtable =reshape(pdtable, [30,30]);

%% Circular Histogram of PDs
figure
theta = deg2rad(pdtable);
theta = reshape((theta).', 1, []);
his = polarhistogram(theta, 36);

%% Put PDs in 30x30 heatmap

figure
fig = heatmap(pdtable);
% jet_wrap = vertcat(jet,flipud(jet));
fig.Colormap = hsv;
fig.Title='Heatmap of PDs from 30x30 area 2 neurons';
fig.GridVisible = 'off';

%% randomly select stimulation neuron


