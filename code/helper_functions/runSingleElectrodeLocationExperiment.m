function [output_data] = runSingleElectrodeLocationExperiment(input_data)
% How does the direction of stim effect compare to the PD of the stimulated
% location during single electrode stimulation?

    % Independent Variables: Amplitude, Activation Function, Frequency. 

    % Dependent Variables : Direction and magnitude of stim effect,
    % measured from predicted hand velocity from the linear decoder

    % Will do simulations for multiple locations, can then sanity check
    % with a neighborhood metric.
    % Will also do simulations for multiple hand kinematics, which will
    % affect firing rate of neurons, and thus the effect of stim.

% input_data contains:
% td : trial data structure
% n_moves : number of movement trials to test
% n_locs : number of stimulation locations to test
% amps_test : amplitude(s) of stimulation to test
% freqs_test : frequenc(ies) of stimulation to test
% acts_test : activation functions to test
% locs : location of neurons
% dec : decoder from firing rate to hand velocity

    stim_len = floor(input_data.train_length/input_data.td.bin_size);
    
    % pick stimulation locations
    loc_idx = datasample(1:1:size(input_data.locs,1),input_data.n_locs,'Replace',false);
    stim_locs = input_data.locs(loc_idx,:);
    
    
    % pick stim start times
    stim_start_idx = datasample(1:1:(size(input_data.td.vel,1)-10*stim_len),input_data.n_moves,'Replace',false);
    
    
    % get hand vel -- this is commented out because it takes too much
    % memory. Instead, do in a for loop
%     stim_start_idx = stim_start_idx + [0:stim_len-1]';
%     vel_data = input_data.td.vel(stim_start_idx',:);
%     vel_data = reshape(vel_data,[input_data.n_moves,stim_len,2]);
%     fr_data = input_data.td.VAE_firing_rates(stim_start_idx',:);
%     fr_data = reshape(fr_data,[input_data.n_moves,stim_len,size(input_data.td.VAE_firing_rates,2)]);
    % vel data is now a 3D matrix, with the first entry being each movemnt,
    % the second being each entry in the stim train, the third being x and
    % y hand vel
    
    % for each amplitude, frequency, and activation function, location,
    % movement, get stimulation effect
    
    % initialize output matrices for experiment
    n_out = numel(input_data.acts_test)*numel(input_data.amps_test)*numel(input_data.freqs_test)*input_data.n_moves*input_data.n_locs;
    n_bins = ceil(input_data.train_length/input_data.td.bin_size);
    stim_vel = zeros(n_out,n_bins,2);
    base_vel = zeros(size(stim_vel));
    num_pulses_active = zeros(n_out, size(input_data.locs,1));
    amp_list = zeros(n_out,1);
    act_func = cell(n_out,1);
    freq_list = zeros(size(amp_list));
    move_idx = zeros(size(amp_list));
    stim_loc = zeros(n_out,2);
    
    % initialize params for experiment
    stim_effect_data = [];
    stim_effect_data.locs = input_data.locs;
    stim_effect_data.bin_size = input_data.td.bin_size;
    stim_effect_data.dec = input_data.dec;
    counter = 1;
    for i_act = 1:numel(input_data.acts_test)
        stim_effect_data.act_func = input_data.acts_test{i_act};
        for i_amp = 1:numel(input_data.amps_test)
            stim_effect_data.amp = input_data.amps_test(i_amp);
            for i_freq = 1:numel(input_data.freqs_test)
                
                % get which bin in the stim train each pulse is in
                stim_timing = 0:1/input_data.freqs_test(i_freq):input_data.train_length;
                bin_edges = [0:1:ceil(input_data.train_length/input_data.td.bin_size)]*input_data.td.bin_size;
                [~,~,stim_effect_data.pulse_bin_idx] = histcounts(stim_timing, bin_edges);
                stim_effect_data.n_pulses = numel(stim_timing);
                
                for i_move = 1:input_data.n_moves
                    stim_effect_data.FR = input_data.td.VAE_firing_rates(stim_start_idx(i_move):stim_start_idx(i_move)+stim_len-1,:);
                    for i_loc = 1:input_data.n_locs
                        stim_effect_data.stim_loc = stim_locs(i_loc,:);
                        
                        stim_effect_temp = getStimEffectSingleElec(stim_effect_data);
                        % store velocity in each bin
                        stim_vel(counter,:,:) = stim_effect_temp.stim_vel;
                        base_vel(counter,:,:) = stim_effect_temp.base_vel;
                        
                        % store which neurons were activated
                        num_pulses_active(counter,:) = sum(stim_effect_temp.is_act,2)';
                        
                        % store relevant parameters for this run
                        act_func{counter,1} = input_data.acts_test{i_act};
                        amp_list(counter,1) = input_data.amps_test(i_amp);
                        freq_list(counter,1) = input_data.freqs_test(i_freq);
                        move_idx(counter,1) = stim_start_idx(i_move);
                        stim_loc(counter,:) = stim_locs(i_loc,:);
                        
                        counter = counter + 1;
                    end % end loc
                end % end move
            end % end freq
        end % end amp
    end % end activation
    
    
    
    % package outputs
    output_data = [];
    output_data.locs = input_data.locs;
    output_data.act_func = act_func;
    output_data.amp_list = amp_list;
    output_data.freq_list = freq_list;
    output_data.move_idx = move_idx;
    output_data.stim_loc = stim_loc;
    output_data.num_pulses_active = num_pulses_active;
    output_data.stim_vel = stim_vel;
    output_data.base_vel = base_vel;
end