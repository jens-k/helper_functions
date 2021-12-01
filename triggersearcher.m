
% Use either or

% This works if no other (irrelevant) trigger is 
exp_delay		= 8000; % expected delay (based on the data)
jit			= 50;	% allowed jitter
beg_keep		= find(diff(loc) >= exp_delay-jit & diff(loc) <= exp_delay+jit);
loc			= loc([beg_keep beg_keep+1]);
pks			= pks([beg_keep beg_keep+1]);

% Problem: Sometimes (quite rarely), one of the triggers of a pair is weaker
% than the others, as week as many irrelevant markers. Therefore:

% Find any pair of triggers that is x samples apart, independent of any triggers in between
[loc, srt]		= sort(loc); % make sure triggers are sorted
pks				= pks(srt);

exp_delay		= 8000; % expected delay between beginn and end trigger (based on the data)
jit				= 100;	% allowed jitter
idx				= []; %zeros(1, numel(loc));
last			= 0;
min_iti			= 5100;
for iTr = 1:numel(loc)-1
	if loc(iTr) > last+min_iti % potential beg sample should be at least larger than the last end sample
		end_idx = find((loc - loc(iTr) >= exp_delay-jit) & (loc - loc(iTr) <= exp_delay+jit));
		if ~isempty(end_idx)
			idx = [idx iTr end_idx(1)];
			last = loc(end_idx(1));
		end
	end
end
loc = loc(idx);
pks = pks(idx);