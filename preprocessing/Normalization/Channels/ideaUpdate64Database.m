%% Loads the desired subject
load('AA_RS_05_2407.mat');

%% Takes the data from that subjects into an 'EEGLab'-like format
sName = 'ej64.set';
EEG = f_dataToEEG2(EEGData, EEGTime, sName, pwd);

%% Takes the coordinates of interest
labels = {Properties.Channels(:).Name}';
theta = [Properties.Channels(:).CoordsTheta]';
azimuth = [Properties.Channels(:).CoordsPhi]';
head_circumference = 63;
f_createXyzFromCoords(labels, theta, azimuth, head_circumference);

%% Updates the EEG structure with the given chahnnel information (coordinates and labels)
EEG.chanlocs = readlocs('BioSemi64_HeadCirc63cms.xyz');

%% Saves the EEG structure
pop_saveset(EEG, 'ej64.set', pwd);