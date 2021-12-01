function f = plotIRASAspectrum(freq, areasplit)
% Takes the output of as_getIRASAspectrum and plots it nicely. Allowed
% clicking on a line to get coordinates and channel name
%
% areasplit leads to same colors used for each brain area (as indicated by
% letters before a digit in freq.label)

%% SETUP
if nargin < 2
	areasplit = 0;
else
	areasplit = 1;
end

if areasplit
	barea			= cell(numel(freq.label),1);
	num_idx			= cell2mat(regexp(freq.label, '\d*'));
	for iCh = 1:numel(freq.label)
		barea{iCh}	= freq.label{iCh}(2:num_idx(iCh)-1);
	end
	bareas			= unique(barea); % a second output would record first entry for each unique area (needed for legend), has to be done in later loop now since we collapse homologous areas
	% 	map				= brewermap(numel(bareas),'Dark2');
	map				= lines(numel(bareas));
	cmap			= nan(numel(freq.label), 3);
	iA				= nan(numel(bareas), 1); % memorize first entry for each area (needed for legend)
	for iArea = 1:numel(bareas)
		idx = find(~cellfun('isempty', regexp(freq.label, ['\w' bareas{iArea} '\d*'])));
		iA(iArea) = idx(1);
		% 		idx = find(startsWith(freq.label, bareas(iArea)));
		cmap(idx, :) = repmat(map(iArea, :), numel(idx), 1);
	end
end

%% START
f = figure;
s = subplot(3,1,1);
p = plot(freq.freq, freq.mix, '-', 'LineWidth', 2);
if areasplit
	for iL = 1:numel(p), set(p(iL), 'Color', cmap(iL,:)); end
end
title('Raw spectrum')
hold on
plot(freq.freq, freq.fra, 'k-', 'LineWidth', 1)
xlim([freq.freq(1) freq.freq(end)])
if areasplit
	l = legend(p(iA), bareas, 'Location', 'bestoutside');
else
	l = legend(freq.label, 'Location', 'bestoutside');
end
pos1 = get(s, 'Position');
wid1 = pos1(3);

s = subplot(3,1,2);
p = plot(freq.freq, freq.osc, '-', 'LineWidth', 2);
if areasplit
	for iL = 1:numel(p), set(p(iL), 'Color', cmap(iL,:)); end
end
title('Oscillatory component')
xlim([freq.freq(1) freq.freq(end)])
pos2 = get(s, 'Position');
l = legend(freq.label, 'Location', 'bestoutside'); % just to adjust subplot size
l.Visible = 'off';

s = subplot(3,1,3);
p = plot(freq.freq, freq.rel, '-', 'LineWidth', 2);
if areasplit
	for iL = 1:numel(p), set(p(iL), 'Color', cmap(iL,:)); end
end
title('Oscillatory/fractal component')
xlim([freq.freq(1) freq.freq(end)])
pos3 = get(s, 'Position');
l = legend(freq.label, 'Location', 'bestoutside'); % just to adjust subplot size
l.Visible = 'off';

set(f, 'Position', get(0, 'Screensize'));
set(f, 'Color', [1 1 1])
datacursormode on;
dcm = datacursormode(f);
set(dcm,'UpdateFcn',@showLegendTooltip)
end

function output_txt = showLegendTooltip(~,event_obj,~)
pos = get(event_obj, 'Position');
output_txt = {...
	[num2str(pos(2),4)] ...
	['Freq: ', num2str(pos(1),4) ' Hz']...
	['Channel: ' event_obj.Target.DisplayName]...
	};
end