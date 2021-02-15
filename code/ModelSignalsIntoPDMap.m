% %% import signals from map
% 
% td.joint_vel = rmmissing(td.joint_vel);
% td.pos = rmmissing(td.pos);
% td.vel = rmmissing(td.vel);
% td.S1_spikes = rmmissing(td.S1_spikes);
% td.speed = rmmissing(td.speed);
% td.vel_rect = rmmissing(td.vel_rect);


%% split tds
%Split TD
splitParams.split_idx_name = 'idx_startTime';
splitParams.linked_fields = {'trialID','result'};
td = splitTD(td,splitParams);

%Get movement onset
td(isnan([td.idx_startTime])) = [];

moveOnsetParams.start_idx = 'idx_startTime';
moveOnsetParams.end_idx = 'idx_endTime';
td = getMoveOnsetAndPeak(td,moveOnsetParams);

td(isnan([td.idx_movement_on])) = [];

%get rid of non-reward trials
x=[td.result]=='R';
td = td(x);



%% calculate PDs for signals
%call model output signals for this
params.out_signals = 'S1_spikes';
params.in_signals = {'vel'};
params.num_boots = 100;
pdtable = getTDPDs(td, params);

pdtable =rad2deg(pdtable.velPD);
pdtable(pdtable<0) = pdtable(pdtable<0)+360;
pdtable =reshape(pdtable, [6,8]);
%% Put PDs in 30x30 heatmap
fig = heatmap(pdtable);