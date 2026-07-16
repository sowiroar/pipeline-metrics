function [status, EEGcell] = f_makeGrandAverage(cellSubNames, stepPath, modality, task)
%Function that performs a grand average of the subjects given in cellSubNames
%INPUTS:
%cellSubNames = Cell of 1xN with N different sets of subject names. Each cell
%   has a cell of N subject names to be considered for the grand average
%stepPath = Path of the desired step that wants to be preprocessed.
%   NOTE: The databasePath MUST already be in a BIDS-like structure
%modality = String with the modality of the data that will be analyzed ('eeg' by default)
%task = String with the task to analyze ('rs_HEP by default')

status = 1;

nSetOfSubj = length(cellSubNames);
EEGcell = cell(1, nSetOfSubj);

%Iterates over the different set of subjects given
for i = 1:nSetOfSubj
    subjFolders = cellSubNames{i};
    nSubj = length(subjFolders);
        
    EEGDataContainer = cell(1,nSubj);       %Container of the [channels, time] data averaged per epoch for each individual subject
    stepName = regexp(stepPath, filesep, 'split');
    stepName = stepName{end};
    disp('---------------------------------------------------------------------------------------------');
    fprintf('Preprocessing the step: %s with the filters given (if any) (%d subjects in total) \n', stepName, nSubj);
    %Iterates over the different subjects of the i-th set of subjects
    for j = 1:nSubj
        %Defines the name of the current subject
        jSubName = subjFolders{j};
        jSetPath = fullfile(stepPath, jSubName, modality);
        jSetName = dir(fullfile(jSetPath, '*.set'));
        if isempty(jSetName)
            fprintf('WARNING: The subject %s does not have a .set ot the modality: %s \n', jSubName, modality);
            continue
        end
        jSetName = jSetName(1).name;
        
        %Checks that the subject has the given task
        jSetTask = split(jSetName, '.');
        jSetTask = split(jSetTask{1}, '_');
        jSetTask = jSetTask{end-1};
        if ~strcmp(jSetTask, task)
            fprintf('WARNING: The subject %s does not have a .set ot the task: %s \n', jSubName, task);
            continue
        end

        %Loads the i-th .set
        EEG = pop_loadset('filename', jSetName, 'filepath', jSetPath);

        %If this is the first iteration, there is no need to check that the fields match with the pre-existing ones
        if j~=1
            %Otherwise, do check that the given .sets all have the same structure
            %Checks that they have the same reference
            if ~strcmp(EEG.ref, oldEEG.ref)
                fprintf('ERROR: The subject %s of the given path has a different reference than the previous subject: %s \n', jSubName, oldName);
                fprintf('%s_ref = %s; %s_ref = %s \n', jSubName, EEG.ref, oldName, oldEEG.ref);
                status = 0;
                return
            end

            %Checks that they consider the same window of time
            if (EEG.pnts ~= oldEEG.pnts) || (EEG.xmin ~= oldEEG.xmin) || (EEG.xmax ~= oldEEG.xmax) || (EEG.srate ~= oldEEG.srate)
                fprintf('ERROR: The subject %s of the given path considers a different window of time than the previous subject: %s \n', jSubName, oldName);
                fprintf('[xmin, xmax, numPoints, sRate] for %s = [%.4f, %.4f, %d, %d] ; vs %s = [%.4f, %.4f, %d, %d] \n', ...
                    jSubName, EEG.xmin, EEG.xmin, EEG.pnts, EEG.srate, oldName, oldEEG.xmin, oldEEG.xmin, oldEEG.pnts, oldEEG.srate);
                status = 0;
                return
            end


            %Checks that they have the same number of channels
            if EEG.nbchan ~= oldEEG.nbchan
                fprintf('ERROR: The subject %s of the given path has a different number of channels than the previous subject: %s \n', jSubName, oldName);
                fprintf('%s_nChans = %d; %s_nChans = %d', jSubName, EEG.nbchan, oldName, oldEEG.nbchan);
                status = 0;
                return
            end
        end

        %If the jth-subject has only one epoch, give the user a warning
        jData = EEG.data;
        if length(size(jData)) < 3
            fprintf('WARNING: The subject %s does not have any epochs. \n', jSubName);
            disp('Assuming that this subject already had its epochs averaged');
            EEGDataContainer{j} = jData;

        else
            %Otherwise, average the epochs before adding them to the EEGDataContainer
            jData = mean(jData, 3);
            EEGDataContainer{j} = jData;
        end

        %Saves the current EEG as 'oldEEG' to compare it with the next subject
        oldEEG = EEG;
        oldName = jSubName;
    end
    
    
    %All the subjects have the same EEG structure.  For that reason, only the last EEG loaded is modified
    tempFinalData = zeros(EEG.nbchan, EEG.pnts, nSubj);
    EEG.trials = nSubj;
    for j = 1:nSubj
        tempFinalData(:,:,j) = EEGDataContainer{j};
    end
    EEG.data = tempFinalData;
    
    %Clear the fields of events, as they are no longer of interest (already averaging across one particular event)
    EEG.event = [];
    EEG.urevent = [];
    EEG.epoch = [];

    %Clear other events that have no longer meaning
    EEG.reject = [];
    EEG.stats = [];
    EEG.subject = '';
    EEG.group = '';

    %Checks that everything is okay
    EEG = eeg_checkset(EEG);
    
    %If everything was okay, add the current EEG structure to the output cell
    EEGcell{i} = EEG;
end