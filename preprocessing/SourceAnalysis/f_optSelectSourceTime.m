function [status, EEG, newSelectSourceTime] = f_optSelectSourceTime(setPath, setName, selectSourceTime, avgSourceTime)
%Description:
%Function that performs the modification of the signals in time before transforming them to a source level
%INPUTS:
%setPath            = Path of the .set that the user wants to modify in time before transforming to a source level
%setName            = Name of the .set that the user wants to modify in time before transforming to a source level
%selectSourceTime   = Vector of [1,2] with the time window in seconds that the user wants to transform to a source level 
%                   [timeBeg, timeEnd]. (empty by Default)
%avgSourceTime      = Boolean. True if the user wants to average the selected time window. False otherwise (false by default)
%OUTPUTS:
%status             = 1 if the script was completed succesfully. 0 otherwise
%EEG                = EEGLab structure after performing the modification of the signals in time
%newSelectSourceTime= Vector of [1,2] with the time window in seconds ACTUALLY USED to transform to a source level 
%Author: Jhony Mejia


%Defaults the default inputs
if nargin < 3
    selectSourceTime = [];
end
if nargin < 4
    avgSourceTime = false;
end

%Defines the default outputs
status = 0;
EEG = [];
newSelectSourceTime = selectSourceTime;


%Verifies that the selectSourceTime has valid inputs
if isempty(selectSourceTime) || length(selectSourceTime) ~= 2
    disp('WARNING: selectSourceTime must be a vector of [1,2] with the [beggining, end] of the time window (in seconds) to be source transformed');
    
    disp('Please enter the range of time in seconds (can be negative, relative to the time-locked event)');
    disp('Please enter the lower bound of the time range (in seconds, as a number and decimals separated by .):');
    lowerBound = input('', 's');

    %Considers the case in which the user does not provide a valid input
    lowerBound = str2double(lowerBound);
    if isnan(lowerBound)
        disp('ERROR: Please enter a number, with decimals separated by point');
        disp('Do you want to try running this script again? (y/n)');
        runAgain = input('', 's');
        if strcmpi(runAgain, 'y')
            [status, EEG, newSelectSourceTime] = f_optSelectSourceTime(setPath, setName, selectSourceTime, avgSourceTime);
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
            [status, EEG, newSelectSourceTime] = f_optSelectSourceTime(setPath, setName, selectSourceTime, avgSourceTime);
        else
            status = 0;
        end
        return
    end

    %Finally, define the given outputs as the selectSourceTime vector
    newSelectSourceTime = [lowerBound, higherBound];
end


%If everything is okay, give the user a warning about selecting subsets of time
disp('WARNING: The optional selection in time before source transformation can be useful to speed up the process');
disp('However, it is recommended to be used ONLY in task-based analyses');


%Loads the .set
EEG = pop_loadset('filename', setName, 'filepath', setPath);

%Checks that the .set has values in time inside the range defined by newSelectSourceTime
if newSelectSourceTime(1) < EEG.xmin || newSelectSourceTime(2) > EEG.xmax
    fprintf('WARNING: The range defined by selectSourceTime ([%.3f, %.3f]) is outside the time of the .set ([%.3f, %.3f])\n', ...
        newSelectSourceTime(1), newSelectSourceTime(2), EEG.xmin, EEG.xmax);
    disp('Please enter "y" if you want to enter the selectSourceTime parameter again, or any other key to quit');
    runAgain = input('', 's');
    if strcmpi(runAgain, 'y')
    	[status, EEG, newSelectSourceTime] = f_optSelectSourceTime(setPath, setName, [], avgSourceTime);
    end
    return
end


%Defines the points that should be kept
disp('Performing selection of time before computing the source transformation');
fprintf('ONLY the data between %.3f and %.3f will be kept\n', newSelectSourceTime);
EEG = pop_select(EEG, 'time', newSelectSourceTime);

%If an averaging is desired, perform it (keep the times field as the lower bound)
if avgSourceTime
    EEG.data = mean(EEG.data, 2);
    EEG.times = EEG.xmin*1000;      %*1000 because the times filed must be in ms
    EEG.pnts = 1;
    EEG.xmax = EEG.xmin;
end

%Clears ICA fields and event/urevent (if any)
EEG.icaact = [];
EEG.icawinv = [];
EEG.icasphere = [];
EEG.icaweights = [];
EEG.icachansind = [];
EEG.event = [];
EEG.urevent = [];
EEG = eeg_checkset(EEG);

%If it made it this far, the script was completed successfully
status = 1;

end