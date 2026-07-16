%% Defines the subject to be loaded, and the splines files
iSub = 'ej64.set';
originalSplines = 'splines64.spl';
destinationSplines = 'splines64.spl';
type = 1;       %1 if wants to perform mean correction 2 if wants to ignore it, and 3 if wants to make nearest neighbour

%% Loads the data and iterates over all timepoints
%Loads the .set (EEGLab readable file)
EEG = pop_loadset(iSub);

%Step 0: Create the splines file (Has to be done only once)
if ~exist(originalSplines, 'file')
    headplot('setup', EEG.chanlocs, originalSplines);                                              %Default 6067-points mesh
    %headplot('setup', EEG.chanlocs, originalSplines, 'meshfile', 'colin27headmesh.mat');            %1082-points mesh
end
if ~exist(destinationSplines, 'file')
    headplot('setup', EEG.chanlocs, destinationSplines);                                           %Default 6067-points mesh
    %headplot('setup', EEG.chanlocs, originalSplines, 'meshfile', 'colin27headmesh.mat');            %1082-points mesh
end

%Step 1: Define the data (matrix of [Channels, Time, Epochs]) that wants to be spatially normalized
%mData = EEG.data(:,1,1);
%mData = mData - mean(mData);
mData = mean(EEG.data, 3);
%mData = EEG.data(:,1:2048);
%mData = mData - mean(mData, 2);

%% Calculates the newData in the destination configuration
tic
[newData, distanceToNearest] = f_spatiallyNormalize(mData, originalSplines, destinationSplines, type);
% [newData, distanceToNearest] = f_spatiallyNormalize(mData, originalSplines, destinationSplines, type, 'meshfile', 'colin27headmesh.mat');
t = toc;

%% Plots the data
absDiff = abs(newData - mData);
percentageError = 100*absDiff./mData;

plot(mData, newData, '*r'), 
hold on,
plot([min(min(mData)), max(max(mData))], [min(min(mData)), max(max(mData))])
plot([min(min(mData)), max(max(mData))], [0, 0], 'k')
plot([0, 0], [min(min(mData)), max(max(mData))], 'k')
xlabel('Original Data');
ylabel('Predicted Data');


