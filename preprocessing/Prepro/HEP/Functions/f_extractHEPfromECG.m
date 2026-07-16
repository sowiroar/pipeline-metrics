function [status, HEP] = f_extractHEPfromECG(ecgChanName, setPath, setName)
%Description:
%Function that gets the R peaks from the given ecgChanName
%INPUTS:
%ecgChanName = Name of the channel that contains the ECG channel
%setPath = Path were the desired .set is located
%setName = Name of the desired .set
%OUTPUTS:
%status = 1 if the script was completed succesfully. 0 otherwise
%HEP = Structure with useful information to record how HEPLab was run
%eventsTable = Table with the information of the events (ready to save as a txt)
% IMPORTANT: Heplab may fail sometimes to correctly define an R-peak,
% visual inspection required after code run.

status = 1;
HEP = [];

%Loads the desired .set
EEG = pop_loadset('filename', setName, 'filepath', setPath);

%Checks if the given ecgChanName exists
lbl = {EEG.chanlocs(:).labels};
idx = strcmpi(lbl, ecgChanName);
if sum(idx) == 0
    status = 0;
    disp('ERROR: Please enter a valid ECG channel label');
    fprintf('The label %s does not exist in the set %s \n', ecgChanName, setName);
    return
end

%% HEPLAB modification, ECG and Srate structures needed
% Heplab toolbox was manualy modified for it to run automatically
% without need of using the cursor. Peak finder algorithm used:
% Pan-Tompink
% Defines the needed variables for HEPLab
ecg                 = EEG.data(idx,:);
srate               = EEG.srate;
HEP.ecg   = ecg;
HEP.srate = srate;

% Use Pan-Tomkin on ECG
[~,HEP.qrsIdx] = heplab_pan_tompkin(HEP.ecg, 200);         %HEP.qrsIdx is actually points, not time

% Makes sure that HEPLab wasb able to identify the R-peaks
if isempty(HEP.qrsIdx)
    status = 0;
    fprintf('ERROR: HEPLab was not able to recognize any R-peak in the channel %s \n', ecgChanName);
    fprintf('Please make sure that the given ECG channel corresponds to the set: %s \n', setName);
    disp('If it does correspond, please try running f_step0HEPmarks yourself');
    return
end


% Name to be saved for the HEP structure
[~, subjName, ~] = fileparts(setName);
HEP.savefilename = (['Heplab_HEP_Matrix_', subjName]);

HEP.qrsMs = EEG.times(HEP.qrsIdx);

%Makes sure that the HEP.qrs is specified as a column vector
if size(HEP.qrsMs, 2) > 1
    HEP.qrsMs = HEP.qrsMs';
end

end