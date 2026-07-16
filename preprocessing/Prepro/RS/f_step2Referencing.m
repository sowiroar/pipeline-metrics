function [status, EEG] = f_step2Referencing(pathStep0, nameStep0, isReferenced, pathStep1, nameStep1, reref_REST)
%Function that performs re-referencing to an average reference
%INPUTS:
%setPath = Path of the .set that wants to be analyzed
%setName = Name of the .set that wants to be analyzed
%isReferenced = True if the .json said that the EEGs were already referenced. False otherwise
%pathStep0 = Path of the .mat containing the vector of channel indexes to exclude, as well as the labels of those channels. (Empty by default)
%nameStep0 = Name of the .mat containing the vector of channel indexes to exclude, as well as the labels of those channels. (Empty by default)
%reref_REST = true if the user wants to re-reference the data using REST, in addition to average referencing (false by default)
%OUTPUTS:
%status = 1 if this script was completed succesfully. 0 otherwise
%EEG =  EEGLab structure already referenced to an average reference

%Defines default input values
status = 1;
if nargin < 4
    pathStep1 = [];
    nameStep1 = [];
elseif nargin > 4
    if ~exist(fullfile(pathStep1, nameStep1), 'file')
        disp('ERROR: The given path and name for the step 1 (Identification of bad channels) do not exist');
        status = 0;
        return
    end
else
    disp('ERROR: The inputs for this function must be either 3, 5 or 6. See the documentation below:');
    help('f_step2Referencing');
    status = 0;
    return
end
if nargin < 6
    reref_REST = false;
end


%Loads the desired .set
EEG = pop_loadset('filename', nameStep0, 'filepath', pathStep0);

%Checks that the .set has the channel information (chanlocs)
if isempty(EEG.chanlocs)
    status = 0;
    disp('ERROR: chanlocs are required for this and further steps');
    disp('TIP: You can import the chanlocs information using readlocs');
    help readlocs;
    return
end

%If available, load the .mat with the bad channels
if ~isempty(pathStep1) && ~isempty(nameStep1)
    load(fullfile(pathStep1, nameStep1));           %This loads up 2 variables (badChanIndexes and badChanLabels)
    
    %Makes sure that the labels exist in the given dataset (should always exist, but just a sanity check)
    chanLbls = {EEG.chanlocs(:).labels};
    for i = 1:length(badChanIdxs)
        %If the indexes and labels saved do not correspond to the EEG's channel labels of the .set, something went wrong
        if ~strcmp(chanLbls{badChanIdxs(i)}, badChanLbls{i})
            status = 0;
            disp('ERROR: The labels of the bad channels (Step 1) at the following path:');
            disp(fullfile(pathStep1, nameStep1));
            disp('Do not correspond to the channel labels of the original .set at the following path:');
            disp(fullfile(pathStep0, nameStep0));
            disp('Tip: The error should not be generated on normal conditions. Please make sure that you are saving the correct files at the correct steps for each subject')
            disp('Tip: By running the script f_mainPreproRS you should avoid getting this error');
            return
        end
    end
else
    badChanIdxs = [];
end

%If the .json said it was referenced to average, check that the reference of the .set says so as well
if isReferenced && strcmp(EEG.ref, 'averef')
    fprintf('WARNING: The database said that the original .sets were already referenced to average, but the EEGLab structure has a different reference: %s', EEG.ref);
    disp('Do you want to reference it (y), or assume that it is already referenced (n)?');
    ignoreDatabaseRef = input('');
    
    if strcmpi(ignoreDatabaseRef, 'y')
        %Re-reference to the average of the electrodes
        EEG = pop_reref(EEG, [], 'exclude', badChanIdxs);
        
    else
        %Simply change the field so it says it was already referenced
        EEG.ref = 'averef';
    end
    
else
    %If there was no trouble with the database information, re-reference to the average of the electrodes
    EEG = pop_reref(EEG, [], 'exclude', badChanIdxs);
end

%Performs REST referencing, if desired
if reref_REST
    EEG = f_myREST_reref(EEG, badChanIdxs);
end

%Checks everything is ok
EEG = eeg_checkset(EEG);

end