function [s, cfg] = ft_statfun_signedrank(cfg, dat, design)

% FT_STATFUN_DEPSAMPLEST calculates the dependent samples T-statistic 
% on the biological data in dat (the dependent variable), using the information on 
% the independent variable (ivar) in design.
%
% Use this function by calling one of the high-level statistics functions as
%   [stat] = ft_timelockstatistics(cfg, timelock1, timelock2, ...)
%   [stat] = ft_freqstatistics(cfg, freq1, freq2, ...)
%   [stat] = ft_sourcestatistics(cfg, source1, source2, ...)
% with the following configuration option
%   cfg.statistic = 'ft_statfun_depsamplesT'
%
% See FT_TIMELOCKSTATISTICS, FT_FREQSTATISTICS or FT_SOURCESTATISTICS for details.
%
% For low-level use, the external interface of this function has to be
%   [s,cfg] = ft_statfun_depsamplesT(cfg, dat, design);
% where
%   dat    contains the biological data, Nsamples x Nreplications
%   design contains the independent variable (ivar) and the unit-of-observation (uvar) 
%          factor,  Nfac x Nreplications
%
% Configuration options
%   cfg.computestat    = 'yes' or 'no', calculate the statistic (default='yes')
%   cfg.computecritval = 'yes' or 'no', calculate the critical values of the test statistics (default='no')
%   cfg.computeprob    = 'yes' or 'no', calculate the p-values (default='no')
% The following options are relevant if cfg.computecritval='yes' and/or
% cfg.computeprob='yes'.
%   cfg.alpha = critical alpha-level of the statistical test (default=0.05)
%   cfg.tail  = -1, 0, or 1, left, two-sided, or right (default=1)
%               cfg.tail in combination with cfg.computecritval='yes'
%               determines whether the critical value is computed at
%               quantile cfg.alpha (with cfg.tail=-1), at quantiles
%               cfg.alpha/2 and (1-cfg.alpha/2) (with cfg.tail=0), or at
%               quantile (1-cfg.alpha) (with cfg.tail=1).
%
% Design specification
%   cfg.ivar  = row number of the design that contains the labels of the conditions that must be 
%               compared (default=1). The labels are the numbers 1 and 2.
%   cfg.uvar  = row number of design that contains the labels of the units-of-observation (subjects or trials)
%               (default=2). The labels are assumed to be integers ranging from 1 to 
%               the number of units-of-observation.

% Copyright (C) 2006, Eric Maris
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% set defaults
if ~isfield(cfg, 'computestat'),    cfg.computestat    = 'yes'; end 
if ~isfield(cfg, 'computecritval'), cfg.computecritval = 'no';  end
if ~isfield(cfg, 'computeprob'),    cfg.computeprob    = 'no';  end
if ~isfield(cfg, 'alpha'),          cfg.alpha          = 0.05;  end
if ~isfield(cfg, 'tail'),           cfg.tail           = 0;     end

% perform some checks on the configuration
if strcmp(cfg.computeprob,'yes') && strcmp(cfg.computestat,'no')
    ft_error('P-values can only be calculated if the test statistics are calculated.');
end
% if ~isfield(cfg,'uvar') || isempty(cfg.uvar)
%     ft_error('uvar must be specified for dependent samples statistics');
% end

% perform some checks on the design
sel1 = design(cfg.ivar,:)==1;
sel2 = design(cfg.ivar,:)==2;
% n1  = length(sel1);
% n2  = length(sel2);
numObs = size(dat,1);

% fprintf('number of observations %d\n', numObs);
% fprintf('number of replications %d and %d\n', n1, n2);

% if (n1+n2)<size(design,2) || (n1~=n2)
%   ft_error('Invalid specification of the design array.');
% end
% nunits = length(design(cfg.uvar, sel1));
% df = nunits - 1;
% if nunits<2
%     ft_error('The data must contain at least two units (usually subjects).')
% end
% if (nunits*2)~=(n1+n2)
%   ft_error('Invalid specification of the design array.');
% end
% nsmpls = size(dat,1);

if strcmp(cfg.computestat,'yes')
    
    switch cfg.tail
        case 0
          tmpTail = 'both';
        case -1
          tmpTail = 'left';
        case 1
          tmpTail = 'right';
    end
    
    tmpProb = nan(numObs,1);
    s.mask = nan(numObs,1);
    s.stat = nan(numObs,1);
    s.rank = nan(numObs,1);
    
    for iObs = 1 : numObs
        [tmpProb(iObs),s.mask(iObs),tmpStats] = signrank(dat(iObs,sel1),dat(iObs,sel2),'alpha', cfg.alpha,'tail', tmpTail,'method','approximate');
        s.stat(iObs) = tmpStats.zval;
        s.rank(iObs) = tmpStats.signedrank;
    end
        
    clear tmpTail tmpStat tmpMask tmpRank
        
end

if strcmp(cfg.computecritval,'yes')
  % also compute the critical values
  switch cfg.tail
      case -1
          s.critval = norminv(cfg.alpha,0,1);
      case 0
          s.critval = [norminv(cfg.alpha/2,0,1) norminv(1-cfg.alpha/2,0,1)];
      case 1
          s.critval = norminv(1-cfg.alpha,0,1);
  end
end

if strcmp(cfg.computeprob,'yes')
  % also compute the p-values
  s.prob = tmpProb;
end


%% graveyard
%   switch cfg.tail
%     case 0
%       cfg.tail = 'both';
%     case -1
%       cfg.tail = 'left';
%     case 1
%       cfg.tail = 'right';
%   end
%   
%   if size(design,1)~=1
%     ft_error('design matrix should only contain one factor (i.e. one row)');
%   end
%   Ncond = length(unique(design));
%   if Ncond~=2
%     ft_error('method ''%s'' is only supported for two conditions', cfg.statistic);
%   end
%   Nobs  = size(dat, 1);
%   selA = find(design==design(1));
%   selB = find(design~=design(1));
%   Nrepl = [length(selA), length(selB)];
% 
%   h = zeros(Nobs, 1);
%   p = zeros(Nobs, 1);
%   s = zeros(Nobs, 1);
%   fprintf('number of observations %d\n', Nobs);
%   fprintf('number of replications %d and %d\n', Nrepl(1), Nrepl(2));
% 
%   ft_progress('init', cfg.feedback);
%   for chan = 1:Nobs
%     ft_progress(chan/Nobs, 'Processing observation %d/%d\n', chan, Nobs);
%     [p(chan), h(chan), stats] = signrank(dat(chan, selA), dat(chan, selB),'alpha', cfg.alpha,'tail', cfg.tail);
%     s(chan) = stats.signedrank;
%   end

