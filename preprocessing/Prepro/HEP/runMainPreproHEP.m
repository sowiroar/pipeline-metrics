%Runs the main preprocessing for a database with HEP data

%% Run the complete pre-processing pipeline for each subject (all steps for one subject before moving to the next one)
%Path of the desired database that wants to be preprocessed
%databasePath = 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat';
%f_mainPreproHEP(databasePath);

%% Run a specific step of the pre-processing pipeline for all subjects (one step for all subjects)
%0: HEP marks (optional filtering and resampling).
%1: Identification of bad channels
%2: Average reference
%3: ICA computation
%4: Components rejection
%5: Bad channel interpolation
%6: Epoch definition
%7: Epoch rejection
%8: Baseline removal
databasePath = 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat';
%step = [6, 7];               %Can be either an integer or a vector of steps
step = [0];               %Can be either an integer or a vector of steps
f_mainPreproHEP(databasePath, step, 'newPath', 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat\pruebaHEP');
% f_mainPreproHEP(databasePath, step, 'newPath', 'F:\Pavel\Estandarizacion\Bases_de_Datos\HEP_AD_FTD_CN-UdeSa_BrainLat\pruebaHEP', ...
%     'newSR', 256, 'freqRange', [0.5, 50], 'onlyBlinks', true, 'epochRange', [-0.2, 0.6], 'jointProbSD', 5, 'kurtosisSD', 5, ...
%     'baselineRange', [-0.1, 0]);

%% OPTIONAL PARAMETERS:
%Type help f_mainPreproHEP to know about the additional optional parameters
%f_mainPreproHEP(databasePath, step, 'key', val);
%E.g.: f_mainPreproHEP(databasePath, step, 'initialSub', 6);
%General optional parameters: 'modality' - string, 'task' - string, 'newPath' - string, 'initialSub' - int
%Optional Step 0 (f_optStep0FilterAndResample): 'filterAndResample' - boolean, 'newSR' - int, 'freqRange' - vector [2,1]
%Step 4 (f_step4RejectComponents): 'onlyBlinks' - boolean
%Step 6 (f_step6DefineEpochs): 'epochRange' - vector [2,1], 'heartEventName' - string
%Step 7 (f_step7RejectEpochs): 'jointProbSD' - float or [], 'kurtosisSD' float or []
%Step 8 (f_step8RemoveBaseline): 'baselineRange' - vector of [2,1]