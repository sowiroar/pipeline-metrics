function [status, finalNormStepPath, normParams] = f_mainNormalization(databasePath, finalStepPath, runSpatialNorm, runPatientControlNorm, varargin)
%Description:
%Function that performs spatial and patient-control normalization
%INPUTS:
%databasePath           = Path of the desired database that wants to be preprocessed.
%       NOTE: The databasePath MUST already be in a BIDS-like structure
%finalStepPath          = Path were the final .sets are expected to be
%       NOTE: The finalStepPath MUST already be in a BIDS-like structure
%runSpatialNorm         = true if the user wants to perform spatial normalization, false otherwise (false by Default)
%       NOTE: The current Spatial Normalization is in a testing version and is not recommended. 
%       NOTE: Only works for the layouts of BioSemi64 and BioSemi128
%runPatientControlNorm  = true if the user wants to perform patient-control normalization, false otherwise (true by Default)
%       NOTE: The current Patient-Control version only performs normalization by diagnostic and nationality
%OPTIONAL INPUTS:
%BIDSmodality           = String with the modality of the data that will be analyzed (used in sub-#_BIDStask_BIDSmodality.set) ('eeg' by default)
%BIDStask               = String with the task to analyze (used in sub-#_BIDStask_BIDSmodality.set) ('rs' by default)
%newPath                = String with the path in which the new folders will be stored ('databasePath/analysis_RS' by default)
%OPTIONAL INPUTS FOR SPATIAL NORMALIZATION:
%fromXtoYLayout         = '64to128' if wants to move from a BioSemi64 Layout to a BioSemi128 Layout,
%       or '128to64' if wants to move froma Biosemi128 to a Biosemi64 Layout
%       NOTE: In further releases it could be modified to a Xto128 to allow more flexibility, and include other layouts
%headSizeCms            = Integer with the head size in Cms that the user wants to analyse (55cms by default).
%OPTIONAL INPUTS FOR PATIENT-CONTROL NORMALIZATION:
%controlLabel           = String with the label that the control subjects have (CN by default)
%minDurationS           = Integer with the minimal duration in seconds required to consider a .set (240s by default [4min])
%normFactor = String with the normalization factor desired (regular 'z-score' by default)
%       All the metrics are calculated for the CONTROLS only, and applied (divided) in all subjects
%       'Z-SCORE': Subtrates the mean and divides by the standard deviation
%       'UN_ALL': Uniform scaling of channel data by dividing by the robust standard deviation of concatenated channel data
%       'PER_CH': Dividing each channel by the robust standard deviation of its continuous activity across the whole recording
%       'UN_CH_HB': Uniform scaling of all channels by dividing all channel data by the Huber mean of channel robust standard 
%                   deviation values (same scaling applied to all channels).
%       'RSTD_EP_Mean': Normalizes by taking the mean of each N subject's robust standard deviation per channel individually
%       'RSTD_EP_Huber': Normalizes by taking the Huber mean of each N subject's robust standard deviation per channel individually
%       'RSTD_EP_L2': Normalizes by taking the Euclidean mean of each N subject's robust standard deviation per channel individually
%
%OUTPUTS:
%status                 = 1 if the script was completed successfully. 0 otherwise
%finalNormStepPath      = Path were the final .sets are expected to be (if status is 0, returns an empty array)
%normParams             = Parameters used in the normalization pipeline (if status is 0, returns an empty array)
%Author: Jhony Mejia


%Defines the default outputs
status = 0;
finalNormStepPath = '';
normParams = '';

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
    disp('To do so, you must first run the preprocessing part of the pipeline');
    return
end
if ~exist(finalStepPath, 'dir')
    fprintf('ERROR: The finalStepPath: %s does not exist \n', finalStepPath);
    disp('You should not get this error if you first run the preprocessing part of the pipeline succesfully');
    return
end

%Defines the default values for spatial and patient-control normalization
if nargin < 3
    runSpatialNorm = false;
end
if nargin < 4
    runPatientControlNorm = true;
end

%Defines the default optional parameters
%Type help finputcheck to know more about it. Basically it takes the inputs, makes sure everything is okay 
%and puts that information as a structure
params = finputcheck( varargin, {'BIDSmodality',        'string',       '',         'eeg'; ...
                                'BIDStask',             'string',       '',         'task-rest';
                                'newPath',              'string',       '',         fullfile(databasePath, 'analysis_RS');
                                'fromXtoYLayout',       'string',       '',         '';
                                'headSizeCms',          'float',        [0, inf],   55;
                                'controlLabel',         'string',       '',         'CN';
                                'minDurationS',         'float',        [0, inf],   120; %se cambia de 240 a 100 para ejectar os 120 seg
                                'normFactor',           'string',       '',         'Z-SCORE';
                                } ...
                                );

%Z-SCORE, UN_ALL, PER_CH, UN_CH_HB, RSTD_EP_Mean, RSTD_EP_Huber, RSTD_EP_L2
%Checks that the defaults where properly created
if ischar(params) && startsWith(params, 'error:')
    disp(params);
    return
end

%Adds the fields of runSpatialNorm y runPatientControlNorm (useful for updating the parameters.txt)
params.runSpatialNorm = runSpatialNorm;
params.runPatientControlNorm = runPatientControlNorm;


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


%If everything is okay, start by checking if the .sets have ChannelsLocations
%To do so, opens the .json and sees if the .sets have ChannelsLocations
fid = fopen(fullfile(databasePath, strcat(params.BIDStask, '_', params.BIDSmodality, '.json')));
raw = fread(fid, inf);
str = char(raw');
fclose(fid);
taskInfo = jsondecode(str);
hasChanLocs = false;
%if (strcmpi(taskInfo.ChannelsLocations, 'Yes')) || strcmpi(taskInfo.ChannelsLocations, '1') || taskInfo.EEGReference == 1
%    hasChanLocs = true;  
%end


%Asks the user to check that the number of subjects is correct
dirFinalStep = dir(finalStepPath);
dirFinalStepNames = {dirFinalStep(:).name};
subjFolders = startsWith(dirFinalStepNames, 'sub-');
subjFolders = dirFinalStepNames(subjFolders);
nSubj = length(subjFolders);
fprintf('You currently have %d subjects after pre-processing \n', nSubj);
disp('If that is the number of subject you expected, please press any key to continue with the normalization step, or "q" to quit');
quitNorm = input('', 's');
if strcmpi(quitNorm, 'q')
    disp('ERROR: Finishing the pipepline. Please check that the pre-processing was completed correctly and run this script again');
    return
end



%Adds the path that contains the functions used in the spatial and patient-control normalization.
addpath(genpath('Channels'));
addpath(genpath('Patient_Control'));

%If the analysis folder does not exist, create it, sending a warning
if ~exist(params.newPath, 'dir')
    fprintf('WARNING: %s does not exist, but should exist if you run the pre-processing steps correctly \n', params.newPath);
    disp('If you are running the mainNormalization function on your own, please ignore the warning');
    mkdir(params.newPath);
end

%If the parameters.txt does not exit, create it, sending a warning
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    fprintf('WARNING: %s does not exist, but should exist if you run the pre-processing steps correctly \n', params.newPath);
    disp('If you are running the mainNormalization function on your own, please ignore the warning');
    
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'w');
    fprintf(fileID, 'This txt contains the parameters used to create the .set located in the following path:\n');
    fprintf(fileID, '%s \n \n', fullfile(params.newPath));
    fprintf(fileID, 'General parameters: \n');
    fprintf(fileID, '\t - BIDSmodality = %s \n', params.BIDSmodality);
    fprintf(fileID, '\t - BIDStask = %s \n', params.BIDStask);
    fprintf(fileID, '\t - newPath = %s \n \n', params.newPath);
    fclose(fileID);
end


contStepSpatial = 0;            %Iterator to know how many subjects have the step for spatial normalization completed
contStepPC = 0;                 %Iterator to know how many subjects have the step for patient-control normalization completed



%Starts the spatial normalization pipeline for all subjects of the given finalStepPath
databaseName = regexp(databasePath, filesep, 'split');
databaseName = databaseName{end};
disp('****************************************************************************');
fprintf('Normalizing the database %s \n', databaseName);
fprintf('With its corresponding final step of preprocessing: \n%s \n', finalStepPath);
disp('****************************************************************************');
for i = 1:nSubj
    %Defines the name of the current subject
    iSubName = subjFolders{i};
    iSetPath = fullfile(finalStepPath, iSubName, params.BIDSmodality);
    iSetName = dir(fullfile(iSetPath, '*.set'));
    iSetName = iSetName(1).name;
    
    %Print to have a track of which subject is being analyzed
    disp('----------------------------------------------------------------------------');
    disp('----------------------------------------------------------------------------');
    fprintf('Pre processing subject %s (%d/%d) \n', iSubName, i, nSubj);
    
    
    %% Step 1: Spatial Normalization
    %Defines the path in which this step will (or should already) be saved
    iPathStep1 = fullfile(params.newPath, 'Normalization', 'Step1_SpatialNorm', iSubName, params.BIDSmodality);
    iNameStep1 = strcat('n1_', iSetName);
    
    %If the desired .set does not exist, either create the interpolated .set, or copy the .set of the final pre-processing step
    if ~exist(fullfile(iPathStep1, iNameStep1), 'file')

        if runSpatialNorm
            disp('------------------Starting Step 1 (Spatial Normalization)-------------------');

            %Send a warning to let the user know that the current version might create artifacts
%             disp('WARNING: The current version of spatial normalization is under testing. It is HIGHLY recommended that you DO NOT use it');
%             disp('Do you still want to continue? (y/n)');
%             continueSpatial = input('', 's');
%             if ~strcmp(continueSpatial, 'y')
%                 return
%             end

            %Performs the spatial interpolation with the desired parameters
            [status, EEG, newFromXtoYLayout] = f_mainSpatialNorm(iSetPath, iSetName, hasChanLocs, params.fromXtoYLayout, params.headSizeCms);

            %Checks that the script was completed succesfully
            if status == 0
                disp('ERROR: Could not complete Step 1. Continuing with the next subject');
                continue;
            end
            
            %If it was run succesfully, update the fromXtoYLayout (if it was the same, it would not make a difference anyway)
            params.fromXtoYLayout = newFromXtoYLayout;

            %Add a new row to the .comments field, mentioning the parameters used for this step
            iComment = sprintf('-------------------------Normalization-------------------------------');
            EEG.comments = strvcat(EEG.comments, iComment);
            iComment = sprintf('Step 1: runSpatialNorm = true ; fromXtoYLayout = %s ; headSizeCms = %.1f ', params.fromXtoYLayout, params.headSizeCms);
            EEG.comments = strvcat(EEG.comments, iComment);

            %If everything is okay, save the results
            if ~exist(iPathStep1, 'dir')
                mkdir(iPathStep1);
            end
            pop_saveset(EEG, 'filename', iNameStep1, 'filepath', iPathStep1);


            %Updates the parameters.txt with the parameters used
            statusUpdate = f_updateParametersTxtNorm('runSpatialNorm', params);
            if statusUpdate == 0
               disp('WARNING: Could not update the parameters.txt');
            end

            contStepSpatial = contStepSpatial +1;

            disp('----------------------------Step 1 completed--------------------------------');


        %If the user does not want to run the spatial interpolation, copy the .set of the final preprocessing step
        else
            disp('Not performing the Spatial Normalization step. Copying the .set of the final preprocessing step');
            EEG = pop_loadset('filename', iSetName, 'filepath', iSetPath);
            
            %Removes data that corresponds to ICA as it would not be further required
            EEG.chaninfo = [];
            EEG.icaact = [];
            EEG.icawinv = [];
            EEG.icasphere = [];
            EEG.icaweights = [];
            EEG.icachansind = [];
            
            %Add a new row to the .comments field, mentioning the parameters used for this step
            iComment = sprintf('-------------------------Normalization-------------------------------');
            EEG.comments = strvcat(EEG.comments, iComment);
            iComment = sprintf('Step 1: runSpatialNorm = false ');
            EEG.comments = strvcat(EEG.comments, iComment);
          
            %If everything is okay, save the results
            if ~exist(iPathStep1, 'dir')
                mkdir(iPathStep1);
            end
            pop_saveset(EEG, 'filename', iNameStep1, 'filepath', iPathStep1);
            
            %Updates the parameters.txt with the parameters used
            statusUpdate = f_updateParametersTxtNorm('runSpatialNorm', params);
            if statusUpdate == 0
                disp('WARNING: Could not update the parameters.txt');
            end

            contStepSpatial = contStepSpatial +1;

            disp('----------------------------Step 1 completed--------------------------------');
        end
        
    
    else
        %If the file for step 1 already exists, let the user know and add to the iterator
        disp('This subject already had the Step 1 files (Spatial Normalization)');
        contStepSpatial = contStepSpatial +1;
    end
    
end
disp('----------------------------Step 1 completed--------------------------------');


%% Step 2: Patient-Control Normalization

%Defines the subject names that are present in the previous step
pathStep1 = fullfile(params.newPath, 'Normalization', 'Step1_SpatialNorm');

%Asks the user to check that the number of subjects is correct
dirStep1 = dir(pathStep1);
dirStep1Names = {dirStep1(:).name};
subjFolders = startsWith(dirStep1Names, 'sub-');
subjFolders = dirStep1Names(subjFolders);
n1Subj = length(subjFolders);
disp('----------------------------------------------------------------------------');
fprintf('You currently have %d subjects after the spatial normalization step \n', n1Subj);
% disp('If that is the number of subject you expected, please press any key to continue with the normalization step, or "q" to quit');
% quitNorm = input('', 's');
% if strcmpi(quitNorm, 'q')
%     disp('ERROR: Finishing the pipepline. Please check that the pre-processing was completed correctly and run this script again');
%     return
% end

%Performs the patient control normalization, if desired
if params.runPatientControlNorm
    disp('--------------Starting Step 2 (Patient-Control Normalization)---------------');
    
    %First, stratifies the subjects of that step by nationality and control vs noControl, considering the information of each database
    %pathsPatientsControls = Structure with 4 fields: 'ControlsName', 'ControlsPath', 'RemainingName' and 'RemainingPath' 
    %           (Remaining are the subjects of interest / non-controls).
    %           Each field has a 1xM cell where M is the number of nationalities of the databases.
    %           Each field of the M nationalities contains a cell of Nx1, 
    %           where N is the number of subjects that the database(s) have per nationality
    %nationalities = Cell of 1xM with a string in each field with the Names of the nationalities
    [status, pathsPatientsControls, nationalities, newControlLabel] = f_getControlsAndRemainingIDs({databasePath}, {pathStep1}, ...
        {params.controlLabel}, params.BIDSmodality);
    params.controlLabel = newControlLabel{1};
    
    if status == 0
        disp('ERROR: Could not identify the nationality and diagnostic of the subjects');
        return
    end
    
    %Performs the patient-control normalization per nationality across databases
    controlPaths = pathsPatientsControls.ControlsPath;
    controlNames = pathsPatientsControls.ControlsName;
    remainingPaths = pathsPatientsControls.RemainingPath;
    remainingNames = pathsPatientsControls.RemainingName;
    
    %Check the minimum duration of the whole databases(s)
    [status, realMinDuration] = f_getMinDuration(controlPaths, controlNames, remainingPaths, remainingNames, params.minDurationS);
    params.minDurationS = realMinDuration;
    
    if status == 0
        fprintf('ERROR: Could not complete the identification of the minimal duration of the .sets, greater than: %d', minDurationS);
        return
    end
    
    %For each nationality, perform an individual normalization
    nNat = length(nationalities);
    for i = 1:nNat
        fprintf('Performing normalization for the nationality %s (%d/%d)\n', nationalities{i}, i, nNat);
        [status, normData, normTable, finalPaths, finalNames] = f_mainPatientControlNorm(controlPaths{i}, controlNames{i}, ...
            remainingPaths{i}, remainingNames{i}, params.normFactor, realMinDuration);
        
        %Checks that the script was completed succesfully
        if status == 0
            fprintf('ERROR: Could not perform the patient-control normalization for the nationality: %s\n', nationalities{i});
            return
        end
        
        %Saves the data of the controls
        iControlPaths = finalPaths.Controls;
        iControlNames = finalNames.Controls;
        nSubjI = length(iControlPaths);
        for j = 1:nSubjI
            %Identifies the path and name of the subjects analyzed from the previous step
            jPath = iControlPaths{j};
            jName = iControlNames{j};
            jSubName = strsplit(jPath, filesep);
            jSubName = jSubName{end-1};
            
            %Print to have a track of which subject is being analyzed
            disp('----------------------------------------------------------------------------');
            disp('----------------------------------------------------------------------------');
            fprintf('Normalizing control subject %s (%d/%d) \n', jSubName, j, nSubjI);
            
            %Defines the path and name of the NEW normalized .sets
            jPathStep2 = fullfile(params.newPath, 'Normalization', 'Step2_PatientControlNorm', jSubName, params.BIDSmodality);
            jNameStep2 = strcat('n2', jName(3:end));
            
            %If the given subject does not exist, create it
            if ~exist(fullfile(jPathStep2, jNameStep2), 'file')

                %Loads the old data and updates it
                EEG = pop_loadset('filename', jName, 'filepath', jPath);
                EEG.data = normData.Controls(:,:,j);
                EEG.pnts = size(EEG.data, 2);
                EEG.srate = EEG.pnts/params.minDurationS;
                EEG.xmax = (EEG.pnts-1)/EEG.srate;
                EEG.times = 0:1/EEG.srate:EEG.xmax;

                %Checks that everything is okay
                EEG = eeg_checkset(EEG);

                %Adds the comment of the parameters used
                iComment = sprintf('Step 2: runPatientControlNorm = true ; controlLabel = %s ; minDurationS = %.1f ; normFactor = %s ', ...
                    params.controlLabel, params.minDurationS, params.normFactor);
                EEG.comments = strvcat(EEG.comments, iComment);

                %If everything is okay, save the results
                if ~exist(jPathStep2, 'dir')
                    mkdir(jPathStep2);
                end
                pop_saveset(EEG, 'filename', jNameStep2, 'filepath', jPathStep2);
                %Saves the table, both as a .mat and as a .csv
                save(fullfile(jPathStep2, strcat('normTable_', jNameStep2(1:end-4), '.mat')), 'normTable');
                writetable(normTable, fullfile(jPathStep2, strcat('normTable_', jNameStep2(1:end-4), '.csv')), 'WriteRowNames',true);

                %Updates the parameters.txt with the parameters used
                statusUpdate = f_updateParametersTxtNorm('runPatientControlNorm', params);
                if statusUpdate == 0
                    disp('WARNING: Could not update the parameters.txt');
                end
                contStepPC = contStepPC +1;
                
            else
                %If the file for step 2 already exists, let the user know and add to the iterator
                disp('This subject already had the Step 2 files (Patient Control Normalization)');
                contStepPC = contStepPC +1;
            end
            
        end
        
        %Saves the data of the remaining subjects
        iRemainingPaths = finalPaths.Remaining;
        iRemainingNames = finalNames.Remaining;
        nSubjI = length(iRemainingPaths);
        for j = 1:nSubjI
            %Identifies the path and name of the subjects analyzed from the previous step
            jPath = iRemainingPaths{j};
            jName = iRemainingNames{j};
            jSubName = strsplit(jPath, filesep);
            jSubName = jSubName{end-1};
            
            %Print to have a track of which subject is being analyzed
            disp('----------------------------------------------------------------------------');
            disp('----------------------------------------------------------------------------');
            fprintf('Normalizing remaining subject %s (%d/%d) \n', jSubName, j, nSubjI);
            
            %Defines the path and name of the NEW normalized .sets
            jPathStep2 = fullfile(params.newPath, 'Normalization', 'Step2_PatientControlNorm', jSubName, params.BIDSmodality);
            jNameStep2 = strcat('n2', jName(3:end));
            
            
            %If the given subject does not exist, create it
            if ~exist(fullfile(jPathStep2, jNameStep2), 'file')
            
                %Loads the old data and updates it
                EEG = pop_loadset('filename', jName, 'filepath', jPath);
                EEG.data = normData.Remaining(:,:,j);
                EEG.pnts = size(EEG.data, 2);
                EEG.srate = EEG.pnts/params.minDurationS;
                EEG.xmax = (EEG.pnts-1)/EEG.srate;
                EEG.times = 0:1/EEG.srate:EEG.xmax;

                %Checks that everything is okay
                EEG = eeg_checkset(EEG);

                %Adds the comment of the parameters used
                iComment = sprintf('Step 2: runPatientControlNorm = true ; controlLabel = %s ; minDurationS = %.1f ; normFactor = %s ', ...
                    params.controlLabel, params.minDurationS, params.normFactor);
                EEG.comments = strvcat(EEG.comments, iComment);

                %If everything is okay, save the results
                if ~exist(jPathStep2, 'dir')
                    mkdir(jPathStep2);
                end
                pop_saveset(EEG, 'filename', jNameStep2, 'filepath', jPathStep2);
                %Saves the table, both as a .mat and as a .csv
                save(fullfile(jPathStep2, strcat('normTable_', jNameStep2(1:end-4), '.mat')), 'normTable');
                writetable(normTable, fullfile(jPathStep2, strcat('normTable_', jNameStep2(1:end-4), '.csv')), 'WriteRowNames',true);

                %Updates the parameters.txt with the parameters used
                statusUpdate = f_updateParametersTxtNorm('runPatientControlNorm', params);
                if statusUpdate == 0
                    disp('WARNING: Could not update the parameters.txt');
                end
                contStepPC = contStepPC +1;
                
                
            else
                %If the file for step 2 already exists, let the user know and add to the iterator
                disp('This subject already had the Step 2 files (Patient Control Normalization)');
                contStepPC = contStepPC +1;
            end
            
        end
        
        
        fprintf('Normalization Completed for the nationality %s (%d/%d)!\n', nationalities{i}, i, nNat);
    end
    disp('----------------------------Step 2 completed--------------------------------');
    
    
else
    %If the user does not want to perform patient-control norm, and there are non sub-# folders
    %Send a warning telling the benefits of normalization
    pathStep2 = fullfile(params.newPath, 'Normalization', 'Step2_PatientControlNorm');
    sendWarning = false;
    if ~exist(pathStep2, 'dir')
        sendWarning = true;
    else
        dirStep2 = dir(pathStep2);
        dirStep2Names = {dirStep2(:).name};
        subjFolders = startsWith(dirStep2Names, 'sub-');
        nStep2Subj = sum(subjFolders);
        if nStep2Subj == 0
            sendWarning = true;
        end
    end
    
    %If a warning was sent, give the user the opportunity to run the script again
    if sendWarning
%          disp('WARNING: It is highly encouraged that you perform patient-control normalization');
%          disp('Please press "y" to run the the normalization step again, or any other key to continue and copy the files of the previous step');
%          runPC = input('', 's');
%          if strcmpi(runPC, 'y')
%              runPatientControlNorm = true;
%              vararginParams = {'BIDSmodality', params.BIDSmodality, 'BIDStask', params.BIDStask, 'newPath', params.newPath, ...
%                  'fromXtoYLayout', params.fromXtoYLayout, 'headSizeCms', params.headSizeCms, ...
%                  'controlLabel', params.controlLabel, 'minDurationS', params.minDurationS, 'normFactor', params.normFactor};
%              [status, finalNormStepPath, normParams] = f_mainNormalization(databasePath, finalStepPath, runSpatialNorm, runPatientControlNorm, vararginParams{:});
%              return
%          end
        
        %If the user still wants to avoid the normalization, copy the files from the step1 into step2
        disp('WARNING: NOT PERFORMING PATIENT CONTROL NORMALIZATION. Copying files from the previous step');

        for i = 1:n1Subj
            %Defines the name of the current subject
            iSubName = subjFolders{i};
            iSetPath = fullfile(pathStep1, iSubName, params.BIDSmodality);
            iSetName = dir(fullfile(iSetPath, '*.set'));
            iSetName = iSetName(1).name;

            %Print to have a track of which subject is being analyzed
            disp('----------------------------------------------------------------------------');
            disp('----------------------------------------------------------------------------');
            fprintf('NOT NORMALIZING subject %s (%d/%d) \n', iSubName, i, n1Subj);

            %Defines the path and name of the step2
            jPathStep2 = fullfile(params.newPath, 'Normalization', 'Step2_PatientControlNorm', iSubName, params.BIDSmodality);
            jNameStep2 = strcat('n2', iSetName(3:end));

            %Loads the .set of the previous step
            EEG = pop_loadset('filename', iSetName, 'filepath', iSetPath);

            %Adds the comment of the parameters used
            iComment = sprintf('Step 2: runPatientControlNorm = false ');
            EEG.comments = strvcat(EEG.comments, iComment);

            %If everything is okay, save the results
            if ~exist(jPathStep2, 'dir')
                mkdir(jPathStep2);
            end
            pop_saveset(EEG, 'filename', jNameStep2, 'filepath', jPathStep2);

            %Updates the parameters.txt with the parameters used
            statusUpdate = f_updateParametersTxtNorm('runPatientControlNorm', params);
            if statusUpdate == 0
                disp('WARNING: Could not update the parameters.txt');
            end
            contStepPC = contStepPC +1;
            disp('----------------------------Step 2 completed--------------------------------');
        end
        
       
    else
        %If there were already some subjects for this step, leave it as it is
        contStepPC = nStep2Subj;
    end
    
end   


%Prints the number of subjects available per step
fprintf('Number of subjects checked/saved for the database %s, over the BIDSmodality %s, and BIDStask %s IN THIS RUN: \n', databaseName, params.BIDSmodality, params.BIDStask);
fprintf('The initial .sets (final step of preprocessing) were loaded from the following path: %s\n', finalStepPath);
fprintf('Final Preprocessing Step = %d \n', nSubj);
fprintf('Step 1 (Spatial Normalization) = %d / %d \n', contStepSpatial, nSubj);
fprintf('Step 2 (Patient Control Normalization) = %d / %d \n', contStepPC, n1Subj);


%If it made it this far, the script was completed succesfully
status = 1;
finalNormStepPath = fullfile(params.newPath, 'Normalization', 'Step2_PatientControlNorm');
normParams = params;

end