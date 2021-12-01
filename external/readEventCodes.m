function [eventTimes, eventCodes] = readEventCodes(pl2FilePath)
% Read all event times and corresponding event codes stored as a binary 
% variable across Plexon EVT event variables in a Plexon PL2 file
%
% Inputs:
% - pl2FilePath: path to Plexon PL2 data file on filesystem
%
% Outputs:
% - eventTimes: 1 x N array of event times (in seconds)
% - eventCodes: 1 x N array of event codes (in base 10) associated with
%               each event time
%
% read header information of PL2 file
dataInfo = PL2GetFileIndex(pl2FilePath);

% access and store event times for each event variable in PL2 file (has
% format EVTxx) where xx is 01, 02, ...
nEventCh = 0;
% fprintf('Found event variables: ');
for i = 1:numel(dataInfo.EventChannels)
    if dataInfo.EventChannels{i}.NumEvents > 0
        nEventCh = nEventCh + 1;
%         fprintf('%s(%d), ', dataInfo.EventChannels{i}.Name, dataInfo.EventChannels{i}.NumEvents);
        ts = PL2EventTs(pl2FilePath, dataInfo.EventChannels{i}.Name);
        assert(strcmp(dataInfo.EventChannels{i}.Name, sprintf('EVT%02d', nEventCh)));
        D.events{nEventCh} = ts.Ts;
    end
end
% fprintf('\n');

% get all event times (assumes that an event that triggers different event
% variables have the EXACT same time)
eventTimes = unique(cat(1, D.events{:}));

nEvent = numel(eventTimes);
eventCodes = nan(nEvent, 1);
for i = 1:nEvent
    timeMatches = cellfun(@(x) any(eventTimes(i) == x), D.events(8:-1:1)); % reverse event order to get proper binary code (EVT1 is rightmost)
    eventCodes(i) = bin2dec(num2str(timeMatches, '%d')); % convert from logical to decimal (00001110 to 14)
end
% eventmatT.code=eventCodes;
% eventmatT.times=eventTimes;
% save('eventmat.mat','eventmatT');
assert(~any(isnan(eventCodes)) && ~any(eventCodes == 0));

% print how many events exist for each event code
% uniqueEventCodes = unique(eventCodes);
% for i = 1:numel(uniqueEventCodes)
%     fprintf('Event code %3d: %5d events\n', uniqueEventCodes(i), sum(eventCodes == uniqueEventCodes(i)));
% end

% eventTimes(eventCodes == 15) % get all event times that have event code 15