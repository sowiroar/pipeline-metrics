function [status, EEGcell, EEGnames] = f_optStep9GrandAverage(stepPath, modality, task, databasePath, groupType, groupName)
%Description:
%Function that performs the final optional step of Grand-average
%INPUTS:
%stepPath = Path of the desired step that wants to be preprocessed.
%   NOTE: The databasePath MUST already be in a BIDS-like structure
%modality = String with the modality of the data that will be analyzed ('eeg' by default)
%task = String with the task to analyze ('rs_HEP by default')
%databasePath = Path of the original database (just to obtain the participants.tsv)
%groupType = Cell of [1, column] with the name(s) of the type(s) of the group (condition/diagnostic/nationality) 
%           that the user wants to use to average (column of participants.tsv)
%           If nothing is given, averages all subjects that appear in the stepPath
%groupName = Cell of [values, column] with the name(s) of a specific condition(s)/diagnostic(s) that the user wants to average 
%           (values of the corresponding columns of participants.tsv)
%           If nothing is given, averages all subjects that appear in the stepPath
%OUTPUTS:
%status = 1 if this script was completed succesfully. 0 otherwise.
%EEGcell = Cell with EEGLab structures with the Grand Averaged data [channels, time, subjects]
%EEGnames = Names of each EEGLab structure stored in EEGcell
%Author: Jhony Mejia

status = 1;
EEG = [];

%Defines default inputs
if nargin < 2
    modality = 'eeg';
end
if nargin < 3
    task = 'rs-HEP';
end
if nargin < 4
    infoForAveraging = false;
elseif nargin == 6
    infoForAveraging = true;
    %Checks that the given inputs make sense
    nCols = length(groupType);
    if nCols ~= size(groupName, 2)
        disp('ERROR: The number of columns of groupType and groupName MUST be the same');
        return
    end
else
    disp('ERROR: You can either run this function with 3 or 6 parameters. Info about the function below:');
    help f_optStep9GrandAverage
    return
end


%Checks that the database exists
if ~exist(stepPath, 'dir')
    disp('ERROR: The given path does not exist. Please enter a valid folder name');
    return
end

%Checks that the folder has a BIDS-like structure
%MUST have a 'README.txt', 'participants.tsv', 'task_modality.json' and folders that start with 'sub-'
mainDir = dir(stepPath);
mainDirNames = {mainDir(:).name};
if (sum(startsWith(mainDirNames, 'sub-'))) == 0
    disp('ERROR: Please check that the folder you gave has a BIDS-like structure');
    disp('It MUST have the following files:');
    disp(strcat('Folders that start with sub-, with their corresponding .sets inside'));
end


%Starts the Grand Average for all subjects of the given database, if no additional information is given
EEGnames = {};
if ~infoForAveraging
    subjFolders = startsWith(mainDirNames, 'sub-');
    cellSubNames = {mainDirNames(subjFolders)};
    
    [status, EEGcell] = f_makeGrandAverage(cellSubNames, stepPath, modality, task);
    EEGnames{end+1} = strcat('s9_GrandAverage_', task, '.set');
    
else
    %If more information was given, try to use it
    %Checks that the database has a participants.tsv file
    if ~exist(fullfile(databasePath, 'participants.tsv'), 'file')
        status = 0;
        disp('ERROR: The databasePath given does not contain any participants.tsv file');
        disp('This file is the one that has demographic information about the subjects, and allows the pipeline to know how to group the subjects');
        return
    end
    
    %Makes a temporary copy of the participants.tsv file in the current folder, and loads it
    copyfile(fullfile(databasePath, 'participants.tsv'), 'temp_participants.txt');
    participantsTsv = readtable('temp_participants.txt', 'Delimiter', 'tab');
    delete('temp_participants.txt');
    
    %Iterates over the given columns
    nGroupNames = size(groupName, 1);
    colNames = participantsTsv.Properties.VariableNames;
    logicalIdx = cell(size(groupName));
    for i = 1:nCols
        
        %Check that the column exists
        iColName = groupType{i};
        colExists = strcmpi(iColName, colNames);
        if sum(colExists) == 0
            fprintf('ERROR: The given column: %s, does not exist in the participants.tsv \n', iColName);
            disp('These are the possible columns:');
            disp(colNames);
            status = 0;
            return
        end
        
        %If the column exists, extract the WHOLE column
        iColInfo = participantsTsv.(colNames{colExists});
        
        %Over that column of information, looks for the groupName of the corresponding groupType (column)
        for j = 1:nGroupNames
            %First, check that the given group type (row) has a value
            jGroupName = groupName{j,i};
            if isempty(jGroupName)
                continue
            end
            rowFiltered = strcmpi(iColInfo, jGroupName);
            
            %Check that the given group type (value) exist
            if sum(rowFiltered) == 0
                fprintf('ERROR: The given group name: %s, does not exist for the group type %s. \n', jGroupName, iColName);
                disp('The possible group types are:');
                disp(unique(iColInfo));
                status = 0;
                return
            end
            
            %If everything was okay, add that filtering to the logicalIdx cell
            logicalIdx{j, i} = rowFiltered;
        end
    end
    
    
    %After obtaining the different logical indexing of the desired parameters, operate them to create different .sets
    %Considers three possible filtering columns, and makes the combination of each entry
    subjFolders = startsWith(mainDirNames, 'sub-');
    subjFolders = mainDirNames(subjFolders);
    subjNames = participantsTsv.subject_id;
    
    cellSubNames = {};
    for i = 1:nGroupNames                   %Iteration for the first column
        
        for j = 1:nGroupNames               %Iteration for the second column
            %Checks if the given group names had more than one column
            if (nCols < 2) && (j > 1)
                continue
            end
            
            for k = 1:nGroupNames           %Iteration for the third column
                %Checks if the given group names had more than two columns
                if (nCols < 3) && (k > 1)
                    continue
                end
                
                %Check if the given groupName exists and is non-empty
                ijkName = 's9_GrandAverage';
                ijkCombination = ones(length(subjNames), 1);
                try groupName(i, 1);
                    if ~isempty(groupName{i, 1})
                        ijkCombination = ijkCombination .* logicalIdx{i, 1};
                        ijkName = strcat(ijkName, '_', groupName{i, 1});
                    else
                        continue
                    end
                catch
                end
                
                try groupName(j, 2);
                    if ~isempty(groupName{j, 2})
                        ijkCombination = ijkCombination .* logicalIdx{j, 2};
                        ijkName = strcat(ijkName, '_', groupName{j, 2});
                    else
                        continue
                    end
                catch
                end
                
                try groupName(k, 3);
                    if ~isempty(groupName{k, 3})
                        ijkCombination = ijkCombination .* logicalIdx{k, 3};
                        ijkName = strcat(ijkName, '_', groupName{k, 3});
                    else
                        continue
                    end
                catch
                end
                
                %Finally, group those subject names
                cellSubNames{end+1} = {subjNames{ijkCombination == 1}};
                EEGnames{end+1} = strcat(ijkName, '_', task, '.set');
            end
        end
    end
    
    %Check that the cellSubNames filtered are in the current step. Otherwise, remove them
    nSetSubj = length(cellSubNames);
    idxsSetsToRemove = [];
    for i = 1:nSetSubj
        idxsToRemove = [];
        iCell = cellSubNames{i};
        
        for j = 1:length(iCell)
            if ~ismember(iCell{j}, subjFolders)
                idxsToRemove = [idxsToRemove, j];
            end
        end
        
        iCell(idxsToRemove) = [];
        cellSubNames{i} = iCell;
        
        if isempty(iCell)
            idxsSetsToRemove = [idxsSetsToRemove, i];
        end
    end
    
    %Removes the empty cells (if any)
    if ~isempty(idxsSetsToRemove)
        disp('WARNING: The following combinations do not have any subject for the given directory:');
        disp(EEGnames(idxsSetsToRemove));
        disp('Those combinations WILL NOT be saved')
        
        cellSubNames(idxsSetsToRemove) = [];
        EEGnames(idxsSetsToRemove) = [];
    end
    	
    
    %Finally, run the grand average over the distinct sets of subjects
    [status, EEGcell] = f_makeGrandAverage(cellSubNames, stepPath, modality, task);
    
end

%Checks that the EEGcell and EEGnames have the same size
if size(EEGcell) ~= size(EEGnames)
    disp('ERROR: Unexpected mismatch between the EEGLab structures and their corresponding names');
    disp('See f_optStep9GrandAverage and debug it');
    status = 0;
    return
end


end