%% import data files
filename = 'Han_20170203_COactpas_SmoothKin.mat';
pathname = '~/Documents/Documents/Thesis_Seminar/Model/data/';
load([pathname filesep filename]);

firing_rates = readtable('firing_rates_20210216.csv');
firing_rates = firing_rates{:,:};

%% add new firing rates to td
td.firing_rates = firing_rates;

%% split tds
%Split TD
splitParams.split_idx_name = 'idx_startTime';
splitParams.linked_fields = {'trialID','result'};
td = splitTD(td,splitParams);

%% Get movement onset
td(isnan([td.idx_startTime])) = [];

moveOnsetParams.start_idx = 'idx_startTime';
moveOnsetParams.end_idx = 'idx_endTime';
td = getMoveOnsetAndPeak(td,moveOnsetParams);

td(isnan([td.idx_movement_on])) = [];

%% get rid of non-reward trials
x=[td.result]=='R';
td = td(x);

%% plot reaches
for trial= 1:length(td)
    reach = plot(td(trial).pos(:,1),td(trial).pos(:,2));
    hold on
end

%% calculate PDs for signals
%call model output signals for this
params.out_signals = 'firing_rates';
params.in_signals = {'vel'};
params.num_boots = 10;
pdtable = getTDPDs(td, params);

pdtable =rad2deg(pdtable.velPD);
pdtable(pdtable<0) = pdtable(pdtable<0)+360;
pdtable =reshape(pdtable, [30,30]);

%% Put PDs in 30x30 heatmap
fig = heatmap(pdtable);
% jet_wrap = vertcat(jet,flipud(jet));
fig.Colormap = hsv;
fig.Title='Heatmap of PDs from 30x30 area 2 neurons';
fig.GridVisible = 'off';

%% randomly select stimulation neuron

%% simulate circular stimulation
i = 20;  %current in µA
k = 1292; %space constant in µa/mm^2 (Stoney,et al)
r = (i^2)/k; %radius of activation in mm
