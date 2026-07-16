%Runs the main pipeline for a database with BIDS format
%NOTE: The current version DOES NOT allow the comparison of MULTIPLE databases at the SAME TIME
%% Run a specific step of the pre-processing pipeline for all subjects (one step for all subjects)%
%databasePath = '  F:\Pavel\Estandarizacion\Bases_de_Datos\EMP-ManyPipelines';
%databasePath = 'F:\Pavel\Estandarizacion\Bases_de_Datos\RS_SQZ-BrainLat';
databasePath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/';      %Database already in BIDS format
%preproSteps = [1];                    %Can be either an integer or a vector of steps, or 'all'/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis
signalType = 'RS';                 %singalType to be anaylzed ('HEP', 'RS', or 'task')
%f_mainPipeline(databasePath, 'signalType', 'RS', 'runPrepro'y, false, 'runChansToSouryce', false, 'runSourceAvgROI', false, ...
%    'runPatientControlNorm', false, 'avgSourceTime', false, 'sourceTransfMethod', 'FT_eLORETA', 'runConnectivity', false, ...
%    'runFeatureSelection', true, 'classCrossValFolds', 3);
%f_mainPipeline(databasePath, 'signalType', 'RS', 'runPrepro', false, 'runSpatialNorm', false, 'runChansToSource', true, 'runSourceAvgROI', true, ...
  %  'runPatientControlNorm', false, 'runClassifier', false,'finalNormStepPath', '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/Normalization/Step2_PatientControlNorm')
%eventosHip1 = {'101', '102'};
f_mainPipeline(databasePath, 'signalType', 'RS', 'runPrepro', false, 'runSpatialNorm', false, 'runChansToSource', false, 'runSourceAvgROI', false, ...
   'runPatientControlNorm',false, 'runClassifier', false,'finalNormStepPath', '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/Normalization/Step2_PatientControlNorm')
%eventosHip1 = {'101', '102'};



%f_mainPipeline(databasePath, 'signalType', 'RS', 'runPrepro', false, 'runSpatialNorm', false, 'runChansToSource', false, 'runSourceAvgROI', false, ...
%'runPatientControlNorm', false, 'runClassifier', false,'finalNormStepPath', '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/Normalization/Step2_PatientControlNorm')



%f_mainPipeline(databasePath, 'signalType', 'RS', 'runPrepro', false, 'runSpatialNorm', false, 'runChansToSource', false, 'runSourceAvgROI', false, ...
%    'runPatientControlNorm', false, 'runClassifier', false,'finalNormStepPath', '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/SourceTransformation/Step2_SourceAvgROI')


%NOTE: Linea de c???digo pyara HEP_AD RS:
%f_mainPipeline(databasePath, 'preproSteps', preproSteps, 'signalType', signalType, 'BIDStask', 'rs-HEP', 'runPrepro', false, ...
 %   'runPatientControlNorm', false);%, 'eventName', {1030, '1031'}, 'epochRange', [-2,1]), 'selectSourceTime', [1/512, 2/512], ;



%f_mainPipeline(databasePath, 'runPrepro', false, 'runSpatialNorm', true, 'runPatientControlNorm', true, ...
%    'finalPreproStepPath', 'F:\Pavel\Estandarizacion\Bases_de_Datos\RS_SQZ-BrainLat\prueba\Preprocessing\StepX', ...
%    'fromXtoYLayout', '64to128', 'headSizeCms', 6y0, 'controlLabel', 'HC', 'normFactor', 'RSTD_EP_L2');

% f_mainPipeline(databasePath, 'preproSteps', preproSteps, 'signalType', signalType, ...
%     'newPath', fullfile(databasePath, 'pruebaTask'), 'onlyBlinks', true, ...
%     'newSR', 256, 'freqRange', [1,50], 'reref_REST', true, 'burstCriterion', 7, ...
%     'windowCriterion', 0.4, 'epochRange', [-0.2, 0.5], 'jointProbSD', [7.5] , 'kurtosisSD', [], 'baselineRange', [-0.2, 0]);
     %'jointProbSD', 2.5, 'kurtosisSD', 2.5, 'baselineRange', [-0.2, 0], 'eventName' [], eventosHip1,);
     

%% GENERAL PARAMETERS FOR THE PIPELINE:
%Type  help f_mainPipeline to know about the additional optional parameters
%runPrepro              = true if the user wants to perform the preprocessing steps. false otherwise (true by default)
%signalType             = String with the type of the signal acquired (HEP, RS or task)
%preproSteps            = 'all' if you want to run ALL the steps for each subject (e.g. run all the steps for subject 1, then subject 2 and so on);
%   or a specific step that you want to run (as a vector or int) ('all' by default)
%   NOTE: If a specific step is given, that step will ONLY be run over the available subjects of the previous step
%finalPreproStepPath    = String with the fprepro_analysis containing the .sets with the final step of the preprocessing
%   Empty by default as it will be filled after succesfully completing the prepro
%   NOTE: If the user does not need to run the prepro (e.g. already has a pre-processed database), gives the opportunity to add a custom path)
%runSpatialNorm         = true if the user wants to perform the spatial normalization step. false otherwise (false by default, NOT READY YET!)
%runPatientControlNorm  = true if the user wants to perform the patient-control normalization step. false otherwise (true by default)
%finalNormStepPath          = Path were the final .sets are expected to be
%   Empty by default as it will be filled after succesfully completing the normalization step
%   NOTE: If the user does not need to run the normalization (e.g. already has a normalized database), gives the opportunity to add a custom path)
%runChansToSource       = true if the user wants to perform source transformation, false otherwise (true by Default)
%       NOTE: The current source transformation considers an average brain
%runSourceAvgROI        = true if the user wants to perform averaging of the source transformation by anatomical ROIs (true by Default)
%       NOTE: The current averaging is done using the 116 ROIs defined in the AAL atlas 
%finalSourceStepPath    = String with the fprepro_analysis_unkn containing the .sets with the final step of the source transformation
%   Empty by default as it will be filled after succesfully completing the source transformation
%   NOTE: If the user does not need to run the source transformation, gives the opportunity to add a custom path)
%runConnectivity        = true if the user wants to calculate connectivity metrics, false otherwise (true by Default)
%finalConnectStepPath    = String with the fprepro_analysis_unkn containing the .sets with the final step of the connectivity
%   Empty by default as it will be filled after succesfully completing the connectivity metrics
%   NOTE: If the user does not need to run the connectivity metrics, gives the opportunity to add a custom 
%runClassifier          = true if the user wants to use a classifier, false otherwise (true by Default)
%
%General optional parameters: 'BIDSmodality' - string, 'BIDStask' - string, 'newPath' - string
%% OPTIONAL PARAMETERS FOR PREPROCESSING:
%Type help f_mainPipeline, f_mainPreproTask, f_mainPreproHEP or f_mainPreproRS to know about the additional optional parameters
%f_mainPreproHEP(databasePath, step, 'key', val);
%E.g.: f_mainPreproTask(databasePath, step, 'initialSub', 6);
%General optional parameters: 'initialSub' - int
%Optional Step 0 (f_optStep0FilterAndResample): 'filterAndResample' - boolean, 'newSR' - int, 'freqRange' - vector [2,1]
%Step 2 (f_step2Referencing): 'reref_REST' - boolean
%Step 3 (f_step3CorrectArtifacts) (ONLY FOR RS signalType): 'burstCriterion' - int, 'windowCriterion' - int
%Step 4 (f_step4RejectComponents): 'onlyBlinks' - boolean
%Step 6 (f_step6DefineEpochs) (NOT FOR RS signalType): 'epochRange' - vector [2,1], 'eventName' - string, cell, vector or int
%Step 7 (f_step7RejectEpochs) (NOT FOR RS signalType): 'jointProbSD' - float or [], 'kurtosisSD' float or []
%Step 8 (f_step8RemoveBaseline) (NOT FOR RS signalType): 'baselineRange' - vector of [2,1]
%NOTE: The number of the steps might vary in RS signalType, but the parameters can still be defined

%% OPTIONAL PARAMETERS FOR NORMALIZATION:
%Type help f_mainPipeline, f_mainNormalization, f_mainSpatialNorm or f_mainPatientControlNorm to know about the additional optional parameters
%f_mainNormalization(databasePath, finalStepPath, runSpatialNorm, runPatientControlNorm, 'key', val)
%E.g.: f_mainPreproTask(databasePath, fullfile(databasePath, 'analysis_RS', 'Preprocessing', 'Step6_BadChanInterpolation'), false, true, 'controlLabel', 'HC');
%Step 1 (f_mainSpatialNorm): 'fromXtoYLayout' - string, 'headSizeCms' - float
%Step 2 (f_mainPatientControlNorm): 'controlLabel' - string, 'minDurationS' - int, 'normFactor' - string

%% OPTIONAL PARAMETERS FOR SOURCE TRANSFORMATION:
%Type help f_mainPipeline, f_mainSourceTransformation, f_mainChansToSource or f_mainSourceAvgROI to know about the additional optional parameters
%E.g.: f_mainSourceTransformation(databasePath, finalStepPath, runChannelsToSource, runSourceAvgROI, 'key', val)
%Step 0 (f_optSelectSourceTime): 'selectSourceTime' - vector [2,1], 'avgSourceTime' - boolean
%Step 1 (f_mainChansToSource): 'sourceTransfMethod' - string,
%   FOR BMA: 'BMA_MCwarming' - int, 'BMA_MCsamples' - int, 'BMA_MET' - string, 'BMA_OWL' - string, 
%   FOR FIELDTRIP: 'FT_sourcePoints' - int, 'FT_plotTimePoints' - float or vector [2,1]
%Step 2 (f_mainSourceAvgROI): '%sourceROIatlas' - string

%% OPTIONAL PARAMETERS FOR CONNECTIVITY METRICS:
%Type help f_mainPipeline, or f_mainConnectivity to know about the additional optional parameters
%E.g.: f_mainConnectivity(databasePath, finalStepPath, 'key', val)
%Step 1 (f_mainConnectivity): 'connIgnoreWSM' - boolean

%% OPTIONAL PARAMETERS FOR CLASSIFIER:
%Type help f_mainPipeline, or f_mainClassifier to know about the additional optional parameters
%E.g.: f_mainClassifier(databasePath, finalStepPath, 'key', val)
%Step 0 (f_mainFeatSelection): 'runFeatureSelection' - boolean, 'classDxComparison' - cell, 
%                               'classNumPermutations' - int, 'classSignificance' - float
%Step 1 (f_mainConnectivity): 'classCrossValFolds' - int