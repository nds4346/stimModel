function [ is_act ] = activateNeurons( input_data )
% returns whether each neuron is activated for each pulse
% based on location, amplitude and
% activation function

% input_data contains: 
    % act_func : string picking the activation function
    % locs : location of neurons
    % stim_loc : location of stimulation
    % amp : stimulation amplitude
    % n_pulses : number of pulses. 
    
    is_act = [];
    dist = sqrt(sum((input_data.locs - input_data.stim_loc).^2,2));
    
    switch(input_data.act_func)
        case 'circular'
            % pick radius of activation based on I = k*r^2 (r is radius, k is uA/mm)
            k = 1292;
            r = sqrt(input_data.amp/k);
            
            is_act = dist < r;
            is_act = repmat(is_act, 1, input_data.n_pulses);
        case 'exp_decay'
            % get space constant from linear interpolation
            amp_list = [15,30,50,100];
            space_constant_list = [100,250,325,500]/1000; % in mm
            space_constant = interp1(amp_list,space_constant_list,input_data.amp);
            
            prob_act = exp(-dist/space_constant);
            rand_num = rand(numel(prob_act),input_data.n_pulses);
            is_act = rand_num < prob_act;
            
        otherwise
            error('unknown activation function');
    end

end

