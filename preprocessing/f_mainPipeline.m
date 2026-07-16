function f_mainPipeline(databasePath, varargin)
%Function that performs the pre-processing, normalization, source analysis,
%statistical analysis, connectivity and classification together.
%This function calls the main functions described in Prepro, Normalization,
%SourceAnalysis and StatisticalAnalysis
%INPUTS:
%databasePath = Path of the desired database that wants to be preprocessed.
%   NOTE: The databasePath MUST already be in a BIDS-like structure
%3
%OPTIONAL INPUTS:
%------------------------GENERAL PARAMETERS--------------------------------
%BIDSmodality           = String with the modality of the data that will be analyzed (used in sub-#_BIDStask_BIDSmodality.set) ('eeg' by default)
%BIDStask               = String with the task to analyze (used in sub-#_BIDStask_BIDSmodality.set) ('rs' by default, but it will be updated accordingly)
%newPath                = String with the path in which the new fprepro_analysis_unkns will be stored ('databasePath/analysis_RS' by default, but it will be updated accordingly)
%runPrepro              = true if the user wants to perform the preprocessing steps. false otherwise (true by default)
%signalType             = String with the type of the signal acquired (HEP, RS or task)
%preproSteps            = 'all' if you want to run ALL the steps for each subject (e.g. run all the steps for subject 1, then subject 2 and so on);
%   or a specific step that you want to run (as a vector or int) ('all' by default)
%   NOTE: If a specific step is given, that step will ONLY be run over the available subjects of the previous step
%finalPreproStepPath    = String with the fprepro_analysis_unkn containing the .sets with the final step of the preprocessing
%   Empty by default as it will be filled after succesfully completing the prepro
%   NOTE: If the user does not need to run the prepro (e.g. already has a pre-processed database), gives the opportunity to add a custom path)
%runSpatialNorm         = true if the user wants to perform the spatial normalization step. false otherwise (false by default, NOT READY YET!)
%runPatientControlNorm  = true if the user wants to perform the patient-control normalization step. false otherwise (true by default)
%finalNormStepPath      = String with the fprepro_analysis_unkn containing the .sets with the final step of the normalization
%   Empty by default as it will be filled after succesfully completing the normalization
%   NOTE: If the user does not need to run the normalization (e.g. already has a normalised database), gives the opportunity to add a custom path)
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
%   NOTE: If the user does not need to run the connectivity metrics, gives the opportunity to add a custom path)
%runClassifier          = true if the user wants to use a classifier, false otherwise (true by Default)
%
%---------------------PREPROCESSING PARAMETERS-----------------------------
%BIDSmodality       = String with the modality of the data that will be analyzed ('eeg' by default)
%BIDStask           = String with the task to analyze ('' by default, but defined for each EEG activity after preprocessing)
%newPath            = String with the path in which the new fprepro_analysis_unkns will be stored ('' by default, but will be updated after the preprocessing)
%initialSub         = Integer corresponding to the subject in which the user desires to start (1 by default)
%filterAndResample  = true if the user wants to filter and resample the data before running the Step0 (true by default). (Runs f_optStep0FilterAndResample)
%newSR              = Integer with the new sampling rate desired in Hz (512 by default)
%freqRange          = Vector of [2, 1] with the range of frequencies [lowcut, highcut] that want to be kept ([0.5, 40]Hz by default)
%reref_REST         = true if the user wants to re-reference the data using REST, in addition to average referencing (false by default)
%burstCriterion     = Data portions with variance larger than the calibration data will be marked for ASR correction
%                   (lower is more strict, default: 5)
%windowCriterion    = Maximum proportion of noisy channels after ASR correction. 
%                   If it surpasses it, removes the time window. (lower is more strict, default: 0.25) (Common ranges: 0.05-0.3)
%onlyBlinks         = true if wants to remove blinks only. false if wants to remove all eye artifacts (false by default)
%epochRange         = Vector of [2, 1] with the times (in s) [start end] relative to the time-locking event. ([] by default)
%eventName          = Name of the event of interest. ('' by default)
%jointProbSD        = Threshold of standard deviation to consider something an outlier in terms of Joint Probability (2.5 by default)
%                   Can be empty [] if the user does not want to discard epochs by kurtosis
%kurtosisSD         = Threshold of standard deviation to consider something an outlier in terms of Kurtosis (2.5 by default). 
%                   Can be empty [] if the user does not want to discard epochs by kurtosis
%baselineRange      = Vector of [2,1] with the times [start, end] (in seconds) considered as baseline. (Empty [] by default, 
%                   but will be overwritten as [mostNegativePoint, 0] by default once f_step8RemoveBaseline is called)
%
%---------------------NORMALIZATION PARAMETERS-----------------------------
%BIDSmodality       = String with the modality of the data that will be analyzed ('eeg' by default)
%BIDStask           = String with the task to analyze ('default defined for each EEG activity')
%newPath            = String with the path in which the new fprepro_analysis_unkns will be stored (databasePath/analysis_signalType by default)
%OPTIONAL INPUTS FOR SPATIAL NORMALIZATION:
%fromXtoYLayout     = '64to128' if wants to move from a BioSemi64 Layout to a BioSemi128 Layout,
%       or '128to64' if wants to move froma Biosemi128 to a Biosemi64 Layout
%       NOTE: In further releases it could be modified to a Xto128 to allow more flexibility, and include other layouts
%headSizeCms        = Integer with the head size in Cms that the user wants to analyse (55cms by default).
%OPTIONAL INPUTS FOR PATIENT-CONTROL NORMALIZATION:
%controlLabel           = String with the label that the control subjects have (CN by default)
%minDurationS           = Integer with the minimal duration in seconds required to consider a .set (240s by default [4min])
%normFactor = String with the normalization factor desired (regular 'z-score' by default)
%       All the metrics are calculated for the CONTROLS only, and applied (divided) in all subjects
%       'Z-SCORE': Subtrates the mean and divides by the standard deviation
%       'UN_ALL': Uniform scaling of channel data by dividing by the robust standard deviation of concatenated channel data
%       'PER_CH': Dividing each channel by the robust standard deviation of its continuous activity across the whole recording
%       'UN_CH_HB': Uniform scaling of all channels by dividing all channel data by the Huber mean of channel robust standard 
%                   deviation values (same scaling applied to all channels).
%       'RSTD_EP_Mean': Normalizes by taking the mean of each N subject's robust standard deviation per channel individually
%       'RSTD_EP_Huber': Normalizes by taking the Huber mean of each N subject's robust standard deviation per channel individually
%       'RSTD_EP_L2': Normalizes by taking the Euclidean mean of each N subject's robust standard deviation per channel individually
%
%-----------------SOURCE TRANSFORMATION PARAMETERS-------------------------
%BIDSmodality           = String with the modality of the data that will be analyzed ('eeg' by default)
%BIDStask               = String with the task to analyze ('default defined for each EEG activity')
%newPath                = String with the path in which the new fprepro_analysis_unkns will be stored (databasePath/analysis_signalType by default)
%OPTIONAL PARAMETERS FOR TIME SELECTION AND AVERAGING:
%selectSourceTime       = Vector of [1,2] with the time window in seconds that the user wants to transform to a source level 
%                       [timeBeg, timeEnd]. (empty by Default)
%avgSourceTime          = Boolean. True if the user wants to average the selected time window. False otherwise (false by default)
%OPTIONAL INPUTS FOR CHANNELS TO SOURCE:
%sourceTransfMethod     = String with the method to calculate the source transformation ('BMA' by default)
%       NOTE: The current version only has 'BMA', 'FT_eLoreta' and 'FT_MNE' but more methods could be added
%BMA_MCwarming          = Integer with the warming length of the Markov Chain for source transformation (4000 by default)
%BMA_MCsamples          = Integer with the number of samples from the Monte Carlo Markov Chain sampler for source transformation (3000 by default)
%BMA_MET:               = String with the method of preference for exploring the models space:
%           If MET=='OW', the Occam's Window algorithm is used.
%           If MET=='MC', The MC3 is used (Default).
%BMA_OWL:               = Integer with the Occam's window lower bounds 
%           [3-Very Strong, 20-strong, 150-positive, 200-Weak] (3 by default)
%FT_sourcePoints    = Integer with the desired number of source points (5124 or 8196)
%       NOTE: 5124 defined as default because it takes less memory, while producing acceptable results
%FT_plotTimePoints  = Empty if the user does not want to plot anything at source level (by default)
%       NOTE: Can be an integer with the single time in seconds to be visualized, 
%       or can be a vector with [begin, end] times in seconds to be averaged and visualized
%OPTIONAL INPUTS FOR SOURCE AVERAGE ROI:
%sourceROIatlas         = String with the name of the Atlas that the user wants to use ('AAL-116' by default)
%
%----------------------CONNECTIVITY PARAMETERS-----------------------------
%connIgnoreWSM          = true if wants to ignore the Weighted Symbolic Metrics (3 in total). false otherwise
%       NOTE: false by default because those metrics take a lot of time to be computed
%
%-----------------------CLASSIFIER PARAMETERS------------------------------
%runFeatureSelection    = true to run a statictical feature selection using permutations with FDR correction prior to creating the model
%classDxComparison      = Cell of 2x1, each field containing strings of the diagnostics to be compared ({} by default)
%classNumPermutations   = Integer with the number of permutations desired for the statistical tests (5000 by default)
%classSignificance      = Number with the level of significance desired (0.05 by default)
%classCrossValFolds     = Number of Cross-Validation folds to use for creating the ROC curves (5 by Default)
%
%Author: Jhony Mejia

%Checks that the user has eeglab
try
    version = eeg_getversion;
catch
    %If eeglab has not been executed, try executing it to enable all eeglab functions, and ask for the version again.
    try
        eeglab;
        close;
        clc;
        version = eeg_getversion;
    catch
        disp('ERROR: It seems that you do not have EEGLab. Please download and install it');
        disp('https://sccn.ucsd.edu/eeglab/download.php');
        disp('https://eeglab.org/tutorials/01_Install/Install.html');
        return;
    end
end
%Checks that the EEGLab version is newer than 2020
if str2double(version) < 2020
    disp('ERROR: These scripts were built using EEGLab v.2020.0');
    disp('Most of the functions can work with prepro_analysis_unkn versions of EEGLab, but it is suggested that you have a version from 2020 or newer');
    return;
end


%Adds the path that contains the functions used in the  normalization, source analysis and statistical analysis.
%NOTE: The pre-processing fprepro_analysis_unkns will be added depending on the version required by the user
currentPath = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentPath);
warning('off','MATLAB:rmpath:DirNotFound');
rmpath(genpath(fullfile(currentPath, 'Prepro')));      %Prepro removed to avoid running previously executed versions of the prepro
warning('on','MATLAB:rmpath:DirNotFound');
addpath(genpath(fullfile(currentPath, 'Normalization')));
addpath(genpath(fullfile(currentPath, 'SourceAnalysis')));
addpath(genpath(fullfile(currentPath, 'Classifier')));
addpath(genpath(fullfile(currentPath, 'Connectivity')));


%If the general input is not even, the user did not follow the key-value format needed
if ~isempty(varargin) && mod(length(varargin), 2) ~= 0
    disp('ERROR: Please follow the key-value format needed to run this function');
    return
end

%Defines the default general parameters (the rest of default parameters will be defined its corresponding f_main)
generalInput = strcmp(varargin, 'BIDSmodality') | strcmp(varargin, 'BIDStask') | strcmp(varargin, 'newPath') | ...
    strcmp(varargin, 'runPrepro') | strcmp(varargin, 'signalType') | ...
    strcmp(varargin, 'preproSteps') | strcmp(varargin, 'finalPreproStepPath') | ...
    strcmp(varargin, 'runSpatialNorm') | strcmp(varargin, 'runPatientControlNorm') | ...
    strcmp(varargin, 'finalNormStepPath') | strcmp(varargin, 'runChansToSource') | ...
    strcmp(varargin, 'runSourceAvgROI') | strcmp(varargin, 'finalSourceStepPath') | ...
    strcmp(varargin, 'runConnectivity') | strcmp(varargin, 'finalConnectStepPath') | ...
    strcmp(varargin, 'runClassifier');
idxGeneral = find(generalInput);
idxGeneral = sort([idxGeneral, idxGeneral+1]);
generalInput = varargin(idxGeneral);
params = finputcheck( generalInput, {'BIDSmodality',        'string',                   '',         'eeg'; ...
                                    'BIDStask',             'string',                   '',         '';
                                    'newPath',              'string',                   '',         '';
                                    'runPrepro',            'boolean',                  '',         true;
                                    'signalType',           'string',                   '',         '';
                                    'preproSteps',          {'string', 'integer'},      '',         'all';
                                    'finalPreproStepPath',  'string',                   '',         '';
                                    'runSpatialNorm',       'boolean',                  '',         false;
                                    'runPatientControlNorm','boolean',                  '',         true;
                                    'finalNormStepPath',    'string',                   '',         '';
                                    'runChansToSource',     'boolean',                  '',         true;
                                    'runSourceAvgROI',      'boolean',                  '',         true;
                                    'finalSourceStepPath',  'string',                   '',         '';
                                    'runConnectivity',      'boolean',                  '',         true;
                                    'finalConnectStepPath', 'string',                   '',         '';
                                    'runClassifier',        'boolean',                  '',         true
                                    } ...
                                    );
if ischar(params) && startsWith(params, 'error:')
    disp(params);
    return
end

%Tries to automatically define the BIDStask and BIDSmodality parameters
jsonNames = dir(fullfile(databasePath, '*.json'));
jsonNames = {jsonNames(:).name};
taskAndModJson = {};
if ~isempty(jsonNames)
    taskAndModJson = startsWith(jsonNames, 'task-');
    if sum(taskAndModJson) > 0
        taskAndModJson = jsonNames(taskAndModJson);
    end
end
if isempty(params.BIDSmodality)
    if length(taskAndModJson) == 1
        modalityName = split(taskAndModJson, '_');
        modalityName = split(modalityName{2}, '.');
        modalityName = modalityName{1};
        fprintf('WARNING: Assuming that the files that you want to analyze are from the modality: %s\n', modalityName);
        params.BIDSmodality = modalityName;
    elseif length(taskAndModJson) > 1
        disp('WARNING: Found the following .json files that seem to have task and modality information:');
        disp(taskAndModJson);
        disp('Please input the BIDSmodality that you wish to analyze (the files follow a "BIDStask_BIDSmodality.json"):');
        modalityName = input('', 's');
        params.BIDSmodality = modalityName;
    end
end
if isempty(params.BIDStask)
    if length(taskAndModJson) == 1
        taskName = split(taskAndModJson, '_');
        taskName = taskName{1};
        fprintf('WARNING: Assuming that the files that you want to analyze are from the task: %s\n', taskName);
        params.BIDStask = taskName;
    elseif length(taskAndModJson) > 1
        disp('WARNING: Found the following .json files that seem to have task and modality information:');
        disp(taskAndModJson);
        disp('Please input the BIDStask that you wish to analyze (the files follow a "BIDStask_BIDSmodality.json"):');
        taskName = input('', 's');
        params.BIDStask = taskName;
    end
end

%Defines constant fields that will be used by almost all steps of the pre-processing (makes easier the updating process)
constantFields = {'BIDSmodality', params.BIDSmodality};
if ~isempty(params.BIDStask)
    constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
end
if ~isempty(params.newPath)
    constantFields(end+1:end+2) = {'newPath', params.newPath};
end

%% PRE-PROCESSING
%If no signalType is given, and the user want to perform preprocessing, ask the user the signalType
if isempty(params.signalType) && params.runPrepro
    disp('WARNING: Please enter the signal type that you want to analyse (HEP, RS or task)');
    params.signalType = input('', 's');
    if ~(strcmpi(params.signalType, 'HEP') || strcmpi(params.signalType, 'RS') || strcmpi(params.signalType, 'task'))
        disp('ERROR: Please enter a valid signal type');
        return
    end
end
if ~isempty(params.signalType)
    fprintf('Initializing a %s analysis type!\n', params.signalType);
end


%Performs the pre-processing steps, if desired
preproStatus = 1;
if params.runPrepro
    %Defines the preprocessing parameters (the rest of parameters will be defined with its corresponding f_main)
    preproInput = strcmp(varargin, 'initialSub') | strcmp(varargin, 'filterAndResample') | ...
        strcmp(varargin, 'newSR') | strcmp(varargin, 'freqRange') | ...
        strcmp(varargin, 'reref_REST') | strcmp(varargin, 'onlyBlinks');
    
    
    %Executes the mainPrepro specified by the user, starting at the step desired
    if strcmpi(params.signalType, 'HEP')
        addpath(genpath(fullfile(currentPath, 'Prepro/HEP')));

        %Defines parameters unique to HEP
        if sum(strcmpi(varargin, 'eventName')) > 1    %If the input was eventName, replace it with heartEventName
            varargin{strcmp(varargin, 'eventName')} = 'heartEventName';
        end
        preproInput = preproInput | strcmp(varargin, 'epochRange') | strcmp(varargin, 'heartEventName') | ...
            strcmp(varargin, 'jointProbSD') | strcmp(varargin, 'kurtosisSD') | strcmp(varargin, 'baselineRange');
        idxPrepro = find(preproInput);
        idxPrepro = sort([idxPrepro, idxPrepro+1]);
        preproInput = varargin(idxPrepro);
        preproInput(end+1:end+length(constantFields)) = constantFields;

        
        %Runs the preprocessing for HEP
        [preproStatus, finalPreproStepPath, preproParams] = f_mainPreproHEP(databasePath, params.preproSteps, preproInput{:});

    elseif strcmpi(params.signalType, 'RS')
        addpath(genpath(fullfile(currentPath, 'Prepro/RS')));
        
        %Defines parameters unique to RS
        preproInput = preproInput | strcmp(varargin, 'burstCriterion') | strcmp(varargin, 'windowCriterion');
        idxPrepro = find(preproInput);
        idxPrepro = sort([idxPrepro, idxPrepro+1]);
        preproInput = varargin(idxPrepro);
        preproInput(end+1:end+length(constantFields)) = constantFields;
        
        %Runs the preprocessing for RS
        [preproStatus, finalPreproStepPath, preproParams] = f_mainPreproRS(databasePath, params.preproSteps, preproInput{:});

    elseif strcmpi(params.signalType, 'task')
        addpath(genpath(fullfile(currentPath, 'Prepro/Task')));
        
        %Defines parameters unique to task
        preproInput = preproInput | strcmp(varargin, 'epochRange') | strcmp(varargin, 'eventName') | ...
            strcmp(varargin, 'jointProbSD') | strcmp(varargin, 'kurtosisSD') | strcmp(varargin, 'baselineRange');
        idxPrepro = find(preproInput);
        idxPrepro = sort([idxPrepro, idxPrepro+1]);
        preproInput = varargin(idxPrepro);
        preproInput(end+1:end+length(constantFields)) = constantFields;
        
        %Runs the preprocessing for task
        [preproStatus, finalPreproStepPath, preproParams] = f_mainPreproTask(databasePath, params.preproSteps, preproInput{:});

    else
        disp('ERROR: The signal type must be either HEP, RS or task');
    end
    
end


%% NORMALIZATION (SPATIAL AND PATIENT-CONTROL)
%Check that the preproSteps could be completed
if preproStatus == 0
    disp('ERROR: Could not complete the pre-processing steps. Cannot continue with the main pipeline');
    return
end

normStatus = 1;
%If none of the normalization steps are required by the user, do not run them
if params.runSpatialNorm || params.runPatientControlNorm
    
    %If no path was given as finalPreproStepPath, try and add the expected path given the prepro, or the signalType
    if isempty(params.finalPreproStepPath)
        
        %If the prepro was run, updates BIDSmodality, BIDStask and/or newPath if they were updated in the preprocessing
        if exist('preproParams', 'var')
            params.finalPreproStepPath = finalPreproStepPath;
            constantFields = {'BIDSmodality', preproParams.BIDSmodality, 'BIDStask', preproParams.BIDStask, 'newPath', preproParams.newPath};
            
        %In any other case, try and find where the .sets should be
        else
            
            %If the user entered a 'newPath', try and define the expectedPath given the signalType
            if ~isempty(params.newPath)
                if strcmpi(params.signalType, 'HEP')
                    expectedFinalPreproStepPath = fullfile(params.newPath, 'Preprocessing', 'Step8_BaselineRemoval');
                elseif strcmpi(params.signalType, 'RS')
                    expectedFinalPreproStepPath = fullfile(params.newPath, 'Preprocessing', 'Step6_BadChanInterpolation');
                elseif strcmpi(params.signalType, 'task')
                    expectedFinalPreproStepPath = fullfile(params.newPath, 'Preprocessing', 'Step8_BaselineRemoval');
                else
                    expectedFinalPreproStepPath = '';
                end
                
            %In any other case, define the default output fprepro_analysis_unkns
            else
                if strcmpi(params.signalType, 'HEP')
                    expectedFinalPreproStepPath = fullfile(databasePath, 'analysis_HEP', 'Preprocessing', 'Step8_BaselineRemoval');
                elseif strcmpi(params.signalType, 'RS')
                    expectedFinalPreproStepPath = fullfile(databasePath, 'analysis_RS', 'Preprocessing', 'Step6_BadChanInterpolation');
                elseif strcmpi(params.signalType, 'task')
                    expectedFinalPreproStepPath = fullfile(databasePath, 'analysis_Task', 'Preprocessing', 'Step8_BaselineRemoval');
                else
                    expectedFinalPreproStepPath = '';
                end
            end

            %If it was not possible to define an expected path, ask the user to enter the path containing the pre-processed .sets
            if isempty(expectedFinalPreproStepPath)
                disp('Please paste the path of the step fprepro_analysis_unkn containing the .sets that you want to analyse, or press "q" to exit');
                newPreproPath = input('', 's');
                if strcmpi(newPreproPath, 'q')
                    disp('ERROR: Ending the pipeline before the normalizations step');
                    return
                else 
                    params.finalPreproStepPath = newPreproPath;
                end

            %If there is any expectedPath, Assume that the pre-processing .sets are located in the default path were they should be saved
            elseif exist(expectedFinalPreproStepPath, 'dir')
                disp('WARNING: Assuming that the fprepro_analysis_unkn were the .sets that you want to analyse after preprocessing are located in:');
                disp(expectedFinalPreproStepPath);
                disp('Do you want to continue analysing those fprepro_analysis_unkns? (y/n)');
                assumePreproPath = input('', 's');

                if strcmpi(assumePreproPath, 'y')
                    params.finalPreproStepPath = expectedFinalPreproStepPath;
                else
                    %If the path is not the expected, ask the user to enter the path
                    disp('Please paste the path of the step fprepro_analysis_unkn containing the .sets that you want to analyse, or press "q" to exit');
                    newPreproPath = input('', 's');
                    if strcmpi(newPreproPath, 'q')
                        disp('ERROR: Ending the pipeline before the normalizations step');
                        return
                    else 
                        params.finalPreproStepPath = newPreproPath;
                    end
                end
                
            end
            
            %Finally, updates the constantFields with the path given
            preproPathParts = strsplit(params.finalPreproStepPath, filesep);
            if length(preproPathParts) < 3
                disp('ERROR: The finalPreproStepPath is expected to follow the directory structure: newPath/Preprocessing/Step#');
                return
            end
            constantFields = {'BIDSmodality', params.BIDSmodality, 'newPath', fullfile(preproPathParts{1:end-2})};
            if ~isempty(params.BIDStask)
                constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
            end
        end

    %If the user gives a params.finalPreproStepPath, update the newPath to be two directories up
    %(the expected directory structure is 'newPath/Preprocessing/Step#')
    else
        preproPathParts = strsplit(params.finalPreproStepPath, filesep);
        if length(preproPathParts) < 3
            disp('ERROR: The finalPreproStepPath is expected to follow the directory structure: newPath/Preprocessing/Step#');
            return
        end
        constantFields = {'BIDSmodality', params.BIDSmodality, 'newPath', fullfile(preproPathParts{1:end-2})};
        if ~isempty(params.BIDStask)
            constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
        end
    end


    %Check that the finalPreproStepPath exists
    if ~exist(params.finalPreproStepPath, 'dir')
        disp('ERROR: The path you entered as the final preprocessing step does not exist:');
        disp(params.finalPreproStepPath);
        disp('Please enter a valid path using the key ''finalPreproStepPath'' and run the main pipeline script again');
        return
    end


    %Define the parameters used for the normalization steps
    normInput = strcmp(varargin, 'fromXtoYLayout') | strcmp(varargin, 'headSizeCms') | ...
        strcmp(varargin, 'controlLabel') | strcmp(varargin, 'minDurationS') | strcmp(varargin, 'normFactor');
    idxNorm = find(normInput);
    idxNorm = sort([idxNorm, idxNorm+1]);
    normInput = varargin(idxNorm);
    normInput(end+1:end+length(constantFields)) = constantFields;

    %Runs the normalization step (both spatial and patient-control)
    [normStatus, finalNormStepPath, normParams] = f_mainNormalization(databasePath, params.finalPreproStepPath, params.runSpatialNorm, ...
        params.runPatientControlNorm, normInput{:});
end

%% SOURCE TRANSFORMATION (BMA)
%Check that the normalizationStep could be completed
if normStatus == 0
    disp('ERROR: Could not complete the normalization steps. Cannot continue with the main pipeline');
    return
end

sourceStatus = 1;
%If the source runChansToSource step is not required by the user, do not run either of the source transformation steps
if params.runChansToSource
    
    %If no path was given as finalNormStepPath, try and add the expected path given the normalization, or the signalType
    if isempty(params.finalNormStepPath)
        
        %If the normalization was run, updates BIDSmodality, BIDStask and/or newPath if they were updated
        if exist('normParams', 'var')
            params.finalNormStepPath = finalNormStepPath;
            constantFields = {'BIDSmodality', normParams.BIDSmodality, 'BIDStask', normParams.BIDStask, 'newPath', normParams.newPath};
            
        %In any other case, try and find where the .sets should be
        else
            
            %If the user entered a 'newPath', try and define the expectedPath
            if ~isempty(params.newPath)
                expectedfinalNormStepPath = fullfile(params.newPath, 'Normalization', 'Step2_PatientControlNorm');
                
            %In any other case, define the default output fprepro_analysis_unkns
            else
                expectedfinalNormStepPath = fullfile(databasePath, 'analysis_RS', 'Normalization', 'Step2_PatientControlNorm');
            end

            
            %If there is any expectedPath, Assume that the normalised .sets are located in the default path were they should be saved
            if exist(expectedfinalNormStepPath, 'dir')
                disp('WARNING: Assuming that the fprepro_analysis_unkn were the .sets that you want to analyse after normalization are located in:');
                disp(expectedfinalNormStepPath);
                disp('Do you want to continue analysing those fprepro_analysis_unkns? (y/n)');
                assumePreproPath = input('', 's');

                if strcmpi(assumePreproPath, 'y')
                    params.finalNormStepPath = expectedfinalNormStepPath;
                else
                    %If the path is not the expected, ask the user to enter the path
                    disp('Please paste the path of the step fprepro_analysis_unkn containing the .sets that you want to analyse, or press "q" to exit');
                    newNormPath = input('', 's');
                    if strcmpi(newNormPath, 'q')
                        disp('ERROR: Ending the pipeline before the source transformation step');
                        return
                    else 
                        params.finalNormStepPath = newNormPath;
                    end
                end
                
            end
            
            %Finally, updates the constantFields with the path given
            params.finalNormStepPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/Normalization/Step2_PatientControlNorm';
            %params.finalNormStepPath = '/users/gpb23120/Documents/General_Code/prepro_analysis_unkn/analysis_RS/Normalization/Step2_PatientControlNorm';
            normPathParts = strsplit(params.finalNormStepPath, filesep);
            if length(normPathParts) < 3
                disp('ERROR: The finalNormStepPath is expected to follow the directory structure: newPath/Normalization/Step2_PatientControlNorm');
                return
            end
            constantFields = {'BIDSmodality', params.BIDSmodality, 'newPath', fullfile(normPathParts{1:end-2})};
            if ~isempty(params.BIDStask)
                constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
            end
        end

    %If the user gives a params.finalNormStepPath, update the newPath to be two directories up
    %(the expected directory structure is 'newPath/Normalization/Step2_PatientControlNorm')
    else
        params.finalNormStepPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/Normalization/Step2_PatientControlNorm';
        %params.finalNormStepPath = '/users/gpb23120/Documents/General_Code/users/gpb23120/Documents/General_Code/prepro_analysis_unkn/analysis_RS/Normalization/Step2_PatientControlNorm';
        normPathParts = strsplit(params.finalNormStepPath, filesep);
        if length(normPathParts) < 3
            disp('ERROR: The finalNormStepPath is expected to follow the directory structure: newPath/Normalization/Step2_PatientControlNorm');
            return
        end
        constantFields = {'BIDSmodality', params.BIDSmodality, 'newPath', fullfile(normPathParts{1:end-2})};
        if ~isempty(params.BIDStask)
            constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
        end
    end


    %Check that the finalNormStepPath exists
    if ~exist(params.finalNormStepPath, 'dir')
        disp('ERROR: The path you entered as the final normalization step does not exist:');
        disp(params.finalNormStepPath);
        disp('Please enter a valid path using the key ''finalNormStepPath'' and run the main pipeline script again');
        return
    end


    %Define the parameters used for the source transformation steps
    sourceInput = strcmp(varargin, 'selectSourceTime') | strcmp(varargin, 'avgSourceTime') | ...
        strcmp(varargin, 'sourceTransfMethod') | strcmp(varargin, 'BMA_MCwarming') | ...
        strcmp(varargin, 'BMA_MCsamples') | strcmp(varargin, 'BMA_MET') | strcmp(varargin, 'BMA_OWL') | ...
        strcmp(varargin, 'FT_sourcePoints') | strcmp(varargin, 'FT_plotTimePoints') | ...
        strcmp(varargin, 'sourceROIatlas');
        
    idxSource = find(sourceInput);
    idxSource = sort([idxSource, idxSource+1]);
    sourceInput = varargin(idxSource);
    sourceInput(end+1:end+length(constantFields)) = constantFields;

    params.finalSourceStepPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/SourceTransformation/Step2_SourceAvgROI';%
    %Runs the source transformation step (channelsToSource, and sourceAvgROI)
    [sourceStatus, finalSourceStepPath, sourceParams] = f_mainSourceTransformation(databasePath, params.finalNormStepPath, ...
        params.runChansToSource, params.runSourceAvgROI, sourceInput{:});
    params.finalSourceStepPath = finalSourceStepPath;
end

params.finalSourceStepPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/SourceTransformation/Step2_SourceAvgROI';%


%% CONNECTIVITY METRICS
%Check that the sourceTransformationStep could be completed
if sourceStatus == 0
    disp('ERROR: Could not complete the source transformation steps. Cannot continue with the main pipeline');
    return
end

connectivityStatus = 1;
%If the runConnectivity step is not required by the user, do not run it
if params.runConnectivity
    
    %If no path was given as finalSourceStepPath, try and add the expected path given the prepro, or the signalType
    if isempty(params.finalSourceStepPath)
        
        %If the source transformation was run, updates BIDSmodality, BIDStask and/or newPath if they were updated
        if exist('sourceParams', 'var')
            params.finalSourceStepPath = finalSourceStepPath;
            finalSourceStepPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/SourceTransformation/Step2_SourceAvgROI';
            constantFields = {'BIDSmodality', sourceParams.BIDSmodality, 'BIDStask', sourceParams.BIDStask, 'newPath', sourceParams.newPath};
            
        %In any other case, try and find where the .sets should be
        else
            
            %If the user entered a 'newPath', try and define the expectedPath
            if ~isempty(params.newPath)
                expectedfinalSourceStepPath = fullfile(params.newPath, 'SourceTransformation', 'Step2_SourceAvgROI');
                
            %In any other case, define the default output fprepro_analysis_unkns
            else
                expectedfinalSourceStepPath = fullfile(databasePath, 'analysis_RS', 'SourceTransformation', 'Step2_SourceAvgROI');
            end

            
            %If there is any expectedPath, Assume that the source transformed .sets are located in the default path were they should be saved
            if exist(expectedfinalSourceStepPath, 'dir')
                disp('WARNING: Assuming that the fprepro_analysis_unkn were the .sets that you want to analyse after source transformation are located in:');
                disp(expectedfinalSourceStepPath);
                disp('Do you want to continue analysing those fprepro_analysis_unkns? (y/n)');
                assumePreproPath = input('', 's');

                if strcmpi(assumePreproPath, 'y')
                    params.finalSourceStepPath = expectedfinalSourceStepPath;
                else
                    %If the path is not the expected, ask the user to enter the path
                    disp('Please paste the path of the step fprepro_analysis_unkn containing the .sets that you want to analyse, or press "q" to exit');
                    newSourcePath = input('', 's');
                    if strcmpi(newSourcePath, 'q')
                        disp('ERROR: Ending the pipeline before the connectivity metrics step');
                        return
                    else 
                        params.finalSourceStepPath = newSourcePath;
                    end
                end
                
            end
            
            %Finally, updates the constantFields with the path given
            params.finalSourceStepPath = '/data/VoiceLab/Users/U10 - Jhosmary Cuadros Castro/JCC/General_Code/prepro_analysis/analysis_RS/SourceTransformation/Step2_SourceAvgROI';%
            sourcePathParts = strsplit(params.finalSourceStepPath, filesep);
            if length(sourcePathParts) < 3
                disp('ERROR: The finalSourceStepPath is expected to follow the directory structure: newPath/SourceTransformation/Step2_SourceAvgROI');
                return
            end
            constantFields = {'BIDSmodality', params.BIDSmodality, 'newPath', fullfile(sourcePathParts{1:end-2})};
            if ~isempty(params.BIDStask)
                constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
            end
        end

    %If the user gives a params.finalSourceStepPath, update the newPath to be two directories up
    %(the expected directory structure is 'newPath/Normalization/Step2_PatientControlNorm')
    else
        sourcePathParts = strsplit(params.finalSourceStepPath, filesep);
        if length(sourcePathParts) < 3
            disp('ERROR: The finalSourceStepPath is expected to follow the directory structure: newPath/SourceTransformation/Step2_SourceAvgROI');
            return
        end
        constantFields = {'BIDSmodality', params.BIDSmodality, 'newPath', fullfile(sourcePathParts{1:end-2})};
        if ~isempty(params.BIDStask)
            constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
        end
    end


    %Check that the finalSourceStepPath exists
    if ~exist(params.finalSourceStepPath, 'dir')
        disp('ERROR: The path you entered as the final source transformation step does not exist:');
        disp(params.finalSourceStepPath);
        disp('Please enter a valid path using the key ''finalSourceStepPath'' and run the main pipeline script again');
        return
    end

    
    %TODO: A�adir las m�tricas de frecuencia
    %Define the parameters used for the connectivity step
    connectivityInput = strcmp(varargin, 'runConnectivity') | strcmp(varargin, 'connIgnoreWSM');
    idxConnectivity = find(connectivityInput);
    idxConnectivity = sort([idxConnectivity, idxConnectivity+1]);
    connectivityInput = varargin(idxConnectivity);
    connectivityInput(end+1:end+length(constantFields)) = constantFields;

    %Runs the connectivity step
    [connectivityStatus, finalConnectStepPath, connectivityParams] = f_mainConnectivity(databasePath, ...
        params.finalSourceStepPath, connectivityInput{:});
    params.finalConnectStepPath = finalConnectStepPath;
end

%% CLASSIFIER
%Check that the connectivityStatus could be completed
if connectivityStatus == 0
    disp('ERROR: Could not complete the connectivity steps. Cannot continue with the main pipeline');
    return
end

classifierStatus = 1;
%If the runClassifier step is not required by the user, do not run it
if params.runClassifier
    
    %If no path was given as finalConnectStepPath, try and add the expected path given the prepro, or the signalType
    if isempty(params.finalConnectStepPath)
        
        %If the connectivity was run, updates BIDSmodality, BIDStask and/or newPath if they were updated
        if exist('connectivityParams', 'var')
            params.finalConnectStepPath = finalConnectStepPath;
            constantFields = {'BIDSmodality', connectivityParams.BIDSmodality, 'BIDStask', connectivityParams.BIDStask, 'newPath', connectivityParams.newPath};
            
        %In any other case, try and find where the .sets should be
        else
            
            %If the user entered a 'newPath', try and define the expectedPath
            if ~isempty(params.newPath)
                expectedfinalConnectStepPath = fullfile(params.newPath, 'Connectivity', 'Step1_ConnectivityMetrics');
                
            %In any other case, define the default output fprepro_analysis_unkns
            else
                expectedfinalConnectStepPath = fullfile(databasePath, 'analysis_RS', 'Connectivity', 'Step1_ConnectivityMetrics');
            end

            
            %If there is any expectedPath, Assume that the connectivity .sets are located in the default path were they should be saved
            if exist(expectedfinalConnectStepPath, 'dir')
                disp('WARNING: Assuming that the fprepro_analysis_unkn were the .sets that you want to analyse after connectivity metrics are located in:');
                disp(expectedfinalConnectStepPath);
                disp('Do you want to continue analysing those fprepro_analysis_unkns? (y/n)');
                assumePreproPath = input('', 's');

                if strcmpi(assumePreproPath, 'y')
                    params.finalConnectStepPath = expectedfinalConnectStepPath;
                else
                    %If the path is not the expected, ask the user to enter the path
                    disp('Please paste the path of the step fprepro_analysis_unkn containing the .sets that you want to analyse, or press "q" to exit');
                    newConnectivityPath = input('', 's');
                    if strcmpi(newConnectivityPath, 'q')
                        disp('ERROR: Ending the pipeline before the connectivity metrics step');
                        return
                    else 
                        params.finalConnectStepPath = newConnectivityPath;
                    end
                end
                
            end
            
            %Finally, updates the constantFields with the path given
            connectivityPathParts = strsplit(params.finalConnectStepPath, filesep);
            if length(connectivityPathParts) < 3
                disp('ERROR: The finalConnectStepPath is expected to follow the directory structure: newPath/Connectivity/Step1_ConnectivityMetrics');
                return
            end
            constantFields = {'BIDSmodality', params.BIDSmodality, 'newPath', fullfile(connectivityPathParts{1:end-2})};
            if ~isempty(params.BIDStask)
                constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
            end
        end

    %If the user gives a params.finalConnectStepPath, update the newPath to be two directories up
    %(the expected directory structure is 'newPath/Normalization/Step2_PatientControlNorm')
    else
        connectivityPathParts = strsplit(params.finalConnectStepPath, filesep);
        if length(connectivityPathParts) < 3
            disp('ERROR: The finalConnectStepPath is expected to follow the directory structure: newPath/Connectivity/Step1_ConnectivityMetrics');
            return
        end
        constantFields = {'BIDSmodality', params.BIDSmodality, 'newPath', fullfile(connectivityPathParts{1:end-2})};
        if ~isempty(params.BIDStask)
            constantFields(end+1:end+2) = {'BIDStask', params.BIDStask};
        end
    end


    %Check that the finalConnectStepPath exists
    if ~exist(params.finalConnectStepPath, 'dir')
        disp('ERROR: The path you entered as the final connectivity step does not exist:');
        disp(params.finalConnectStepPath);
        disp('Please enter a valid path using the key ''finalConnectStepPath'' and run the main pipeline script again');
        return
    end


    %TODO: Modificar par�metros del step de Classifier
    %Define the parameters used for the classifier step
    classifierInput = strcmp(varargin, 'runClassifier') | strcmp(varargin, 'runFeatureSelection') | ...
        strcmp(varargin, 'classDxComparison') | strcmp(varargin, 'classNumPermutations') | ...
        strcmp(varargin, 'classSignificance') | strcmp(varargin, 'classCrossValFolds');
    idxClassifier = find(classifierInput);
    idxClassifier = sort([idxClassifier, idxClassifier+1]);
    classifierInput = varargin(idxClassifier);
    classifierInput(end+1:end+length(constantFields)) = constantFields;

    %Runs the classifier step
    [classifierStatus, finalClassifierStepPath, classifierParams] = f_mainClassifier(databasePath, ...
        params.finalConnectStepPath, classifierInput{:});
    params.finalClassifierStepPath = finalClassifierStepPath;
    
    
    %End of the pipeline
    if classifierStatus == 0
        disp('ERROR: Could not complete the classifier step');
    else
        disp('End of the pipeline!');
    end
end