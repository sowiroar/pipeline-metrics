function [status, realMinDuration] = f_getMinDuration(controlPaths, controlNames, remainingPaths, remainingNames, minDurationS)
%Description:
%Function that performs control-patient normalization of a given nationality and saves the results
%INPUTS:
%controlPaths       = Cell of 1xM nationalities, with each cell containing 1xN paths of the controls for each M nationality
%controlNames       = Cell of 1xM nationalities, with each cell containing 1xN .set names of the controls for each nationality
%remainingPaths     = Cell of 1xN containing the paths of the remaining subjects (non-controls) of a given nationality
%remainingNames     = Cell of 1xN containing the .set names of the remaining subjects (non-controls) of a given nationality)
%minDurationS       = Integer with the minimal duration in seconds required to consider a .set (240s by default [4min])
%OUTPUTS:
%status             = 1 if the script was completed succesfully. 0 otherwise
%realMinDuration    = Real minimal duration of the .sets (must be equal or greater than 240)

%Defines the default minimal duration in seconds required to consider a .set
if nargin < 5
    minDurationS = 240;
end

%Initializes the output variable
status = 0;
realMinDuration = inf;
allSRate = [];

%Iterates over all controls
mNationalitiesCtrls = length(controlPaths);
for i = 1:mNationalitiesCtrls
    iNatPath = controlPaths{i};
    iNatName = controlNames{i};
    nSubjects = length(iNatPath);
    for j = 1:nSubjects
        %Loads each subject and considers it's total duration (using evalc to avoid command printing)
        EEGchar = evalc('pop_loadset(iNatName{j}, iNatPath{j}, ''info'')');    %filename, filepath, loadmode
        [~, sBeg] = regexp(EEGchar, 'srate: ');
        sEnd = regexp(EEGchar(sBeg+1:end), '\n', 'once');
        jSrate = str2double(EEGchar(sBeg+1:sBeg+sEnd-1));   %Defines the sampling rate of the given .set
        
        %Checks that the sampling rate is the same for all subjects
        if isempty(allSRate)
            allSRate = jSrate;
        end
        if jSrate ~= allSRate
            %If there are sampling rates different from the ones of the first subjects, gives the user to resample them to that value
            disp('WARNING: For this step it is required that all .sets have the same sampling rate');
            fprintf('Do you want to resample all subjects to %dHz? (y/n)\n', allSRate);
            resampleAll = input('', 's');
            if ~strcmpi(resampleAll, 'y')
                disp('Please resample the .sets yourself and run this script again');
                return
            end
            
            %Overwrites the given .set after resampling it
            fprintf('Resampling to %d the .set:\n', allSRate);
            disp(fullfile(iNatPath, iNatName));
            tempEEG = pop_loadset('filename', iNatName, 'filepath', iNatPath);
            tempEEG = pop_resample(tempEEG, allSRate);
            pop_saveset(tempEEG, 'filename', iNatName, 'filepath', iNatPath);
            
            jSrate = allSRate;
        end
        
        %Defines the duration of the actual .set
        [~, pBeg] = regexp(EEGchar, 'pnts: ');
        pEnd = regexp(EEGchar(pBeg+1:end), '\n', 'once');
        jPnts = str2double(EEGchar(pBeg+1:pBeg+pEnd-1));    %Defines the points of the given .set
        iDurationS = jPnts/jSrate;
        
        %If the duration is less than the actual minimum, and greater than the minimum imposed in minDurationS [240 (4min)], updates it
        if iDurationS < realMinDuration && iDurationS >= minDurationS
            realMinDuration = iDurationS;
        end
    end
end


%Iterates over all remaining subjects
mNationalitiesRemaining = length(remainingPaths);
for i = 1:mNationalitiesRemaining
    iNatPath = remainingPaths{i};
    iNatName = remainingNames{i};
    nSubjects = length(iNatPath);
    for j = 1:nSubjects
        %Loads each subject and considers it's total duration (using evalc to avoid command printing)
        EEGchar = evalc('pop_loadset(iNatName{j}, iNatPath{j}, ''info'')');    %filename, filepath, loadmode
        [~, sBeg] = regexp(EEGchar, 'srate: ');
        sEnd = regexp(EEGchar(sBeg+1:end), '\n', 'once');
        jSrate = str2double(EEGchar(sBeg+1:sBeg+sEnd-1));   %Defines the sampling rate of the given .set
        
        %Checks that the sampling rate is the same for all subjects
        if jSrate ~= allSRate
            %If there are sampling rates different from the ones of the first subjects, gives the user to resample them to that value
            disp('WARNING: For this step it is required that all .sets have the same sampling rate');
            fprintf('Do you want to resample all subjects to %dHz? (y/n)\n', allSRate);
            resampleAll = input('', 's');
            if ~strcmpi(resampleAll, 'y')
                disp('Please resample the .sets yourself and run this script again');
                return
            end
            
            %Overwrites the given .set after resampling it
            fprintf('Resampling to %d the .set:\n', allSRate);
            disp(fullfile(iNatPath, iNatName));
            tempEEG = pop_loadset('filename', iNatName, 'filepath', iNatPath);
            tempEEG = pop_resample(tempEEG, allSRate);
            pop_saveset(tempEEG, 'filename', iNatName, 'filepath', iNatPath);
            
            jSrate = allSRate;
        end
        
        %Defines the duration of the actual .set
        [~, pBeg] = regexp(EEGchar, 'pnts: ');
        pEnd = regexp(EEGchar(pBeg+1:end), '\n', 'once');
        jPnts = str2double(EEGchar(pBeg+1:pBeg+pEnd-1));    %Defines the points of the given .set
        iDurationS = jPnts/jSrate;
        
        %If the duration is less than the actual minimum, and greater than the minimum imposed in minDurationS [240 (4min)], updates it
        if iDurationS < realMinDuration && iDurationS >= minDurationS
            realMinDuration = iDurationS;
        end
    end
end


%If the realMinDuration did not change from inf, THERE ARE NONE .SETS that are equal or greater than minDurationS!
if realMinDuration == inf
    fprintf('ERROR: There are none .sets that have duration greater than %d\n', minDurationS);
    disp('TIP: Please make sure that your data makes sense, or change the parameter minDurationS');
    return
end

%If it made it this far, the script was completed succesfully
status = 1;

end