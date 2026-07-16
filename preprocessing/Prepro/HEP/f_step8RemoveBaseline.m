function [status, EEG, newBaselineRange] = f_step8RemoveBaseline(pathStep7, nameStep7, baselineRange)
%Description:
%Function that removes the baseline of the given dataset
%INPUTS:
%pathStep7 = Path of the .set with noisy epochs already removed
%nameStep7 = Name of the .set with noisy epochs already removed
%baselineRange = Vector of [2,1] with the times [start, end] (in seconds) considered as baseline
%   [mostNegativePoint, 0] by default
%OUTPUTS:
%status = 1 if this script was completed succesfully. 0 otherwise
%EEG = EEGLab structure after removing the baseline
%newBaselineRange = Vector of [2,1] with the times [start, end] (in seconds) that was actually considered as baseline

status = 1;

%Defines the default baseline
if nargin < 3
    baselineRange = [];
end
newBaselineRange = baselineRange;

%Loads the given .set
EEG = pop_loadset('filename', nameStep7, 'filepath', pathStep7);

%If the baseline is not given, tries to define it as the most negative point, up to 0
if isempty(baselineRange)
    if EEG.xmin < 0
        baselineRange = [EEG.xmin, 0];
        
    else
        %If the first point is not negative, asks the user to enter the baseline interval
        disp('Please enter the range of time (in seconds) considered as baseline');
        fprintf('TIP: Must be between %.2f and %.2f \n', EEG.xmin, EEG.xmax);
        disp('Please enter the lower bound of the time range (in seconds, as a number and decimals separated by .):');
        lowerBound = input('', 's');
        
        %Considers the case in which the user does not provide a valid input
        lowerBound = str2double(lowerBound);
        if isnan(lowerBound)
            disp('ERROR: Please enter a number, with decimals separated by point');
            disp('Do you want to try running this script again? (y/n)');
            runAgain = input('', 's');
            if strcmpi(runAgain, 'y')
                [status, EEG, newBaselineRange] = f_step8RemoveBaseline(pathStep7, nameStep7, baselineRange);
            else
                status = 0;
            end
            return
        end
        
        disp('Please enter the higher bound of the time range (in seconds, as a number and decimals separated by .):');
        higherBound = input('', 's');
        %Considers the case in which the user does not provide a valid input
        higherBound = str2double(higherBound);
        if isnan(higherBound) || higherBound <= lowerBound
            disp(strcat('ERROR: Please enter a number, with decimals separated by point AND greater than: ', num2str(lowerBound)));
            disp('Do you want to try running this script again? (y/n)');
            runAgain = input('', 's');
            if strcmpi(runAgain, 'y')
                [status, EEG, newBaselineRange] = f_step8RemoveBaseline(pathStep7, nameStep7, baselineRange);
            else
                status = 0;
            end
            return
        end
        
        %Finally, define the given outputs as the baselineRange vector
        baselineRange = [lowerBound, higherBound];
    end
    
end

%Updates the newBaselineRange
newBaselineRange = baselineRange;

%Removes the baseline
EEG = pop_rmbase( EEG, baselineRange ,[]);
EEG = eeg_checkset(EEG);

end