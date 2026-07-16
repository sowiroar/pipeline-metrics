%main%Reorders .mat files with the corresponding BIDS format

%Obtains the general path
%mainPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/Takeda_Alzheimer Disease (AD)_2/';
%mainPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/Omega_t2/';
mainPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/omega_new/Omega_/Omega_control_set/';

% Lista de los canales que deseas seleccionar
%canales_seleccionados = {'Fp1','Fp2','F7','F3','Fz','F4','F8','T7','C3','Cz','C4','T8','P7','P3','Pz',...
                         %'P4','P8','O1','O2','F9','F10'}  



%% Reorders the data of the given folders in the desired BIDS format
originalFolders = {'CN'};
nFolders = length(originalFolders);

%Iterates over the desired folders.
for i = 1:nFolders
    iPath = [fullfile(mainPath)];
    %iDir = dir(fullfile(iPath, '*.vhdr'));
     iDir = dir(fullfile(iPath, '*.set'));

    
    nSub = length(iDir);
    %Iterates over subjects within a folder
    for j = 1:nSub
        jName = iDir(j).name;
        [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
        %EEG = pop_loadset('filename',jName,'filepath','/home/jhc/Descargas/AD Peru/');
        %EEG = pop_readegi([mainPath, '/', jName]);
        EEG = pop_loadset('filename',jName,'filepath','//data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/omega_new/Omega_/Omega_control_set/');
        %EEG = pop_biosig([mainPath, '/', jName])
        %EEG = pop_loadcnt([mainPath, '/', jName]);
        %EEG = pop_loadbv('/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/Polonia2/', jName);% [1 661520], [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127]);
        % Selección de los canales de interés
        %EEG = pop_select(EEG, 'channel', canales_seleccionados);  % Aquí seleccionas los canales


       % Verificar si coilpos existe
        % if isfield(EEG.chanlocs, 'coilpos')
        %     disp('coilpos está presente');
        % else
        %     % Asigna coilpos manualmente si no está
        %     % Asignar coordenadas a coilpos
        %         for k = 1:length(EEG.chanlocs)
        %             if strcmp(EEG.chanlocs(k).type, 'megmag') || strcmp(EEG.chanlocs(k).type, 'megplanar')
        %                 EEG.chanlocs(k).coilpos = [EEG.chanlocs(k).X, EEG.chanlocs(k).Y, EEG.chanlocs(k).Z];
        %             end
        %         end
        % 
        %     % for k = 1:length(EEG.chanlocs)
        %     %     % Asegúrate de tener las coordenadas x, y, z
        %     %     EEG.chanlocs(k).coilpos = [x(k), y(k), z(k)]; % Asigna las coordenadas necesarias
        %     % end
        %     disp('coilpos asignado manualmente');
        % end



        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off'); 

        %EEG=pop_chanedit(EEG, 'save','/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/159_agus_peru.ced');
        %EEG = pop_loadbv([mainPath, jName]);%, [1 661520], [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127]);
%[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off'); 
%EEG = pop_loadbv('/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/Polonia2/', 'sub-01_task-rest_eeg.vhdr'
%EEG=pop_chanedit(EEG, 'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/72controlCarlos.ced','filetype','autodetect'});
   
%EEG=pop_chanedit(EEG, {'lookup','/home/jhc/Descargas/eeglab2023.1/plugins/dipfit/standard_BEM/elec/standard_1005.elc'},'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/karina.ced','filetype','autodetect'},'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/Data/Coordinates/256.xyz','filetype','autodetect'},'save','/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/karina.ced');


%%%%%%%%%%%MugreEEG=pop_chanedit(EEG, 'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/megg.ced','filetype','autodetect'});
%[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
        % Comprobar la longitud de los canales
        nChannels = size(EEG.data, 1); % Obtén el número de canales
        
        %if nChannels == 21
            % Cargar un archivo específico
            %EEG = pop_chanedit(EEG, 'load', {'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/meeg_321.ced', 'filetype', 'autodetect'});
        %else
            % Cargar otro archivo
            %EEG = pop_chanedit(EEG, 'load', {'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/lucia_28_09.ced', 'filetype', 'autodetect'});

%EEG=pop_chanedit(EEG, 'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/restingUsco64.ced','filetype','autodetect'});
%EEG=pop_chanedit(EEG, 'load',{'/users/gpb23120/Documents/DataPreproc/biosemi62_cuba.ced','filetype','autodetect'});
%EEG=pop_chanedit(EEG, 'lookup','/users/yqb22198/Documents/MATLAB/eeglab2022.1/plugins/dipfit/standard_BEM/elec/standard_1005.elc')
%EEG = pop_editset(EEG, 'run', [], 'chanlocs', '/users/yqb22198/Downloads/BioSemi_128eeg_8exg.sfp');
%EEG=pop_chanedit(EEG, 'changefield',{137,'theta',''},'changefield',{137,'radius',''},'changefield',{137,'X',''},'changefield',{137,'Y',''},'changefield',{137,'Z',''},'changefield',{137,'sph_theta',''},'changefield',{137,'sph_phi',''},'changefield',{137,'sph_radius',''},'changefield',{128,'theta',''},'changefield',{30,'radius',''},'changefield',{30,'X',''},'changefield',{30,'Y',''},'changefield',{30,'Z',''},'changefield',{30,'sph_theta',''},'changefield',{30,'sph_phi',''},'changefield',{30,'sph_radius',''},'changefield',{31,'theta',''},'changefield',{31,'radius',''},'changefield',{31,'X',''},'changefield',{31,'Y',''},'changefield',{31,'Z',''},'changefield',{31,'sph_theta',''},'changefield',{31,'sph_phi',''},'changefield',{31,'sph_radius',''},'changefield',{32,'theta',''},'changefield',{32,'radius',''},'changefield',{32,'X',''},'changefield',{32,'Y',''},'changefield',{32,'Z',''},'changefield',{32,'sph_theta',''},'changefield',{32,'sph_phi','¿'},'changefield',{32,'sph_radius',''});
%EEG=pop_chanedit(EEG, 'lookup','/users/yqb22198/Documents/MATLAB/eeglab2022.1/plugins/dipfit/standard_BEM/elec/standard_1005.elc');
%EEG=pop_chanedit(EEG, 'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/287_carlos_omega_grad.ced'});
%EEG=pop_chanedit(EEG, 'save','/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/64_sin_ext_noruega.ced');
%EEG=pop_chanedit(EEG, 'lookup','/users/yqb22198/Downloads/BioSemi_128eeg_8exg','filetype','autodetect'});
%EEG=pop_chanedit(EEG, 'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/264_2.ced','filetype','autodetect'});
%EEG=pop_chanedit(EEG, {'lookup','/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/eeglab2023.1/plugins/dipfit/standard_BEM/elec/standard_1005.elc'},'load',[],'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/128+8extbiosemi.ced','filetype','autodetect'});
EEG=pop_chanedit(EEG, 'load',{'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/285_omega.ced','filetype','autodetect'});

%EEG=pop_chanedit(EEG, 'load',{'/home/jhc/Descargas/sub-DCLSTIM001_ses-eeg_space-CapTrak_electrodes.tsv','filetype','autodetect'},'save','/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/DataPreproc/64_espana.ced');
[ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

        
        %Defines the new name of the file to be saved
        subName = jName(1:3);       %Names are given by: s###
        %if j < 10
        aux=0;
        aux=aux+j;
            %newName = strcat('sub-1', '000',  num2str(aux), '_rs_eeg.set');
        newName = strcat('sub-1', '000',  num2str(aux), '_rs_meg.set');

        %elseif j < 100
         %   newName = strcat('sub-', num2str(i), '00', num2str(j), '_rs-HEP_eeg.set');
        %else
            %newName = strcat('sub-2000', num2str(i), '0', num2str(j), '_rs-HEP_eeg.set');
        %end
        
        %Creates the new directory given a subject name
        newParts = strsplit(newName, '_');
        newDir = fullfile(mainPath, 'prepro_analysis', newParts{1}, 'meg');
        if ~isfolder(newDir)
            mkdir(newDir);
        end
        
        %In this case, takes the raw data and time, and passes it into an EEG-like structure
        %EEG = f_dataToEEG(jData.data, jData.time, newNam64chansudeae, newDir);
        %channel_name = [jName(1:13), 'ses-V01_task-protmap_channels.tsv']; 

        
        %dir_chan = fullfile(mainPath channel_name);
        %copyfile(fullfile(mainPath, channel_name), fullfile(newDir, channel_name));
 % Guardar el archivo .set
% Supongamos que EEG es tu estructura de datos
        % if isfield(EEG, 'chanlocs')
        %     % Eliminar los campos X, Y y Z
        %     EEG.chanlocs = rmfield(EEG.chanlocs, {'X', 'Y', 'Z'});
        % end

        EEG = pop_saveset(EEG, 'filename', newName, 'filepath', newDir);
        disp(['Archivo guardado como: ' fullfile(newDir, newName)]);



        
        archivo = fopen(fullfile(newDir, jName(1:end-4)), 'w');
        fclose(archivo);
        
        %save(fullfile(newDir, newName));

        %else
            %continue
       
    
    %end


    end
end