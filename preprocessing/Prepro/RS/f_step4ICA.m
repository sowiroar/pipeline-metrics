function [status, EEG] = f_step4ICA(pathStep3, nameStep3, pathStep1, nameStep1)
%Function that computes the ICA for the .sets of Step0 excluding the channels of Step1
%INPUTS:
%pathStep3 = Path of the .set without noisy segments in time
%nameStep3 = Name of the .set without noisy segments in time
%pathStep1 = Path of the .mat containing the vector of channel indexes to exclude, as well as the labels of those channels
%nameStep1 = Name of the .mat containing the vector of channel indexes to exclude, as well as the labels of those channels
%OUTPUTS:
%status = 1 if the script was completed succesfully. 0 otherwise.
%EEG = EEGLab structure obtained after calculating the ICA

status = 1;

%Loads the .set and the .mat
EEG = pop_loadset('filename', nameStep3, 'filepath', pathStep3);
badChanInfo = load(fullfile(pathStep1, nameStep1));       %This loads up 2 variables (badChanIndexes and badChanLabels)

%Makes sure that the labels exist in the given dataset (should always exist, but just a sanity check)
chanLbls = {EEG.chanlocs(:).labels};
for i = 1:length(badChanInfo.badChanIdxs)
    %If the indexes and labels saved do not correspond to the EEG's channel labels of the .set, something went wrong
    if ~strcmp(chanLbls{badChanInfo.badChanIdxs(i)}, badChanInfo.badChanLbls{i})
        status = 0;
        disp('ERROR: The labels of the bad channels (Step 1) at the following path:');
        disp(fullfile(pathStep1, nameStep1));
        disp('Do not correspond to the channel labels of the cleaned in time .set (Step 3) at the following path:');
        disp(fullfile(pathStep3, nameStep3));
        disp('Tip: The error should not be generated on normal conditions. Please make sure that you are saving the correct files at the correct steps for each subject')
        disp('Tip: By running the script f_mainPreproRS you should avoid getting this error');
        return
    end
end


%If everything is correct, exclude the bad channels before running the ICA
ICAchans = 1:length(chanLbls);
ICAchans(badChanInfo.badChanIdxs) = [];

%Finally, compute the ICA
EEG = pop_runica(EEG, 'chanind', ICAchans , 'extended',1,'interupt','off');
EEG = eeg_checkset(EEG);

end