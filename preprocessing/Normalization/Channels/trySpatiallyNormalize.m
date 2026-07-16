cPositions = {'front', 'posterior', 'right', 'left', 'top'};
cValues = {10, -10, 70, -70};
cTypes = {2, 3};
for kType = 1:length(cTypes)
for iPos = 1:length(cPositions)
for jVal = 1:length(cValues)
%% Defines the subject to be loaded, and the splines files
iSub = 'ej64.set';
originalSplines = 'splines64.spl';
destinationSplines = 'splines64.spl';
type = cTypes{kType};
%type = 1;        %1 if wants to perform mean correction 2 if wants to ignore it, and 3 if wants to make nearest neighbour
scenario = 1;   %Scenarios to be created (see f_createScenario) [1-5]
value = cValues{jVal};
%value = -70;
position = cPositions{iPos};
%position = 'posterior';     %'front', 'posterior', 'right', 'left', 'top'
saveImgs = true;

%% Loads the data and iterates over all timepoints
%Loads the .set (EEGLab readable file)
EEG = pop_loadset(iSub);
labels = {EEG.chanlocs(:).labels};

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
mData = f_createScenario(labels, scenario, value, position);
%mData = EEG.data(:,1,1);
%mData = mData - mean(mData);
%mData = mean(EEG.data, 3);
%mData = EEG.data(:,1:2048);
%mData = mData - mean(mData, 2);

%Calculates the newData in the destination configuration
tic
[newData, distanceToNearest] = f_spatiallyNormalize(mData, originalSplines, destinationSplines, type);
% [newData, distanceToNearest] = f_spatiallyNormalize(mData, originalSplines, destinationSplines, type, 'meshfile', 'colin27headmesh.mat');
t = toc;

%% Plots
if strcmp(position, 'posterior')
    view = 'back';
else 
    view = position;
end
headplot(mData, destinationSplines, 'title', 'Original', 'view', view, 'cbar', 0);
figure,
headplot(newData, destinationSplines, 'title', 'Re-created', 'view', view, 'cbar', 0);

figure,
plot(mData, newData, '*r'), 
hold on,
plot([min(min(mData)), max(max(mData))], [min(min(mData)), max(max(mData))])
plot([min(min(mData)), max(max(mData))], [0, 0], 'k')
plot([0, 0], [min(min(mData)), max(max(mData))], 'k')
xlabel('Original Data');
ylabel('Predicted Data');

dim = [.15 .6 .3 .3];
summary = [mean(mData), mean(newData), min(mData), min(newData), max(mData), max(newData)];
str = sprintf('Mean: Ori | New = %.2f | %.2f, \n Min: Ori | New =  %.2f | %.2f, \n Max: Ori | New: %.2f | %.2f', summary);
annotation('textbox',dim,'String',str,'FitBoxToText','on', 'BackgroundColor', 'w');

%% If wants to save, save the plots
if saveImgs
    %Creates the folders to save the plots (Escenarios/Scenario_#/InterpolType_#/.png)
    savePath = fullfile('Escenarios', strcat('Scenario_', num2str(scenario)), strcat('InterpolType_', num2str(type)));
    if ~exist(savePath, 'dir')
        mkdir(savePath)
    end
    
    %Defines the layout, value, position, scenario and interpolation type as strings
    sLay = strcat('Lay', num2str(length(labels)));
    sVal = strcat('Val', num2str(value));
    sPos = strcat('Pos', position);
    sSc = strcat('Sc', num2str(scenario));
    sIt = strcat('It', num2str(type));
    
    %Defines the filenames (layout_value_position_scenario_interpolationType.png)
    saveName = strcat(sLay, '_', sVal, '_', sPos, '_', sSc, '_', sIt, '.png');
    
    %Saves the figures
    saveas(gcf, fullfile(savePath, strcat('comp_', saveName)));
    close
    saveas(gcf, fullfile(savePath, strcat('new_', saveName)));
    close
    saveas(gcf, fullfile(savePath, strcat('ori_', saveName)));
    close
end
end
end
end