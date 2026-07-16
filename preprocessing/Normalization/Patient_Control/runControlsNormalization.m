%Script that runs the patient-control normalization of a whole database
%Path of the database to be normalized
databasePath = {'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat'};

%Gets the paths of the 'Controls' and 'Remaining' subjects of the given dataset(s)
%NOTE: The only reason to stratify them is by nationality
[paths, nationalities] = f_getControlsAndRemainingIDs(databasePath);

%Performs the patient-control database normalization per nationality
controlNames = paths.ControlsName;
remainingNames = paths.RemainingName;
controlPaths = paths.ControlsPath;
remainingPaths = paths.RemainingPath;
nNat = length(nationalities);
oldData = cell(1, nNat);            %Container for the NON-normalized original data (fields of [channels, time, subjects])
newData = cell(1, nNat);            %Container for the NORMALIZED data (fields of [channels, time, subjects])
for i = 1:nNat
    [oldData{i}, newData{i}] = f_controlsNormalization(controlPaths{i}, controlNames{i}, remainingPaths{i}, remainingNames{i});
end