function data_ref = rh_bipolar(data, chans)

% reref of raw data
% data in FT format, epoched

data_ref = data;

for c = 1:length(chans)
    
    % find electrode number
    num_idx = regexp(chans{c}, '\d'); % find index of the number in channel name
    
    % calculate reref electrode number (always the next one of the same region)
    reref_num = [str2num(chans{c}(num_idx))] + 1;
    
    % add together to reref electrode name
    reref_elec = [chans{c}(1:num_idx-1), num2str(reref_num)];
    % reref_elec = [chans{c}(1:num_idx-1), num2str(reref_num, '%02i')];
    
    % do the actual rereferencing  
    for tr = 1:length(data.trial)
		data_ref.trial{1,tr}(find(strcmp(data.label, chans{c}) == 1),:) = ...
        data.trial{1,tr}(find(strcmp(data.label, chans{c}) == 1),:) - ...
        data.trial{1,tr}(find(strcmp(data.label, reref_elec) == 1),:);
    end
    % disp result
    disp(['Bipolar: Rereferenced ' chans{c} ' to ' reref_elec])
    
end


end