function spectra = getIRASAspectrum(data, freqs)
% If you want data to be cut into segments, do it before calling this
% function.

label = data.label;

% Calculate spectra
ft_warning off % makes the output unreadable otherwise (will be turned on again below)
cfg_tmp						= [];
cfg_tmp.foi					= freqs;
cfg_tmp.method				= 'irasa';
cfg_tmp.pad					= 'nextpow2';
fra							= ft_freqanalysis(cfg_tmp, data);

cfg_tmp.method 				= 'mtmfft';
cfg_tmp.taper 				= 'hanning';
mix							= ft_freqanalysis(cfg_tmp, data);

clear data
ft_warning on

% Calculate the oscillatory component by subtracting the fractal from the
% mixed component
cfg_tmp						= [];
cfg_tmp.parameter			= 'powspctrm';
cfg_tmp.operation			= 'subtract';
osc							= ft_math(cfg_tmp, mix, fra);

% Use percent change for even more obvious peaks
cfg_tmp.operation			= 'divide';
rel							= ft_math(cfg_tmp, osc, fra);

% Fill output structure
spectra						= [];
spectra.fra					= fra.powspctrm;
spectra.mix					= mix.powspctrm;
spectra.osc					= osc.powspctrm;
spectra.rel					= rel.powspctrm;
spectra.freq				= rel.freq; % add frequency vector
spectra.label				= label; % channel names
