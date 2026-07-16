function [status, sourceMat] = f_mainChansToSource(setPath, setName, sourceTransfMethod, saveStruct, varargin)
%Description:
%Function that performs the transformation from electrode-channels to source level using an average brain
%INPUTS:
%setPath            = Path of the .set that the user wants to transform to a source level
%setName            = Name of the .set that the user wants to transform to a source level
%sourceTransfMethod = String with the method to calculate the source transformation ('BMA' by default)
%       NOTE: The current version only has BMA, FT_eLoreta and FT_MNE, but more methods could be added
%saveStruct         = "Struct" Matlab type file containing two fields:
%                       Path:  Path to save the solutions 
%                       Name:  Name to save the solutions
%   FOR BMA: It will save a .txt of [nSourcePoints x nTimes, 1],
%       and will save a 'Name-MC3.mat' or 'Name-OW.mat' with nTimes BMA# variables .mat
%   FOR FT_eLoreta or FT_MNE: It will save a .txt of [nSourcePoints x nTimes, 1],
%       and will save a '.fig' if the plotting option is used
%
%OPTIONAL INPUTS FOR BMA SOURCE TRANSFORMATION:
%BMA_MCwarming      = Integer with the warming length of the Markov Chain for source transformation (4000 by default)
%BMA_MCsamples      = Integer with the number of samples from the Monte Carlo Markov Chain sampler for source transformation (3000 by default)
%BMA_MET:           = String with the method of preference for exploring the models space:
%           If MET=='OW', the Occam's Window algorithm is used.
%           If MET=='MC', The MC3 is used (Default).
%BMA_OWL:           = Integer with the Occam's window lower bounds 
%           [3-Very Strong, 20-strong, 150-positive, 200-Weak] (3 by default)
%
%OPTIONAL INPUTS FOR FIELDTRIP SOURCE TRANSFORMATION:
%FT_sourcePoints    = Integer with the desired number of source points (5124 or 8196)
%       NOTE: 5124 defined as default because it takes less memory, while producing acceptable results
%FT_plotTimePoints  = Empty if the user does not want to plot anything at source level (by default)
%       NOTE: Can be an integer with the single time in seconds to be visualized, 
%       or can be a vector with [begin, end] times in seconds to be averaged and visualized
%
%OUTPUTS:
%status             = 1 if the script was completed successfully, 0 otherwise
%sourceMat          = Structure with a .data Matrix of [nSourcePoints, nTimes] with the data already transformed to a source level
%And saved .txt, some .mat, .png and/or .fig (All optional and pretty much additional). 
%NOTE: The important structure (sourceMat) to save will be saved in f_mainSourceTransformation


%Defines the default outputs
status = 0;
sourceMat = [];

%Defines the default inputs
if nargin < 3 || isempty(sourceTransfMethod)
    sourceTransfMethod = 'BMA';
end
if nargin < 4 || isempty(saveStruct)
    disp('ERROR: A structure with fields Path and Name are needed to save the .mat, .txt and/or .fig created');
    return;
end

%Defines the default optional parameters
%Type help finputcheck to know more about it. Basically it takes the inputs, makes sure everything is okay 
%and puts that information as a structure
params = finputcheck( varargin, {'BIDSmodality',        'string',               '',         'meg'; ...
                                'BIDStask',             'string',               '',         'task-rest';
                                'BMA_MCwarming',        'float',                [0, inf],   4000;
                                'BMA_MCsamples',        'float',                [0, inf],   3000;
                                'BMA_MET',              'string',               '',         'MC';
                                'BMA_OWL',              'float',                [0, inf],   3;
                                'FT_sourcePoints',      'float',                '',         5124;
                                'FT_plotTimePoints',    {'float', 'integer'},   [],         [];
                                } ...
                                );
                            
%Checks that the defaults where properly created
if ischar(params) && startsWith(params, 'error:')
    disp(params);
    return
end


%Checks that sourceTransfMethod have valid values
if ~ (strcmpi(sourceTransfMethod, 'BMA') || strcmpi(sourceTransfMethod, 'FT_eLoreta') ...
        || strcmpi(sourceTransfMethod, 'FT_MNE'))
    disp('ERROR: The only current valid value for sourceTransfMethod are BMA, FT_eLoreta and FT_MNE');
    return
end

%If a task of RS is given, let the user know that it is recommended to use one fo the FieldTrip methods to speed up the analysis
if strcmpi(sourceTransfMethod, 'BMA') && ( strcmpi(params.BIDStask, 'task-RS') || contains(params.BIDStask, 'RS', 'IgnoreCase',true) || ...
    strcmpi(params.BIDStask, 'task-rest') || contains(params.BIDStask, 'rest', 'IgnoreCase',true))
    disp('WARNING: It seems that the signal analyzed was acquired during a Resting State task');
    disp('TIP: It is recommended to use one of the FieldTrip methods to speed up the source transformation step');
    disp('Please press "y" to use the FT_eLoreta method, or any other key to continue with BMA instead');
    changeToLoreta = input('', 's');
    if strcmpi(changeToLoreta, 'y')
        sourceTransfMethod = 'FT_eLoreta';
        disp('WARNING: Method for source transformation changed to FT_eLoreta');
    end
end



%If everything is okay, load the .set to transform from channels-electrodes to source-level
EEG = pop_loadset('filename', setName, 'filepath', setPath);
nChans = EEG.nbchan;


fprintf('Running a Source Transformation using: %s\n', sourceTransfMethod);
%If the transformation method chosen was BMA, run it's corresponding script
if strcmpi(sourceTransfMethod, 'BMA')
    %Checks that the BMA parameters are correctly defined
    if ~ (strcmpi(params.BMA_MET, 'MC') || strcmpi(params.BMA_MET, 'OW'))
        disp('ERROR: The only current valid values for BMA_MET are MC and OW');
        return
    end
    
    %The current version of the pipeline only supports data with one trial. Checks that requirement
    if EEG.trials > 1 || length(size(EEG.data)) > 2
        disp('WARNING: The current version of the BMA pipeline only supports data with one trial');
        disp('TIP: It would take a lot of time to run BMA on multiple trials');
        disp('Please press "y" to run the FT_eLoreta method instead, or any other key to quit the pipeline');
        runELoreta = input('', 's');
        if strcmpi(runELoreta, 'y')
            sourceTransfMethod = 'FT_eLoreta';
            disp('WARNING: Running eLoreta instead of BMA');
            [status, sourceMat] = f_mainChansToSource(setPath, setName, sourceTransfMethod, saveStruct, ...
                'FT_sourceMethod', params.FT_sourceMethod, ...              %Optional FieldTrip parameters
                'FT_sourcePoints', params.FT_sourcePoints, 'FT_plotTimePoints', params.FT_plotTimePoints);
        end
        return
    end
    
    %Adds the 'BMA' folder path to use the functions inside it
    currentPath = mfilename('fullpath');
    [currentPath, ~, ~] = fileparts(currentPath);
    addpath(fullfile(currentPath, 'BMA'))
    
    %Defines the data to be transformed
    cp = double(EEG.data);
    
    %Loads the surface model containing an AAL atlas of 116 regions
    headModelName = 'models_surface_aal(6000).mat';
    models = load(fullfile(currentPath, 'BMA', 'Images', headModelName));
    models = models.models;
    mod = 1:size(models,2);
    
    %Loads the Lead Field matrix (Ke) and the Laplacian matrix (Le) depending on the original number of channels
    if nChans == 128
        KeLeName = 'EEG_Sur_5656_128_Biosemi.mat';
        nSourcePoints = 5656;       %Number of points in the source level
        disp('Assuming a BioSemi128 Layout');
    elseif nChans == 64
        KeLeName = 'EEG_Sur_5656_64_Biosemi.mat';
        nSourcePoints = 5656;       %Number of points in the source level
        disp('Assuming a BioSemi64 Layout');
    else
        disp('ERROR: Currently, the pipeline only considers models for BioSemi64 and BioSemi128');
        fprintf('The current number of channels for the given subject is: %d', nChans);
        return
    end
    KeLeorig = load(fullfile(currentPath, 'BMA', 'LeadField', KeLeName));
    KeLe.Ke = KeLeorig.Ke;
    KeLe.Le = KeLeorig.Le;

    %Defines other parameters needed by the BMA_fMRIG (for more info, consult the documentation of the function)
    VS = 'surface'; % 'volume'
    TF = 'time';
    format = 'txt';
    Options(1) = 0;
    Options(2) = 0;
    model0 = [];
    
    %Runs the function that performs the transformation from channels-electrodes to source level
    %Saves a [nTimes x nSourcePoints, 1] .txt and a -MC3.mat or -OW.mat [nTimes BMA# variables]
    disp('Transforming the data to a source-level. This will take a while...');
    BMA_fMRIG(models, mod, KeLe, cp, params.BMA_MCwarming, params.BMA_MCsamples, Options, model0, ...
        saveStruct, params.BMA_MET, params.BMA_OWL, VS, TF, format, 0);
    
    
    %Loads the info of the .txt created by BMA_fMRIG, and reshapes the data to be in [nSourcePoints, time]
    sourceData = load(fullfile(saveStruct.Path, saveStruct.Name));
    sourceData = reshape(sourceData(:), nSourcePoints, []);
     
    %Creates an EEG-like structure
    sourceMat.leadFieldName = KeLeName;
    sourceMat.headModelName = headModelName;
    sourceMat.BMA_MCwarming = params.BMA_MCwarming;
    sourceMat.BMA_MCsamples = params.BMA_MCsamples;
    sourceMat.BMA_MET = params.BMA_MET;
    sourceMat.BMA_OWL = params.BMA_OWL;
    
    
elseif strcmpi(sourceTransfMethod, 'FT_eLoreta') || strcmpi(sourceTransfMethod, 'FT_MNE')
    %If the transformation method chosen was one of FieldTrip (eLoreta or MNE), run it's corresponding script
    [status, sourceData] = f_FieldTripSource(EEG, saveStruct, sourceTransfMethod, params.FT_sourcePoints, params.FT_plotTimePoints);
    if status == 0
        disp('ERROR: Could not complete the source transformation using the FieldTrip method');
    end
    
end

%Adds the results of the source transformation to the EEG-like structure
sourceMat.sourceTransfMethod = sourceTransfMethod;
sourceMat.data = single(sourceData);
sourceMat.srate = EEG.srate;
if size(sourceData, 2) == length(EEG.times)
    sourceMat.times = EEG.times;
else
    disp('WARNING: Reconstructing the time window due to time points that could not be reconstructed. Assuming continuous points');
    sourceMat.times = (0: 1/EEG.srate : (size(sourceData, 2)-1)/EEG.srate) .*1000;    %*1000 because EEG.times MUST BE in ms
end
sourceMat.comments = EEG.comments;
sourceMat.originalEEGname = setName;
sourceMat.originalEEGpath = setPath;

%If it reached this far, the script was completed succesfully
status = 1;


end