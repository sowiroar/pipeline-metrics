function [status, normData, normTable, finalPaths, finalNames] = ...
    f_mainPatientControlNorm(controlPaths, controlNames, remainingPaths, remainingNames, normFactor, realMinDuration)
%Description:
%Function that performs control-patient normalization of a given nationality and saves the results
%INPUTS:
%controlPaths = Cell of 1xN containing the paths of the controls of a given nationality
%controlNames = Cell of 1xN containing the .set names of the controls of a given nationality
%remainingPaths = Cell of 1xN containing the paths of the remaining subjects (non-controls) of a given nationality
%remainingNames = Cell of 1xN containing the .set names of the remaining subjects (non-controls) of a given nationality
%normFactor = String with the normalization factor desired (regular 'z-score' by default)
%       All the metrics are calculated for the CONTROLS only, and applied (divided) for all subjects
%       'Z-SCORE': Subtrates the mean and divides by the standard deviation
%       'UN_ALL': Uniform scaling of channel data by dividing by the robust standard deviation of concatenated channel data
%       'PER_CH': Dividing each channel by the MAD of its continuous activity across the whole recording
%       'UN_CH_HB': Uniform scaling of all channels by dividing all channel data by the Huber mean of channel robust standard 
%                   deviation values (same scaling applied to all channels).
%       'RSTD_EP_Mean': Normalizes by taking the mean of each N subject's robust standard deviation per channel individually
%       'RSTD_EP_Huber': Normalizes by taking the Huber mean of each N subject's robust standard deviation per channel individually
%       'RSTD_EP_L2': Normalizes by taking the Euclidean mean of each N subject's robust standard deviation per channel individually
%realMinDuration    = Real minimal duration of the .sets (must be equal or greater than 240)
%OUTPUTS:
%status: 1 if the script was completed successfully, 0 otherwise
%normData: Structure with 2 fields: Controls and Remaining. Each field has a matrix of [channels, time, subjects] already normalized.
%normTable: Table with the metrics to evaluate the performance of the normalization [2, numMetrics]
%finalPaths: Structure with 2 fields: Controls and Remaining. Each field has a cell with the subject paths that were used to generate normData'
%finalNames: Structure with 2 fields: Controls and Remaining. Each field has a cell with the subject names that were used to generate normData'

%Defines the default outputs
status = 0;
normData = [];
normTable = [];
finalPaths = '';
finalNames = '';

%Defines the default type of normalization and savePath, if nothing is given
if nargin < 5
    normFactor = 'Z-SCORE';
end
if nargin < 6
    realMinDuration = 0;
end


%Loads the controls and remaining subjects data
nControls = length(controlPaths);
fprintf('Calculating the normalization factor, and normalizing the controls data (%d subjects)\n', nControls);
iEEG = pop_loadset('filename', controlNames{1}, 'filepath', controlPaths{1}, 'loadmode', 'info');
minPoints = realMinDuration*iEEG.srate;
nChans = iEEG.nbchan;

matControl = zeros(iEEG.nbchan, minPoints, nControls);      %Matrix that will contain the data of all controls
for i = 1:nControls
    fprintf('Loading controls (%d/%d)', i, nControls);
    iEEG = pop_loadset('filename', controlNames{i}, 'filepath', controlPaths{i});

    %Checks that the i-th subject has the minimum number of points required
    if iEEG.pnts < minPoints
        fprintf('WARNING: The current subject has %d number of points, but a minimum of %d points is required\n', iEEG.pnts, minPoints);
        disp('Continuing with the next subject');
        continue
    end
    %Checks that the i-th subject has the same number of points as the first subject
    if iEEG.nbchan ~= nChans
        fprintf('WARNING: The current subject has %d channels, but %d channels were expected\n', iEEG.nbchan, nChans);
        disp('TIP: Run the spatial normalization step to avoid getting this message');
        disp('ERROR: Could not perform patient-control normalization because subjects had different number of channels');
        return
    end
    
    matControl(:,:,i) = iEEG.data(:, 1:minPoints);
end


%Loads the remaining subjects' .set in a matrix of [channels, time, subjects]
nRemaining = length(remainingPaths);
matRemaining = nan(iEEG.nbchan, minPoints, nRemaining);     %Matrix that will contain the data of all remaining subjects
for i = 1:nRemaining
    fprintf('Loading remaining subjects (%d/%d)', i, nRemaining);
    iEEG = pop_loadset('filename', remainingNames{i}, 'filepath', remainingPaths{i});

    %Checks that the i-th subject has the minimum number of points required
    if iEEG.pnts < minPoints
        fprintf('WARNING: The current subject has %d number of points, but a minimum of %d points is required\n', iEEG.pnts, minPoints);
        disp('Continuing with the next subject');
        continue
    end
    %Checks that the i-th subject has the same number of points as the first subject
    if iEEG.nbchan ~= nChans
        fprintf('WARNING: The current subject has %d channels, but %d channels were expected\n', iEEG.nbchan, nChans);
        disp('TIP: Run the spatial normalization step to avoid getting this message');
        disp('Continuing with the next subject');
        return
    end

    matRemaining(:,:,i) = iEEG.data(:, 1:minPoints);
end

%Identifies the subjects that did not had enough points
excludedControls = isnan(matControl);
excludedControls = squeeze(sum(sum(excludedControls))) == minPoints*iEEG.nbchan;
excludedRemaining = isnan(matRemaining);
excludedRemaining = squeeze(sum(sum(excludedRemaining))) == minPoints*iEEG.nbchan;


%Removes the subjects and data of the subjects that did not had enough points
if sum(excludedControls) > 0 || sum(excludedRemaining) > 0
    fprintf('Removing the %d subjects that did not had the minimum number of points required \n', sum(excludedControls) + sum(excludedRemaining));
    matControl(:,:,excludedControls) = [];
    controlPaths(excludedControls) = [];
    controlNames(excludedControls) = [];
    matRemaining(:,:,excludedRemaining) = [];
    remainingPaths(excludedRemaining) = [];
    remainingNames(excludedRemaining) = [];
end



%CHECKS NORMALITY BEFORE NORMALIZING! Lets the user know if the data follows a normal distribution or not
alpha = 0.05;
disp('Making normality tests for all the actual subjects. This might take a while...');
[isNormalCtrl, cWarningsCtrl] = f_checkNormality(matControl, alpha);
[isNormalRem, cWarningsRem] = f_checkNormality(matRemaining, alpha);
if isNormalCtrl < 0 || isNormalRem < 0
    %Displays the warning messages generated when checking normality
    disp('WARNINGS FOR CONTROLS:');
    for i = 1:length(cWarningsCtrl)
        disp(cWarningsCtrl{i});
    end
    disp('WARNINGS FOR REMAINING SUBJECTS:');
    for i = 1:length(cWarningsRem)
        disp(cWarningsRem{i});
    end
    
    %Sends additional warnings depending on which combination of data does not follow a normal distribution
    if isNormalCtrl == -1 || isNormalRem  == -1
        disp('WARNING: The data DOES NOT follow a normal distribution for at least one channel');
    end
    if isNormalCtrl == -2 || isNormalRem  == -2
        disp('WARNING: The data DOES NOT follow a normal distribution for all the data combined');
    end
    if isNormalCtrl == -3 || isNormalRem  == -3
        disp('WARNING: The data DOES NOT folow a normal distribution for all data combined and for at least one individual channel');
        disp('All the normalization metrics ASSUME A NORMAL DISTRIBUTION');
        disp('Are you sure you want to continue? (y/n)');
        ignoreNormality = input('', 's');
        
        if ~strcmpi(ignoreNormality, 'y')
            disp('ERROR: Could not normalize the data because the data does not follow a normal distribution');
            return
        end
    end
end



%Performs the desired patient-control normalization
fprintf('Calculating the normalization factor using: %s\n', normFactor);
if strcmp(normFactor, 'Z-SCORE')
    %Finds the mean and std per channel of the controls across subjects per time and per channel
    meanPerCh = mean(mean(matControl, 3), 2);
    stdPerCh = std(std(matControl, [], 3), [], 2);
    
    %Performs the normalization both for controls and the rest of the subjects
    normControl = (matControl - meanPerCh)./stdPerCh;
    normRemaining = (matRemaining - meanPerCh)./stdPerCh;
    
else
    %Obtains the normalization factor for the desired normalization metric
    [status, normFactor] = f_getNormalizationFactor(matControl, normFactor);
    
    %Checks that the normalization factor was calculated successfully
    if status == 0
        disp('ERROR: Could not calculate the normalization factor. Check the function f_getNormalizationFactor');
        return
    end
    
    %Performs the normalization
    normControl = matControl./normFactor;
    normRemaining = matRemaining./normFactor;
end
disp('Patient-Control Normalization completed!');


%Identifies infinite or NaN values and let the user know that it might be due to non-EEG Channels
excludedChanControls = (normControl == inf) | (normControl == -inf) | isnan(normControl);
excludedChanControls = squeeze(sum(sum(excludedChanControls, 3), 2)) > 0;
excludedChanRemaining = (normRemaining == inf) | (normRemaining == -inf) | isnan(normRemaining);
excludedChanRemaining = squeeze(sum(sum(excludedChanRemaining, 3), 2)) > 0;
if sum(excludedChanControls) > 0 || sum(excludedChanRemaining) > 0
    %Gives info about the error
    disp('WARNING: Infinite or NaN values were produced in the normalized data. This might be due to non-EEG channels');
    disp('These are the channels that had infinite or NaN values:');
    chanLbls = {iEEG.chanlocs(:).labels};
    disp('Infinite or NaN Channels for Controls:');
    disp(chanLbls(excludedChanControls));
    disp('Infinite or NaN Channels for Remaining subjects:');
    disp(chanLbls(excludedChanRemaining));
    disp('TIP: If these are non-EEG channels, please remove the channels by yourself from the previous step using pop_select');
    
    %Ask the user if the script should continue without the Infinite channels
    disp('If it is not the case, do you want to continue BUT WITHOUT THOSE CHANNELS? (y/n)');
    removeChans = input('', 's');
    if ~strcmpi(removeChans, 'y')
        disp('ERROR: Could not complete the step due to infinte values');
        return
    end
    
    %Replaces the infinite channels from the normalized data
    chansToRemove = excludedChanControls | excludedChanRemaining;
    fprintf('WARNING: Replacing %d infinite channels from the normalized data with the original data\n', sum(chansToRemove));
    disp(chanLbls(chansToRemove));
    normControl(chansToRemove, :, :) = matControl(chansToRemove,:,:);
    normRemaining(chansToRemove, :, :) = matRemaining(chansToRemove,:,:);
end


%Calculates some metrics to evaluate the normalization performance, if desired
testNormalization = true;
if testNormalization
    disp('Calculating the metrics to evaluate the normalization performance, this might take a while...');
    testMetrics = {'VAR_EXP', 'TOT_VAR', 'DIST', 'COR_DIST', 'SPR_COR_DIST', 'COS_DIST', ...
        'VAR_EXP_ROB', 'TOT_VAR_ROB', 'DIST_ROB', 'COR_DIST_ROB', 'SPR_COR_DIST_ROB', 'COS_DIST_ROB'};
    nTestMetrics = length(testMetrics);
    oldDataMetrics = zeros(1, nTestMetrics);
    newDataMetrics = zeros(1, nTestMetrics);
    oldData = cat(3, matControl, matRemaining);
    newData = cat(3, normControl, normRemaining);
    for i = 1:nTestMetrics
        try
            oldDataMetrics(i) = f_CalculateMetrics(oldData, testMetrics{i});
            newDataMetrics(i) = f_CalculateMetrics(newData, testMetrics{i});
        catch
            fprintf('WARNING: Could not calculate the metric: %s\n', testMetrics{i});
            oldDataMetrics(i) = NaN;
            newDataMetrics(i) = NaN;
        end
    end
    
    %Shows the results of the normalization in a table
    disp('METRICS RESULTS: (The normalized data should have HIGHER values than the original)');
    normTable = cell2table(num2cell([oldDataMetrics; newDataMetrics]), 'RowNames', {'Original', 'Normalized'}, 'VariableNames', testMetrics);
    disp(normTable);
    
    worsePerformance = oldDataMetrics>newDataMetrics;
    fprintf('\nIn total, there were %d/%d metrics that showed WORSE feature stability after the normalization\n', ...
        sum(worsePerformance), nTestMetrics);
    
    disp('And these were the metrics that showed WORSE performance:');
    disp(testMetrics(worsePerformance));
    
    %If more than half of the metrics showed bad results, let the user know
    if sum(worsePerformance) > round(nTestMetrics/2)
        disp('WARNING: More than half of the metrics showed WORSE performance after normalization');
        disp('It is highly encouraged that you choose another (normMetric)');
        disp('Do you still want to continue and save the results? (y/n)');
        ignoreMetrics = input('', 's');
        if ~strcmpi(ignoreMetrics, 'y')
            return
        end
    end
end


%Defines the outcomes
normData.Controls = normControl;
normData.Remaining = normRemaining;
finalPaths.Controls = controlPaths;
finalPaths.Remaining = remainingPaths;
finalNames.Controls = controlNames;
finalNames.Remaining = remainingNames;

%If it made it this far, the script was completed successfully
status = 1;

end