function [status, EEG, newFromXtoYLayout] = f_mainSpatialNorm(setPath, setName, hasChanLocs, fromXtoYLayout, headSizeCms)
%Description:
%Function thet loads EEGLab .sets already pre-processed and spatially translates it to the desired layout
%INPUTS:
%setPath            = Path of the desired .set (latest step of the pre-processing)
%setName            = Name of the desired .set (latest step of the pre-processing)
%hasChanLocs        = True if the database .json said it had ChannelsLocations. False otherwise
%fromXtoYLayout     = '64to128' if wants to move from a BioSemi64 Layout to a BioSemi128 Layout,
%       or '128to64' if wants to move froma Biosemi128 to a Biosemi64 Layout
%       NOTE: In further releases it could be modified to a Xto128 to allow more flexibility, and include other layouts
%headSizeCms        = Integer with the head size in Cms that the user wants to analyse (55cms by default).
%
%OUTPUTS:
%status             = 1 if this script was completed succesfully. 0 otherwise
%EEG                = EEGLab structure with the data in the desired layout
%newFromXtoYLayout  = Final interpolation performed (actual fromXtoYLayout option used)

%Defines the default outputs
status = 0;
EEG = [];
newFromXtoYLayout = fromXtoYLayout;

%Defines the default parameters
if nargin < 5
    headSizeCms = 55;
end

%Checks if the user gave the conversion of layouts desired. If not, asks for it
if nargin < 4 || isempty(fromXtoYLayout)
    disp('WARNING: To run the spatial normalization you need to specify from which layout you part from, and which is your desired destination layout');
    disp('Current options are: ''64to128'' and ''128to64'' ');
    disp('Please enter which of the options listed above you wish to run, or "q" to quit');
    fromXtoYLayout = input('', 's');
    
    %Manages invalid inputs
    if strcmp(fromXtoYLayout, 'q')
        disp('ERROR: Not performing spatial normalization');
        return
        
    elseif ~strcmp(fromXtoYLayout, '64to128') && ~strcmp(fromXtoYLayout, '128to64') && ~strcmp(fromXtoYLayout, '128to128')
        disp('Please enter a valid option. The script will be run again ');
        status = f_mainSpatialNorm(setPath, setName, hasChanLocs, [], headSizeCms);
        return
    end
end
newFromXtoYLayout = fromXtoYLayout;     %Updates the fromXtoYLayout used

%Defines the original n Channels, and destination n Channels
originalNChans = strsplit(fromXtoYLayout, 'to');
destinationNChans = str2double(originalNChans{2});
originalNChans = str2double(originalNChans{1});


%Looks for the .xyz layout, both from the original and destination layouts. If it does not exist, create it
[channelsCodePath, ~, ~] = fileparts(mfilename('fullpath'));
originalXYZ = sprintf('BioSemi%d_HeadCirc%dcms.xyz', originalNChans, headSizeCms);
if ~exist(fullfile(channelsCodePath, originalXYZ), 'file')
    %Creates the original .xyz Biosemi Layout for the given NChans and given headSize
    f_createBiosemiXyz(num2str(originalNChans), headSizeCms, channelsCodePath, originalXYZ);
end

destinationXYZ = sprintf('BioSemi%d_HeadCirc%dcms.xyz', destinationNChans, headSizeCms);
if ~exist(fullfile(channelsCodePath, destinationXYZ), 'file')
    %Creates the original .xyz Biosemi Layout for the given NChans and given headSize
    f_createBiosemiXyz(num2str(destinationNChans), headSizeCms, channelsCodePath, destinationXYZ);
end


%Looks for the .spl layouts, both from the original and destination layouts. If it does not exist, create it
nGridPoints = 6067;         %By default, performs the interpolation in a mesh of 6067-points. Another mesh of 1082 points can be used
originalSplines = sprintf('BioSemi%d_HeadCirc%dcms_%dPoints.spl', originalNChans, headSizeCms, nGridPoints);
if ~exist(fullfile(channelsCodePath, originalSplines), 'file')
    %Creates the original .spl Biosemi Layout for the given NChans and given headSize
    originalChanLocs = readlocs(fullfile(channelsCodePath, originalXYZ), 'filetype', 'xyz');
    if nGridPoints == 6067
        headplot('setup', originalChanLocs, fullfile(channelsCodePath, originalSplines));
        close
    elseif nGridPoints == 1082
        headplot('setup', originalChanLocs, fullfile(channelsCodePath, originalSplines), 'meshfile', 'colin27headmesh.mat');
        close
    end
end

destinationSplines = sprintf('BioSemi%d_HeadCirc%dcms_%dPoints.spl', destinationNChans, headSizeCms, nGridPoints);
destinationChanLocs = readlocs(fullfile(channelsCodePath, destinationXYZ), 'filetype', 'xyz');
if ~exist(fullfile(channelsCodePath, destinationSplines), 'file')
    %Creates the destination .spl Biosemi Layout for the given NChans and given headSize
    if nGridPoints == 6067
        headplot('setup', destinationChanLocs, fullfile(channelsCodePath, destinationSplines));
        close
    elseif nGridPoints == 1082
        headplot('setup', destinationChanLocs, fullfile(channelsCodePath, destinationSplines));
        close
    end
end


%Let the user know that the .json said it did not have channel locations
if ~hasChanLocs
    disp('WARNING: The database .json said this database does not have channel locations');
    disp('Do you still want to continue, as it might be that the database owner forgot to update this field? (y/n)');
    ignoreChanLocs = input('', 's');
    
    %If the user did not want to continue, end this function
    if ~strcmpi(ignoreChanLocs, 'y')
        disp('ERROR: Could not run the spatial normalization because the .json said it did not have any ChannelsLocations');
        return
    end
end


%If everything else is okay, load the .sets
EEG = pop_loadset('filename', setName, 'filepath', setPath);

%In the current version, only 2-D data is supported [channels, time] (not epochs)
if EEG.trials > 1 || size(EEG.data, 3) > 1
    disp('ERROR: The current version of spatial normalization, only supports 2-D data [channels, time] (not epochs)');
    return
end

%If this subject already has the destination layout desired, simply return it and let the user know
% if EEG.nbchan == destinationNChans
%     disp('This subject already had the number of channels desired. Continuing with the next subject');
%     status = 1;
%     %Removes data that corresponds to ICA calculated with the previous layout
%     EEG.chaninfo = [];
%     EEG.icaact = [];
%     EEG.icawinv = [];
%     EEG.icasphere = [];
%     EEG.icaweights = [];
%     EEG.icachansind = [];
% 
%     %Checks that everything is ok
%     EEG = eeg_checkset(EEG);
%     return
    
%If the subject has the original layout, make the interpolation required for the destination layout
%elseif EEG.nbchan == originalNChans
if EEG.nbchan == originalNChans
    type = 1;   %Currently, there are 3 types of interpolation. Type number 1 produces the best numerical results so far
    %type help f_spatiallyNormalize for more information.
    
    %try to run the function that performs the interpolation
    try
        %By default, performs the interpolation in a mesh of 6067-points.
        %Another mesh of 1082 points can be used instead adding: 'meshfile', 'colin27headmesh.mat', as final parameters
        disp('Performing spatial interpolation. This might take a while...');
        
        if nGridPoints == 6067
            [newData, ~] = f_spatiallyNormalize(EEG.data, fullfile(channelsCodePath, originalSplines), ...
                    fullfile(channelsCodePath, destinationSplines), type);
        elseif nGridPoints == 1082
            [newData, ~] = f_spatiallyNormalize(EEG.data, fullfile(channelsCodePath, originalSplines), ...
                    fullfile(channelsCodePath, destinationSplines), type, 'meshfile', 'colin27headmesh.mat');
        end
    catch e
        disp(e);
        return
    end
    
%If the real number of channels is neither the destination nor the original layout, throw an error
else
    fprintf('ERROR: The real number of channels for the given subject is: %d \n', EEG.nbchan);
    fprintf('But it was expected to be equal to the original Layout: %d, or the destination layout: %d \n', originalNChans, destinationNChans);
    disp('Currently you can only move from/to BioSemi64 and BioSemi128');
    return
end


%If the interpolation was completed succesfully, update the EEG structure with the new data
EEG.data = newData;
EEG.nbchan = destinationNChans;
EEG.chanlocs = destinationChanLocs;
EEG.urchanlocs = [];

%Removes data that corresponds to ICA calculated with the previous layout
EEG.chaninfo = [];
EEG.icaact = [];
EEG.icawinv = [];
EEG.icasphere = [];
EEG.icaweights = [];
EEG.icachansind = [];

%Checks that everything is ok
EEG = eeg_checkset(EEG);

%Finally, if it made it this far, the scrpit was completed succesfully
status = 1;

end