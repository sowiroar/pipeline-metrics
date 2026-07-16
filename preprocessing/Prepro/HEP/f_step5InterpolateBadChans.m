function [status, EEG] = f_step5InterpolateBadChans(pathStep4, nameStep4, pathStep1, nameStep1)
%Description:
%Function that performs interpolation of bad channels
%INPUTS:
%pathStep4 = Path of the .set without noisy components
%nameStep4 = Name of the .set without noisy components
%pathStep1 = Path of the .mat containing the vector of channel indexes to exclude, as well as the labels of those channels
%nameStep1 = Name of the .mat containing the vector of channel indexes to exclude, as well as the labels of those channels
%OUTPUTS:
%status = 1 if this step was completed succesfully. 0 otherwise
%EEG = Structure obtained after performing the interpolation of bad channels

status = 1;

%Loads the .set and the .mat with the bad channel information
EEG = pop_loadset('filename', nameStep4, 'filepath', pathStep4);
badChanInfo = load(fullfile(pathStep1, nameStep1));


%Makes sure that the labels exist in the given dataset (should always exist, but just a sanity check)
chanLbls = {EEG.chanlocs(:).labels};
for i = 1:length(badChanInfo.badChanIdxs)
    %If the indexes and labels saved do not correspond to the EEG's channel labels of the .set, something went wrong
    if ~strcmp(chanLbls{badChanInfo.badChanIdxs(i)}, badChanInfo.badChanLbls{i})
        status = 0;
        disp('ERROR: The labels of the bad channels (Step 1) at the following path:');
        disp(fullfile(pathStep1, nameStep1));
        disp('Do not correspond to the channel labels of the .set without noisy components (Step 4) at the following path:');
        disp(fullfile(pathStep4, nameStep4));
        disp('Tip: The error should not be generated on normal conditions. Please make sure that you are saving the correct files at the correct steps for each subject')
        disp('Tip: By running the script f_mainPreproHEP you should avoid getting this error');
        return
    end
end


%Interpolates the bad channels using a spherical approach, and checks everything is okay
if ~isempty(badChanInfo.badChanIdxs)
    %If there are non-EEG channels in the .mat list, remove them from the .set prior to running the interpolation
    %First, identifies non-empty channels (only EEG channels remain)
    nonemptychans = find(~cellfun('isempty', { EEG.chanlocs.theta }));
    
    %Then, identify the bad channels, on that list of non-empty (EEG only) channels
    badchans  = intersect_bc(badChanInfo.badChanIdxs, nonemptychans);
    finalBadChanLbls = chanLbls(badchans);
    
    %After that, select the nonempty channels in a new EEG channel
    disp('Removing empty (non-EEG) channels...');
    EEG = pop_select(EEG, 'channel', nonemptychans);
    
    %Afterwards, find the indexes of the bad channels in the new list of non-empty channels
    newLbls = {EEG.chanlocs(:).labels};
    finalBadIdxs = zeros(length(finalBadChanLbls), 1);
    for i = 1:length(finalBadChanLbls)
        finalBadIdxs(i) = find(strcmp(finalBadChanLbls{i}, newLbls));
        
        %Check that the new label was a member of the initial labels (should always be the case, but just to be sure)
        if ~ismember(newLbls{finalBadIdxs(i)}, badChanInfo.badChanLbls)
            disp('ERROR: Unexpected mismatch when removing the empty (non-EEG) channels.');
            disp('To try to solve this, check the function f_step4InterpolateBadChans.m');
            status = 0;
            return
        end
    end
    
    %Finally, if there are any bad channels left, run the interpolation
    if isempty(badchans)
        disp('WARNING: The bad channels of this subject were all non-EEG. Not performing any interpolation');
        EEG = eeg_checkset( EEG );
    else
        disp('Removing bad channels that should be interpolated...');
        EEG = pop_interp(EEG, finalBadIdxs, 'spherical');
        EEG = eeg_checkset( EEG );
    end
    
else
    %If the subject didn't had any channel identified as bad, let the user know that
    disp('WARNING: This subject did not have any channel identifies as bad. Not performing any interpolation');
    EEG = eeg_checkset( EEG );
end

end