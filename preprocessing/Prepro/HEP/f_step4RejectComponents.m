function [status, EEG, rejectedComponents] = f_step4RejectComponents(pathStep3, nameStep3, onlyBlinks, eyeDetector)
%Description:
%Function that rejects noisy components given the .sets with ICA components
%There are currently 3 methods for noise components rejection:
%-IClabel (https://github.com/sccn/ICLabel) gives probabilities for ocular and cardiac artifacts
%-EyeCatch (https://github.com/bigdelys/eye-catch) identifies ocular artifacts
%-EEG-BLINKS (https://github.com/VisLab/EEG-Blinks) identifies blinking artifacts
%INPUTS:
%pathStep3 = Path of the .set containing the ICA information
%nameStep3 = Name of the .set containing the ICA information
%onlyBlinks = Boolean. True if wants to remove blinks only. False if wants to remove all eye artifacts (false by default)
%eyeDetector = Object created when executing eyeCatch (received as input to improve speed)
%OUTPUTS:
%status =  1 if this step was completed succesfully. 0 otherwise
%EEG = EEG structure obtained after rejecting the components
%rejectedComponents = Structure with the components removed (eyes and heart)

%Defines the default eyeCatch object if it is not given as input
if nargin < 3
    onlyBlinks = false;
end
if nargin < 4
    eyeDetector = eyeCatch;
end


%Initializes the status
status = 1;
rejectedComponents = [];

%Loads the desired dataset
EEG = pop_loadset('filename', nameStep3, 'filepath', pathStep3);

%Makes sure that the .set has the ICA information
if isfield(EEG, 'icawinv') * isfield(EEG, 'icasphere') * isfield(EEG, 'icaweights') * isfield(EEG, 'icachansind') == 0
    status = 0;
    disp('ERROR: The subject does not have the ICA information (icawinv, icasphere, icaweights, icachansind)');
    return
end

%Runs an automatic labelling of the ICA components
EEG_iclabel = pop_iclabel(EEG, 'default');

%And identifies the data corresponding to eyes and heart noise
comp_rej_heart = find(EEG_iclabel.etc.ic_classification.ICLabel.classifications(:,4)>0.85);
comp_rej_eyes = find(EEG_iclabel.etc.ic_classification.ICLabel.classifications(:,3)>0.85);

%Runs an automatic identification of eye components using EyeCatch (Bigdely-Shamlo 2013)
[eyeIC, ~, ~] = eyeDetector.detectFromEEG(EEG); % detect eye ICs
eyeIC = find(eyeIC);

%Merges the eye components, and merges it with the heart components
mergedEyeComponents = [comp_rej_eyes', eyeIC];
mergedEyeComponents = unique(mergedEyeComponents);
comp_rej = [comp_rej_heart', mergedEyeComponents];


%Removes the desired ICA component and checks everything is okay
EEG_EyeCatch = pop_subcomp(EEG, comp_rej, 0);
EEG_EyeCatch = eeg_checkset(EEG_EyeCatch);
rejectedComponents.heart = comp_rej_heart';
rejectedComponents.eyes = mergedEyeComponents;


%If the user want to remove the blinks only, makes the modifications required
if onlyBlinks
    
    % Runs an automatic identification of blinking components using EEG-BLINKS (Kleifges, 2017)
    params = checkBlinkerDefaults(struct(), getBlinkerDefaults(EEG));
    
    %Defines the parameters needed by BLINKER
    params.signalNumbers = EEG.icachansind;                     %The numbers of the channel numbers to try as potential signals if signalTypeIndicator is ‘UseNumbers’.
    allChanLbls = {EEG.chanlocs(:).labels};
    params.signalLabels = allChanLbls(EEG.icachansind);         %The names of channels to try as potential signals if signalTypeIndicator is 'UseLabels'.
    excludedIdxs = 1:EEG.nbchan;
    excludedIdxs(EEG.icachansind) = [];
    params.excludeLabels = allChanLbls(excludedIdxs);           %The names of signals to exclude from consideration.
    params.signalTypeIndicator = 'UseNumbers';                 %String specifying the type of signals from which to extract blinks. ('UseNumbers' or 'UseLabels' or 'UseICs')
    params.srate = EEG.srate;                                   %A positive scalar giving the sampling rate of the signal in Hz

    params.uniqueName = '';                                     %String uniquely identifying this data set.
    params.experiment = 'Experiment1';                          %String identifying the experiment.
    params.subjectID = '';                                      %String identifying the subject for the data set
    params.task = '';                                           %Name of task performed in this data set
    params.fileName = fullfile(pathStep3, nameStep3);
    params.blinkerSaveFile = fullfile(pwd, strcat(nameStep3(1:end-3), '.mat'));
    params.showMaxDistribution = false;                         %Figure for blinks distribution (false to avoid showing it)

    %Runs BLINKER with the desired parameters
    try
        [outEEG, com, blinks, blinkFits, blinkProperties, blinkStatistics, params] = pop_blinker(EEG, params);
    catch
        disp('WARNING: The current subject does not have any blinks');
        disp('Rejecting the whole eye-related components instead');
        EEG = EEG_EyeCatch;
        return;
    end
    
    %Reject the heart-related components
    EEG_Blinker = pop_subcomp(EEG, comp_rej_heart', 0);
    EEG_Blinker.etc.BLINKER_params = params;
    
    %Checks that BLINKER was succesfully completed
    if ~startsWith(blinks.status, 'success')
        disp('WARNING: Could not identify blinks using BLINKER. Rejecting Heart componens only');
        EEG = EEG_Blinker;
    end
    
    %Identifies the channel that contains the indexes for the detected blinks
    blinksChan = [blinks.signalData(:).signalNumber];               %Looks at all the channels that seemed to have blinks
    blinksIdx = find(blinksChan == blinks.usedSignal);              %Takes the positions of the blinks for the best channel only
    if isempty(blinksIdx)
        error('ERROR: Unexpected error. Could not find the channel used for blink detection. Check f_step4RejectComponents');
    end
    
    %Takes the blinks positions
    blinkPositions = blinks.signalData(blinksIdx).blinkPositions;   %[2, N] with the position [beggining, end] of the detected N blinks
    nBlinks = size(blinkPositions, 2);
    totalSeconds = EEG.pnts/EEG.srate;
    blinkPerMin = 60*nBlinks/totalSeconds;
    fprintf('Identified %d blinks in %.1f seconds (%.1f Blinks per min) \n', nBlinks, totalSeconds, blinkPerMin);
        
    
    %Then, in the positions of blinks, put the data that rejected Eye Components using EyeCatch.
    %In the remaining positions, keep the data in which only the heart artifacts were removed
    for i = 1:nBlinks
        iPosition = blinkPositions(1,i):blinkPositions(2,i);
        EEG_Blinker.data(:, iPosition) = EEG_EyeCatch.data(:, iPosition);
    end
    
    %Defines the output as that modified by BLINKER
    EEG = EEG_Blinker;
    
    
else
    %If the user does not want to use BLINKER (remove all eye-related components instead), 
    %define the output as that created by EyeCatch and ICLabel
    EEG = EEG_EyeCatch;
end

end