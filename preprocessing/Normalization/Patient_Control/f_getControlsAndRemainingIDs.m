function [status, paths, nationalities, newControlLabel] = f_getControlsAndRemainingIDs(databasePath, stepPath, controlLabel, modality)
%Description:
%Function that get's the IDs for control-normalization for a whole database(s) discriminating by nationality ONLY
%It is assumed that the databases are comparable and the only reason to separate them are: CONTROLS and NATIONALITY
%INPUTS:
%databasePath       = Cell with the path of the original database(s) that the user wants to normalize (MUST BE ALREADY IN BIDS-LIKE FORMAT)
%stepPath           = Cell with the path of the database(s) with the preprocessed and spatially normalized data that the user wants to normalize 
%   NOTE: (MUST BE ALREADY IN BIDS-LIKE FORMAT, and must correspond 1-to-1 with the databasePath)
%controlLabel       = Cell with the label(s) that the control subjects have (CN by default)
%modality           = Cell with the modality to consider per database (NOTE: AS FOR NOW, ONLY WORKS FOR EEG)
%OUTPUTS:
%status             = 1 if the script was completed succesfully. 0 otherwise
%paths              = Structure with 4 fields: 'ControlsName', 'ControlsPath', 'RemainingName' and 'RemainingPath' 
%                   (Remaining are the subjects of interest / non-controls).
%                   Each field has a 1xM cell where M is the number of nationalities of the databases.
%                   Each field of the M nationalities contains a cell of Nx1, 
%                   where N is the number of subjects that the database(s) have per nationality
%nationalities      = Cell of 1xM with a string in each field with the Names of the nationalities
%newControlLabel    = String with the controlLabel 

%Defines the default outputs
status = 0;
paths = {};
nationalities = {};
newControlLabel = controlLabel;

%Verifies that the databasePath is indeed a cell
if ~iscell(databasePath)
    disp('ERROR: Please enter the databasePath as a cell with the path of the database(s) to be normalized.');
    return
end
%Checks that the stepPath are given as cells, and that have the same length as databasePath
if ~iscell(stepPath)
    disp('ERROR: Please enter the stepPath as a cell with the path of the step(s) to be normalized.');
    return
end
if length(databasePath) ~= length(stepPath)
    disp('ERROR: The number of stepPath MUST BE the same as databasePath');
    return
end

%Defines the default values of controlLabel ('CN') and modality ('eeg')
if nargin < 3
    controlLabel = cell(1, length(databasePath));
    controlLabel(:) = {'CN'};                       %CN for all databases by default
end
if nargin < 4
    modality = 'eeg';
end

%Checks that the controlLabels are given as cells, and that have the same length as databasePath
if ~iscell(controlLabel)
    disp('ERROR: Please enter the controlLabels as a cell with the labels of the controls for the database(s) to be normalized.');
    return
end
if length(databasePath) ~= length(controlLabel)
    disp('ERROR: The number of controlLabels MUST BE the same as databasePath');
    return
end



%If everything is ok, check the controls for each database
nDatabases = length(databasePath);
tempNameControls = {};
tempPathControls = {};
tempNameRemaining = {};
tempPathRemaining = {};
for i = 1:nDatabases
    iDatabase = databasePath{i};
    iStepPath = stepPath{i};
    
    %Checks that the database and the stepPath exist
    if ~exist(iDatabase, 'dir')
        disp('ERROR: Please enter a valid database path');
        return
    end
    if ~exist(iStepPath, 'dir')
        disp('ERROR: Please enter a valid database path for the step you want to analyze');
        return
    end

    %Checks that the participants.tsv file exists
    if ~exist(fullfile(iDatabase, 'participants.tsv'), 'file')
        disp('ERROR: The given databasepath does not have a participants.tsv file.');
        disp('Please check that the database is already in a BIDS-like structure');
        return
    end

    %Makes a temporary copy of the participants.tsv file in the current folder, and loads it
      fileID = fopen(fullfile(iDatabase, 'participants.tsv'), 'r');
      participantsTsv = textscan(fileID, '%s %s %s', 'Delimiter', '\t', 'HeaderLines', 1);
      participantsTsv = table(participantsTsv{:}, 'VariableNames', {'subject_id','diagnostic', 'Nationality'});
    %copyfile(fullfile(iDatabase, 'participants.tsv'), 'temp_participants.txt');
    %participantsTsv = readtable('temp_participants.txt', 'Delimiter', 'tab');
    %delete('temp_participants.txt');

    %Checks that the database has a column for nationality
    colNames = participantsTsv.Properties.VariableNames;
    if sum(strcmp(colNames, 'Nationality')) == 0
        disp('ERROR: The participants.tsv MUST have a column named Nationality');
        disp('Please go to the following route:');
        disp(fullfile(iDatabase, 'code'));
        disp('and check runUpdateTsv to add that column to your dataset');
        return
    end
    
    %Checks that the database has a column 'diagnostic'
    if sum(strcmp(colNames, 'diagnostic')) == 0
        disp('ERROR: The database at the path:');
        disp(iDatabase);
        disp('Does not have a diagnostic column. Please create this column using code/runUpdateTsv');
        return
    end
    
    %Checks that the column diagnostic has the label given by controlLabel
    iDiagnostics = participantsTsv.diagnostic;
    if sum(strcmp(iDiagnostics, controlLabel{i})) == 0
        disp('WARNING: The database at the path:');
        disp(iDatabase);
        fprintf('Does not have a controlLabel: %s in the participants.tsv\n', controlLabel{i});        
        disp('These are the diagnostics available:');
        disp(unique(iDiagnostics)');
        disp('Please, enter the name corresponding to controls, or press q to exit');
        newControlLabel{i} = input('', 's');
        if strcmpi(newControlLabel{i}, 'q')
            return
        else
            fprintf('Running the identification of patients and controls again, with the controlLabel: %s ...\n', newControlLabel{i});
            [status, paths, nationalities, newControlLabel] = f_getControlsAndRemainingIDs(databasePath, stepPath, newControlLabel, modality);
        end
        return
    end
    
    %Checks that the database has a column 'subject_id'
    if strcmp(colNames, 'subject_id') == 0
        disp('UNEXPECTED ERROR: The database at the path:');
        disp(iDatabase);
        disp('Does not have a subject_id column. This is the most basic field that the participants.tsv must have');
        return
    end
    iSubsId = participantsTsv.subject_id;
    
    
    %Defines the subject folders of the step to be analyzed
    iDirStep = dir(iStepPath);
    iDirStepName = {iDirStep(:).name};
    iStepSubjFolders = startsWith(iDirStepName, 'sub-');
    iStepSubjFolders = iDirStepName(iStepSubjFolders);
    nStepSubjFolders = length(iStepSubjFolders);
    
    %Checks which of the original database subjects are still in the subjects folders of the step to be analyzed
    rowIdxStep = zeros(length(iSubsId), 1) == 1;
    for j = 1:nStepSubjFolders
        rowIdxStep = rowIdxStep | strcmp(iStepSubjFolders{j}, iSubsId);
    end
    if sum(rowIdxStep) ~= nStepSubjFolders
        disp('ERROR: Unexpected mismatch between the subjects of the step to be analyzed, and the original database subjects');
        return
    end
    
    %Defines the indexes for controls and for the remaining subjects
    rowIdxCtrl = strcmp(iDiagnostics, controlLabel{i});
    rowIdxRemaining = ~rowIdxCtrl;
    
    %Checks the nationalities that this database has
    iNationalities = participantsTsv.Nationality;
    uniNat = unique(iNationalities);
    
    %Add the corresponding control paths depending on their nationality
    for j = 1:length(uniNat)
        jTemp = uniNat{j};
        
        %Checks if the given nationalities already exist
        colIdxNat = strcmpi(jTemp, nationalities);
        if sum(colIdxNat) == 0         %If it does not exist, add it
            nationalities{end+1} = jTemp;
            colIdxNat = [colIdxNat, true];
            tempNameControls{1, colIdxNat} = {};
            tempPathControls{1, colIdxNat} = {};
            tempNameRemaining{1, colIdxNat} = {};
            tempPathRemaining{1, colIdxNat} = {};
        end
        
        %Defines the subjects of the controls that have the current nationality
        rowIdxNat = strcmp(jTemp, iNationalities);
        finalCtrlIdx = rowIdxNat & rowIdxCtrl & rowIdxStep;
        finalCtrlIDs = iSubsId(finalCtrlIdx);
        for k = 1:length(finalCtrlIDs)                  %Iterates over the subjects, and looks for their corresponding .set
            kPath = fullfile(iStepPath, finalCtrlIDs{k}, modality);
            if ~exist(kPath, 'dir')
                disp('UNEXPECTED ERROR: The following path does not exist:');
                disp(kPath);
                disp('Please check that the Participants.tsv and the folders structure correspond to one another');
                return
            end
            
            kDir = dir(fullfile(kPath, '*.set'));
            if length(kDir) ~= 1
                disp('ERROR: The following path does not have a corresponding .set, or has more than one');
                disp(kPath);
                return
            end
            
            %Appends the correspoding filename to the given nationality (colIdxNat) 
            tempNameControls{1, colIdxNat}{end+1, 1} = kDir(1).name;
            tempPathControls{1, colIdxNat}{end+1, 1} = kPath;
        end
        
        %Defines the subjects of the remaining subjects that have the current nationality
        finalRemainingIdx = rowIdxNat & rowIdxRemaining & rowIdxStep;
        finalRemainingIDs = iSubsId(finalRemainingIdx);
        for k = 1:length(finalRemainingIDs)                  %Iterates over the subjects, and looks for their corresponding .set
            kPath = fullfile(iStepPath, finalRemainingIDs{k}, modality);
            if ~exist(kPath, 'dir')
                disp('UNEXPECTED ERROR: The following path does not exist:');
                disp(kPath);
                disp('Please check that the Participants.tsv and the folders structure correspond to one another');
                return
            end
            
            kDir = dir(fullfile(kPath, '*.set'));
            if length(kDir) ~= 1
                disp('ERROR: The following path does not have a corresponding .set, or has more than one');
                disp(kPath);
                return
            end
            
            tempNameRemaining{1, colIdxNat}{end+1, 1} = kDir(1).name;
            tempPathRemaining{1, colIdxNat}{end+1, 1} = kPath;
        end
        
    end
end


%Creates the fields .Controls and .Remaining in the output variable paths
paths.ControlsName = tempNameControls;
paths.ControlsPath = tempPathControls;
paths.RemainingName = tempNameRemaining;
paths.RemainingPath = tempPathRemaining;

%If it made it this far, the script was completed succesfully
status = 1;

end