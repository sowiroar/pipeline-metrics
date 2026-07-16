function [isNormal, cWarnings] = f_checkNormality(mData, alpha)
%Function that checks if the data of mData follows a normal distribution
%using the Kolmogorov-Smirnov test (n>500) or the Shapiro�Wilk test (n<500)
%INPUTS:
%mData: Matrix of [channels, time, subjects]
%alpha: Level of significance for the normality tests (0.05 by default)
%OUTPUTS:
%isNormal = 1 if the data follows a normal distribution for all cases.
%   -1 if the data DOES NOT follow a normal distribution for at least one channels, but FOLLOWS a normal distribution of all the data combined
%   -2 if the data DOES NOT follow a normal distribution for all the data combined, but FOLLOWS a normal distribution of all the individual channels
%   -3 if the data DOES NOT folow a normal distribution for all data combined and for at least one individual channel
%cWarning = Cell of 1xN with N warnings

%Cell that will contain the warnings
cWarnings = {};
isNormal = 1;

%Flattens the data and performs the normal distribution test
allData = reshape(mData, [], 1);
if length(allData) > 500
    hAll = kstest(allData, 'Alpha', alpha);
else
    hAll = 1;%swtest(x, alpha);
end

%Adds a warning if the concatenated data does not follow a normal distribution
if hAll == 1
    cWarnings{end+1} = 'WARNING: The data does not follow a normal distribution for all the data concatenated';
end

%Checks normality for individual channels
nChans = size(mData, 1);
fprintf('Calculating normalization tests per channel (%d): ', nChans);
for i = 1:nChans
    iChan = mData(i, :, :);
    iChan = reshape(iChan, [], 1);
    if length(iChan) > 500
        hChan = kstest(iChan, 'Alpha', alpha);
    else
        hChan = 1;%swtest(iChan, alpha);
    end
    
    %Adds a warning if the given channel data does not follow a normal distribution
    if hChan == 1
        cWarnings{end+1} = sprintf('WARNING: The channel number %d does not follow a normal distribution', i);
        isNormal = -1;
    end
    fprintf('%d, ', i);
end
fprintf('\n');


%Given the results of the tests, defines the output isNormal
if isNormal == -1 && hAll == 1
    isNormal = -3;
elseif isNormal == 1 && hAll == 1
    isNormal = -2;
end

end