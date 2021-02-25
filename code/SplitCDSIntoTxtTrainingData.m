%% Load cds File into td

filename = 'Han_20160325_RW_CDS_001.mat';


params.cont_signal_names = {'joint_vel'};
params.array_name = 'S1';
trial_data = loadTDfromCDS(append('~/Documents/Documents/Thesis_Seminar/Model/data/',filename) , params);
%% process file
% rebin 
trial_data = binTD(trial_data, 5);

%% load from .mat file
%filename = 'Han_20160325_RW_SmoothJointVel.mat';
pathname = '~/Documents/Documents/Thesis_Seminar/Model/data/';
load([pathname filesep filename]);

% Smooth kinematic variables
smoothParams.signals = {'joint_vel'};
smoothParams.width = 0.10;
smoothParams.calc_rate = false;
td = smoothSignals(trial_data,smoothParams);


save('Han_20160325_RW_SmoothJointVel.mat')

%% Extract joint_vel data in txt file
joint_vel = td.joint_vel;
joint_vel = rmmissing(joint_vel);
joint_vel = normalize(joint_vel);
joint_vel = fix(joint_vel * 10^6)/10^6;
writematrix(joint_vel, 'Han_20160325_RW_SmoothNormalizedJointVel_50ms.txt')