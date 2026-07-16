function [status, EEG] = f_optStep0FilterAndResample(setPath, setName, newSR, freqRange)
%Description:
%Optional function that filters and resamples the data
%INPUTS:
%setPath = Path of the .set that the user wants to filter and resample
%setName = Name of the .set that the user wants to filter and resample
%newSR = New sampling rate desired (512Hz by default)
%    NOTE: If it is empty, does not perform any resampling
%freqRange = Vector of [2, 1] with the range of frequencies [lowcut, highcut] that want to be kept ([0.5, 40]Hz by default)
%    NOTE: If it is empty, does not perform any filtering
%OUTPUTS:
%status = 1 if the script was completed succesfully. 0 otherwise
%EEG = EEGLab structure already resampled

%Defines default frequency range and new sampling rate
if nargin < 3    
    newSR = 512;
end
if nargin < 4
    freqRange = [0.5, 40];
end


%If filtering is desired, checks that a valid format was entered
if ~isempty(freqRange)
    %Checks that two inputs are given, and that the order is [low, high]
    if (length(freqRange)) ~= 2 || (freqRange(2) <= freqRange(1))
        disp('ERROR: Please enter freqRange as a vector of two values = [lowcut, highcut]');
        status = 0;
        return
    end
    %Checks that the inputs are greater than zero
    if sum(freqRange < 0) > 0
        disp('ERROR: Please enter freqRange as positive values = [lowcut, highcut]');
        status = 0;
        return
    end
end


status = 1;

%Loads the desired .set
EEG = pop_loadset('filename', setName, 'filepath', setPath);


%If any non-empty new campling rate value was given, resample the data
if ~isempty(newSR)
    %If the original sampling rate is less than the new one, inform the user that it is recommended to avoid resampling
    if EEG.srate < newSR
        fprintf('Your new Sampling rate = %dHz, is greater than your original Sampling rate = %dHz. Upsampling might create artifacts \n', newSR, EEG.srate);
        fprintf('It is recommended that you do not upsample your data. Instead, downsample the rest of your data to the current sampling rate = %d \n', EEG.srate);
        fprintf('To do so, run f_optStep1FilterAndResample(setPath, setName, %d), with the path and names of your whole dataset \n', EEG.srate);
        disp('Do you want to upsample your data anyway (y/n?)');
        upsampleData = input('', 's');
        if strcmpi(upsampleData, 'y')
            fprintf('Not upsampling, neither filtering the .set: %s \n', fullfile(setPath, setName));
            status = 0;
            return
        end
    end

    % Resample (if needed)
    if EEG.srate ~= newSR
        EEG = pop_resample(EEG, newSR);
    else
        fprintf('WARNING: Data is already at %dHz. No need to resample \n', newSR);
    end
    
else
    %If none re-sampling was performed, let the use know
    fprintf('WARNING: Not performing any resampling. Leaving the .set at %dHz\n', EEG.srate);
end


% Filter (if desired)
if ~isempty(freqRange)
    % Low filter
    EEG = pop_eegfiltnew(EEG, 'locutoff', freqRange(1),'plotfreqz',0);
    EEG = eeg_checkset(EEG);

    % Upper filter
    EEG = pop_eegfiltnew(EEG, 'hicutoff', freqRange(2), 'plotfreqz', 0);
    EEG = eeg_checkset(EEG);
else
    disp('WARNING: Note performing ANY filtering');
    disp('WARNING: It is highly recommended that you perform filtering before continuing');
end


end