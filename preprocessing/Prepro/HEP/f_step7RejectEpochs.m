function [status, EEG, infoRejection] = f_step7RejectEpochs(pathStep6, nameStep6, jointProbSD, kurtosisSD)
%Function that performs noisy epoch rejection based on standard deviation of kurtosis
%INPUTS:
%pathStep6 = Path of the .set with the defined epochs
%pathStep6 = Name of the .set with the defined epochs
%jointProbSD = Threshold of standard deviation to consider something an outlier in terms of Joint Probability (2.5 by default)
%              Can be empty [] if the user does not want to discard epochs by joint probability
%kurtosisSD = Threshold of standard deviation to consider something an outlier in terms of Kurtosis (2.5 by default).
%             Can be empty [] if the user does not want to discard epochs by kurtosis
%OUTPUTS:
%status = 1 if this script was completed succesfully. 0 otherwise
%EEG = EEGLab structure after rejecting noisy epochs
%infoRejection = Cell of [2,5] with information about the subjectName,
%   original number of epochs, indexes of rejected epochs, original indexes 
%   of the rejected epochs, and percentage of rejected epochs

status = 1;
infoRejection = [];

%Defines the default threshold of standard deviations
if nargin < 3
    jointProbSD  = 2.5;
end
if nargin < 4
    kurtosisSD  = 2.5;
end

%Loads the .set
EEG = pop_loadset('filename', nameStep6, 'filepath', pathStep6);

%Makes sure that the .set has epochs (e.g. [channels, time, epochs], with epochs greater than 1)
dataSize = size(EEG.data);
if ~dataSize(3) > 1
    disp('ERROR: The given .set does not have the epochs defined');
    disp('Please define the epochs using f_step5DefineEpochs, and run this script again');
    status = 0;
    return;
end

%Marks artifacts based on amplitude and joint probabilities
if ~isempty(jointProbSD)
    EEG = pop_jointprob(EEG, 1, 1:EEG.nbchan , jointProbSD, jointProbSD, 0, 0);
end

%Marks the epochs with kurtosis greater than kurtosisSD
if ~isempty(kurtosisSD)
    EEG = pop_rejkurt(EEG, 1, 1:EEG.nbchan , kurtosisSD, kurtosisSD, 0, 0);
end

% Use every reject possible (kurtosis and jp wont run again)
EEG = eeg_rejsuperpose( EEG, 1, 1, 1, 1, 1, 1, 1, 1);   %Originally, kurtosis was on 0
EEG = eeg_checkset( EEG );

%% Rejected epochs information
%Index of the events to discard
idxRejected = unique([find(EEG.reject.rejjp), find(EEG.reject.rejkurt)]);

%Number of total epochs (before rejecting)
nEpochsOriginal = length(EEG.epoch);

%Number of trials to be rejected
if ~isempty(idxRejected)
    nRejected = size(idxRejected,2);
    originalIdxRejected = [EEG.event(idxRejected).urevent];
else
    nRejected = 0;
    originalIdxRejected = [];
end

%Percentage of trials rejected
percentageRejected  = nRejected*100/nEpochsOriginal;

%If the percentage of epochs to be rejected is greater than 50%, let the user know and suggest them to look at the epochs themselves
if percentageRejected > 50
    fprintf('WARNING: More than 50 per cent of the epochs were marked to be rejected %.1f (%d/%d) \n', ...
        percentageRejected, nRejected, nEpochsOriginal);
    disp('It is strongly recommended that you look at the data yourself to make sure of the quality of the data');
    disp('Do you wish to continue without looking at the data (y/n)?');
    seeData = input('', 's');
    
    %If the user wants to check the data, allow him to do so
    if strcmpi(seeData, 'y')
        disp('WARNING: More than 50 per cent of the epochs will be discarded');
    else
        status = 0;
        return
    end
end

%% Rejects the marked epochs
EEG = pop_rejepoch( EEG, idxRejected ,0);
EEG = eeg_checkset(EEG);

%% Save rejection information in a structure
infoRejection = cell(2, 4);

infoRejection{1,1} = 'SubjectName';
infoRejection{1,2} = 'OriginalNumberOfEpochs';
infoRejection{1,3} = 'IndexOfRejectedEpochs';
infoRejection{1,4} = 'OrginalIndexOfRejectedEpochs';
infoRejection{1,5} = 'PercentageOfRejectedEpochs';

fName = strsplit(nameStep6, '_');
infoRejection{2,1} = fName{1};
infoRejection{2,2} = nEpochsOriginal;
infoRejection{2,3} = idxRejected;
infoRejection{2,4} = originalIdxRejected;
infoRejection{2,5} = percentageRejected;

end