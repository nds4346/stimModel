%% load file
filename = 'Han_201603015_RW_SmoothKin_50ms.mat';

%Nathan's mac path
pathname = '~/Documents/Documents/Thesis_Seminar/Model/data/';

%Joe's windows path
%pathname = 'D:\Lab\Data\StimModel';

load([pathname filesep filename]);

%% load in firing rates
firing_rates = readtable('firing_rates_20210223.csv');
firing_rates = firing_rates{:,:};
td.VAE_firing_rates = firing_rates(:,:);


%% IF USING PARTIAL DATA SET: cut off first elements of td to match td time bins with firing_rates
td.acc(1:30000,:) = [];
td.pos(1:30000,:) = [];
td.vel(1:30000,:) = [];
td.joint_vel(1:30000,:) = [];
td.S1_spikes(1:30000,:) = [];
td.speed(1:30000,:) = [];
td.vel_rect(1:30000,:) = [];
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
%% find predictors of hand velocities from firing rates
hand_vel = td.vel;

x = fr_lagged\hand_vel;
%% find predicted hand velocities using firing rates
% A*x = b, A\b = x
hand_vel_hat = fr_lagged*x;


