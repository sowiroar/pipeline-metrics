% run_prepro_test.m - Test preprocessing for all subjects
% Run this from the preprocessing folder:
% >> cd('c:\Users\eguen\Documents\Githubs-Redlat\A_Pipeline_Metricas\pipeline-metrics\preprocessing')
% >> run_prepro_test

more off;  % Disable pagination

%% 1. Initialize EEGLAB (nogui mode)
eeglab_dir = 'C:/Users/eguen/AppData/Roaming/MathWorks/MATLAB Add-Ons/Collections/EEGLAB';
addpath(eeglab_dir);
eeglab nogui;

%% 2. Install clean_rawdata if missing (just try to install, it will skip if already present)
if ~exist('clean_asr', 'file')
    disp('Installing clean_rawdata plugin...');
    plugin_askinstall('clean_rawdata', [], true);
    eeglab nogui;
end

%% 3. Initialize FieldTrip
fieldtrip_path = 'C:/Users/eguen/AppData/Roaming/MathWorks/MATLAB Add-Ons/Collections/FieldTrip/ft_defaults.m';
run(fieldtrip_path);

%% 4. Set database path and run preprocessing
currentPath = mfilename('fullpath');
[currentDir, ~, ~] = fileparts(currentPath);
databasePath = fullfile(currentDir, '..', '..', '2_prepro_analysis_brainlat');

disp('=== STARTING PREPROCESSING ===');
disp(['Database: ' databasePath]);

% Delete partial Step1 output so it starts fresh
step1_dir = fullfile(databasePath, 'analysis_RS', 'Preprocessing', 'Step1_BadChansIdentification');
if exist(step1_dir, 'dir')
    rmdir(step1_dir, 's');
    disp('Cleaned up partial Step1');
end

% Run full preprocessing
f_mainPipeline(databasePath, 'signalType', 'RS', 'runPrepro', true, 'runSpatialNorm', false, ...
    'runChansToSource', false, 'runSourceAvgROI', false, ...
    'runPatientControlNorm', false, 'runClassifier', false, ...
    'newPath', fullfile(databasePath, 'analysis_RS_test'), ...
    'finalNormStepPath', fullfile(databasePath, 'analysis_RS', 'Normalization', 'Step2_PatientControlNorm'));

disp('=== PREPROCESSING COMPLETED SUCCESSFULLY ===');
