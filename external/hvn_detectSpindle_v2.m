function cfg = hvn_detectSpindle_v2(cfg, inData)
% Generic detection function, based on code by Hong-Viet V. Ngo and Til
% Bergmann.
%
% Configuration parameters
% cfg.chThres           = (N x 1) string listing the N channels to determine the thresholds for
% cfg.chDetct           = (M x 1) string listing the M (< N) channels to detect SO in (based on the previously determined thresholds)

% cfg.param.stageoi     = (N_SlSt x 1) vector containing sleep stages of interest for detection
% cfg.param.bpfreq      = [freqMin, freqMax]: Lower and upper limit for bandpass filter
% cfg.param.filtType    = 'fir' or 'but' (default) - determines whether data processingis based on a FIR or butterworth filter
% cfg.param.thresType   = 'channelwise' (default), 'average' or 'fixed' (not implemented)
%                         Use thresholds corresponding to each channel, a mean threshold 
%                         across all channels or given fixed values. If channelwise is chosen
%                         detectCh must be a subset of chThres.
% cfg.param.envType     = 'env', 'rms' (default), perform thresholding on rms signal or envelope (via spline interpolation of the peaks in the rectified signal) of bandpassed signal
% cfg.param.envWin      = Window (in s) to use for envelope calculation (default 0.2 s)
% cfg.param.artfctPad   = [prePad, postPad] (in s) additional padding around each 
%                         artifact, negative values = pre-artifact padding (default = [0 0])
%
% cfg.criterion.duration    = [minLen, maxLen]: Minimal and maximal allowed duration of slow oscillation events
% cfg.criterion.center      = 'mean' (default) or 'median'
% cfg.criterion.varience    = 'centerSD' (default), 'centerMAD' (median absolute derivation), 'scaleCenter', 'scaleEnvSD' or 'percentile' or 'scaleFiltSD'
% cfg.criterion.scaling       = scalar representing the scaling factor applied to the 'criterionVar' parameter
% cfg.criterion.padding     = [prePad, postPad] (in s) additional padding around
%                             each event candidate, negative value = pre-event 
%                             padding (default = [0 0])

% cfg.paramOpt.smoothEnv    = If > 0 (default = 0), window (in s) to use for smoothing of envelope signal
% cfg.paramOpt.upperCutoff  = Scaling factor for an additional threshold, which discard any exceeding events to avoid artifacts (default = inf)
%                             Corresponding threshold is saved in cfg.thres.upperCutoff
% cfg.paramOpt.mergeEvts    = if > 0, maximal gap (in s) until which close events are merged
% cfg.paramOpt.scndThres    = if > 0 (default = 0), introduce a second
%                             (higher) threshold criterion threshold saved
%                             in cfg.thres.second
% cfg.paramOpt.minCycles    = Option to activate minimum number of required cycles per event
%                             0: Deactivated (default)
%                             1: Based on raw signal
%                             2: Based on bandpass filtered signal
% cfg.paramOpt.minCyclesNum = Scalar representing the minimum number of required cycles
%
% cfg.doFalseposRjct  = set to 1 if detected events are checked for their
%                         frequency profile, i.e. a spectral peak with a
%                         specific prominence within a specified frequency range
% cfg.falseposRjct.freqlim    = [freqMin freqMax], frequency range event
%                                 should have a spectral maximum
% cfg.falseposRjct.timePad    = [timeMin timeMax], time padded around
%                                 events to calculate TFRs
% cfg.falseposRjct.tfrFreq    = Frequencies for TFR calculation. Must
%                                 include freqlim set above
% cfg.falseposRjct.tfrTime    = Time range of TFR
% cfg.falseposRjct.tfrWin     = Length of time window for TFR calculation
% cfg.falseposRjct.avgWin     = Time window used for averaging TFR, usual
%                                 narrowly set around the event, i.e. t = 0 s
% cfg.falseposRjct.prominence = Threshold the spectral peak amplitude has to exceed
%
% example input structure for two channel analyis:
% inData.label:       {'Fz'; 'Cz'}
% inData.time:        {[2?37320000 double]}
% inData.trial:       {[2?37320000 double]}
% inData.staging:     {[1?37320000 int8]}
% inData.fsample:     1000
% inData.artifacts:   {[46020?2 double]; [50020?2 double]}
% inData.sampleinfo:  [1 37320000]

%% housekeeping
%.. check input
if nargin ~= 2;                     error('Wrong number of arguments');     end
if ~isfield(inData, 'staging');     error('No sleep staging available');    end

%.. check input channels
if ~isfield(cfg,'chThres') || ismember('all', cfg.chThres);     cfg.chThres = inData.label;     end
if ~isfield(cfg,'chDetct') || ismember('all', cfg.chDetct);     cfg.chDetct = inData.label;     end

if strcmp(cfg.param.thresType, 'channelwise') %% Check if detectCh is a subset of chThres
    if sum(ismember(cfg.chThres, cfg.chDetct)) ~= size(cfg.chDetct)
        error('Channelwise detection requires detectCh to be a subset of chThres');
    end
end

%.. check criterion struct
if ~isfield(cfg.criterion,'duration');  error('no duration specfied');          end
if ~isfield(cfg.criterion,'center');    cfg.criterion.center    = 'mean';       end
if ~isfield(cfg.criterion,'variance');  cfg.criterion.variance  = 'centerSD';   end
if ~isfield(cfg.criterion,'scaling');   cfg.criterion.scaling   = 1;            end
if ~isfield(cfg.criterion,'padding');   cfg.criterion.padding   = [0 0];        end

%.. check param struct
if ~isfield(cfg.param,'bpfreq');        error('band pass filter information is missing!');  end
if ~isfield(cfg.param,'stageoi');       error('please specify sleep stages of interest!');  end
if ~isfield(cfg.param,'filtType');      cfg.param.filtType  = 'fir';                        end
if ~isfield(cfg.param,'envType');       cfg.param.envType   = 'rms';                        end
if ~isfield(cfg.param,'envWin');        cfg.param.envWin    = 0.2;                          end
if ~isfield(cfg.param,'artfctPad');     cfg.param.artfctPad = [0 0];                        end

%.. check paramOpt struct
if ~isfield(cfg.paramOpt,'smoothEnv');     cfg.paramOpt.smoothEnv = 0;      end
if ~isfield(cfg.paramOpt,'scndThres');     cfg.paramOpt.scndThres = 0;      end
if ~isfield(cfg.paramOpt,'upperCutoff');   cfg.paramOpt.upperCutoff = inf;  end
if ~isfield(cfg.paramOpt,'mergeEvts');      cfg.paramOpt.mergeEvts = 0;     end

%--- Check minCycle option
if ~isfield(cfg.paramOpt,'minCycles')
    cfg.paramOpt.minCycles      = 0;
    cfg.paramOpt.minCyclesNum   = 0;
elseif cfg.paramOpt.minCycles > 0 && ~isfield(cfg.paramOpt, 'minCyclesNum')
    error('Specification of minCyclesNum is missing');
end

%.. false positive rejection
if ~isfield(cfg,'doFalseposRjct'); cfg.doFalseposRjct = 0; end


%% Prepare output structure
cfg.thres       = [];
cfg.evtIndiv    = struct;
cfg.summary     = struct;


%% Important variables
fsample     = round(inData.fsample);
numTrl      = size(inData.trial,2);
lenTrl      = diff(inData.sampleinfo,1,2)+1;
numThres    = size(cfg.chThres,1);
numDetct    = size(cfg.chDetct,1);
artfctPad   = round(cfg.param.artfctPad * fsample);
critPad     = round(cfg.criterion.padding * fsample);


%% Prepare artfctFilter
godfltr = cellfun(@(x) ones(numThres,size(x,2),'logical'),inData.trial,'UniformOutput',0);

if isfield(inData, 'artfcts')
    for iTrl = 1 : numTrl
        for iCh = 1 : numThres
            currCh = ismember(inData.label,cfg.chThres{iCh});
            
            tmpArt = inData.artifacts{currCh,iTrl} + artfctPad;
            tmpArt(tmpArt(:,1) < 1,1)                         = 1;                              %% Ensure padding does not...
            tmpArt(tmpArt(:,2) > inData.sampleinfo(iTrl,2),2) = inData.sampleinfo(iTrl,2);      %% exceed data range
            
            godfltr{iTrl}(iCh,:) = all([ismember(inData.staging{iTrl},cfg.param.stageoi);...
                                        ~hvn_createBnrySignal(tmpArt,lenTrl(iTrl))]);
            
            clear tmpArt
        end
    end   
end


%% Prepare data to determine thresholds
thres       = arrayfun(@(x) nan(numThres,x),lenTrl,'UniformOutput',0);
thresEnv    = arrayfun(@(x) nan(numThres,x),lenTrl,'UniformOutput',0);

for iTrl = 1 : numTrl                                                   % loop over trials
    for iCh = 1 : numThres                                            % loop over channels
        fprintf('Filter channel %d/%d (%s)\n', iCh, numThres, cfg.chThres{iCh});
        
        currCh = ismember(inData.label,cfg.chThres{iCh});
        
        %.. filtering
        switch cfg.param.filtType
            case 'fir'
                thres{iTrl}(iCh,:) = ft_preproc_bandpassfilter(inData.trial{iTrl}(currCh,:), fsample, cfg.param.bpfreq, 3*fix(fsample/cfg.param.bpfreq(1))+1, 'fir', 'twopass');
            case 'but'
                tmpHP = ft_preproc_highpassfilter(inData.trial{iTrl}(currCh,:), fsample, cfg.param.bpfreq(1), 5, 'but', 'twopass','reduce');
                thres{iTrl}(iCh,:) = ft_preproc_lowpassfilter(tmpHP, fsample, cfg.param.bpfreq(2), 5, 'but', 'twopass','reduce');
                
                clear tmpHP
        end
        
        %.. envelope
        thresEnv{iTrl}(iCh,:) = envelope(thres{iTrl}(iCh,:),round(cfg.param.envWin * fsample),cfg.param.envType);
        
        %.. optional smoothing
        if cfg.paramOpt.smoothEnv > 0 %% Smooth envelope if requested
            thresEnv{iTrl}(iCh,:) = smoothdata(thresEnv{iTrl}(iCh,:),2,'movmean',round(cfg.paramOpt.smoothEnv * fsample));
        end
    end
end


%% determine amplitude threshold
% gather data for variance threshold calculation
vardata = cell(numThres,1);
for iTrl = 1 : numTrl                           % loop over trials
    if strcmp(cfg.criterion.varience,'scaleFiltSD')
        for iCh = 1 : numThres
            vardata{iCh} = [vardata{iCh}, thres{iTrl}(iCh,godfltr{iTrl}(iCh,:))];
        end
    else
        for iCh = 1: numThres
            vardata{iCh} = [vardata{iCh}, thresEnv{iTrl}(iCh,godfltr{iTrl}(iCh,:))];
        end
    end
end

switch cfg.criterion.center
    case 'median'
        centerfun = @(x) nanmedian(x,2);
    case 'mean'
        centerfun = @(x) nanmean(x,2);
end
cfg.thres.center = cell2mat(cellfun(@(x) centerfun(x), vardata,'UniformOutput',0));

if strcmp(cfg.criterion.varience,'centerMAD')
    varfun = @(x) mad(x,1,2,'omitnan');
elseif any(contains(cfg.criterion.varience,{'centerSD','scaleEnvSD','scaleFiltSD'}))
    varfun = @(x) nanstd(x,1,2);
else
    varfun = @(x) [];
end
cfg.thres.variance = cell2mat(cellfun(@(x) varfun(x),vardata,'UniformOutput',0));

if any(contains(cfg.criterion.varience,{'centerMAD','centerSD'}))
    thresfun = @(x,y,z) x + (y .* z);
elseif any(contains(cfg.criterion.varience,{'scaleEnvSD','scaleFiltSD'}))
    thresfun = @(x,y,z) y .* z;
elseif strcmp(cfg.criterion.varience,'scaleCenter')
    thresfun = @(x,y,z) x .* z;
end

if strcmp(cfg.criterion.varience,'percentile')
    cfg.thres.main          = cellfun(@(x) prctile(x, cfg.criterion.scaling,2), vardata);
    cfg.thres.upperCutoff   = cellfun(@(x) prctile(x, cfg.paramOpt.upperCutoff,2), vardata);

    if cfg.paramOpt.scndThres > 0
        cfg.thres.second = cellfun(@(x) prctile(x, cfg.paramOpt.scndThres,2), vardata);
    end
else
    cfg.thres.main           = thresfun(cfg.thres.center, cfg.thres.variance, cfg.criterion.scaling);
    cfg.thres.upperCutoff    = thresfun(cfg.thres.center, cfg.thres.variance, cfg.paramOpt.upperCutoff);

    if cfg.paramOpt.scndThres > 0
        cfg.thres.second = thresfun(cfg.thres.center, cfg.thres.variance, cfg.paramOpt.scndThres);
    end
end


%% If upperCutoff < Inf set samples upperCutoff to Nan and re-calculate the threshold
if cfg.paramOpt.upperCutoff < Inf
    for iCh = 1 : numThres
        vardata{iCh}(vardata{iCh} > cfg.thres.upperCutoff(iCh)) = nan;
    end
    
    cfg.thres.center      = cell2mat(cellfun(@(x) centerfun(x),vardata,'UniformOutput',0));
    cfg.thres.variance    = cell2mat(cellfun(@(x) varfun(x),vardata,'UniformOutput',0));
    
    if strcmp(cfg.criterion.varience,'percentile')
        cfg.thres.main = cellfun(@(x) prctile(x, cfg.criterion.scaling,2), vardata);
        
        if cfg.paramOpt.scndThres > 0
            cfg.thres.second = cellfun(@(x) prctile(x, cfg.paramOpt.scndThres,2), vardata);
        end
    else
        cfg.thres.main = thresfun(cfg.thres.center, cfg.thres.variance, cfg.criterion.scaling);
        
        if cfg.paramOpt.scndThres > 0
            cfg.thres.second = thresfun(cfg.thres.center, cfg.thres.variance, cfg.paramOpt.scndThres);
        end
    end
end    


%% If desired calculate average threshold
if strcmp(cfg.param.thresType, 'average')
    cfg.thres.main = repmat(mean(cfg.thres.main,1),numThres,1);
    
    if cfg.paramOpt.scndThres > 0
        cfg.thres.second = repmat(mean(cfg.thres.second,1),numThres,1);
    end
end


%% Prepare new artifact filter for channels specified for the detection
% bnryArtfree = cellfun(@(x) ones(numDetct,size(x,2),'logical'),inData.trial,'UniformOutput',0);
% 
% if isfield(inData, 'artfcts')
%     for iTrl = 1 : numTrl
%         for iCh = 1 : numDetct
%             currCh = ismember(inData.label,cfg.chDetct{iCh});
%             
%             tmpArt = inData.artifacts{currCh,iTrl} + artfctPad;
%             tmpArt(tmpArt(:,1) < 1,1)                      = 1;                         %% Ensure padding does not...
%             tmpArt(tmpArt(:,2) > inData.sampleinfo(1,2),2) = inData.sampleinfo(1,2);    %% exceed data range
%             
%             for iArt = 1 : size(tmpArt,1)
%                 bnryArtfree{iTrl}(iCh,tmpArt(iArt,1):tmpArt(iArt,2)) = 0;
%             end
%             
%             clear tmpArt
%         end
%     end
% end


%% Prepare data to detect events
% tmpDetect = [];
% 
% for iTrl = 1 : numTrl                                       %% loop over trials
%     for iCh = 1 : numDetct                               %% loop over channels
%         if any(ismember(cfg.chThres, cfg.chDetct{iCh}))    %% re-use previous filtered data if possible
%             tmpDetect.trial{iTrl}(iCh,:) = thres{iTrl}(ismember(cfg.chThres, cfg.chDetct{iCh}),:);
%         else
%             fprintf('Channel %d/%d (%s)\n', iCh,numDetct, cfg.chDetct{iCh});
%             currCh = ismember(inData.label, cfg.chDetct{iCh});
%             switch cfg.filtType
%                 case 'fir'
%                     tmpDetect.trial{iTrl}(iCh,:) = ft_preproc_bandpassfilter(inData.trial{iTrl}(currCh,:), fsample, cfg.param.bpfreq, 3*fix(fsample/cfg.param.bpfreq(1))+1, 'fir', 'twopass');
%                 case 'but'
%                     tmpHP = ft_preproc_highpassfilter(inData.trial{iTrl}(currCh,:), fsample, cfg.param.bpfreq(1), 5, 'but', 'twopass','reduce');
%                     tmpDetect.trial{iTrl}(iCh,:) = ft_preproc_lowpassfilter(tmpHP, fsample, cfg.param.bpfreq(2), 5, 'but', 'twopass','reduce');
%                     
%                     clear tmpHP
%             end
%         end
%     end
% end
% 
% clear tmpThres

%% calculate envelope of bandpass filtered signal
% tmpDetectEnv = [];
% switch cfg.param.envType
%     case 'rms'
%         tmpDetectEnv.trial = cellfun(@(x) envelope(x',round(cfg.param.envWin * fsample),'rms')',tmpDetect.trial,'UniformOutput',0);
%     case 'env'
%         tmpDetectEnv.trial = cellfun(@(x) envelope(x',round(cfg.param.envWin * fsample),'analytic')',tmpDetect.trial,'UniformOutput',0);
% end
% 
% if cfg.paramOpt.smoothEnv > 0       %% Smooth envelope if requested
%     if ~verLessThan('matlab','9.2')
%         tmpDetectEnv.trial = cellfun(@(x) smoothdata(x,2,'movmean',round(cfg.paramOpt.smoothEnv * fsample)),tmpDetectEnv.trial,'UniformOutput',0);
%     else
%         for iTrl = 1 : numTrl
%             for iCh = 1 : numDetct
%                 tmpDetectEnv.trial{iTrl}(iCh,:) = smooth(tmpDetectEnv.trial{iTrl}(iCh,:),round(cfg.paramOpt.smoothEnv * fsample));
%             end
%         end
%     end
% end


%% detect crossings
supThres = arrayfun(@(x) nan(numDetct,x),lenTrl,'UniformOutput',0);
for iTrl = 1 : numTrl % loop over trials
    for iCh = 1 : numDetct
        currCh = ismember(cfg.chThres, cfg.chDetct{iCh});  % match current detection channel to chThres vector
        
        supThres{iTrl}(iCh,:) = all([thresEnv{iTrl}(currCh,:) >= cfg.thres.main(currCh);...
                                     thresEnv{iTrl}(currCh,:) <= cfg.thres.upperCutoff(currCh);...
                                     godfltr{iTrl}(currCh,:)]);
    end
end


%% check all event requirements and calculate metrics
for iTrl = 1 : numTrl               % loop over trials
    for iCh = 1 : numDetct       % loop over detect channels
        currCh = ismember(cfg.chThres, cfg.chDetct{iCh});
        
        cfg.evtIndiv(iCh,iTrl).label   = cfg.chDetct{iCh};                                      % Channel name
        cfg.evtIndiv(iCh,iTrl).tss     = sum(godfltr{iTrl}(currCh,:),2) / (fsample * 60);       % time spend asleep (in min), based on artifact-free sleep

                
        %% Optional: Second thresholding
        if cfg.paramOpt.scndThres > 0
            tmpEvts = hvn_extrctBnryBouts(supThres{iTrl}(iCh,:));
            
%             dsig    = diff([0 supThres{iTrl}(iCh,:) 0]);
%             staIdx  = find(dsig > 0);
%             endIdx  = find(dsig < 0) - 1;
            
            for kEvt = 1 : size(tmpEvts,1)
                if max(thresEnv{iTrl}(currCh,tmpEvts(kEvt,1):tmpEvts(kEvt,2))) < cfg.thres.second(currCh)
                    supThres{iTrl}(iCh,tmpEvts(kEvt,1):tmpEvts(kEvt,2)) = 0;
                end
            end
        end
        
        %% Discard intervals not fulfilling minimal length
        tmpEvts = hvn_extrctBnryBouts(supThres{iTrl}(iCh,:));
        rmvIdx  = hvn_createBnrySignal(tmpEvts(diff(tmpEvts,1,2) < round(cfg.criterion.duration(1) * fsample),:),lenTrl(iTrl));
        supThres{iTrl}(iCh,rmvIdx) = 0;
        
%         dsig    = diff([0 supThres{iTrl}(iCh,:) 0]);
%         staIdx  = find(dsig > 0);
%         endIdx  = find(dsig < 0)-1;
%         tmpLen  = (endIdx-staIdx+1) < round(cfg.criterion.duration(1) * fsample);
%         
%         rmvIdx                      = cell2mat(reshape(arrayfun(@(x,y) x:y, staIdx(tmpLen), endIdx(tmpLen),'UniformOutput',0),1,sum(tmpLen)));
%         supThres{iTrl}(iCh,rmvIdx)  = 0;
        
%         for kEvt = 1 : size(staIdx,2)
%             if duration(kEvt) < round(cfg.criterionLen(1,1) * fsample)
%                 supThres{iTrl}(jCh,staIdx(kEvt):endIdx(kEvt)) = 0;
%             end
%         end
        
        %% Optional: Merge intervals closer than specified margin and artifact free
        if cfg.paramOpt.mergeEvts > 0
            tmpEvts = hvn_extrctBnryBouts(supThres{iTrl}(iCh,:));
            
%             dsig    = diff([0 supThres{iTrl}(iCh,:) 0]);
%             staIdx  = find(dsig > 0);
%             endIdx  = find(dsig < 0)-1;
            
            for kEvt = 1 : size(tmpEvts,1)-1
                if tmpEvts(kEvt+1,1) - tmpEvts(kEvt,2) <= round(cfg.paramOpt.mergeEvts * fsample) && ...
                   all(godfltr{iTrl}(currCh,tmpEvts(kEvt,1):tmpEvts(kEvt+1,2)))
                    supThres{iTrl}(iCh,tmpEvts(kEvt,1):tmpEvts(kEvt+1,2)) = 1;
                end
            end
        end
        
        %% Optional: Discard events not fulfilling minimal number of cycles
        if cfg.paramOpt.minCycles > 0
%             dsig    = diff([0 supThres{iTrl}(iCh,:) 0]);
%             staIdx  = find(dsig > 0);
%             endIdx  = find(dsig < 0)-1;
            tmpEvts = hvn_extrctBnryBouts(supThres{iTrl}(iCh,:));
            
            switch cfg.paramOpt.minCycles
                case 1
                    currSig = smoothdata(inData.trial{iTrl}(ismember(inData.label,cfg.chDetct{iCh}),:),'movmedian',3);
                case 2
                    currSig = smoothdata(thres{iTrl}(currCh,:),'movmedian',3);
            end
            
            for kEvt = 1 : size(tmpEvts,1)
                [~,maxidx] = findpeaks(currSig(1,tmpEvts(kEvt,1):tmpEvts(kEvt,2)));
                [~,minidx] = findpeaks((-1) * currSig(1,tmpEvts(kEvt,1):tmpEvts(kEvt,2)));
                
                if (numel(maxidx) < cfg.paramOpt.minCyclesNum) || (numel(minidx) < cfg.paramOpt.minCyclesNum)
                    supThres{iTrl}(iCh,tmpEvts(kEvt,1):tmpEvts(kEvt,2)) = 0;
                end
            end
            
            clear currSig
        end
        
        %% Last iteration to discard spindles longer than specified duration
        numEvt = 0; % initialize event counter
        
        tmpEvts = hvn_extrctBnryBouts(supThres{iTrl}(iCh,:));
        tmpLen  = diff(tmpEvts,1,2)+1;
                
        for kEvt = 1: size(tmpEvts,1)
            if tmpLen(kEvt) <= round(cfg.criterion.duration(2)*fsample) && ... % inclusion criterion fullfilled w/o artifacts
               all(godfltr{iTrl}(currCh,tmpEvts(kEvt,1)+critPad(1) : tmpEvts(kEvt,2)+critPad(2)))
%                all(all([bnryStage{iTrl}(staIdx(kEvt) - critPad(1) : endIdx(kEvt) + critPad(2)); ...
%                         bnryArtfree{iTrl}(iCh,staIdx(kEvt) - critPad(1) : endIdx(kEvt) + critPad(2))]))
                
                numEvt = numEvt + 1;
                
                cfg.evtIndiv(iCh,iTrl).staTime(numEvt) = tmpEvts(kEvt,1);                   % event start (in datapoints)
                cfg.evtIndiv(iCh,iTrl).midTime(numEvt) = round(mean(tmpEvts(kEvt,:),2));    % event cent (in datapoints)
                cfg.evtIndiv(iCh,iTrl).endTime(numEvt) = tmpEvts(kEvt,2);                   % event end (in datapoints)
                
                cfg.evtIndiv(iCh,iTrl).duration(numEvt) = tmpLen(kEvt) / fsample;  % event duration (in seconds)
                
                cfg.evtIndiv(iCh,iTrl).stage(numEvt)   = inData.staging{iTrl}(tmpEvts(kEvt,1));
                
                                
                tmpWin                                  = thres{iTrl}(currCh,tmpEvts(kEvt,1):tmpEvts(kEvt,2));
                [minAmp,minIdx]                         = min(tmpWin);
                [maxAmp,maxIdx]                         = max(tmpWin);
                cfg.evtIndiv(iCh,iTrl).maxTime(numEvt)  = tmpEvts(kEvt,1) + maxIdx - 1; % time of event peak (in datapoints)
                cfg.evtIndiv(iCh,iTrl).minTime(numEvt)  = tmpEvts(kEvt,1) + minIdx - 1; % time of event trough (in datapoints)
                cfg.evtIndiv(iCh,iTrl).minAmp(numEvt)   = minAmp;
                cfg.evtIndiv(iCh,iTrl).maxAmp(numEvt)   = maxAmp;
                
                tmpWin                                      = thresEnv{iTrl}(currCh,tmpEvts(kEvt,1):tmpEvts(kEvt,2));
                [maxAmp,maxIdx]                             = max(tmpWin);
                cfg.evtIndiv(iCh,iTrl).envMaxAmp(numEvt)    = maxAmp;                     % RMS max
                cfg.evtIndiv(iCh,iTrl).envMaxTime(numEvt)   = tmpEvts(kEvt,1) + maxIdx - 1;  % time of RMS max (in datapoints)
                cfg.evtIndiv(iCh,iTrl).envMean(numEvt)      = mean(tmpWin,2);
                cfg.evtIndiv(iCh,iTrl).envSum(numEvt)       = sum(tmpWin,2);
                
                % Add peaks and troughs
                tmpWin          = thres{iTrl}(currCh,tmpEvts(kEvt,1):tmpEvts(kEvt,2));
                [~, peaks]      = findpeaks(tmpWin,tmpEvts(kEvt,1):tmpEvts(kEvt,2));
                [~, troughs]    = findpeaks((-1) * tmpWin,tmpEvts(kEvt,1):tmpEvts(kEvt,2));
                                                
                cfg.evtIndiv(iCh,iTrl).peaks{numEvt}    = peaks;
                cfg.evtIndiv(iCh,iTrl).troughs{numEvt}  = troughs;
                cfg.evtIndiv(iCh,iTrl).freq(numEvt)     = fsample / mean([diff(peaks),diff(troughs)]);
                                
%             else % duration criterion NOT fullfilled
%                 supThres{iTrl}(iCh,staIdx(kEvt):endIdx(kEvt)) = 0; % remove unfit events from suprathresh-data
            end
        end
        
        cfg.evtIndiv(iCh,iTrl).numEvt = numEvt;   % Save number of detected events
    end
end

clear thres thresEnv supThres


%% Optional: False positive rejection based on frequency profile
if cfg.doFalseposRjct
    fprintf('----- Event rejection by frequency profile\n');
    cfg.falseposRjct.rejects = cell(numDetct,numTrl);
    
    for iTrl = 1 : numTrl
        for iCh = 1 : numDetct
            fprintf('Channel %d/%d (%s): ', iCh, numDetct,cfg.chDetct{iCh});
            
            tmpTic = tic;
            currCh = ismember(inData.label,cfg.chDetct{iCh});
            
            %--- Segment data
            tfg         = [];
            tfg.trl     = [cfg.evtIndiv(iCh,iTrl).envMaxTime' + round(cfg.falseposRjct.timePad(1) * fsample),...
                           cfg.evtIndiv(iCh,iTrl).envMaxTime' + round(cfg.falseposRjct.timePad(2) * fsample),...
                           ones(cfg.evtIndiv(iCh,iTrl).numEvt,1) * round(cfg.falseposRjct.timePad(1) * fsample)];
            tmpTrls   = ft_redefinetrial(tfg,inData);
            
            %--- Calculate time frequency representation
            tfg             = [];
            tfg.channel     = tmpTrls.label(currCh);
            tfg.taper       = 'hanning';
            tfg.method      = 'mtmconvol';
            tfg.pad         = 'nextpow2';
            tfg.output      = 'pow';
            tfg.keeptrials  = 'yes';
            tfg.foi         = cfg.falseposRjct.tfrFreq;
            tfg.toi         = cfg.falseposRjct.tfrTime;
            tfg.t_ftimwin   = cfg.falseposRjct.tfrWin;
            
            tmpTFR  = ft_freqanalysis(tfg,tmpTrls);
            tmpPow  = squeeze(tmpTFR.powspctrm);                                        %% Note: rpt x freq x time
            tmpTime = arrayfun(@(x) nearest(tmpTFR.time,x),cfg.falseposRjct.avgWin);
            tmpFreq = arrayfun(@(x) nearest(tmpTFR.freq,x),cfg.falseposRjct.freqlim);
            
            %--- Perform event rejection
            cfg.falseposRjct.rejects{iCh,iTrl} = ones(size(tmpPow,1),1,'logical');
            
            tmpPow = squeeze(sum(tmpPow(:,:,tmpTime(1):tmpTime(2)),3));
            tmpMax = max(tmpPow,[],2);                                      %% Determine maximum per trial
            tmpPow = tmpPow ./ repmat(tmpMax,1,size(tmpPow,2));             %% Normalise by maximum value
  
            for iEvt = 1 : size(tmpPow,1)
                [~, tmpPks,~,tmpProm] = findpeaks(tmpPow(iEvt,:));
                
                hazMax = find(tmpPks >= tmpFreq(1) & tmpPks <= tmpFreq(2));
                if numel(hazMax) > 0 && any(tmpProm(hazMax) > cfg.falseposRjct.prominence)
                    cfg.falseposRjct.rejects{iCh,iTrl}(iEvt) = 0;
                end
            end
            
            fprintf(' reject %d of %d (%.2f) - took %.2f s\n',...
                     sum(cfg.falseposRjct.rejects{iCh,iTrl}),...
                     size(tmpPow,1),...
                     100 * sum(cfg.falseposRjct.rejects{iCh,iTrl}) / size(tmpPow,1),...
                     toc(tmpTic));
            
            clear tmpTrls tmpTFR tmpPow

        end
    end
end


%% add summary statistics to cfg.summary
for iTrl = 1 : numTrl % loop over trials
    for iCh = 1 : numDetct
        cfg.summary(iCh,iTrl).label = cfg.chDetct{iCh};
        cfg.summary(iCh,iTrl).tss   = cfg.evtIndiv(iCh,iTrl).tss;
        
        if cfg.doFalseposRjct
            cfg.summary(iCh,iTrl).numEvt    = sum(~cfg.falseposRjct.rejects{iCh,iTrl});
            tmpIdx                          = ~cfg.falseposRjct.rejects{iCh,iTrl};
        else
            cfg.summary(iCh,iTrl).numEvt    = cfg.evtIndiv(iCh,iTrl).numEvt;
            tmpIdx                          = ones(cfg.summary(iCh,iTrl).numEvt,1,'logical');
        end    
            
        if cfg.summary(iCh,iTrl).numEvt > 0
            cfg.summary(iCh,iTrl).density   = cfg.summary(iCh,iTrl).numEvt / cfg.summary(iCh,iTrl).tss;
            cfg.summary(iCh,iTrl).duration  = mean(cfg.evtIndiv(iCh,iTrl).duration(tmpIdx),2);
            cfg.summary(iCh,iTrl).freq      = mean(cfg.evtIndiv(iCh,iTrl).freq(tmpIdx),2);
            cfg.summary(iCh,iTrl).minAmp    = mean(cfg.evtIndiv(iCh,iTrl).minAmp(tmpIdx),2);
            cfg.summary(iCh,iTrl).maxAmp    = mean(cfg.evtIndiv(iCh,iTrl).maxAmp(tmpIdx),2);
            cfg.summary(iCh,iTrl).envMax    = mean(cfg.evtIndiv(iCh,iTrl).envMaxAmp(tmpIdx),2);
            cfg.summary(iCh,iTrl).envMean   = mean(cfg.evtIndiv(iCh,iTrl).envMean(tmpIdx),2);
            cfg.summary(iCh,iTrl).envSum    = mean(cfg.evtIndiv(iCh,iTrl).envSum(tmpIdx),2);
        end
    end
end
