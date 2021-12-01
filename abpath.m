function absolutepath = abpath(relativepath)
% If input path is given relative to a $root or $data path token this
% token and all path fileseparators are replaced by the respective full path.
%
% The full path is determined using the function specified via amn init
% function. A handle to this function must exist in the base workspace
% under paths.init.
%
% If input is already an absolute path (= without $root or $data tokens)
% the input path is returned with potential absolute root or data paths as
% well as the path fileseparators changed to current or given system.
%
% If input is a paths structure abpath is called on all its fields.

% Get current root / data paths  
if isstruct(relativepath) && isfield(relativepath, 'init')
    % ...from function specified in input (if it is a path structure)
    root = relativepath.init('root');
    data = relativepath.init('data');
else
    % ...or the workspace paths.init
    root = feval(evalin('base', 'paths.init'), 'root');
    data = feval(evalin('base', 'paths.init'), 'data');
end

% If input is a paths structure, abpath every field
if isstruct(relativepath)
    absolutepath = [];
    fields = fieldnames(relativepath);
    for ifield=1:numel(fields)
		if iscell(relativepath.(fields{ifield}))
			for iC = 1:numel(relativepath.(fields{ifield}))
				absolutepath.(fields{ifield}){iC} = abpath(relativepath.(fields{ifield}){iC});
			end
		else
			absolutepath.(fields{ifield}) = abpath(relativepath.(fields{ifield}));
		end
        
    end
elseif ischar(relativepath)
    % Check if the beginning of the path matches any known path tokens and if
    % yes, replace them with the full path.
    % [\/\\] = regular expression for: either / or \
    if strcmp(relativepath(1:5), '$root')
        absolutepath = [root regexprep(relativepath(6:end), '[\/\\]', filesep)];
    elseif strcmp(relativepath(1:5), '$data')
        absolutepath = [data regexprep(relativepath(6:end), '[\/\\]', filesep)];
    else
        absolutepath = relativepath;  % otherwise we return the input
    end
elseif isa(relativepath, 'function_handle')
    absolutepath = relativepath;
elseif isempty(relativepath)
	absolutepath = relativepath;
else
    error('Input does not match requirements.')
end
end