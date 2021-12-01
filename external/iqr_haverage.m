function [Y,Q]=iqr_haverage(X)
%     iqr Interquartile range. 
%     Y = iqr_haverage(X) returns the interquartile range of the values in X using the HAVERAGE method.
%     It accepts only vector input, Y is the interquartile range(IQR), it is the difference between the 75th and 25th percentiles
%     of X.
%     The quartiles for 25th, 50th and 75th percentiles are stored in Q with respective order. 
%
%     The HAVERAGE method is the default method in SPSS used in analyses EXAMINE and FREQUENCIES 
%     It gives different values than Matlab's iqr.m and prctile.m
%
%     For more information on the convention that SPSS uses see http://www-01.ibm.com/support/docview.wss?uid=swg21480663
%     For different methods see: http://www.xycoon.com/quartiles.htm
%
%     Murat Saglam, 16.07.2014.
%
%     Added NaN functionality and some comments. Values may diverge from
%     SPSS IQR output due to SPSS's listwise exclusion in case of missing
%     values.
%     Jens Klinzing, 13.01.2017, jens.klinzing@uni-tuebingen.de

X = X(~isnan(X));
X=sort(X);
n=length(X);
p=[.25,.5,.75];

for z=1:3
    j=floor((n+1)*p(z));    % integer part
    
    g=(n+1)*p(z)-j;             % fractional part
    Q(z)=(1-g)*X(j)+g*X(j+1);
end
Y=Q(3)-Q(1);

