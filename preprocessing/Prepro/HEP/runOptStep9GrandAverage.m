%Script that runs the grand average on the already pre-processed data

%Path of the latest (8th) step
stepPath = 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat\analysis_BLINKER\Step8_BaselineRemoval';
modality = 'eeg';
task = 'rs-HEP';
databasePath = 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat';
groupType = {'Nationality', 'diagnostic'};     %groupType is a cell of [1, column]
groupName = {'Argentina', 'Chile'; 'CN', 'AD'}';             %groupName is a cell of [values, column]
% [status, EEGcell, EEGnames] = f_optStep9GrandAverage(stepPath, modality, task, databasePath, groupType, groupName);
[status, EEGcell, EEGnames] = f_optStep9GrandAverage(stepPath, modality, task);


%If everything was correctly executed, save it in the newPath
if status == 1
    %Moves one directory up
    pathParts = regexp(stepPath, filesep, 'split');
    mainPath = pathParts{1};
    for i = 2:length(pathParts) -1
        mainPath = fullfile(mainPath, pathParts{i});
    end
    
    %Defines the folder 'Step8_GrandAverage', one directory up the given step
    newPath = fullfile(mainPath, 'Step9_GrandAverage');
    if ~exist(newPath, 'dir')
        mkdir(newPath);
    end
    
    %Iterates over the different EEG structures averaged, and saves them
    for i = 1:length(EEGcell)
        newName = EEGnames{i};
        
        EEGcell{i}.setname = newName;
        pop_saveset(EEGcell{i}, 'filename', newName, 'filepath', newPath);
    end
else
    disp('ERROR: Could not complete the step of Grand Average');
end