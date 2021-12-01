function art = isArt(evt, arts)
% Checks for a provided event window ([beg end]) whether it overlap with
% any of n provided artifact windows (n x 2).
if length(evt) ~= 2 || size(arts, 2) ~= 2
	error('Incorrect input format.')
end

% Is there an artifact where the artifact end if after the event start sample  is before th
art = any(arrayfun(@(x) arts(x, 2) >= evt(1) && arts(x, 1) <= evt(end), 1:size(arts,1)));
end

