function blocks = find_blocks(log_array)
% When provided a 1-dimensional array of logicals, this function will
% return the indices of the beginnings and ends of blocks of trues.
% [0 1 1 0 0 1 1 1 1] -> [2 3; 6 9]
%
% AUTHOR:
% Jens Klinzing, jens.klinzing@bitbrain.es
diffs				= diff(log_array); % find consecutive occurrences of this stage (= episodes)
diffs				= [false diffs false]; % so we also find the first and last one
bl_starts			= find(diffs == 1);
bl_ends				= find(diffs == -1);
bl_ends				= bl_ends-1;

if log_array(1), bl_starts = [1 bl_starts]; end % in case array starts ...
if log_array(end), bl_ends = [bl_ends length(log_array)]; end % ...or ends with a block
blocks				= [bl_starts' bl_ends'];
end