function [ output_data ] = buildDecoderDropout( input_data )
% this function builds a decoder using dropout reguralization
% input data contains:
% lr : learning rate
% num_iters : number of iterations
% dropout_rate : percentage of neurons to drop for each iteration
% fr : firing rates to train with
% hand_vel : output data to predict

    

    dec = rand(size(input_data.fr,2),2)-0.5;
    bias = [0,0];

    vaf_list_drop = zeros(input_data.num_iters,2);
    vaf_list_mdl = zeros(input_data.num_iters,2);
    n_neurons = size(input_data.fr,2);
    
    for i_iter = 1:input_data.num_iters
        % dropout inputs
        keep_mask = zeros(n_neurons,1);
        keep_mask(datasample(1:1:n_neurons,ceil(n_neurons*(1-input_data.dropout_rate)))) = 1;
        x = (input_data.fr.*keep_mask');

        vel_pred = x*dec + bias;

        d_dec = -2*x'*(input_data.hand_vel-vel_pred)/length(dec);
        d_bias = mean(-2*(input_data.hand_vel-vel_pred));

        bias = bias - input_data.lr*d_bias;
        dec = dec - input_data.lr*d_dec;

        vaf_list_drop(i_iter,:) = compute_vaf(input_data.hand_vel,vel_pred);
        vaf_list_mdl(i_iter,:) = compute_vaf(input_data.hand_vel,(input_data.fr*dec)*(1-input_data.dropout_rate) + bias);

        if(mod(i_iter,25)==0)
            disp(vaf_list_mdl(i_iter,:))
        end
    end

    % adjust dec to deal with dropout
    dec = dec*(1-input_data.dropout_rate);
    
    % package outputs
    output_data.dec = dec;
    output_data.bias = bias;
    output_data.vaf_list_drop = vaf_list_drop;
    output_data.vaf_list_mdl = vaf_list_mdl;
    
    

end

