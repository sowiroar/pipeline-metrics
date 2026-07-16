function [status, EEG, newEventName] = f_step6DefineEpochs(pathStep5, nameStep5, epochRange, heartEventName)
%Description:
%Function that defines the epochs of the marked .set given (without noisy components, and with interpolated bad channels)
%INPUTS:
%pathStep5 = Path of the .set with interpolated bad channels
%nameStep5 = Name of the .set with interpolated bad channels
%epochRange = Vector of 2x1 with the times (in s) [start end] relative to the time-locking event. ([-0.3, 0.8] by default)
%heartEventName = Name of the event of the heartbeats. ('HeartBeat' by default)
%   If there are more than one events, asks the user which event corresponds to the heartbeats.
%   If there is only one event, takes that event as Heart Beat
%OUTPUTS:
%stauts = 1 if this script was completed succesfully. 0 otherwise.
%EEG = EEGLab structure after performinf the definition of epochs
%newEventName = String with the name of the event that was actually used (or the last try to use) to epoch


%Defines the default inputs
if nargin < 3
    epochRange = [-0.3, 0.8];
end
if nargin <4
    heartEventName = 'HeartBeat';
end
status = 1;
newEventName = heartEventName;


%Loads the .set
EEG = pop_loadset('filename', nameStep5, 'filepath', pathStep5);
allEventNames = {EEG.event(:).type};

%Checks how many different types of events this .set has
try         %Try finding the unique values as a cell (if there are strings)
    uniqueEvents = unique(allEventNames);
catch       %If there are numbers, convert them into strings
    nAll = length(allEventNames);
    for i = 1:nAll
        if isnumeric(allEventNames{i})
            allEventNames{i} = num2str(allEventNames{i});
        end
    end
    uniqueEvents = unique(allEventNames);
end

%If it is empty, send an error message
if isempty(uniqueEvents)
    disp('ERROR: The given .set does not contain any events. Please make sure that the step0 was run, and re-run steps 1-4 again');
    disp('NOTE: You could modify f_step6DefineEpochs to run step0 if it does not have any markings, but that is left for future versions');
    status = 0;
    return;
end

%If the label given by parameter does not exist in the .set, send a warning message 
%(it will be managed differently depending on the number of differnt event types)
isMember = true;
if ~ismember(heartEventName, uniqueEvents)
    fprintf('WARNING: The event name: %s was given, but the dataset only has the following event names:\n', heartEventName);
    disp(uniqueEvents);
    isMember = false;
end


%Finally, performs the definition of epochs
if ~isMember
    %If the given event name is not in the .set, but the .set only has ONE event, assume that it is a heartbeat
    if (length(uniqueEvents) == 1)
        fprintf('Assuming that the event name corresponding to heart beats is %s \n', uniqueEvents{1});
        EEG = pop_epoch( EEG, uniqueEvents(1), epochRange, 'epochinfo', 'yes');
        newEventName = uniqueEvents{1};
        
    else
        %Else if the given event name is not in the .set, and it has MULTIPLE events, 
        %ask the user to specify which event corresponds to the heartbeat
        disp('Please enter the name of the event that corresponds to the heartbeats (see list of events above, or press q if you do not know)');
        realEventName = input('', 's');
        if strcmpi(realEventName, 'q')
            disp('Please check which event corresponds to the heartbeat, and run the script again');
            status = 0;
            return;
            
        else
            %Check that the event the user prompted exists in the given dataset, and give them the opportunity to run the script again
            if sum(strcmp(realEventName, uniqueEvents)) == 0
                disp('ERROR: The name of the event that you entered does not exist in the given .set');
                disp('The events of this dataset are:');
                disp(uniqueEvents);
                disp('Do you want to run this function again (y), or skip to the next subject (any other key)?');
                repeatScript = input('', 's');
                if strcmpi(repeatScript, 'y')
                    [status, EEG, newEventName] = f_step6DefineEpochs(pathStep5, nameStep5, epochRange, heartEventName);
                else
                    status = 0;
                end
                return
                
            %If the event existed, just define the epochs
            else
                EEG = pop_epoch( EEG, {realEventName}, epochRange, 'epochinfo', 'yes');
                newEventName = realEventName;
            end
        end
    end
    
else
    %If the given event name does exist, just define the epochs
    EEG = pop_epoch( EEG, {heartEventName}, epochRange, 'epochinfo', 'yes');
end

EEG = eeg_checkset(EEG);

disp('Defined the epochs with the time-locked event(s):');
disp(newEventName);
fprintf('With a duration of [%.3f, %.3f] seconds around the event\n', epochRange);

end