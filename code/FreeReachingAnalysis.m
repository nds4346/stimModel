pathname = 'D:\Lab\Data\StimModel';

%% make a joint vel entry into trial data 

td = td_all{1}{2};
td.joint_vel = td.opensim(:,8:14);

%%

% Smooth kinematic variables
smoothParams.signals = {'joint_vel'};
smoothParams.width = 0.10;
smoothParams.calc_rate = false;
td = smoothSignals(td,smoothParams);


%% Extract joint_vel data in txt file
joint_vel = td.joint_vel;
joint_vel = rmmissing(joint_vel);
joint_vel = zscore(joint_vel);
joint_vel = fix(joint_vel * 10^6)/10^6;
% writematrix(joint_vel, 'Han_20160325_RW_SmoothNormalizedJointVel_50ms.txt')
% dlmwrite([pathname,filesep,'Han_20201204_RT3D_SmoothNormalizedJointVel_dropout50_50ms.txt'],joint_vel,'delimiter',',','newline','pc')

%%

firing_rates = readtable([pathname,filesep,'vae_rates_Han_20201204_RT3D_dropout01_50ms.csv']);
firing_rates = firing_rates{:,:};
%%

field_len = length(td.joint_vel);
td_fieldnames = fieldnames(td);
[~,mask] = rmmissing(td.joint_vel);

for i_field = 1:numel(td_fieldnames)
    if(length(td.(td_fieldnames{i_field})) == field_len)
        td.(td_fieldnames{i_field}) = td.(td_fieldnames{i_field})(mask==0,:);
    end
end

%% add new firing rates to td
td.firing_rates = firing_rates;

%% calculate PDs for signals
%call model output signals for this

markername = 'hand2';
dlc_idx = [find(strcmpi(td.dlc_pos_names,[markername,'_x'])),...
    find(strcmpi(td.dlc_pos_names,[markername,'_y'])),...
    find(strcmpi(td.dlc_pos_names,[markername,'_z']))];
                
td.dlc_vel_handxy = td.dlc_vel(:,dlc_idx);

pdParams = struct(...
    'out_signals','firing_rates',...
    'in_signals','dlc_vel_handxy',...
    'bootForTuning',false,...
    'num_boots',1,...
    'verbose',false,...
    'doing_3D_pd',true);
temp_pdTable = getTDPDs3D(td,pdParams);

% velPD =rad2deg(temp_pdTable.dlc_vel_handxyPD);
% velPD(velPD<0) = velPD(velPD<0)+360;
velPD = temp_pdTable.dlc_vel_handxyPD;
figure();
rose(velPD);
velPD =reshape(velPD, [sqrt(length(velPD)),sqrt(length(velPD))]);

%% Put PDs in 30x30 heatmap
figure()
velPD_adj = velPD;
velPD_adj(velPD_adj<0) = velPD_adj(velPD_adj<0)+2*pi;
fig = imagesc(rad2deg(velPD_adj));
colormap(hsv);
% jet_wrap = vertcat(jet,flipud(jet));
% fig.Colormap = hsv;
% fig.Title='Heatmap of PDs from 30x30 area 2 neurons';
% fig.GridVisible = 'off';
colorbar