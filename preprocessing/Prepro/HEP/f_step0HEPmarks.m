function [status, newECGchan] = f_step0HEPmarks(isMarked, setPath, setName, pathStep0, nameStep0, ECGchan, databasePath, task)
%Function that puts the HEP marks in the given dataset
%Ideally, this step should be run first to check if the marks make sense,
%and that the data is a good candidate to undergo the full preprocessing
%INPUTS: 
%isMarked = 1 if the given set is marked or not
%setPath = Path of the .set that wants to be analyzed
%setName = Name of the .set that wants to be analyzed
%pathStep0 = Path where the marked .set will be stored
%nameStep0 = Name where the marked .set will be stored
%OPTIONAL INPUTS (their necessity depends a lot on the raw data, but if given, will take care of every possible scenario)
%ECGchan = Name of the channel to consider for HEP marking (ECG channel). Empty by default
%databasePath = Path of the original database (used to read task_events.json, if needed and available) (two directories up the .set by default)
%task = Task to be analyzed (used to read task_events.json, if needed and availabe) ('rs-HEP' by default)
%OUTPUTS:
%status = 1 if the script was completed succesfully. 0 Otherwise
%newECGchan = Name of the channel to consider for HEP marking (ECG channel).
%Author: Jhony Mejia

%Defines default values
if nargin < 6
    ECGchan = [];
end
if nargin < 7
    %Moves three directories up
    pathParts = regexp(setPath, filesep, 'split');
    databasePath = pathParts{1};
    for i = 2:length(pathParts) -3
        databasePath = fullfile(databasePath, pathParts{i});
    end
end
if nargin < 8
    task = 'HEP';
end


status = 1;
newECGchan = [];

%Defines the subject's name (following a EEG-BIDS structure)
subName = strsplit(setName, '_');
subName = subName{1};

%And defines the files of the main EEG-BIDS database
mainDir = dir(databasePath);
mainDirNames = {mainDir(:).name};

%If it is already marked, just copy the .sets into the newPath
if isMarked
    fprintf('Assuming that the .set of the subject %s is already marked with the events \n', subName);

    %Create a figure to scroll through the signal to make sure the signals make sense
    EEG = pop_loadset('filename', setName, 'filepath', setPath);
    Pix_SS = get(0,'screensize');           %Gets the screensize to avoid the figure obstructing the command line
    pop_eegplot( EEG, 1, 1, 1, [], 'position', [0 Pix_SS(4)*0.3 Pix_SS(3) Pix_SS(4)*0.62]);
    
    
    %And also creates a tacogram to make the quality control easier
    allEvents = {EEG.event(:).type};
    try         %Try finding the unique values as a cell (if there are strings)
        eventNames = unique(allEvents);
    catch       %If there are numbers, convert them into strings
        nAll = length(allEvents);
        for i = 1:nAll
            if isnumeric(allEvents{i})
                allEvents{i} = num2str(allEvents{i});
            end
        end
        eventNames = unique(allEvents);
    end
    
    if length(eventNames) > 1
        %If there is more than one event, asks the user to type the event name corresponding to heart beats
        disp('Please enter which of the following events correspond to the Heart Beat mark:');
        disp(eventNames);
        heartName = input('', 's');
        if ~ismember(heartName, eventNames)
            fprintf('ERROR: The given event name: %s, does not exist as a marked event \n', heartName);
            status = 0;
            return
        end
    else
        %If there is only one event, assumes it is a heart beat mark
        heartName = eventNames{1};
    end
    
    %Identifies the latencies of the heartbeat's marks
    isHeart = strcmp(allEvents, heartName);
    if isfield(EEG.event, 'init_time')
        heartLatencies = [EEG.event(:).init_time];              %init_time is already in ms
    else
        heartLatencies = EEG.times([EEG.event(:).latency]);     %latency is in points, not ms
    end
    heartLatencies = heartLatencies(isHeart);
    
    %Creates the tacogram and plots it
    tacogram = diff(heartLatencies);
    figure, plot(tacogram), xlabel('Consecutive R peak'), ylabel('Interval RR (s)'), title('Tacogram (normal values 0.6-1.2s)');
    dim = [0.15 0 .3 .25];
    str = sprintf('Mean Heart Rate: \n %.1f Beats per sec', 60/mean(tacogram));
    annotation('textbox',dim,'String',str,'FitBoxToText','on');
    
        
    %Asks the user to check that the markings are in place, and that they make sense.
    disp('Please make sure that the markings make sense. If you are happy with the results, please press any key to continue');            
    disp('If the results were not the expected, please press q');
    
    
    step0ok = input('', 's');


    if strcmpi(step0ok, 'q')
        close all;
        %If the markings were not the expected, and the .set was taken from the original database, tell the user to contact the database owner
        fprintf('TIP: The original markings of subject %s are not accurate \n', subName);
        fprintf('Please contact the database owner for more help \n');
        status = 0;
        return

    else
        close all;
        %If everything is okay, simply copy the .set in the new step
        fprintf('Copying the .set in the Step0 path: %s \n', pathStep0);
        copyfile(fullfile(setPath, setName), fullfile(pathStep0, nameStep0));
    end


%If the .sets are not marked, mark them
else
    %Check if the subject has a event.tsv file
    if ~exist(fullfile(setPath, strcat(subName, '_', task, '_events.tsv')), 'file')
        fprintf('WARNING: There is not a %s file for subject %s \n', strcat(task, '_events.tsv'), subName);

        %If the subject does not have a .tsv, ask the user if wants to try to automatically create the .tsv using HEPLab
        disp('Do you want to automatically create the events per subject .tsv files? (y/n)');
        createTSVperPatient = input('', 's');
        if strcmpi(createTSVperPatient, 'y')
            if isempty(ECGchan)
                disp('Please enter the name of the channel that contains the ECG:');
                disp('If you do not know the name of the ECG channel, please type q, check it yourself, and run this script again');
                ECGchan = input('', 's');
                if strcmpi(ECGchan, 'q')
                    status = 0;
                    return
                end

                fprintf('Trying to extract the R peaks from the channel %s over the whole dataset \n', ECGchan);
                newECGchan = ECGchan;
            else
                fprintf('Trying to extract the R peaks from the channel %s over the whole dataset \n', ECGchan);
                newECGchan = ECGchan;
            end

            %Extracts the R peaks using HEPLab
            [status, HEP] = f_extractHEPfromECG(ECGchan, setPath, setName);

            %Checks that the previous function was correctly executed
            if status == 0
                disp('ERROR: Could not identify the R peaks using HEPLab');
                status = 0;
                return
            end

            %If everything is okay, create the table that will be saved as a tsv
            eventsTable = table();
            labels = cell(length(HEP.qrsMs), 1);
            labels(:) = {'Heart Beat'};
            eventsTable.TrialType = labels;
            eventsTable.Onset_ms = HEP.qrsMs;

            %And finally save the .tsv and the .mat
            writetable(eventsTable, fullfile(pathStep0, strcat(subName, '_', task, '_events.txt')), 'Delimiter', 'tab');
            movefile(fullfile(pathStep0, strcat(subName, '_', task, '_events.txt')), fullfile(pathStep0, strcat(subName, '_', task, '_events.tsv')));
            save(fullfile(pathStep0, strcat(HEP.savefilename, '.mat')), 'HEP');
        else
            disp('Please create the .tsv and .json events yourself and run this script again once you have done that');
            status = 0;
            return
        end

        %After the tsv is created, mark the corresponding .set and save it in newPath
        disp('The .tsv was succesfully created. Now those events will be added to the .set and saved in the specified path');
        EEG = pop_loadset('filename', setName, 'filepath', setPath);
        EEG = pop_importevent( EEG, 'event', fullfile(pathStep0, strcat(subName, '_', task, '_events.tsv')), ...
            'fields',{'type', 'latency'},'skipline',1,'append','no','timeunit',1/1000);       %1/1000 because the txt is in ms

        EEG = eeg_checkset(EEG);
        pop_saveset(EEG, 'filename', nameStep0, 'filepath', pathStep0);


    %If there already exists a .tsv file, try to load it to mark the events
    else
        %First, checks that the database has a corresponding task_events.json file
        if sum(strcmp(mainDirNames, strcat(task, '_events.json'))) == 0
            fprintf('ERROR: The subject %s has a %s_events.tsv file but does not have the general %s_events.json', subName, task, task);
            disp('The json is required to know the units of time of the events');
            disp('Please create the json and run this script again');
            status = 0;
            return
        end

        %Then, opens the task_events.json file, to know the units of time and the names of the columns of interest
        fid = fopen(fullfile(databasePath, strcat(task, '_events.json')));
        raw = fread(fid, inf);
        str = char(raw');
        fclose(fid);
        eventsInfo = jsondecode(str);
        eventsCols = fieldnames(eventsInfo);
        nCols = length(eventsCols);
        if nCols < 2
            disp('ERROR: The events.json file is expected to have at least 2 columns:');
            disp('The first two columns should be: TrialType; and Onset_ms or Onset_s');
            disp('Please correct it, make sure that the events.tsv of the subjects have the correct format, and run this script again');
            status = 0;
            return
        end
        
        %Looks for the columns of onset of event
        onsetColName = '';
        for j = 1:nCols         %Iterates over all the columns of the json to know the column names for onset
            if startsWith(eventsCols{j}, 'onset', 'IgnoreCase',true) || endsWith(eventsCols{j}, 'onset', 'IgnoreCase',true)
                onsetColName = eventsCols{j};
                break
            end
        end
        %If it could not find the onset's column, ask the user to identify it manually
        if isempty(onsetColName)
            disp('WARNING: Could not automatically find the ''onset'' column of the events');
            disp('Please open the events.tsv of the following path:');
            disp(fullfile(databasePath, strcat(task, '_events.tsv')));
            disp('And enter the number of the column that corresponds to the onset of the events');
            idxOnsetColName = input('', 's');
            idxOnsetColName = str2double(idxOnsetColName);
            
            %Defines the onset column name with the given column index
            if isempty(idxOnsetColName) || idxOnsetColName > nCols || idxOnsetColName < 0
                disp('ERROR: Please enter a valid number for the column that corresponds to the onset of the events');
                status = 0;
                return
            else
                onsetColName = eventsCols{idxOnsetColName};
            end
        end
        
        %Looks for the columns of 'value' of event
        typeColName = '';
        for j = 1:nCols         %Iterates over all the columns of the json to know the column names for value
            if startsWith(eventsCols{j}, 'value', 'IgnoreCase',true) || endsWith(eventsCols{j}, 'value', 'IgnoreCase',true)
                typeColName = eventsCols{j};
                break
            end
        end
        
        if isempty(typeColName)
            %Looks for columns of 'type' of event, if did not find any 'value'
            for j = 1:nCols         %Iterates over all the columns of the json to know the column names for value
                if startsWith(eventsCols{j}, 'type', 'IgnoreCase',true) || endsWith(eventsCols{j}, 'type', 'IgnoreCase',true)
                    typeColName = eventsCols{j};
                    break
                end
            end
            
            if isempty(typeColName) 
                %If it could not find the value's or type's column, ask the user to identify it manually
                disp('WARNING: Could not automatically find the ''value'' or ''type'' column of the events');
                disp('Please open the events.tsv of the following path:');
                disp(fullfile(databasePath, strcat(task, '_events.tsv')));
                disp('And enter the number of the column that corresponds to the value or type of the events');
                idxTypeColName = input('', 's');
                idxTypeColName = str2double(idxTypeColName);

                %Defines the value or type column name with the given column index
                if isempty(idxTypeColName) || idxTypeColName > nCols || idxTypeColName < 0 || ...
                        idxTypeColName == find(strcmp(eventsCols, onsetColName))
                    disp('ERROR: Please enter a valid number for the column that corresponds to the value or type of the events');
                    status = 0;
                    return
                else
                    typeColName = eventsCols{idxTypeColName};
                end
            end
            
        end
        
        
        %Defines if the events are given in s or ms
        if strcmpi(eventsInfo.(onsetColName).Units, 's') || strcmpi(eventsInfo.(onsetColName).Units, 'seconds')
            eventUnitsInS = 1;
        elseif strcmpi(eventsInfo.(onsetColName).Units, 'ms') || strcmpi(eventsInfo.(onsetColName).Units, 'miliseconds')
            eventUnitsInS = 1000;
        else
            disp('ERROR: Unknown units for the onset (should be "ms" or "s")');
            status = 0;
            return
        end

        %Creates a simplified version of the original events.tsv, with only the type and onset of the events (in that order)
        disp('Creating a simplified version of the original events.tsv, with only the type and onset of the events (in that order) in the specified path');
        copyfile(fullfile(setPath, strcat(subName, '_', task, '_events.tsv')), fullfile(pathStep0, strcat(subName, '_', task, '_events.txt')));
        originalT = readtable(fullfile(pathStep0, strcat(subName, '_', task, '_events.txt')), 'Delimiter', 'tab');
        typeIdx = strcmp(eventsCols, typeColName);
        newT = originalT(:, typeIdx);
        onsetIdx = strcmp(eventsCols, onsetColName);
        newT = [newT, originalT(:, onsetIdx)];
        
        %Saves the new table in the path of Step0 as a txt
        writetable(newT, fullfile(pathStep0, strcat(subName, '_', task, '_events.txt')), 'Delimiter', 'tab');
        movefile(fullfile(pathStep0, strcat(subName, '_', task, '_events.txt')), fullfile(pathStep0, strcat(subName, '_', task, '_events.tsv')));
        disp('The events of the .tsv file will be added to the .set and saved in the specified path');
        fieldsOrder = {'type', 'latency'};
        
        %After the json information is extracted, mark the corresponding .set and save it in newPath
        EEG = pop_loadset('filename', setName, 'filepath', setPath);
        EEG = pop_importevent( EEG, 'event', fullfile(pathStep0, strcat(subName, '_', task, '_events.tsv')), ...
            'fields',fieldsOrder,'skipline',1,'append','no','timeunit',1/eventUnitsInS);       %1/1000 if the txt is in ms. Otherwise 1
                
        EEG = eeg_checkset(EEG);
        pop_saveset(EEG, 'filename', nameStep0, 'filepath', pathStep0);
    end

    %Create a figure to scroll through the signal to make sure the signals make sense
    disp('Please make sure that the events of heartbeat were properly marked');
    Pix_SS = get(0,'screensize');           %Gets the screensize to avoid the figure obstructing the command line
    pop_eegplot( EEG, 1, 1, 1, [], 'position', [0 Pix_SS(4)*0.3 Pix_SS(3) Pix_SS(4)*0.62]);

    
    %And also creates a tacogram to make the quality control easier
    allEvents = {EEG.event(:).type};
    try         %Try finding the unique values as a cell (if there are strings)
        eventNames = unique(allEvents);
    catch       %If there are numbers, convert them into strings
        nAll = length(allEvents);
        for i = 1:nAll
            if isnumeric(allEvents{i})
                allEvents{i} = num2str(allEvents{i});
            end
        end
        eventNames = unique(allEvents);
    end
    
    if length(eventNames) > 1
        %If there is more than one event, asks the user to type the event name corresponding to heart beats
        disp('Please enter which of the following events correspond to the Heart Beat mark:');
        disp(eventNames);
        heartName = input('', 's');
        if ~ismember(heartName, eventNames)
            fprintf('ERROR: The given event name: %s, does not exist as a marked event', heartName);
            status = 0;
            return
        end
    else
        %If there is only one event, assumes it is a heart beat mark
        heartName = eventNames{1};
    end
    
    %Identifies the latencies of the heartbeat's marks
    isHeart = strcmp(allEvents, heartName);
    if isfield(EEG.event, 'init_time')
        heartLatencies = [EEG.event(:).init_time];              %init_time is already in ms
    else
        heartLatencies = EEG.times([EEG.event(:).latency]);     %latency is in points, not ms
    end
    heartLatencies = heartLatencies(isHeart);
    
    %Creates the tacogram and plots it
    tacogram = diff(heartLatencies);
    figure, plot(tacogram), xlabel('Consecutive R peak'), ylabel('Interval RR (s)'), title('Tacogram (normal values 0.6-1.2s)');
    dim = [0.15 0 .3 .25];
    str = sprintf('Mean Heart Rate: \n %.1f Beats per sec', 60/mean(tacogram));
    annotation('textbox',dim,'String',str,'FitBoxToText','on');
    
    
    %Asks the user to make sure that the events were properly marked
    disp('If you are happy with the results, please press any key to continue');
    disp('If the results were not the expected, please press q');
    
    step0ok = input('', 's');
    close all;

    %If the results were not the expected, deletes the created files, 
    %and offers the user some tips on how to improve the marking of the events
    if strcmpi(step0ok, 'q')
        fprintf('WARNING: The files for the step 0 of subject %s will be removed as the results were not the expected \n', subName);
        delete(fullfile(pathStep0, nameStep0));
        if exist(fullfile(pathStep0, strcat(nameStep0(1:end-3), 'fdt')), 'file')
            delete(fullfile(pathStep0, strcat(nameStep0(1:end-3), 'fdt')));
        end

        if ~isempty(dir(fullfile(pathStep0, '*.mat')))
            %If the bad results were obtained after running HEPLab, tell the user to try them themselves
            delete(fullfile(pathStep0, strcat(subName, '_', task, '_events.tsv')));
            delete(fullfile(pathStep0, strcat(HEP.savefilename, '.mat')));
            fprintf('TIP: Check the function f_extractHEPfromECG yourself for subject %s \n', subName);
            fprintf('The original file location is: %s \n', fullfile(setPath, setName));
            disp('Try to put the markings yourself, and then, save the results at:');
            fprintf('%s as %s \n', setPath, setName);
            status = 0;
            return

        else
            %If the bad results were obtained from the given .tsv, the database owner should be contacted
            fprintf('TIP: The original markings of subject %s are not accurate \n', subName);
            disp('Please contact the database owner for more help');
            status = 0;
            return

        end

    end
end

end