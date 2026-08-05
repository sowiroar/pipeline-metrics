function main_frecuency()
    % main_frecuency - Unified script to extract frequency metrics across stages.
    % Reads configuration from ../config/config.json relative to script location.

    % Add script folder to MATLAB path
    script_dir = fileparts(mfilename('fullpath'));
    addpath(script_dir);

    % Load configuration
    config_path = fullfile(script_dir, '..', 'config', 'config.json');
    if ~exist(config_path, 'file')
        error('Configuration file not found at: %s', config_path);
    end
    config_text = fileread(config_path);
    config = jsondecode(config_text);

    % Resolve database_root and output_root relative to config.json if they are relative paths
    [config_dir, ~, ~] = fileparts(config_path);
    if isempty(regexp(config.database_root, '^([a-zA-Z]:[/\\]|/|\\\\)', 'once'))
        config.database_root = fullfile(config_dir, config.database_root);
    end
    if isempty(regexp(config.output_root, '^([a-zA-Z]:[/\\]|/|\\\\)', 'once'))
        config.output_root = fullfile(config_dir, config.output_root);
    end

    % Load EEGLAB if specified
    if isfield(config, 'eeglab_path') && ~isempty(config.eeglab_path)
        try
            run(config.eeglab_path);
            close all;
        catch ME
            warning('Failed to load EEGLAB from specified path: %s. Error: %s', config.eeglab_path, ME.message);
        end
    end

    % Set default fs if not present
    if isfield(config, 'fs')
        fs_default = config.fs;
    else
        fs_default = 512;
    end

    % Loop through countries and stages
    for c_idx = 1:length(config.countries)
        country = config.countries{c_idx};
        
        for s_idx = 1:length(config.stages)
            stage = config.stages{s_idx};
            fprintf('Processing Country: %s, Stage: %s\n', country, stage);
            
            % Read participants.tsv
            participants_path = fullfile(config.database_root, country, 'participants.tsv');
            if ~exist(participants_path, 'file')
                warning('participants.tsv not found at %s. Skipping...', participants_path);
                continue;
            end
            
            subjects_table = readtable(participants_path, 'FileType', 'text', 'Delimiter', '\t');
            subject_id_column = subjects_table.subject_id;
            
            PSD_struct = struct;
            T = table;
            
            for i = 1:numel(subject_id_column)
                subject_id = subject_id_column{i};
                subject_id_padded = sprintf('%-*s', 11, subject_id);
                fprintf('  Subject %d/%d: %s\n', i, numel(subject_id_column), subject_id);
                
                % Determine path and loading logic based on stage
                try
                    eegSignal = [];
                    fs = fs_default;
                    
                    switch stage
                        case 'Preprocessing'
                            path2file = fullfile(config.database_root, country, 'analysis_RS', 'Preprocessing', 'Step6_BadChanInterpolation', strrep(subject_id,' ',''), 'eeg');
                            archivos = dir(fullfile(path2file, '*eeg.set'));
                            if isempty(archivos)
                                archivos = dir(fullfile(path2file, '*eeg.txt'));
                                filename = archivos.name;
                                eegSignal = dlmread(fullfile(path2file, filename));
                            else
                                filename = archivos.name;
                                eeg_ftd = pop_loadset(filename, path2file);
                                eegSignal = eeg_ftd.data;
                                fs = eeg_ftd.srate;
                            end
                            
                        case 'Normalization'
                            % Try Step2_PatientControlNorm
                            path2file = fullfile(config.database_root, country, 'analysis_RS', 'Normalization', 'Step2_PatientControlNorm', strrep(subject_id,' ',''), 'eeg');
                            archivos = dir(fullfile(path2file, '*eeg.set'));
                            if isempty(archivos)
                                archivos = dir(fullfile(path2file, '*eeg.txt'));
                                filename = archivos.name;
                                eegSignal = dlmread(fullfile(path2file, filename));
                            else
                                filename = archivos.name;
                                eeg_ftd = pop_loadset(filename, path2file);
                                eegSignal = eeg_ftd.data;
                                fs = eeg_ftd.srate;
                            end
                            
                        case 'SourceTransformation'
                            path2file = fullfile(config.database_root, country, 'analysis_RS', 'SourceTransformation', 'Step2_SourceAvgROI', strrep(subject_id,' ',''), 'eeg');
                            archivos = dir(fullfile(path2file, '*eeg.mat'));
                            if ~isempty(archivos)
                                EEG_struct = load(fullfile(path2file, archivos.name));
                                eegSignal = EEG_struct.EEG_like.data;
                            else
                                archivos = dir(fullfile(path2file, '*eeg.txt'));
                                if ~isempty(archivos)
                                    eegSignal = dlmread(fullfile(path2file, archivos.name));
                                    eegSignal = eegSignal'; % transpose if txt
                                end
                            end
                            
                        case 'SourceNoNormalizedTransformation'
                            path2file = fullfile(config.database_root, country, 'analysis_RS', 'SourceNoNormalizedTransformation');
                            archivos = dir(fullfile(path2file, ['*' strrep(subject_id,' ','') '_*Rois.txt']));
                            if ~isempty(archivos)
                                archivos = archivos(1);
                                eegSignal = dlmread(fullfile(path2file, archivos.name));
                                eegSignal = eegSignal';
                            else
                                warning('    SourceNoNormalized file not found for subject %s', subject_id);
                                continue;
                            end
                            
                        otherwise
                            error('Unknown stage: %s', stage);
                    end
                    
                    if isempty(eegSignal)
                        warning('    Could not load EEG signal for subject %s', subject_id);
                        continue;
                    end
                    
                    % PSD calculation
                    [pxx, f] = frecuency_functions.PSD(eegSignal', fs, 0);
                    [pxx_n, f_n] = frecuency_functions.PSD(eegSignal', fs, 2); % PSD normalized
                    
                    struct_name = strrep(strrep(subject_id,' ',''), '-', '');
                    PSD_struct.(struct_name) = pxx;
                    PSD_struct.([struct_name '_norm']) = pxx_n;
                    PSD_struct.([struct_name '_f']) = f;
                    PSD_struct.([struct_name '_norm_f']) = f_n;
                    
                    % Compute IAF and TF
                    [IAF, TF] = frecuency_functions.compute_IAF_TF(pxx, f);
                    
                    % Define Bands
                    Freq_Bands = frecuency_functions.define_frequency_bands(IAF, TF);
                    
                    % Compute metrics
                    Frec_metrics = frecuency_functions.compute_PSD_metrics(pxx_n, f_n, Freq_Bands, IAF, TF);
                    
                    % Create subject table row
                    T_subj = frecuency_functions.compute_frec_table(Frec_metrics, subject_id_padded);
                    T = [T; T_subj];
                    
                catch ME
                    warning('  Error processing subject %s: %s', subject_id, ME.message);
                end
            end
            
            % Save outputs
            featDir = fullfile(config.output_root, country, stage);
            if ~exist(featDir, 'dir')
                mkdir(featDir);
            end
            
            output_csv = fullfile(featDir, sprintf('%s_%s_%s_Frecuency_metrics.csv', country, stage, config.subject_class));
            output_mat = fullfile(featDir, sprintf('%s_%s_%s_PSD_struct.mat', country, stage, config.subject_class));
            
            writetable(T, output_csv);
            save(output_mat, 'PSD_struct');
            fprintf('  Saved frequency metrics to: %s\n', output_csv);
        end
    end
    disp('Frequency metrics extraction finished successfully.');
end
