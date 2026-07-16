%% Clear 
close
clear
clc

%% Set Paths
path_general = 'F:\Agus_sainz\Takeda';
group_name   = {'AD', 'CN', 'DF'};
addpath(genpath('F:\Agus_sainz\CODES\'))
addpath(genpath('F:\Agus_Sainz\Takeda\'))
%addpath(genpath('C:\AGUS_BIRBA\Proyectos\Takeda\DATA\Argentina\HEP\a14_Permutaciones'))

%% Functions
pais = 'Argentina'


%% Set country
% Argentina
if strcmp(pais,'Argentina')
nr_chan     = 128
ch_loc_file = 'path_ch_loc.mat'
% Chile
elseif strcmp(pais,'Chile')
nr_chan     = 128
ch_loc_file = 'path_ch_loc.mat'
% Colombia
%elseif strcmp(pais,'Colombia')
%nr_chan     = %no sabemos
%ch_loc_file = 'path_ch_loc.mat'

end

%% Levanto el set y meto las marcas
eeglab

% Run loop for all files in the specified condition group
for j = 1:size(group_name,2)
   
    S = dir((fullfile(path_general,pais,'\1_prepro\',group_name{j},'\*.set')));
    for i = 1%:length(S)
       
        a = fullfile(path_general,pais,'1_prepro\',group_name{j},'\');
        f = fullfile(path_general,pais,'2_hep\',group_name{j},'\');
        e = fullfile(path_general,pais,'2_hep\',group_name{j},'\Heplab_mat\');
        if ~exist(f,'dir')
            mkdir(f);
        end
        if ~exist(e,'dir')
            mkdir(e);
        end
       
        % Load .set files
        EEG = pop_loadset('filename',[S(i).name],'filepath',a);
       
        % Create condition for maximum time for each file (700ms), save
        % suspicious files in new array
        if EEG.xmax>700
        name_file  = ['check_file_',pais, '_', group_name{j},'.mat']
        check_file = [path_general,'\',pais,'\',name_file];    
             if exist(check_file)
        load(check_file,'name');
       
            else % initialize structure
        name=[]; % string indicating directory where data is saved for each subject
             end
        name(i)=S(i).name
        end
        
        % Resample
        EEG = pop_resample(EEG, 512);
        % Filter
        % Low filter
        EEG = pop_eegfiltnew(EEG, 'locutoff',0.5,'plotfreqz',0);
        EEG = eeg_checkset(EEG);
        % Upper filter
        EEG = pop_eegfiltnew(EEG, 'hicutoff',40, 'plotfreqz', 0);
        EEG = eeg_checkset(EEG);

         % Create loop for channel size
         for e     = nr_chan:size(EEG.data,1)
             % Calculate variance in channels
         var_ch(e) = var(EEG.data(e,:));
         end
         nchans_m  = find(var_ch==max(var_ch));
         nchans_c  = find(var_ch==max(var_ch(var_ch<max(var_ch))));
         % Save .set with staples
        [EEG]      = SR_a3_Heplab_metemarcas2(nchans_m,EEG, f, S, i,a,e);      
         EEG       = pop_saveset( EEG, 'filename',[S(i).name(1:end-4)],'filepath',f);
       
    end
end

%% Inspect Bad Channels
eeglab
% Run loop for each subject in condition group
for  j = 1%:3
    name_file            = ['subject_rating_file_',pais, '_', group_name{j},'.mat']
    subject_rating_file2 = [path_general,'\',pais,'\',name_file];
    % Load subjects rating file if they exist
    if exist(subject_rating_file2)
        load(subject_rating_file2,'subjectname','dataquality','bad_channels');
       
    else % initialize structure
        subjectname  = {}; % string indicating directory where data is saved for each subject
        dataquality  = []; % rating 0-2 for each of M eeg files for each subject
        bad_channels = {}; % list of bad channels for each eeg file M * # of subjects
    end
    
    S=dir((fullfile(path_general,pais,'\2_hep',group_name{j},'\*.set')));
       
    % Create iteration for length of bad_channel files, save until last run
    % file
    for i =(size(bad_channels,2)+1): length(S)
        disp(i)
        a = fullfile(path_general,pais,'\2_hep',group_name{j},'\')
        [subjectname, bad_channels, dataquality] = channel_rejection_4(j,a,S,i,subjectname, dataquality,bad_channels,nr_chan);
   save(subject_rating_file2,'subjectname','bad_channels','dataquality');
    end
           
   
end


%% ICA
% Create iteration to load subjects
for j = 3
        S = dir((fullfile(path_general,pais,'\2_hep\', group_name{j},'*.set')))
        for i = 1: length(S)
            % Load path
            a = fullfile(path_general,pais,'\2_hep\',group_name{j},'\')
            % Save Path
            f = fullfile(path_general,pais,'\3_ica\',group_name{j},'\')
            eeglab
            %Load subjects in iteration
            EEG = pop_loadset('filename',[S(i).name],'filepath',a)
            if ~exist(f,'dir')
            mkdir(f);
            end
           
name_file        = ['subject_rating_file2_',group_name{j},'.mat']
load(name_file)
% ICA functions
chan_ica         = 1:128;
bad_ch           = bad_channels{j,i}
chan_ica(bad_ch) = []

% Run ICA
EEG = pop_runica(EEG, 'chanind', chan_ica , 'extended',1,'interupt','off');
EEG = eeg_checkset(EEG);

EEG = pop_saveset(EEG,'filename',[S(i).name],'filepath',f);


        end
end

%% Components
% Create iteration with paths
for j = 2
        S = dir((fullfile(path_general,pais,'\3_ica\', group_name{j},'*.set')))
        for i = 1: length(S)
           % Load Path
            a = fullfile(path_general,pais,'\3_ica\',group_name{j},'\')
            % Save Path
            f = fullfile(path_general,pais,'\4_comp\',group_name{j},'\')
            eeglab
            EEG = pop_loadset('filename',[S(i).name],'filepath',a)
            if ~exist(f,'dir')
            mkdir(f);
            end
EEG                           = pop_iclabel(EEG, 'default');
comp_rej_corazon              = find(EEG.etc.ic_classification.ICLabel.classifications(:,4)>0.85)
comp_rej_ojos                 = find(EEG.etc.ic_classification.ICLabel.classifications(:,3)>0.85)
comp_rej                      = [comp_rej_corazon, comp_rej_ojos']
delete_componentes.heart{1,i} = comp_rej_corazon
delete_componentes.eyes{1,i}  = comp_rej_ojos

EEG = pop_subcomp(EEG, comp_rej, 0);

EEG = eeg_checkset(EEG);

EEG = pop_saveset(EEG,'filename',[S(i).name],'filepath',f);
        end
        
name_file = ['Components_',group_name{j},'.mat']
 save([path_general,pais, name_file],'delete_componentes');

end


%% Interpolo canales feos

eeglab
for  j = 1:3
    S=dir((fullfile(path_general,pais,'\4_comp',group_name{j},'\*.set')));
    load((fullfile(path_general,pais,['subject_rating_file2_',group_name{j}, '.mat' ])))
    for i =1: length(S)
        a=fullfile(path_general,pais,'\4_comp',group_name{j});
        f=fullfile(path_general,pais,'\5_int',group_name{j});
        EEG = pop_loadset('filename',[S(i).name],'filepath',a);
        if ~exist(f,'dir')
            mkdir(f);
        end
        EEG = pop_loadset('filename',[S(i).name],'filepath',a);
        if any(bad_channels{j,i}>128)
            del_ch=find(bad_channels{j,i}>128)
            bad_channels{j,i}(:,del_ch) = [];
        else
        end
       
        EEG = pop_interp(EEG, bad_channels{j,i}, 'spherical');
        EEG = pop_saveset( EEG, 'filename',[S(i).name],'filepath',f);
        EEG = eeg_checkset( EEG );
    end
    clear i
end
%% selecciono las épocas

eeglab
for  j = 1:3
    S=dir((fullfile(path_general,pais,'\5_int',group_name{j},'\*.set')));
    for i =1: length(S)
        a=fullfile(path_general,pais,'\5_int',group_name{j});
        f=fullfile(path_general,pais,'\6_epoch',group_name{j});
        EEG = pop_loadset('filename',[S(i).name],'filepath',a);
        if ~exist(f,'dir')
            mkdir(f);
        end
        EEG = pop_loadset('filename',[S(i).name],'filepath',a);
        EEG = pop_epoch( EEG, {  '666'  }, [-0.3           0.8], 'epochinfo', 'yes');
        EEG = pop_saveset( EEG, 'filename',[S(i).name],'filepath',f);
        EEG = eeg_checkset( EEG );
       
    end
end

%% Funciones de "Rej data Epochs"

eeglab
% Cell to save info
chan_imp = [1:128];
chan_SD  = 2.5;


for  j = 1
    S=dir((fullfile(path_general,pais,'\6_epoch',group_name{j},'\*.set')))
    info_epoch{1,1} = 'suj';
    info_epoch{1,2} = 'Grupo';
    info_epoch{1,3} = 'cant_tot_epoch';
    info_epoch{1,4} = 'num_rej_events';
    info_epoch{1,5} = 'perc_rej_epoch';
   
    for i =1: length(S)
        a=fullfile(path_general,pais,'\6_epoch',group_name{j})
        f=fullfile(path_general,pais,'\7bis_cleanepochs',group_name{j})
       
        EEG = pop_loadset('filename',[S(i).name],'filepath',a)
        if ~exist(f,'dir')
            mkdir(f);
        end
        EEG = pop_loadset('filename',[S(i).name],'filepath',a);
        % Marca las epoch con electrodos o trials que se salgan a mas de X SD
        % haciendo probabilidad
        EEG = pop_jointprob(EEG,1,chan_imp , chan_SD, chan_SD,0,0);
        %EEG = eeg_checkset( EEG );
        %
        %                             % Marca las epoch con electrodos o trials que se salgan a mas de X SD
        %                             % haciendo kurtosis
        EEG = pop_rejkurt(EEG,1,chan_imp ,chan_SD,chan_SD,0,0);
        %EEG = eeg_checkset( EEG );
        %
        %             % Use every reject possible (kurtosis and jp wont run again)
                                    EEG = eeg_rejsuperpose( EEG, 1, 1, 1, 1, 1, 0, 1, 1);
                                    EEG = eeg_checkset( EEG );
       
        %% Conteo de epoch
        % Busca los numeros de los eventos a rechazar
        num_rej_events = [find(EEG.reject.rejjp), find(EEG.reject.rejkurt)] ;
       
        % Cantidad de trails totales
        cant_tot_epoch = length(EEG.epoch);
       
        % Cantidad de trails sacados
        cant_rej_events = size(num_rej_events,2);
       
        % Percentage
        perc_rej_epoch  = cant_rej_events*100/cant_tot_epoch;
       
        %% Rechazo de epocas marcadas
        EEG = pop_rejepoch( EEG, num_rej_events ,0);
       
        %% Save info in Structure
        k = size(info_epoch,1)+1;
        info_epoch{k,1} = S(i).name(1:end-4);
        info_epoch{k,2} = group_name{j};
        info_epoch{k,3} = cant_tot_epoch;
        info_epoch{k,4} = num_rej_events;
        info_epoch{k,5} = perc_rej_epoch;
       
        % Saveset
        EEG = pop_saveset( EEG, 'filename',[S(i).name],'filepath',f);
        EEG = eeg_checkset( EEG );
    end
    % Save Info struct
    cd(f)
    save(['EpochRemovalInfo_',group_name{j}], 'info_epoch')
    clear info_epoch
end

%% Baseline


eeglab
for  j = 1
    S=dir((fullfile(path_general,pais,'\8bis_detrend',group_name{j},'\*.set')));
    for i =1: length(S)
        a=fullfile(path_general,pais,'\8bis_detrend',group_name{j});
        f=fullfile(path_general,pais,'\9bis_baseline',group_name{j});
        EEG = pop_loadset('filename',[S(i).name],'filepath',a);
        if ~exist(f,'dir')
            mkdir(f);
        end
        EEG = pop_loadset('filename',[S(i).name],'filepath',a);
        EEG = pop_rmbase( EEG, [-300 0] ,[]);;
        EEG = pop_saveset( EEG, 'filename',[S(i).name],'filepath',f);
        EEG = eeg_checkset( EEG );
        
    end
end