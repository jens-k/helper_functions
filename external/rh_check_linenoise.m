function [] = rh_check_linenoise(data)

% check noise
cfg = [];
cfg.channel = 'all';
cfg.taper = 'hanning';
cfg.output = 'pow';
cfg.method = 'mtmfft';
cfg.foilim = [1 320];
cfg.pad = 'maxperlen';
cfg.keeptrials = 'no';
freq = ft_freqanalysis(cfg, data);
freq.logspctrm = log(freq.powspctrm);

figure()
for i = 1:length(data.label)
   try 
       subplot(ceil(sqrt(length(data.label))),ceil(sqrt(length(data.label))),i)
       cfg = [];
       cfg.channel = freq.label{i};
       cfg.parameter = 'logspctrm';
       ft_singleplotER(cfg, freq)
   catch end
end

end