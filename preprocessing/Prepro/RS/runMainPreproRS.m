%Runs the main preprocessing for a database with Resting State (RS) data
%% Run the complete pre-processing pipeline for each subject (all steps for one subject before moving to the next one)
%Path of the desired database that wants to be preprocessed
%databasePath = 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat';
%f_mainPreproHEP(databasePath);

%% Run a specific step of the pre-processing pipeline for all subjects (one step for all subjects)
%0: Optional filtering and resampling
%1: Identification of bad channels
%2: Average reference
%3: Artifact rejection
%4: ICA computation
%5: Components rejection
%6: Bad channel interpolation
databasePath = 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat';
%step = [6, 7];               %Can be either an integer or a vector of steps
step = [3:6];               %Can be either an integer or a vector of steps
f_mainPreproRS(databasePath, step, 'newPath', 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat\preproRS_China');

%f_mainPreproRS(databasePath, step, 'newPath', 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat\prueba');
% f_mainPreproRS(databasePath, step, 'newSR', 256, 'freqRange', [1,50], 'burstCriterion', 7, 'windowCriterion', 0.4, ...
%     'onlyBlinks', true, 'newPath', 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat\prueba');

%% OPTIONAL PARAMETERS:
%Type help f_mainPreproRS to know about the additional optional parameters
%f_mainPreproHEP(databasePath, step, 'key', val);
%E.g.: f_mainPreproRS(databasePath, step, 'initialSub', 6);
%General optional parameters: 'modality' - string, 'task' - string, 'newPath' - string, 'initialSub' - int
%Step 0 (f_optStep0FilterAndResample): 'filterAndResample' - boolean, 'newSR' - int, 'freqRange' - vector [2,1]
%Step 3 (f_step3CorrectArtifacts): 'burstCriterion' - int, 'windowCriterion' - int
%Step 5 (f_step5RejectComponents): 'onlyBlinks' - boolean