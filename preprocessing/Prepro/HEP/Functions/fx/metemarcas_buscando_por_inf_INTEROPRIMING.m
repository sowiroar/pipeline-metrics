%% Script to find cardiac signals from EKG
%
% Input: EEG set with EKG electrode
% Output:set with marks over R peak in EEG.

% Functions used:
% peak_detection
% Peakfinder
% BuscarIntervaloMarcas

%% (1) CONFIGURATION
%clear all
%clc
%restoredefaultpath

%% (2) DIRECTIONS
% path eeglab
eeglab

% path funciones
addpath(genpath('F:\Paula\Intero_priming_fondecyt\Scripts_fondecyt\Scripts_prepro_interopriming\'));


%% (2.b) DATASET CONFIGURACION
 
Gru='PD'; % Group name
pais='CHI'; %Country name 

% bdfs path
% cfg.pathset=['F:\Paula\Intero_priming_fondecyt\EEG_analisis_',pais,'\',Gru,'\a3_Marc_E\'];
% cfg.pathMarc=['F:\Paula\Intero_priming_fondecyt\EEG_analisis_',pais,'\',Gru,'\a3_Marc_EyC\'];
% 
cfg.pathset=['F:\Paula\Intero_priming_fondecyt\EEG_analisis_',pais,'_new\',Gru,'\a3_Marc_E\'];
cfg.pathMarc=['F:\Paula\Intero_priming_fondecyt\EEG_analisis_',pais,'_new\',Gru,'\a3_Marc_EyC\'];

cd(cfg.pathset)
suj_aux=dir('*.set')

for suj=1%:length(suj_aux)
    %% Pre load info
    suj_aux2=(suj_aux(suj).name);
    S=suj_aux2(1:4);

 
%% EEGLAB
    eeglab;
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    EEG = pop_loadset('filename',suj_aux2,'filepath',cfg.pathset);
    [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
    eeglab redraw;
    
    %% corazon y umbrales
    corazon=EEG.data(132,:);%129
    figure
    plot(corazon)
    umbral_inf=input('Ingrese umbral para picos inferiores:');
    umbral_sup=input('Ingrese umbral para picos superiores:');
    close

    [sub_picos_superiores] = buscar_picos_cercanos_a_inferiores(corazon, umbral_inf, umbral_sup, 1/5);

%% Check point    
        figure
        plot(corazon)
        hold on
        plot(sub_picos_superiores,corazon(sub_picos_superiores), 'or')
        
        Check_point_1=input('Estan bien puestas las marcas?...(1=SI / Ctrl+C para interrumpir)');
        clear Check_point_1
    
%% Iteracion por la cantidad de picos
    for i= 1:length(sub_picos_superiores)
            HBTP{i,2}= sub_picos_superiores(i)/EEG.srate;   
    end

    
%% Create .txt file to print info in, num2str(cur_subject)
    transposed = HBTP;%eventos;
    typelatency = transposed (:,[1:2]); %select the first two columns
    nr_lines = length(typelatency); %defining length(lines) of typelatency file
    archivo_txt = fullfile(cfg.pathMarc, 'markers_reposo.txt');
    fid = fopen(archivo_txt, 'w'); 
    % cd(suj_dir)
    for j = 1:nr_lines; %loop for copying each line of the typelatency file in the .txt file
        fprintf(fid, '%s\t%d\n', typelatency{j,1}, typelatency{j,2});
    end % j typelatency
    fclose(fid); %close the marker file
    
%% Imports the markers
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    EEG = pop_loadset('filename',suj_aux2,'filepath',cfg.pathset);
    [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );

    EEG = pop_importevent( EEG, 'event',archivo_txt,'fields',{'type' 'latency'},'skipline',1,'timeunit',1);
    [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    EEG = eeg_checkset( EEG );
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 3,'savenew',fullfile([cfg.pathMarc,S,'_Marc']),'gui','off'); 

    eeglab redraw;  
    % clear all
    
    cd(cfg.pathMarc)

end

disp('Finished :) ')