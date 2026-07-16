function [status, newClassDxComparison, subjPerDx] = ...
    f_mainBuildModel(pathStep0, nameStep0, pathStep1, classDxComparison, classCrossValFolds, databasePath, BIDSmodality)
%Description:
%Function that trains a classifier to differentiate two conditions, and creates ROC curves and Feature Importance graphics
%The model trained is an XGBoosting algorithm, using a 80/20 Training/Test stratified split
%INPUTS:
%pathStep0          = String with the path were the files to train the model are located
%       NOTE: If the Step 0 (Feature Selection) was correctly completed, the path will correspond to the Step0_FeatureSelection
%       If the Step 0 was not completed, the path will correspond to the main folder of connectivity metrics
%nameStep0          = String with the name of the .csv file that contains the data to train the model
%       NOTE: The .csv is a matrix of [Subjects, Features], where the first  column corresponds to the diagnostics/comparisons/labels
%       NOTE: nameStep0 can also be a cell with multiple .csv, and the user will be asked to pick one
%       If the Step 0 was not completed, nameStep0 will be empty, as the data will be loaded from each sub-# folder
%pathStep1          = String with the path where the .jpg with the ROC Curves and Feature Importance graphics will be stored 
%classDxComparison  = Cell of 2x1, each field containing strings of the diagnostics to be compared ({} by default)
%classCrossValFolds = Number of Cross-Validation folds to use for creating the ROC curves (5 by Default)
%databasePath       = Path of the desired database that wants to be used
%       NOTE: The databasePath MUST already be in a BIDS-like structure
%       NOTE: databasePath will be only used if the user wants to use the complete connectivity metrics
%BIDSmodality       = String with the modality of the data that will be analyzed (used in sub-#_BIDStask_BIDSmodality.set) ('eeg' by default)
%       NOTE: BIDSmodality will be only used if the user wants to use the complete connectivity metrics
%
%OUTPUTS:
%status             = 1 if the script was completed succesfully. 0 otherwise
%newClassDxComparison= Cell of 2x1, each field containing strings of the diagnostics that were finally compared
%subjPerDx          = Number of subjects used per category/diagnosis/outcome/condition
%Also saves the following metrics for the model: ROC_Curve.jpg, AllFeaturesImportance.jpg, and SHAP_BestFeaturesImportance.jpg
%TIP: For more information about the classifier, check the .py and/or .ipynb scripts

%Defines the default output
status = 0;
newClassDxComparison = {};
subjPerDx = [];

%Defines the default input
if nargin < 4
    classDxComparison = {};
end
if nargin < 5
    classCrossValFolds = 5;
end
if nargin < 6
    %Tries to define the databasePath with the given pathStep0
    %If no nameStep was given, the path should be the connectivity metrics step 
    %(should be databasePath/analysis_XX/Connectivity/Step1_ConnectivityMetrics)
    %In any other case, the path should be the feature selection step
    %(should be databasePath/analysis_XX/Classifier/Step0_FeatureSelection)
    tempPath = strsplit(pathStep0, filesep);
    databasePath = fullfile(tempPath{1:end-3});
end
if nargin < 7
    BIDSmodality = 'eeg';
end


%Checks that the path containing the data to train the model exist
if ~exist(pathStep0, 'dir')
    disp('ERROR: The path that should contain the data to train the model DOES NOT EXIST:');
    disp(pathStep0);
    return
end


%% Defines which data will be loaded
%Considers multiple cases to manage nameStep0
if ischar(nameStep0) && ~isempty(nameStep0)
    %If a name was given, check that it corresponds to a csv, and that it exists
    if ~endsWith(nameStep0, '.csv')
        disp('ERROR: A .csv file was expected, but the following file was given instead:');
        disp(nameStep0);
        return
    end
    fullFileStep0 = fullfile(pathStep0, nameStep0);
    if ~exist(fullFileStep0, 'file')
        disp('ERROR: The .csv that should contain the data to train the model does not exist:');
        disp(fullFileStep0);
        return
    end
    
    %Defines the classDxComparison
    comparison = strsplit(nameStep0, '__VS__');
    dx1 = strsplit(comparison{1}, '_');
    dx2 = strsplit(comparison{2}, '.csv');
    newClassDxComparison = {dx1{end}, dx2{1}};
    if ~isempty(classDxComparison) && ~isequal(newClassDxComparison, classDxComparison)
        fprintf('WARNING: The comparison entered by parameter is: %s VS %s; but the .csv is comparing: %s VS %s\n', ...
            classDxComparison{1}, classDxComparison{2}, newClassDxComparison{1}, newClassDxComparison{2});
        fprintf('WARNING: Assuming that the comparison desired is %s VS %s\n', ...
            newClassDxComparison{1}, newClassDxComparison{2});
    end
    
    %Updates the classDxComparison (If it was the same, it would not make any difference)
    classDxComparison = newClassDxComparison;
    
    
elseif iscell(nameStep0)
    %If multiple .csv were entered, let the user pick one
    disp('WARNING: Multiple .csv files were found in the given folder. These are the files available:');
    disp(nameStep0);
    disp('Please enter the COMPLETE EXACT name (with .csv) of the file you want to analyze:');
    tempName = input('', 's');
    
    %Checks that the name given by the user exists
    if ~ismember(tempName, nameStep0)
        fprintf('WARNING: The file name entered ("%s") does not exist\n', tempName);
        disp('Please press any key to run the script again, or "q" to quit');
        runAgain = input('', 's');
        if strcmpi(runAgain, 'q')
            disp('ERROR: Could not train the classifier because an invalid file was entered');
            return
        end
        
        status = f_mainBuildModel(pathStep0, nameStep0, pathStep1, classDxComparison, classCrossValFolds, databasePath, BIDSmodality);
        return
    end
    
    %If a valid name was given, overwrites 'nameStep0' and defines the classDxComparison
    nameStep0 = tempName;
    comparison = strsplit(nameStep0, '__VS__');
    dx1 = strsplit(comparison{1}, '_');
    dx2 = strsplit(comparison{2}, '.csv');
    newClassDxComparison = {dx1{end}, dx2{1}};
    if ~isempty(classDxComparison) && ~isequal(newClassDxComparison, classDxComparison)
        fprintf('WARNING: The comparison entered by parameter is: %s VS %s; but the .csv is comparing: %s VS %s\n', ...
            classDxComparison{1}, classDxComparison{2}, newClassDxComparison{1}, newClassDxComparison{2});
        fprintf('WARNING: Assuming that the comparison desired is %s VS %s\n', ...
            newClassDxComparison{1}, newClassDxComparison{2});
    end
    
    %Updates the classDxComparison (If it was the same, it would not make any difference)
    classDxComparison = newClassDxComparison;
    
elseif isempty(nameStep0)
    %If none name was given, it means the user selected the complete connectivty metrics, WITHOUT feature selection
    %Creates a new table with all the features for the desired comparison
    [statusNewCsv, newClassDxComparison, newCsvTable, newCsvName] = f_createCsvAllMetrics(pathStep0, databasePath, ...
        BIDSmodality, classDxComparison);
    
    %Checks if the script could be completed
    if statusNewCsv == 0
        disp('ERROR: Could not create a csv with all the connectivity metrics');
        return
    end
    
    %Updates the output variables
    classDxComparison = newClassDxComparison;
    nameStep0 = newCsvName;
    
    %Saves the new .csv in the same foldr of the connectivity metrics step
    writetable(newCsvTable, fullfile(pathStep0, nameStep0));
end

%% Loads the desired data, prints info about it and trains the model using a Python backend
%Loads the csv with the information to train the model
dataTable = readtable(fullfile(pathStep0, nameStep0));

%Checks that the first column has only two unique values (first column corresponds to the labels)
dxColumn = dataTable{:,1};
uniqueDx = unique(dxColumn);
if length(uniqueDx) ~= 2
    fprintf('ERROR: 2 unique diagnostics were expected in the first column, but got %d instead:\n', length(uniqueDx));
    disp(uniqueDx);
    disp('TIP: The first column of the csv MUST contain the labels/diagnostics/groups');
    disp('TIP: The csv must be of size [nSubjects, 1+nFeatures] (where the 1+ is the labels/diagnostics/groups column)');
    return
end

%Let the user know the dimensions of the data that will be used to train the models
[nSubj, nFeats] = size(dataTable);
fprintf('The data to train the model has %d subjects, each with %d features\n', nSubj, nFeats);

%Gets the number of subjects available per diagnosis
nCond1 = sum(strcmp(classDxComparison{1}, dxColumn));
nCond2 = sum(strcmp(classDxComparison{2}, dxColumn));
fprintf('The labels/diagnostics/groups to be compared are: %s (n=%d) and %s (n=%d)\n', ...
    classDxComparison{1}, nCond1, classDxComparison{2}, nCond2);
subjPerDx = [nCond1, nCond2];

%Defines the number of Cross Validation splits that can be performed to have at least 2 subjects in the validation set
minCond = min([nCond1, nCond2]);
if minCond < 25
    disp('ERROR: You need to have at least 25 subjects per category to perform an acceptable cross-validation');
    disp('TIP: If you still want to continue, you can change the train/test split and the number of folds in the .ipynb file at:');
    [classifierPath, ~, ~] = fileparts(mfilename('fullpath'));
    disp(classifierPath);
    disp('Please enter "y" once you have modified the Python script, or press any key to continue');
    modifiedTrainSplit = input('', 's');
    if ~strcmpi(modifiedTrainSplit, 'y')
        return
    end
end
if minCond >= 150
    classCrossValFolds = 10;
    disp('WARNING: You have at least 150 subjects per category. Performing 10-fold Cross-Validation to produce more robust results');
end


%Gets the path that contains the .py with the code to build the XGBoost model
[classifierPath, ~, ~] = fileparts(mfilename('fullpath'));
begCode = sprintf('python %s', fullfile(classifierPath, 'XGBoost_Python.py'));


%Calls the .py function that trains the XGBoost model, and saves the results as .jpg
for i = classCrossValFolds:-1:2
    %NOTE: One type of error could be created if there are not enough subjects to perform Cross-Validation
    %If the python script fails to be completed, try with less k-Splits for Cross-Validation
    
    %The Python script expects the following format: python classifierPath -f 'csv_file' -cv Number_of_Cross_Validation_Splits
    commandStr = sprintf('%s -f %s -cv %d -s %s', begCode, fullfile(pathStep0, nameStep0), classCrossValFolds, fullfile(pathStep1, nameStep0(1:end-4)));
    
    %Calls the python script that builds the XGBoost model and saves the .jpg figures of feature importance and ROC Curve
    fprintf('Trying to create a XGBoost model with %d Cross-Validation splits. This will take a while...\n', i);
    pythonStatus = system(commandStr, '-echo');
    
    %If the status is 0, the script was completed and no further Cross-Validation should be attempted
    if pythonStatus == 0
        break
    else
        disp('WARNING: Could not complete the python script. Trying to create a XGBoost model with less Cross-Validation splits');
    end
end

%Finally, checks if the python script could be completed or not
if pythonStatus ~= 0
    disp('ERROR: Could not complete the Python script to create the XGBoost model');
    disp('TIP: To get more information about the possible error please open the following .ipynb file and execute it');
    disp(classifierPath);
    disp('NOTE: At this point, you must find the error yourself and solve it');
    
else
    disp('The XGBoost model was correctly completed!');
    newClassDxComparison = classDxComparison;
    status = 1;
end


end