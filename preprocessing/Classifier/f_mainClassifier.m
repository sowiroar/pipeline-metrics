function [status, finalClassifierStepPath, classifierParams] = f_mainClassifier(databasePath, ...
        finalStepPath, varargin)
    
%Description:
%Function that performs classification and statistical tests for feature selection of the finalStepPath .mats
%The .mats MUST BE in [ROI, ROI, connectivityMetrics]
%INPUTS:
%databasePath           = Path of the desired database that wants to be used
%       NOTE: The databasePath MUST already be in a BIDS-like structure
%finalStepPath          = Path were the final .sets are expected to be
%       NOTE: The finalStepPath MUST already be in a BIDS-like structure
%OPTIONAL INPUTS:
%BIDSmodality           = String with the modality of the data that will be analyzed (used in sub-#_BIDStask_BIDSmodality.set) ('eeg' by default)
%BIDStask               = String with the task to analyze (used in sub-#_BIDStask_BIDSmodality.set) ('task-rest' by default)
%newPath                = String with the path in which the new folders will be stored ('databasePath/analysis_RS' by default)
%runClassifier          = true to run the classifier. false otherwise (true by default)
%runFeatureSelection    = true to run a statictical feature selection using permutations with FDR correction prior to creating the model
%classDxComparison      = Cell of 2x1, each field containing strings of the diagnostics to be compared ({} by default)
%classNumPermutations   = Integer with the number of permutations desired for the statistical tests (5000 by default)
%classSignificance      = Number with the level of significance desired (0.05 by default)
%classCrossValFolds     = Number of Cross-Validation folds to use for creating the ROC curves (5 by Default)
%OUTPUTS:
%status                 = 1 if the script was completed successfully. 0 otherwise
%finalClassifierStepPath= Path were the final .sets are expected to be (if status is 0, returns an empty array)
%classifierParams       = Parameters used in the classifier pipeline (if status is 0, returns an empty array)

%Defines the default outputs
status = 0;
finalClassifierStepPath = '';
classifierParams = '';

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
    disp('To do so, you must first run the connectivity metrics part of the pipeline');
    return
end
if ~exist(finalStepPath, 'dir')
    fprintf('ERROR: The finalStepPath: %s does not exist \n', finalStepPath);
    disp('You should not get this error if you first run the connectivity metrics part of the pipeline succesfully');
    return
end

%Defines the default optional parameters
%Type help finputcheck to know more about it. Basically it takes the inputs, makes sure everything is okay 
%and puts that information as a structure
params = finputcheck( varargin, {'BIDSmodality',        'string',       '',         'eeg'; ...
                                'BIDStask',             'string',       '',         'task-rest';
                                'newPath',              'string',       '',         fullfile(databasePath, 'analysis_RS');
                                'runClassifier',        'boolean',      '',         true;
                                'runFeatureSelection',  'boolean',      '',         true;
                                'classDxComparison',    'cell',         '',         {};
                                'classNumPermutations', 'integer',      [],         5000;
                                'classSignificance',    'float',        [],         0.05;
                                'classCrossValFolds',   'float',        [],         5;
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
fprintf('You currently have %d subjects after connectivity metrics \n', nSubj);
disp('If that is the number of subject you expected, please press any key to continue with the connectivity step, or "q" to quit');
quitNorm = input('', 's');
if strcmpi(quitNorm, 'q')
    disp('ERROR: Finishing the pipepline. Please check that the source transformation was completed correctly and run this script again');
    return
end


%If the analysis folder does not exist, create it, sending a warning
if ~exist(params.newPath, 'dir')
    fprintf('WARNING: %s does not exist, but should exist if you run the connectivity metrics steps correctly \n', params.newPath);
    disp('If you are running the mainClassifier function on your own, please ignore the warning');
    mkdir(params.newPath);
end

%If the parameters.txt does not exit, create it, sending a warning
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    fprintf('WARNING: %s does not exist, but should exist if you run the connectivity metrics steps correctly \n', params.newPath);
    disp('If you are running the mainClassifier function on your own, please ignore the warning');
    
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'w');
    fprintf(fileID, 'This txt contains the parameters used to create the .set located in the following path:\n');
    fprintf(fileID, '%s \n \n', fullfile(params.newPath));
    fprintf(fileID, 'General parameters: \n');
    fprintf(fileID, '\t - BIDSmodality = %s \n', params.BIDSmodality);
    fprintf(fileID, '\t - BIDStask = %s \n', params.BIDStask);
    fprintf(fileID, '\t - newPath = %s \n \n', params.newPath);
    fclose(fileID);
end


%Gives info about the process that just started
databaseName = regexp(databasePath, filesep, 'split');
databaseName = databaseName{end};
disp('****************************************************************************');
fprintf('Running a classifier for the database %s \n', databaseName);
fprintf('With its corresponding final step of connectivity metrics: \n%s \n', finalStepPath);
disp('****************************************************************************');

%% Step 0: Feature Selection
%Performs the feature selection prior to creating the classifier, if desired
if params.runFeatureSelection
    disp('--------------------Starting Step 0 (Feature Selection)---------------------');
    
    %Defines the path in which this step will (or should already) be saved
    pathStep0 = fullfile(params.newPath, 'Classifier', 'Step0_FeatureSelection');
    nameStep0 = 'finalFeatures.mat';
    
    %Checks if a .csv was already created to run the feature selection step or not
    if isempty(params.classDxComparison)
        
        %If there are multiple csv files, let the user know
        csvDir = dir(fullfile(pathStep0, '*.csv'));
        checkDir = isempty(csvDir);
        if ~checkDir
            disp('WARNING: There already exists various .csv:');
            disp({csvDir(:).name});
            disp('Press any key to perform another feature selection, or press "q" to use (one of) the feature selection file(s) listed above');
            runFS = input('', 's');
            if strcmpi(runFS, 'q')
                disp('WARNING: Using a pre-existing feature selection file. Not re-computing the feature selection step');
                checkDir = false;
            else
                %If the user wants to 
                checkDir = true;
            end
            
        end
        
    else
        csvFdrName = sprintf('fdr_finalFeatures_%s__VS__%s.csv', params.classDxComparison{1}, params.classDxComparison{2});
        csvPermName = sprintf('perm_finalFeatures_%s__VS__%s.csv', params.classDxComparison{1}, params.classDxComparison{2});
        checkDir = ~ (exist(fullfile(pathStep0, csvFdrName), 'file') || exist(fullfile(pathStep0, csvPermName), 'file'));
    end
    
    %If none csv exists for the desired comparison, create it
    if checkDir
        %Stratifies the subjects of that step by diagnosis, considering the information of each database
        %paths = Structure with 2 fields: 'DiagnosticsName' and 'DiagnosticsPath'
        %           Each field has a 1xM cell where M is the number of diagnoses of the databases.
        %           Each field of the M diagnoses contains a cell of Nx1, 
        %           where N is the number of subjects that the database(s) have per diagnosis
        %diagnostics = Cell of 1xM with a string in each field with the Names of the diagnostics
        [status, paths, diagnostics] = f_getDiagnosticIDs({databasePath}, {finalStepPath}, params.BIDSmodality);

        %Checks that the identification of diagnoses was completed succesfully
        if status == 0
            disp('ERROR: Could not identify the diagnostic of the subjects');
            return
        end

        %Performs the main feature selection (permutation and FDR)
        [status, finalStruct, newClassDxComparison, subjPerDx] = f_mainFeatSelection(paths, diagnostics, ...
            params.classDxComparison, params.classNumPermutations, params.classSignificance);

        %Checks that the feature selection could be completed successfully
        if status == 0
            disp('ERROR: Could not complete the feature selection step (permutation and FDR)');
            return
        end

        %If everything is okay, update the classDxComparison parameter
        params.classDxComparison = newClassDxComparison;

        %Add a new row to the .comments field, mentioning that the feature selection step was completed
        iComment = sprintf('---------------------------Classifier--------------------------------');
        finalStruct.comments = iComment;
        iComment = sprintf('Step 0: runFeatureSelection = true ; classDxComparison = %s--VS--%s ; classNumPermutations = %d ; classSignificance = %.3f ', ...
            params.classDxComparison{1}, params.classDxComparison{2}, params.classNumPermutations, params.classSignificance);
        finalStruct.comments = strvcat(finalStruct.comments, iComment);

        %Creates the folder in which the results of Step0 will be saved
        if ~exist(pathStep0, 'dir')
            mkdir(pathStep0);
        end

        %Save the finalStruct as a .mat
        matName = sprintf('%s_%s--VS--%s.mat', nameStep0(1:end-4), params.classDxComparison{1}, params.classDxComparison{2});    
        save(fullfile(pathStep0, matName), 'finalStruct');

        %Creates a table with  the features that survived smaller OR larger comparisons corrected for permutations AND FDR
        if isfield(finalStruct.fdrConnectivityData, 'combined')
            csvName = strcat('fdr_', matName(1:end-4), '.csv');
            csvName = replace(csvName, '-', '_');
            csvData = finalStruct.fdrConnectivityData.combined;
            csvLabels = finalStruct.fdrConnectivityLabels.combined;
            
            %If none FDR features survived, use the permutations features
        elseif isfield(finalStruct.permConnectivityData, 'combined')
            csvName = strcat('perm_', matName(1:end-4), '.csv');
            csvName = replace(csvName, '-', '_');
            csvData = finalStruct.permConnectivityData.combined;
            csvLabels = finalStruct.permConnectivityLabels.combined;
        end
        csvTable = cell2table(csvData);
        colNames = strrep(csvLabels, '-', '_');
        csvTable.Properties.VariableNames = colNames;

        %Saves the features that survived smaller and larger comparisons corrected for permutations AND FDR (if FDR survived)
        writetable(csvTable, fullfile(pathStep0, csvName));


        disp('----------------------------Step 0 completed--------------------------------');
    
    else
        %If the csv already exists, let the user know
        if ~isempty(params.classDxComparison)
            fprintf('The the desired comparison (%s vs %s) already had the step 0 files (Feature Selection)\n', ...
                params.classDxComparison{1}, params.classDxComparison{2});
        else
            if exist('csvDir', 'var') && length(csvDir) == 1
                disp('Assuming that the .csv to be used for the classifier is:');
                disp(fullfile(pathStep0, csvDir(1).name));
            else
                disp('WARNING: Skipping feature selection step');
            end
        end
    end
        
else
    %If the user does not want to perform feature selection, and there are none csv files,
    %Send a warning telling the benefits of feature selection
    pathStep0 = fullfile(params.newPath, 'Classifier', 'Step0_FeatureSelection');
    sendWarning = false;
    if ~exist(pathStep0, 'dir')
        sendWarning = true;
    else
        dirStep0 = dir(pathStep0);
        dirStep0Names = {dirStep0(:).name};
        csvFile = endsWith(dirStep0Names, '.csv');
        if sum(csvFile) == 0
            sendWarning = true;
        end
    end
    
    %If a warning was sent, give the user the opportunity to run the script again
    if sendWarning
        disp('WARNING: It is highly encouraged that you perform feature selection before training the classifier');
        disp('Please press "y" to run the the feature selection step again, or any other key to continue');
        runFS = input('', 's');
        if strcmpi(runFS, 'y')
            vararginParams = {'BIDSmodality', params.BIDSmodality, 'BIDStask', params.BIDStask, 'newPath', params.newPath, ...
                'runClassifier', true, 'runFeatureSelection', true, ...
                'classDxComparison', params.classDxComparison, 'classNumPermutations', params.classNumPermutations, 'classSignificance', params.classSignificance};
            
            [status, finalClassifierStepPath, classifierParams] = f_mainClassifier(databasePath, finalStepPath, vararginParams{:});
            return
        end
    end
end


%% Step 1: Runs the Machine Learning algorithm to differentiate between conditions/diagnoses
if params.runClassifier
    %Tries to find the .csv of the feature selection step
    pathStep0 = fullfile(params.newPath, 'Classifier', 'Step0_FeatureSelection');
    nameStep0 = dir(fullfile(pathStep0, '*.csv'));
    
    if length(nameStep0) == 1
        %If the csv exists, use it
        nameStep0 = nameStep0(1).name;
        
        
    elseif ~isempty(nameStep0)
        %If there are multiple csv, try and find the corresponding one (or create it) if a classDxComparison is given
        if ~isempty(params.classDxComparison)
            possibleName = sprintf('finalFeatures_%s__VS__%s.csv', params.classDxComparison{1}, params.classDxComparison{2});
            isName = endsWith({nameStep0(:).name}, possibleName);
            if sum(isName) > 0
                disp('WARNING: Assuming that the desired file with the finalFeatures is:');
                nameStep0 = nameStep0(isName).name;
                disp(nameStep0);
            else
                fprintf('WARNING: The csv corresponding to the comparison %s--VS--%s does not exist\n', params.classDxComparison{1}, params.classDxComparison{2});
                disp('Please press any key to run the script again to create the corresponding csv, or "q" to use ALL the connectivity metrics');
                runFS = input('', 's');
                if ~strcmpi(runFS, 'q')
                    vararginParams = {'BIDSmodality', params.BIDSmodality, 'BIDStask', params.BIDStask, 'newPath', params.newPath, ...
                        'runClassifier', true, 'runFeatureSelection', true, ...
                        'classDxComparison', params.classDxComparison, 'classNumPermutations', params.classNumPermutations, 'classSignificance', params.classSignificance};

                    [status, finalClassifierStepPath, classifierParams] = f_mainClassifier(databasePath, finalStepPath, vararginParams{:});
                    return
                    
                else
                    disp('WARNING: The models will be trained using the COMPLETE connectivity metrics');
                    pathStep0 = finalStepPath;
                    nameStep0 = '';
                    
                end
            end
            
            
        else
            %If multiple csv exist, and none classDxComparison was given, let the user know
            disp('WARNING: There are multiple .csv files in the same folder, and classDxComparison was not given as parameter');
            nameStep0 = {nameStep0(:).name};
        end
        
        
    else
        %If none csv exist, let the user perform feature selection, or use the complete connectivity metrics files
        disp('WARNING: It is highly encouraged that you perform feature selection before training the classifier');
        disp('Please press "y" to run the the feature selection step again, or any other key to load the complete connectivity metrics');
        runFS = input('', 's');
        if strcmpi(runFS, 'y')
            vararginParams = {'BIDSmodality', params.BIDSmodality, 'BIDStask', params.BIDStask, 'newPath', params.newPath, ...
                'runClassifier', true, 'runFeatureSelection', true, ...
                'classDxComparison', params.classDxComparison, 'classNumPermutations', params.classNumPermutations, 'classSignificance', params.classSignificance};
            
            [status, finalClassifierStepPath, classifierParams] = f_mainClassifier(databasePath, finalStepPath, vararginParams{:});
            return
        end
        
        disp('WARNING: The models will be trained using the COMPLETE connectivity metrics');
        pathStep0 = finalStepPath;
        nameStep0 = '';
    end
    
    
    disp('------------------------Starting Step 1 (Classifier)------------------------');

    
    %Defines the path in which this step will (or should already) be saved
    pathStep1 = fullfile(params.newPath, 'Classifier', 'Step1_Classifier');
    if ~exist(pathStep1, 'dir')
        mkdir(pathStep1);
    end

    %Runs the classifier (if the comparison was already made, send a warning message and does not train another model)
    [status, newClassDxComparison, subjPerDx] = f_mainBuildModel(pathStep0, nameStep0, pathStep1, params.classDxComparison, params.classCrossValFolds, ...
        databasePath, params.BIDSmodality);
    
    %Checks that everything is okay
    if status == 0
        disp('ERROR: Could not train the classifier. Look the messages above for debugging tips');
        rmdir(pathStep1);
        return
    end
    
    %Updates the class comparison performed
    params.classDxComparison = newClassDxComparison;
   
    %Opens figures with the created .jpg
    jpgFiles = dir(fullfile(pathStep1, '*.jpg'));
    nJpgFiles = length(jpgFiles);
    if mod(nJpgFiles, 3) ~= 0
        fprintf('WARNING: Three .jpg files were expected (or a multiple of three), but got %d instead\n', nJpgFiles);
        return
    end
    
    %Tries to open the figures created, given the desired comparison
    if ~isempty(params.classDxComparison)
        allJpgs = {jpgFiles(:).name};
        comparisonOfInterest = strcat(params.classDxComparison{1}, '__VS__', params.classDxComparison{2});
        jpgsOfInterest = contains(allJpgs, comparisonOfInterest);
        jpgsOfInterest = allJpgs(jpgsOfInterest);
        %TODO: Acá poner que busque por el nombre del diagnóstico
        for i = 1:length(jpgsOfInterest)
            iJpg = imread(fullfile(pathStep1, jpgsOfInterest{i}));
            figure, imshow(iJpg);
        end
    end
    
    
    %If everything was okay, let the user know that the whole pipeline was finished
    disp('------------------------------Step 1 Completed------------------------------');
    disp('-----------------------------Pipeline Completed-----------------------------');
end


%Prints the number of subjects available per step
fprintf('Number of subjects checked/saved for the database %s, over the BIDSmodality %s, and BIDStask %s IN THIS RUN: \n', databaseName, params.BIDSmodality, params.BIDStask);
fprintf('Original = %d \n', nSubj);
fprintf('Step 1 (Connectivity Metrics) = %d / %d \n', subjPerDx(1)+subjPerDx(2), nSubj);
fprintf('Compared the condition/diagnostic/outcome: %s (%d), against: %s (%d) \n', ...
    newClassDxComparison{1}, subjPerDx(1), newClassDxComparison{2}, subjPerDx(2));


%If it made it this far, the script was completed succesfully
status = 1;
finalClassifierStepPath = fullfile(params.newPath, 'Connectivity', 'Step1_ConnectivityMetrics');
classifierParams = params;


end