function in = outlier_rej(in, multi)
% Takes an array of values, replaces outliers with NaNs, using an
% interquartile rejection rule with multiplier multi.
%
% in		array of values
% multi		multiplier to use for IQR rule
%
% Author: jens.klinzing@uni-tuebingen.de


% for each parameter
[iqr, q] = iqr_haverage(in);

% calculates IQR using haverage (like SPSS, but without fully exluding missing subjects)
lb = q(1) - iqr*multi; % resulting lower bound
ub = q(3) + iqr*multi; % resulting upper bound

% for each value in all_values_for_current_condition_and_parameter do this:
counter = 0;
for iVal = 1:numel(in)
	if in(iVal) < lb || in(iVal)> ub
		in(iVal) = NaN;
		counter = counter + 1;
	end
end
warning('Rejected %s values (ic_outlier_rej).', num2str(counter))



