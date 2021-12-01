function relativepath = rlpath(absolutepath)
% If absolute input path is a subfolder of the current root or data
% directory (as defined by base workspace function handle paths.init) this
% part of the path is replaced by $root or $data.
%
% If input is a paths structure rlpath is called on all its fields.

% Get current root / data paths from function specified in paths.init
root = feval(evalin('base', 'paths.init'), 'root');
data = feval(evalin('base', 'paths.init'), 'data');

if isstruct(absolutepath)
	relativepath = [];
	fields = fieldnames(absolutepath);
	for ifield=1:numel(fields)
		if iscell(absolutepath.(fields{ifield}))
			for iC = 1:numel(absolutepath.(fields{ifield}))
				relativepath.(fields{ifield}){iC} = rlpath(absolutepath.(fields{ifield}){iC});
			end
		else
			relativepath.(fields{ifield}) = rlpath(absolutepath.(fields{ifield}));
		end
	end
elseif ischar(absolutepath)
    if numel(strfind(absolutepath, root) == 1) && strfind(absolutepath, root) == 1
        relativepath = ['$root' absolutepath(length(root)+1:end)];
    elseif numel(strfind(absolutepath, data) == 1) && strfind(absolutepath, data) == 1
        relativepath = ['$data' absolutepath(length(data)+1:end)];
    else
        relativepath = absolutepath;
    end
elseif isa(absolutepath, 'function_handle')
    relativepath = absolutepath;
elseif isempty(absolutepath)
	relativepath = absolutepath;
else
    error('Input does not match requirements.')
end
end