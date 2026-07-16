function [status, EEG] = f_step3CorrectArtifacts(pathStep2, nameStep2, pathStep1, nameStep1, burstCriterion, windowCriterion)
%Description:
%Function that corrects artifacts in time excluding the previously identified bad channels
%INPUTS:
%pathStep2 = Path of the .set that wants to be analyzed
%nameStep2 = Name of the .set that wants to be analyzed
%pathStep1 = Path of the .mat containing the vector of channel indexes to exclude, as well as the labels of those channels
%nameStep1 = Name of the .mat containing the vector of channel indexes to exclude, as well as the labels of those channels
%burstCriterion = Data portions with variance larger than the calibration data will be marked for ASR correction
%                 (lower is more strict, default: 5)
%windowCriterion = Maximum proportion of noisy channels after ASR correction. 
%                  If it surpasses it, removes the time window. (lower is more strict, default: 0.25) (Common ranges: 0.05-0.3)
%OUTPUTS:
%status = 1 if this script was completed succesfully. 0 otherwise
%EEG = EEGLab structure without noisy artifacts in time

status = 1;

%Loads the desired .set and the .mat with the bad channel information
EEG = pop_loadset('filename', nameStep2, 'filepath', pathStep2);
badChanInfo = load(fullfile(pathStep1, nameStep1));       %This loads up 2 variables (badChanIndexes and badChanLabels)

%Makes sure that the labels exist in the given dataset (should always exist, but just a sanity check)
chanLbls = {EEG.chanlocs(:).labels};
for i = 1:length(badChanInfo.badChanIdxs)
    %If the indexes and labels saved do not correspond to the EEG's channel labels of the .set, something went wrong
    if ~strcmp(chanLbls{badChanInfo.badChanIdxs(i)}, badChanInfo.badChanLbls{i})
        status = 0;
        disp('ERROR: The labels of the bad channels (Step 1) at the following path:');
        disp(fullfile(pathStep1, nameStep1));
        disp('Do not correspond to the channel labels of the average referenced .set (Step 2) at the following path:');
        disp(fullfile(pathStep2, nameStep2));
        disp('Tip: The error should not be generated on normal conditions. Please make sure that you are saving the correct files at the correct steps for each subject')
        disp('Tip: By running the script f_mainPreproRS you should avoid getting this error');
        return
    end
end

%Exclude the noisy channels from the analysis of artifacts in time
woBadChansEEG = pop_select(EEG, 'nochannel', badChanInfo.badChanIdxs);

%Runs the analysis that rejects artifacts in time
[outEEG, ~, ~] = clean_artifacts(woBadChansEEG, 'FlatlineCriterion','off','ChannelCriterion','off','LineNoiseCriterion','off', ...
    'BurstCriterion',burstCriterion,'WindowCriterion',windowCriterion,'BurstRejection','off','Distance','Euclidian',...
    'WindowCriterionTolerances',[-Inf 7]);
%Removed 'Highpass','off'; because it had different default values (0.25 0.75)

%Checks that the output channels are the same as the input ones
if size(woBadChansEEG.data, 1) ~= size(outEEG.data, 1)
    disp('ERROR: The number of channels of the output is not the same as the input');
    status = 0;
end

%Checks that both signals have the same number of points in time
if size(EEG.data, 2) ~= size(outEEG.data, 2)
    disp('WARNING: The number of points in time of the output is not the same as the input');
    disp('This might be caused by highly noisy signals unrecoverable by ASR');
    disp('Eliminating those timepoints');
    EEG.etc = outEEG.etc;
    EEG.pnts = outEEG.pnts;
    EEG.times = outEEG.times;
    EEG.xmax = outEEG.xmax;
    EEG.data = EEG.data(:, outEEG.etc.clean_sample_mask);
end

%Adds the ASR corrected signal to the original EEG (with the noisy channels identified in step1, which will be interpolated in step6)
outChanLbls = {outEEG.chanlocs(:).labels};
for i = 1:length(outChanLbls)
    iOutChanLbl = outChanLbls{i};
    idxOriginal = strcmp(iOutChanLbl, chanLbls);
    EEG.data(idxOriginal, :) = outEEG.data(i, :);
end

%Checks that the updated EEG structure was properly created.
EEG = eeg_checkset(EEG);

%Visualizes the signal before and after correcting the artifacts (will be saved in the f_mainPreproRS script)
vis_artifacts(outEEG, woBadChansEEG);

end