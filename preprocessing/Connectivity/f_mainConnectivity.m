function [status, finalConnectStepPath, connectivityParams] = ...
    f_mainConnectivity(databasePath, finalStepPath, varargin)
%Description:
%Function that calculates the connectivity metrics (7) of the finalStepPath .mats (or .sets)
%The .mats or .sets MUST BE in [channels, time], OR [sourcePoints, time]
%INPUTS:
%databasePath           = Path of the desired database that wants to be preprocessed.
%       NOTE: The databasePath MUST already be in a BIDS-like structure
%finalStepPath          = Path were the final .sets are expected to be
%       NOTE: The finalStepPath MUST already be in a BIDS-like structure
%OPTIONAL INPUTS:
%BIDSmodality           = String with the modality of the data that will be analyzed (used in sub-#_BIDStask_BIDSmodality.set) ('eeg' by default)
%BIDStask               = String with the task to analyze (used in sub-#_BIDStask_BIDSmodality.set) ('rs' by default)
%newPath                = String with the path in which the new folders will be stored ('databasePath/analysis_RS' by default)
%runConnectivity        = true if the user wants to calculate connectivity metrics, false otherwise (true by Default)
%connIgnoreWSM          = true if wants to ignore the Weighted Symbolic Metrics (3 in total). false otherwise
%OUTPUTS:
%status                 = 1 if the script was completed successfully. 0 otherwise
%finalConnectStepPath   = Path were the final .sets are expected to be (if status is 0, returns an empty array)
%connectivityParams     = Parameters used in the connectivity pipeline (if status is 0, returns an empty array)

%Defines the default outputs
status = 0;
finalConnectStepPath = '';
connectivityParams = '';

%Checks that the user has eeglab
try
    version = eeg_getversion;
catch
    %If eeglab has not been executed, try executing it to enable all eeglab functions, and ask for the version again.
    try
        eeglab;
        close;
        clc;
        version = eeg_getversion;
    catch
        disp('ERROR: It seems that you do not have EEGLab. Please download and install it');
        disp('https://sccn.ucsd.edu/eeglab/download.php');
        disp('https://eeglab.org/tutorials/01_Install/Install.html');
        return;
    end
end
%Checks that the EEGLab version is newer than 2020
if str2double(version) < 2020
    disp('ERROR: These scripts were built using EEGLab v.2020.0');
    disp('Most of the functions can work with older versions of EEGLab, but it is suggested that you have a version from 2020 or newer');
    return;
end


%Checks that the finalStepPath is given and exists
if nargin < 2
    disp('ERROR: A finalStepPath must be given to advance in the pipeline');
    disp('To do so, you must first run the source transformation part of the pipeline');
    return
end
if ~exist(finalStepPath, 'dir')
    fprintf('ERROR: The finalStepPath: %s does not exist \n', finalStepPath);
    disp('You should not get this error if you first run the source transformation part of the pipeline succesfully');
    return
end

%Defines the default optional parameters
%Type help finputcheck to know more about it. Basically it takes the inputs, makes sure everything is okay 
%and puts that information as a structure
params = finputcheck( varargin, {'BIDSmodality',        'string',       '',         'eeg'; ...
                                'BIDStask',             'string',       '',         'task-rest';
                                'newPath',              'string',       '',         fullfile(databasePath, 'analysis_RS');
                                'runConnectivity',      'boolean',      '',         true;
                                'connIgnoreWSM',        'boolean',      '',         true
                                } ...
                                );

%Checks that the defaults where properly created
if ischar(params) && startsWith(params, 'error:')
    disp(params);
    return
end


%Checks that the database exists
if ~exist(databasePath, 'dir')
    disp('ERROR: The given path does not exist. Please enter a valid folder name');
    return
end

%Checks that the folder has a BIDS-like structure
%MUST have a 'README.md', 'participants.tsv', 'task_modality.json' and folders that start with 'sub-'
mainDir = dir(databasePath);
mainDirNames = {mainDir(:).name};
if (sum(strcmp(mainDirNames, 'README.md')) * sum(strcmp(mainDirNames, 'participants.tsv')) ...
    * sum(strcmp(mainDirNames, strcat(params.BIDStask, '_', params.BIDSmodality, '.json'))) * sum(startsWith(mainDirNames, 'sub-'))) == 0
    disp('ERROR: Please check that the folder you gave has a BIDS-like structure');
    disp('It MUST have the following files:');
    disp(strcat('README.md, participants.tsv, ', params.BIDStask, '_', params.BIDSmodality, '.json and folders that start with sub-'));
    disp('Also check that the BIDSmodality and BIDStask that you entered are the ones you are interested in');
    return
end


%Asks the user to check that the number of subjects is correct
dirFinalStep = dir(finalStepPath);
dirFinalStepNames = {dirFinalStep(:).name};
subjFolders = startsWith(dirFinalStepNames, 'sub-');
subjFolders = dirFinalStepNames(subjFolders);
nSubj = length(subjFolders);
fprintf('You currently have %d subjects after source transformation \n', nSubj);
disp('If that is the number of subject you expected, please press any key to continue with the connectivity step, or "q" to quit');
quitNorm = input('', 's');
if strcmpi(quitNorm, 'q')
    disp('ERROR: Finishing the pipepline. Please check that the source transformation was completed correctly and run this script again');
    return
end


%If the analysis folder does not exist, create it, sending a warning
if ~exist(params.newPath, 'dir')
    fprintf('WARNING: %s does not exist, but should exist if you run the source transformation steps correctly \n', params.newPath);
    disp('If you are running the mainConnectivity function on your own, please ignore the warning');
    mkdir(params.newPath);
end

%If the parameters.txt does not exit, create it, sending a warning
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    fprintf('WARNING: %s does not exist, but should exist if you run the source transformation steps correctly \n', params.newPath);
    disp('If you are running the mainConnectivity function on your own, please ignore the warning');
    
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'w');
    fprintf(fileID, 'This txt contains the parameters used to create the .set located in the following path:\n');
    fprintf(fileID, '%s \n \n', fullfile(params.newPath));
    fprintf(fileID, 'General parameters: \n');
    fprintf(fileID, '\t - BIDSmodality = %s \n', params.BIDSmodality);
    fprintf(fileID, '\t - BIDStask = %s \n', params.BIDStask);
    fprintf(fileID, '\t - newPath = %s \n \n', params.newPath);
    fclose(fileID);
end


contStepConn = 0;               %Iterator to know how many subjects have the step for connectivity metrics completed


%Starts the spatial normalization pipeline for all subjects of the given finalStepPath
databaseName = regexp(databasePath, filesep, 'split');
databaseName = databaseName{end};
disp('****************************************************************************');
fprintf('Calculating connectivity metrics for the database %s \n', databaseName);
fprintf('With its corresponding final step of source transformation: \n%s \n', finalStepPath);
disp('****************************************************************************');
for i = 1:nSubj
    %Defines the name of the current subject
    iSubName = subjFolders{i};
    iSetPath = fullfile(finalStepPath, iSubName, params.BIDSmodality);
    
    %Ideally, it would load a .mat (if the source transformation step was run)
    iSetName = dir(fullfile(iSetPath, '*.mat'));
    if ~isempty(iSetName)
        %If the step of averaging per ROI was completed, only 1 .mat should be in the folder
        if length(iSetName) == 1
            iSetName = iSetName(1).name;
            
        %Otherwise if only the channels to Source step was completed, 2 .mats should be in the folder
        %The one with the shortest name (without -MC3 or -OW), is the one that should be loaded
        else
            tempNames = {iSetName(:).name};
            strLength = cellfun(@(x) numel(x), tempNames);
            iSetName = tempNames{strLength==min(strLength)};
        end
        
    %If it is loading a step previous to the source transformation, it should be a .set
    else
        iSetName = dir(fullfile(iSetPath, '*.set'));
        %If there is none .set, then the folder given was incorrect
        if isempty(iSetName)
            disp('ERROR: Could not find any .set or .mat at the following path:');
            disp(iSetPath);
            disp('TIP: You should not get this error if you are running the mainPipeline script');
            return
        end
        iSetName = iSetName(1).name;
    end
    
    
    %Print to have a track of which subject is being analyzed
    disp('----------------------------------------------------------------------------');
    disp('----------------------------------------------------------------------------');
    fprintf('Calculating connectivity for subject %s (%d/%d) \n', iSubName, i, nSubj);
    
    
    %% Step 1: Channels To Source
    %Defines the path in which this step will (or should already) be saved
    iPathStep1 = fullfile(params.newPath, 'Connectivity', 'Step1_ConnectivityMetrics', iSubName, params.BIDSmodality);
    iNameStep1 = strcat('c1_', iSetName(1:end-4), '.mat');
    
    %If the desired .set does not exist, calculate the metrics
    if ~exist(fullfile(iPathStep1, iNameStep1), 'file') && params.runConnectivity
        disp('------------Starting Step 1 (Calculating connectivity metrics)--------------');
        
        %Calculates connectivity metrics (7 or 4)
        [status, EEG_like] = f_calculateConnectivity(iSetPath, iSetName, params.connIgnoreWSM);        
        
        %If something went wrong, continue with the next subject
        if status == 0
            disp('ERROR: Could not complete Step 1 (Connectivity Metrics). Continuing with the next subject');
            continue;
        end
        
        %Creates the folder in which the results of Step1 will be saved
        if ~exist(iPathStep1, 'dir')
            mkdir(iPathStep1);
        end
        
        %Add a new row to the .comments field, mentioning that the connectivity metrics were calculated
        iComment = sprintf('----------------------Connectivity Metrics---------------------------');
        EEG_like.comments = strvcat(EEG_like.comments, iComment);
        iComment = sprintf('Step 1: runConnectivity = true ; connIgnoreWSM = %s ', char(string(params.connIgnoreWSM)));
        EEG_like.comments = strvcat(EEG_like.comments, iComment);
        
        
        %If everything is okay, save the .mat
        save(fullfile(iPathStep1, iNameStep1), 'EEG_like');
        
        %Updates the parameters.txt with the parameters used
        statusUpdate = f_updateParametersTxtConnect('runConnectivity', params);
        if statusUpdate == 0
            disp('WARNING: Could not update the parameters.txt');
        end
        
        contStepConn = contStepConn +1;
        
        disp('----------------------------Step 1 completed--------------------------------');
        
    elseif params.runConnectivity
        %If the file for step 1 already exists, let the user know and add to the iterator
        disp('This subject already had the step 1 files (Connectivity Metrics)');
        contStepConn = contStepConn +1;
    end
    
    %% End of the pre-processing for i-th subject
    fprintf('Connectivity metrics finished for subject %s (%d/%d) \n', iSubName, i, nSubj);
end

%Prints the number of subjects available per step
fprintf('Number of subjects checked/saved for the database %s, over the BIDSmodality %s, and BIDStask %s IN THIS RUN: \n', databaseName, params.BIDSmodality, params.BIDStask);
fprintf('Original = %d \n', nSubj);
fprintf('Step 1 (Connectivity Metrics) = %d / %d \n', contStepConn, nSubj);


%If it made it this far, the script was completed succesfully
status = 1;
finalConnectStepPath = fullfile(params.newPath, 'Connectivity', 'Step1_ConnectivityMetrics');
connectivityParams = params;


end