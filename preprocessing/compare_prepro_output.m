% Script to compare the original validation output with the new pipeline output for ALL subjects
clear all; close all; clc;

% Initialize EEGLAB (nogui mode)
eeglab_dir = 'C:/Users/eguen/AppData/Roaming/MathWorks/MATLAB Add-Ons/Collections/EEGLAB';
addpath(eeglab_dir);
eeglab nogui;

disp('========================================================================');
disp('COMPARING STEP 6 OUTPUTS: ORIGINAL VALIDATION VS NEW PIPELINE');
disp('========================================================================');

databasePath = 'C:\Users\eguen\Documents\Githubs-Redlat\A_Pipeline_Metricas\2_prepro_analysis_brainlat';
orig_base = fullfile(databasePath, 'analysis_RS', 'Preprocessing', 'Step6_BadChanInterpolation');
new_base = fullfile(databasePath, 'analysis_RS_test', 'Preprocessing', 'Step6_BadChanInterpolation');

% Get all sub- folders
sub_dirs = dir(fullfile(orig_base, 'sub-*'));

results = {};

for i = 1:length(sub_dirs)
    sub_name = sub_dirs(i).name;
    fprintf('\n---> Processing %s (%d/%d) \n', sub_name, i, length(sub_dirs));
    
    filename = ['s6_' sub_name '_rs-HEP_eeg.set'];
    orig_file = fullfile(orig_base, sub_name, 'eeg', filename);
    new_file = fullfile(new_base, sub_name, 'eeg', filename);
    
    if ~exist(new_file, 'file')
        disp(['ERROR: New output file does not exist for ' sub_name]);
        continue;
    end
    
    try
        EEG_orig = pop_loadset('filename', filename, 'filepath', fullfile(orig_base, sub_name, 'eeg'));
        EEG_new = pop_loadset('filename', filename, 'filepath', fullfile(new_base, sub_name, 'eeg'));
        
        if size(EEG_orig.data) == size(EEG_new.data)
            diff_data = double(EEG_orig.data) - double(EEG_new.data);
            max_diff = max(abs(diff_data(:)));
            mean_diff = mean(abs(diff_data(:)));
            
            fprintf('Max Diff: %g, Mean Diff: %g\n', max_diff, mean_diff);
            
            if max_diff < 1e-5
                status = 'IDENTICAL';
            else
                status = 'DIFFERENT (Random Seeds)';
            end
            results{end+1} = struct('Subject', sub_name, 'Status', status, 'MaxDiff', max_diff, 'MeanDiff', mean_diff);
        else
            fprintf('ERROR: Data dimensions mismatch. Orig: [%d %d], New: [%d %d]\n', size(EEG_orig.data), size(EEG_new.data));
            results{end+1} = struct('Subject', sub_name, 'Status', 'DIM_MISMATCH', 'MaxDiff', NaN, 'MeanDiff', NaN);
        end
    catch ME
        disp(['ERROR loading ' sub_name ': ' ME.message]);
        results{end+1} = struct('Subject', sub_name, 'Status', 'ERROR', 'MaxDiff', NaN, 'MeanDiff', NaN);
    end
end

disp('========================================================================');
disp('SUMMARY REPORT');
disp('========================================================================');
for i = 1:length(results)
    fprintf('%s | %s | Max Diff: %.4f | Mean Diff: %.4f\n', results{i}.Subject, results{i}.Status, results{i}.MaxDiff, results{i}.MeanDiff);
end
disp('========================================================================');
