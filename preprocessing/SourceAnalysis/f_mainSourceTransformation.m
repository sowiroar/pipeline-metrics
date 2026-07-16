function [status, finalSourceStepPath, sourceParams] = ...
    f_mainSourceTransformation(databasePath, finalStepPath, runChansToSource, runSourceAvgROI, varargin)

%Description:
%Function that performs source transformation using an average brain
%INPUTS:
%databasePath           = Path of the desired database that wants to be preprocessed.
%       NOTE: The databasePath MUST already be in a BIDS-like structure
%finalStepPath          = Path were the final .sets are expected to be
%       NOTE: The finalStepPath MUST already be in a BIDS-like structure
%runChansToSource       = true if the user wants to perform source transformation, false otherwise (true by Default)
%       NOTE: The current source transformation considers an average brain
%runSourceAvgROI        = true if the user wants to perform averaging of the source transformation by anatomical ROIs (true by Default)
%       NOTE: The current averaging is done using the 116 ROIs defined in the AAL atlas 
%OPTIONAL INPUTS:
%BIDSmodality           = String with the modality of the data that will be analyzed (used in sub-#_BIDStask_BIDSmodality.set) ('eeg' by default)
%BIDStask               = String with the task to analyze (used in sub-#_BIDStask_BIDSmodality.set) ('rs' by default)
%newPath                = String with the path in which the new folders will be stored ('databasePath/analysis_RS' by default)
%selectSourceTime       = Vector of [1,2] with the time window in seconds that the user wants to transform to a source level 
%                       [timeBeg, timeEnd]. (empty by Default)
%avgSourceTime          = Boolean. True if the user wants to average the selected time window. False otherwise (false by default)
%sourceTransfMethod     = String with the method to calculate the source transformation ('BMA' by default)
%       NOTE: The current version only has BMA, FT_eLoreta and FT_MNE, but more methods could be added
%sourceROIatlas         = String with the name of the Atlas that the user wants to use ('AAL-116' by default)
%
%OPTIONAL INPUTS FOR BMA SOURCE TRANSFORMATION:
%BMA_MCwarming          = Integer with the warming length of the Markov Chain for source transformation (4000 by default)
%BMA_MCsamples          = Integer with the number of samples from the Monte Carlo Markov Chain sampler for source transformation (3000 by default)
%BMA_MET:               = String with the method of preference for exploring the models space:
%           If MET=='OW', the Occam's Window algorithm is used.
%           If MET=='MC', The MC3 is used (Default).
%BMA_OWL:               = Integer with the Occam's window lower bounds 
%           [3-Very Strong, 20-strong, 150-positive, 200-Weak] (3 by default)
%
%OPTIONAL INPUTS FOR FIELDTRIP SOURCE TRANSFORMATION:
%FT_sourcePoints    = Integer with the desired number of source points (5124 or 8196)
%       NOTE: 5124 defined as default because it takes less memory, while producing acceptable results
%FT_plotTimePoints  = Empty if the user does not want to plot anything at source level (by default)
%       NOTE: Can be an integer with the single time in seconds to be visualized, 
%       or can be a vector with [begin, end] times in seconds to be averaged and visualized
%
%OUTPUTS:
%status                 = 1 if the script was completed successfully. 0 otherwise
%finalSourceStepPath    = Path were the final .sets are expected to be (if status is 0, returns an empty array)
%sourceParams           = Parameters used in the source pipeline (if status is 0, returns an empty array)
%Authors: Jhosmary Cuadros and Jhony Mejia

%Defines the default outputs
status = 0;
finalSourceStepPath = '';
sourceParams = '';

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
    disp('To do so, you must first run the normalization part of the pipeline');
    return
end
if ~exist(finalStepPath, 'dir')
    fprintf('ERROR: The finalStepPath: %s does not exist \n', finalStepPath);
    disp('You should not get this error if you first run the normalization part of the pipeline succesfully');
    return
end

%Defines the default values for sourceTransformation and the type that should be used
if nargin < 3
    runChansToSource = true;
end
if nargin < 4
    runSourceAvgROI = true;
end

%Defines the default optional parameters
%Type help finputcheck to know more about it. Basically it takes the inputs, makes sure everything is okay 
%and puts that information as a structure
params = finputcheck( varargin, {'BIDSmodality',        'string',               '',         'eeg'; ...
                                'BIDStask',             'string',               '',         'task-rest';
                                'newPath',              'string',               '',         fullfile(databasePath, 'analysis_RS');
                                'selectSourceTime',     'integer',              [],         [];
                                'avgSourceTime',        'boolean',              '',         false;
                                'sourceTransfMethod'    'string',               '',         'BMA'
                                'BMA_MCwarming',        'float',                [0, inf],   4000;
                                'BMA_MCsamples',        'float',                [0, inf],   3000;
                                'BMA_MET',              'string',               '',         'MC';
                                'BMA_OWL',              'float',                [0, inf],   3;
                                'FT_sourcePoints',      'float',                '',         5124;
                                'FT_plotTimePoints',    {'float', 'integer'},   [],         [];
                                'sourceROIatlas',       'string',               '',         'AAL-116';
                                } ...
                                );

%Z-SCORE, UN_ALL, PER_CH, UN_CH_HB, RSTD_EP_Mean, RSTD_EP_Huber, RSTD_EP_L2
%Checks that the defaults where properly created
if ischar(params) && startsWith(params, 'error:')
    disp(params);
    return
end

%Checks that the sourceTransfMethod is valid
if ~ (strcmpi(params.sourceTransfMethod, 'BMA') || strcmpi(params.sourceTransfMethod, 'FT_eLoreta') || ...
        strcmpi(params.sourceTransfMethod, 'FT_MNE'))
    disp('WARNING: The only valid source transformation methods are:');
    disp('BMA, FT_eLoreta, FT_MNE');
    disp('Please enter one of the methods mentioned above to run this script again, or press ''q'' to quit');
    realSourceTransfMethod = input('', 's');
    if strcmpi(realSourceTransfMethod, 'q')
        disp('ERROR: Could not complete the source transformation step because the method to calculate was invalid');
    else
        varargin(end+1:end+2) = {'sourceTransfMethod', params.sourceTransfMethod};
        [status, finalSourceStepPath, sourceParams] = f_mainSourceTransformation(databasePath, finalStepPath, ...
            runChansToSource, runSourceAvgROI, varargin{:});
    end
    return
end


%Adds the fields of runSourceTransf and runSourceAvgROI (useful for updating the parameters.txt)
params.runChansToSource = runChansToSource;
params.runSourceAvgROI = runSourceAvgROI;

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
fprintf('You currently have %d subjects after normalization \n', nSubj);
disp('If that is the number of subject you expected, please press any key to continue with the source transformation step, or "q" to quit');
quitNorm = input('', 's');
if strcmpi(quitNorm, 'q')
    disp('ERROR: Finishing the pipepline. Please check that the normalization was completed correctly and run this script again');
    return
end



%Adds the path that contains the functions used in the spatial and patient-control normalization.
addpath(genpath('chansToSource'));
addpath(genpath('sourceAvgROI'));


%If the analysis folder does not exist, create it, sending a warning
if ~exist(params.newPath, 'dir')
    fprintf('WARNING: %s does not exist, but should exist if you run the normalization steps correctly \n', params.newPath);
    disp('If you are running the mainSourceTransf function on your own, please ignore the warning');
    mkdir(params.newPath);
end

%If the parameters.txt does not exit, create it, sending a warning
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    fprintf('WARNING: %s does not exist, but should exist if you run the normalization steps correctly \n', params.newPath);
    disp('If you are running the mainSourceTransf function on your own, please ignore the warning');
    
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'w');
    fprintf(fileID, 'This txt contains the parameters used to create the .set located in the following path:\n');
    fprintf(fileID, '%s \n \n', fullfile(params.newPath));
    fprintf(fileID, 'General parameters: \n');
    fprintf(fileID, '\t - BIDSmodality = %s \n', params.BIDSmodality);
    fprintf(fileID, '\t - BIDStask = %s \n', params.BIDStask);
    fprintf(fileID, '\t - newPath = %s \n \n', params.newPath);
    fclose(fileID);
end

contOptStepTime = 0;            %Iterator to know how many subjects have the optional step for time selection completed
contStepSource = 0;             %Iterator to know how many subjects have the step for source transformation completed
contStepROI = 0;                %Iterator to know how many subjects have the step for average ROI completed


%Starts the spatial normalization pipeline for all subjects of the given finalStepPath
databaseName = regexp(databasePath, filesep, 'split');
databaseName = databaseName{end};
disp('****************************************************************************');
fprintf('Transforming to a source level the database %s \n', databaseName);
fprintf('With its corresponding final step of normalization: \n%s \n', finalStepPath);
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
    fprintf('Transforming to a source level the subject %s (%d/%d) \n', iSubName, i, nSubj);
    
    
    %% Step 0: Optional time selection and averaging
    %Defines the path in which this step will (or should already) be saved
    iPathStep0 = fullfile(params.newPath, 'SourceTransformation', 'Step0_optSelectSourceTime', iSubName, params.BIDSmodality);
    iNameStep0 = strcat('t0_', iSetName);
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep0, iNameStep0), 'file') && ~isempty(params.selectSourceTime)
        disp('----------Starting Step 0 (Optional Time Selection and Averaging)-----------');
                
        %Performs the optional time selection and averaging prior to the source transformation step
        [status, EEG, newSelectSourceTime] = f_optSelectSourceTime(iSetPath, iSetName, params.selectSourceTime, params.avgSourceTime);
        
        %Checks that the script was completed succesfully
        if status == 0
            disp('WARNING: Could not complete the Optional Step 0 (Time Selection and Averaging). Continuing with the next subject');
            continue;
        end
        
        %If it was run successfully, update the selectSourceTime parameter (if it was the same, it would not make a difference anyway)
        params.selectSourceTime = newSelectSourceTime;
        
        %Add a new row to the .comments field, mentioning the parameters used for this step
        iComment = sprintf('---------------------Source Transformation---------------------------');
        EEG.comments = strvcat(EEG.comments, iComment);
        iComment = sprintf('Step 0: selectSourceTime = [%.3f, %.3f] ; avgSourceTime = %s ', params.selectSourceTime, char(string(params.avgSourceTime)));
        EEG.comments = strvcat(EEG.comments, iComment);
        
        %If everything is okay, save the results
        if ~exist(iPathStep0, 'dir')
            mkdir(iPathStep0);
        end
        pop_saveset(EEG, 'filename', iNameStep0, 'filepath', iPathStep0);
        
        %Updates the parameters.txt with the parameters used
        statusUpdate0 = f_updateParametersTxtSource('selectSourceTime', params);
        statusUpdate1 = f_updateParametersTxtSource('avgSourceTime', params);
        if statusUpdate0 == 0 || statusUpdate1 == 0
            disp('WARNING: Could not update the parameters.txt');
        end
        contOptStepTime = contOptStepTime +1;
        
        disp('----------------------------Step 0 completed--------------------------------');
    elseif ~isempty(params.selectSourceTime)
        %If the file for step 1 already exists, let the user know and add to the iterator
        disp('This subject already had the step 0 files (Optional Time Selection and Averaging)');
        contOptStepTime = contOptStepTime +1;
    end
    
    
    %% Step 1: Channels To Source
    %Defines the path in which this step will (or should already) be saved
    iPathStep1 = fullfile(params.newPath, 'SourceTransformation', 'Step1_ChannelsToSource', iSubName, params.BIDSmodality);
    iNameStep1 = strcat('t1_', iSetName(1:end-4), '.mat');
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep1, iNameStep1), 'file') && (params.runChansToSource)
        disp('-------------Starting Step 1 (Transforming Channels to Source)--------------');
        
        %First, check that the files for step0 exist
        if ~exist(fullfile(iPathStep0, iNameStep0), 'file')
            disp('WARNING: This subject does not have the files corresponding to Step 0. Loading the .set of the final normalization step');
            iPathStep0 = iSetPath;
            iNameStep0 = iSetName;
        end
        
        %Defines the path and filename were the source transformed files will be saved
        tempSaveStruct.Path = strcat(iPathStep1, filesep);      %Adds a filesep (/ or \) to avoid errors with paths
        tempSaveStruct.Name = strcat(iNameStep1(1:end-4), '.txt');
        
        %Creates the folder in which the results of Step1 will be saved
        if ~exist(iPathStep1, 'dir')
            mkdir(iPathStep1);
        end
        
        %Transforms from electrode-channels to source level
        [status, EEG_like] = f_mainChansToSource(iPathStep0, iNameStep0, params.sourceTransfMethod, tempSaveStruct, ...
            'BIDSmodality', params.BIDSmodality, 'BIDStask', params.BIDStask, ...
            'BMA_MCwarming', params.BMA_MCwarming, 'BMA_MCsamples', params.BMA_MCsamples, ...
            'BMA_MET', params.BMA_MET, 'BMA_OWL', params.BMA_OWL, ...   %Optional BMA parameters              
            'FT_sourcePoints', params.FT_sourcePoints, ...              %Optional FieldTrip parameters
            'FT_plotTimePoints', params.FT_plotTimePoints); 
        
        %If something went wrong, continue with the next subject
        if status == 0
            step1PathParts = strsplit(iPathStep1, filesep);
            rmdir(fullfile(step1PathParts{1:end-1}), 's');      %Removes the ith-subjectName Folder
            disp('ERROR: Could not complete Step 1 (Channels To Source). Continuing with the next subject');
            continue;
        end
        
        %If everything is correct, update the params.sourceTransfMethod field (if it did not change, it would be the same anyway)
        params.sourceTransfMethod = EEG_like.sourceTransfMethod;
        
        %Add a new row to the .comments field, mentioning the parameters used for this step
        iComment = sprintf('---------------------Source Transformation---------------------------');
        if isempty(strfind(EEG_like.comments(end-1, :), iComment))
            EEG_like.comments = strvcat(EEG_like.comments, iComment);
        end
        if strcmpi(params.sourceTransfMethod, 'BMA')
            iComment = sprintf('Step 1: sourceTransfMethod = BMA ; BMA_MCwarming = %d ; BMA_MCsamples = %d ; BMA_MET = %s ; BMA_OWL = %d ', ...
                params.BMA_MCwarming, params.BMA_MCsamples, params.BMA_MET, params.BMA_OWL);
            EEG_like.comments = strvcat(EEG_like.comments, iComment);
        elseif strcmpi(params.sourceTransfMethod, 'FT_eLoreta') || strcmpi(params.sourceTransfMethod, 'FT_MNE')
            iComment = sprintf('Step 1: sourceTransfMethod = %s ; FT_sourcePoints = %d ', ...
                params.sourceTransfMethod, params.FT_sourcePoints);     %The plot parameter is not added as it is unimportant
            EEG_like.comments = strvcat(EEG_like.comments, iComment);
        end
        
        %If everything is okay, save the .mat
        disp('Saving the results of the source transformation in a .mat. This will take a couple of minutes...');
        save(fullfile(iPathStep1, iNameStep1), 'EEG_like', '-v7.3');
        
        %Updates the parameters.txt with the parameters used
        statusUpdate = f_updateParametersTxtSource('sourceTransfMethod', params);
        if statusUpdate == 0
            disp('WARNING: Could not update the parameters.txt');
        end
        
        contStepSource = contStepSource +1;
        
        disp('----------------------------Step 1 completed--------------------------------');
    elseif params.runChansToSource
        %If the file for step 1 already exists, let the user know and add to the iterator
        disp('This subject already had the step 1 files (Channels To Source)');
        contStepSource = contStepSource +1;
    end
    
    
    %% Step 2: Source Average ROI
    %Defines the path in which this step will (or should already) be saved
    iPathStep2 = fullfile(params.newPath, 'SourceTransformation', 'Step2_SourceAvgROI', iSubName, params.BIDSmodality);
    iNameStep2 = strcat('t2_', iSetName(1:end-4), '.mat');
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep2, iNameStep2), 'file') && (params.runSourceAvgROI)
        disp('-----------------Starting Step 2 (Averaging Source by ROI)------------------');
        
        %First, check that the files (.mat y .txt) for step1 (chansToSource) exist
        if ~exist(fullfile(iPathStep1, iNameStep1), 'file')
            disp('WARNING: This subject does not have the .mat file corresponding to step 1. Skipping to the next subject');
            continue
        end
        if ~exist(fullfile(iPathStep1, strcat(iNameStep1(1:end-4), '.txt')), 'file')
            disp('WARNING: This subject does not have the .txt file corresponding to step 1. Skipping to the next subject');
            continue
        end
        
        %Creates the folder in which the results of Step2 will be saved
        if ~exist(iPathStep2, 'dir')
            mkdir(iPathStep2);
        end
        
        %Defines the path and filename were the Source Averaged per ROI files will be saved
        tempSaveStruct.Path = strcat(iPathStep2, filesep);      %Adds a filesep (/ or \) to avoid errors with paths
        tempSaveStruct.Name = strcat(iNameStep2(1:end-4), '.txt');
        
        %Averages the Source-level data by ROI
        [status, EEG_like] = f_mainSourceAvgROI(iPathStep1, iNameStep1, params.sourceROIatlas, tempSaveStruct);
        
        %If something went wrong, continue with the next subject
        if status == 0
            step2PathParts = strsplit(iPathStep2, filesep);
            rmdir(fullfile(step2PathParts{1:end-1}), 's');      %Removes the ith-subjectName Folder
            disp('ERROR: Could not complete Step 2 (Source Average ROI). Continuing with the next subject');
            continue;
        end
        
        %Add a new row to the .comments field, mentioning the parameters used for this step
        iComment = sprintf('Step 2: sourceROIatlas = %s ', params.sourceROIatlas);
        EEG_like.comments = strvcat(EEG_like.comments, iComment);
        
        %If everything is okay, save the .mat
        save(fullfile(iPathStep2, iNameStep2), 'EEG_like');
        
        %Updates the parameters.txt with the parameters used
        statusUpdate = f_updateParametersTxtSource('sourceROIatlas', params);
        if statusUpdate == 0
            disp('WARNING: Could not update the parameters.txt');
        end
        
        contStepROI = contStepROI +1;
        
        disp('----------------------------Step 2 completed--------------------------------');
    elseif params.runChansToSource
        %If the file for step 2 already exists, let the user know and add to the iterator
        disp('This subject already had the step 2 files (Source Average ROI)');
        contStepROI = contStepROI +1;
    end
    
    
    %% End of the source transformation for i-th subject
    fprintf('Source transformation finished for subject %s (%d/%d) \n', iSubName, i, nSubj);
end

%Prints the number of subjects available per step
fprintf('Number of subjects checked/saved for the database %s, over the BIDSmodality %s, and BIDStask %s IN THIS RUN: \n', databaseName, params.BIDSmodality, params.BIDStask);
fprintf('Original = %d \n', nSubj);
fprintf('Step 0 (Time Selection and Averaging) = %d / %d \n', contOptStepTime, nSubj);
fprintf('Step 1 (Channels To Source) = %d / %d \n', contStepSource, nSubj);
fprintf('Step 2 (Source Average ROI) = %d / %d \n', contStepROI, nSubj);


%If it made it this far, the script was completed succesfully
status = 1;
finalSourceStepPath = fullfile(params.newPath, 'SourceTransformation', 'Step2_SourceAvgROI');
sourceParams = params;

%Finally, check if the finalSourceStepPath have any subject. If not, erase the folder
dirFinal = dir(finalSourceStepPath);
dirFinalNames = {dirFinal(:).name};
subjFolders = startsWith(dirFinalNames, 'sub-');
if sum(subjFolders) == 0
    rmdir(finalSourceStepPath);
end

end