field_len = length(td.vel);
td_fieldnames = fieldnames(td);
[~,mask] = rmmissing(td.joint_vel);

for i_field = 1:numel(td_fieldnames)
    if(length(td.(td_fieldnames{i_field})) == field_len)
        td.(td_fieldnames{i_field}) = td.(td_fieldnames{i_field})(mask==0,:);
    end
end

%%
fr = td.firing_rates;
fr_lagged = fr;
num_lags = 0;
for i=1:num_lags
    fr_lag = circshift(fr,i);
    fr_lagged = [fr_lagged,fr_lag];
end
%%
hand_vel = td.vel;

x = fr_lagged\hand_vel;

% A*x = b, A\b = x

hand_vel_hat = fr_lagged*x;


