function [output_data] = getStimEffect(input_data)    
% input_data contains:
% FR : firing rate of neurons in Hz
% dec : decoder (just velocity part, not bias)
% act_func : activation function for activateNeurons
% locs : location of neurons
% stim_loc = location of stimulation
% amp : stimulation amplitude
% n_pulses : number of pulses to stimulate with
% pulse_bin_idx : which trial_data bin each pulse is within
% bin_size : size of bin

    output_data = [];
    
    
    % starting with FR_base (FR in input_data).
    % find FR_act by activating neurons for each pulse. Set FR_act as a
    % firing rate, not spike count
    
    % handles arbitrary number of stim electrodes, need to get activated
    % population for each electrode
    FR_act = input_data.FR;
    all_stim_locs = input_data.stim_loc;
    for i_loc = 1:size(all_stim_locs,1)
        input_data.stim_loc = all_stim_locs(i_loc,:);
        if(i_loc==1)
            is_act = activateNeurons(input_data); % input_data is already formatted properly
        else
            is_act = is_act | activateNeurons(input_data);
        end
    end
    
    % change activated neurons firing rates based on pulses they were
    % responsive to for each bin.
    for i_bin = 1:size(input_data.FR,1)
        is_act_bin = any(is_act(:,input_data.pulse_bin_idx==i_bin),2);
        FR_act(i_bin,is_act_bin==1) = sum(is_act(is_act_bin==1,input_data.pulse_bin_idx==i_bin),2)'/input_data.bin_size;
    end
    
    % find FR_stim as FR_act - FR_base
    FR_stim = FR_act - input_data.FR;
    
    % get (x,y) vel based on decoder;
    act_vel = FR_act*input_data.dec;
    base_vel = input_data.FR*input_data.dec;
    stim_vel = FR_stim*input_data.dec;
    
    % output x,y vel and other stuff
    output_data.stim_vel = stim_vel;
    output_data.act_vel = act_vel;
    output_data.base_vel = base_vel;
    
    output_data.FR_act = FR_act;
    output_data.FR_stim = FR_stim;
    output_data.is_act = is_act;
end