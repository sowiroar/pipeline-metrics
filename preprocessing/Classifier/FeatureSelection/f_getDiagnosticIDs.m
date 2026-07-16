function [status, paths, diagnostics] = f_getDiagnosticIDs(databasePath, stepPath, modality)
%Description:
%Function that get's the IDs for feature selection for a whole database(s) discriminating by diagnosis ONLY
%It is assumed that the databases are comparable and the only reason to separate them is diagnosis
%INPUTS:
%databasePath       = Cell with the path of the original database(s) that the user wants to normalize (MUST BE ALREADY IN BIDS-LIKE FORMAT)
%stepPath           = Cell with the path of the database(s) with the data to perform feature selection 
%   NOTE: (MUST BE ALREADY IN BIDS-LIKE FORMAT, and must correspond 1-to-1 with the databasePath)
%modality           = Cell with the modality to consider per database (NOTE: AS FOR NOW, ONLY WORKS FOR EEG)
%OUTPUTS:
%status             = 1 if the script was completed succesfully. 0 otherwise
%paths              = Structure with 2 fields: 'DiagnosticsName', 'DiagnosticsPath'
%                   Each field has a 1xM cell where M is the number of diagnostics of the databases.
%                   Each field of the M diagnostics contains a cell of Nx1, 
%                   where N is the number of subjects that the database(s) have per diagnosis

%Defines the default outputs
status = 0;
paths = {};
diagnostics = {};

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

%Defines the default values of modality ('eeg')
if nargin < 3
    modality = 'eeg';
end


%If everything is ok, get the diagnostics for each database
nDatabases = length(databasePath);
tempNames = {};
tempPaths = {};
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
    copyfile(fullfile(iDatabase, 'participants.tsv'), 'temp_participants.txt');
    participantsTsv = readtable('temp_participants.txt', 'Delimiter', 'tab');
    delete('temp_participants.txt');
   
    %Checks that the database has a column 'diagnostic'
    colNames = participantsTsv.Properties.VariableNames;
    if sum(strcmp(colNames, 'diagnostic')) == 0
        disp('ERROR: The database at the path:');
        disp(iDatabase);
        disp('Does not have a diagnostic column. Please create this column using code/runUpdateTsv');
        return
    end
    
    %Checks that the column diagnostic has more than one label
    iDiagnostics = participantsTsv.diagnostic;
    uniqueDx = unique(iDiagnostics);
    if length(uniqueDx) < 2
        disp('ERROR: The database at the path:');
        disp(iDatabase);
        disp('Only has one diagnostic available:')       
        disp(uniqueDx);
        disp('ERROR: Cannnot perform either feature selection nor classification with only one diagnostic');
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
    
    
    %Add the corresponding paths and names depending on their diagnostic
    for j = 1:length(uniqueDx)
        jTemp = uniqueDx{j};
        
        %Checks if the given diagnostic already exist
        colIdxDx = strcmpi(jTemp, diagnostics);
        if sum(colIdxDx) == 0         %If it does not exist, add it
            diagnostics{end+1} = jTemp;
            colIdxDx = [colIdxDx, true];
            tempNames{1, colIdxDx} = {};
            tempPaths{1, colIdxDx} = {};
        end
        
        %Defines the subjects that have the current diagnostic
        rowIdxDx = strcmp(jTemp, iDiagnostics);
        finalIdx = rowIdxDx &  rowIdxStep;
        finalIDs = iSubsId(finalIdx);
        for k = 1:length(finalIDs)                  %Iterates over the subjects, and looks for their corresponding .mat
            kPath = fullfile(iStepPath, finalIDs{k}, modality);
            if ~exist(kPath, 'dir')
                disp('UNEXPECTED ERROR: The following path does not exist:');
                disp(kPath);
                disp('Please check that the Participants.tsv and the folders structure correspond to one another');
                return
            end
            
            kDir = dir(fullfile(kPath, '*.mat'));
            if length(kDir) ~= 1
                disp('ERROR: The following path does not have a corresponding .mat, or has more than one');
                disp(kPath);
                return
            end
            
            %Appends the correspoding filename to the given nationality (colIdxNat) 
            tempNames{1, colIdxDx}{end+1, 1} = kDir(1).name;
            tempPaths{1, colIdxDx}{end+1, 1} = kPath;
        end
        
    end
end


%Creates the fields .Controls and .Remaining in the output variable paths
paths.DiagnosticsName = tempNames;
paths.DiagnosticsPath = tempPaths;

%If it made it this far, the script was completed succesfully
status = 1;

end