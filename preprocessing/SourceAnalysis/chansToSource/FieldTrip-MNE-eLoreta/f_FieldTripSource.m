function [status, sourceData] = f_FieldTripSource(EEG, saveStruct, FT_sourceMethod, FT_sourcePoints, FT_plotTimePoints)
%Description:
%Function that performs source transformation using a FieldTrip-based algorithm
%INPUTS:
%EEG                = EEGLab structure with the data of the subject to source transform
%saveStruct         = "Struct" Matlab type file containing two fields:
%                       Path:  Path to save the solutions 
%                       Name:  Name to save the solutions
%   FOR FT_eLoreta or FT_MNE: It will save a .txt of [nSourcePoints x nTimes, 1],
%       and will save a '.fig' if the plotting option is used
%FT_sourceMethod    = String with the desired FieldTrip method (FT_eLoreta or FT_MNE)
%       NOTE: FT_eLoreta defined as default because it seemed to produce better results
%FT_sourcePoints    = Integer with the desired number of source points (5124 or 8196)
%       NOTE: 5124 defined as default because it takes less memory, while producing acceptable results
%FT_plotTimePoints  = Empty if the user does not want to plot anything at source level (by default)
%       NOTE: Can be an integer with the single time in seconds to be visualized, 
%       or can be a vector with [begin, end] times in seconds to be averaged and visualized
%OUTPUTS:
%status             = 1 if the script was completed successfully, 0 otherwise
%sourceData         = Matrix of [nSourcePoints, nTimes] with the data already transformed to a source level
%And saved .txt and/or .fig (All optional and pretty much additional)
%NOTE: The important structure (sourceMat) to save will be created in f_mainChansToSource

%Defines the default outputs
status = 0;
sourceData = [];

%Defines the default inputs
if nargin < 2
    FT_sourceMethod = 'FT_eLoreta';
end
if nargin < 3
    FT_sourcePoints = 5124;
end
if nargin < 4
    FT_plotTimePoints = [];
end

%% FieldTrip preparation, and co-registration with template MRI
%Checks that FieldTrip is correctly installed
try
    [ftVer, ftPath] = ft_version;
catch
    disp('ERROR: You must have FieldTrip installed before using this source transformation option');
    disp('To correctly install FieldTrip, please check the following two links:');
    disp('https://www.fieldtriptoolbox.org/download/');
    disp('https://www.fieldtriptoolbox.org/faq/should_i_add_fieldtrip_with_all_subdirectories_to_my_matlab_path/');
    return
end

%Gets the path of the EEGLab version being used
eegLabPath = which('eeglab.m');
eegLabPath = strsplit(eegLabPath, filesep);
eegLabPath = fullfile(eegLabPath{1:end-1});

%Modifies the channel locations to a readable format by FieldTrip
if length(EEG.chanlocs) == 128
    disp('WARNING: Assuming that the layout was a BioSemi128');
    
    %Tries to create a .xyz file for Biosemi128 (if it doesn't exist yet)
    [mainPath, ~, ~] = fileparts(mfilename('fullpath'));
    mainPath = strsplit(mainPath, filesep);
    channelsCodePath = fullfile(mainPath{1:end-3}, 'Normalization', 'Channels');
    allPaths = path;                %path gets all the added paths
    if ~ismember(channelsCodePath, strsplit(allPaths, ';'))
        addpath(channelsCodePath);
    end
    nChans = 128;
    headSizeCms = 55;
    biosemi128xyz = sprintf('BioSemi%d_HeadCirc%dcms.xyz', nChans, headSizeCms);
    if ~exist(fullfile(channelsCodePath, biosemi128xyz), 'file')
        %Creates the original .xyz Biosemi Layout for the given NChans and given headSize
        f_createBiosemiXyz(num2str(nChans), headSizeCms, channelsCodePath, biosemi128xyz);
    end
    
    EEG = pop_chanedit(EEG, 'lookup', fullfile(channelsCodePath, biosemi128xyz));
    chanFile = fullfile(channelsCodePath, biosemi128xyz);
    EEG = eeg_checkset( EEG );
else
    EEG = pop_chanedit(EEG, 'lookup', fullfile(eegLabPath, 'plugins', 'dipfit', 'standard_BEM', 'elec', 'standard_1005.elc'));
    chanFile = fullfile(eegLabPath, 'plugins', 'dipfit', 'standard_BEM', 'elec', 'standard_1005.elc');
    EEG = eeg_checkset( EEG );
end

%Calculates the co-registration using a standard MRI model
hdmFile = fullfile(eegLabPath, 'plugins', 'dipfit', 'standard_BEM', 'standard_vol.mat');
mriFile = fullfile(eegLabPath, 'plugins', 'dipfit', 'standard_BEM', 'standard_mri.mat');
EEG = pop_dipfit_settings( EEG, 'hdmfile',hdmFile, 'coordformat','MNI', 'mrifile', mriFile, 'chanfile',chanFile, 'coord_transform',[0 0 0 0 0 -1.5708 1 1 1], 'chansel',[1:EEG.nbchan] );
EEG = eeg_checkset( EEG );

%Removes general info to avoid errors when transforming to FieldTrip
EEG.subject = '';
EEG.condition = '';
EEG.group = '';
EEG.session = [];

%% Surface Source estimation
%Transforms data from EEGLab to FieldTrip
dataPre = eeglab2fieldtrip(EEG, 'preprocessing', 'dipfit');   % convert the EEG data structure to fieldtrip

%Basic pre-processing (should already be pre-processed tho)
cfg = [];
cfg.channel = {'all'};
cfg.reref = 'yes';
cfg.refchannel = {'all'};
dataPre = ft_preprocessing(cfg, dataPre);

%Defines the data that will enter the source estimation step
if EEG.trials > 1
    %Uses covariance of trials prior to source estimation
    cfg                  = [];
    cfg.covariance       = 'yes';
    cfg.covariancewindow = [EEG.xmin 0]; % calculate the average of the covariance matrices
                                       % for each trial (but using the pre-event baseline  data only)
    dataAvg = ft_timelockanalysis(cfg, dataPre);
    
else
    %If the data only has one trial, don't do anything. Just assign
    dataAvg = dataPre;
end

%Defines the number of points that will be used
if FT_sourcePoints == 8196 || strcmp(FT_sourcePoints, '8196')
    %Original sourcemodel had 8196 points (too much memory)
    sourcemodel = ft_read_headshape(fullfile(ftPath, 'template', 'sourcemodel', 'cortex_8196.surf.gii'));
elseif FT_sourcePoints == 5124 || strcmp(FT_sourcePoints, '5124')
    %Decided to use 5124 points instead
    sourcemodel = ft_read_headshape(fullfile(ftPath, 'template', 'sourcemodel', 'cortex_5124.surf.gii'));
else
    disp('ERROR: The current version of the FieldTrip Source Transformation only supports meshes of 5124 or 8196 points');
    return
end
fprintf('Performing source transformation for %d points \n', FT_sourcePoints);


%Loads the volumen used for the preparation step
vol = load('-mat', EEG.dipfit.hdmfile);

%Prepares the leadfield parameter
cfg           = [];
cfg.grid      = sourcemodel;    % source points
cfg.headmodel = vol.vol;        % volume conduction model
leadfield = ft_prepare_leadfield(cfg, dataAvg);

%% Source analysis using MNE or eLoreta
%Performs the source transformation using the desired method
if strcmpi(FT_sourceMethod, 'FT_MNE')
    cfg               = [];
    cfg.method        = 'mne';
    cfg.grid          = leadfield;
    cfg.headmodel     = vol.vol;
    cfg.mne.prewhiten = 'yes';
    cfg.mne.lambda    = 3;
    cfg.mne.scalesourcecov = 'yes';
    source            = ft_sourceanalysis(cfg, dataAvg);

elseif strcmpi(FT_sourceMethod, 'FT_eLoreta')
    cfg               = [];
    cfg.method        = 'eloreta';
    cfg.grid          = leadfield;
    cfg.headmodel     = vol.vol;
    source            = ft_sourceanalysis(cfg, dataAvg);
end

%% Source quantification
%source.avg has the data of interest
%source.avg.pow seems to have Frequency power NOT time data [nSourcePoints, nTimePoints]
%source.avg.mom is a cell of {1, nSourcePoints} with the momentum orientation of each surface point [3, nTimePoints]

%Checks that the number of source points are the expected
nSourcePoints = length(source.avg.mom);
if FT_sourcePoints ~= nSourcePoints
    fprintf('ERROR: FATAL ERROR. It should be a problem with the FieldTrip Toolbox. %d points were expected, but %d were created \n', FT_sourcePoints, nSourcePoints);
    return
end


%Defines the source data as a .txt vector of [nSourcePoints x nTimes, 1] using the saveStruct
fileID = fopen(fullfile(saveStruct.Path, saveStruct.Name), 'w');
%Estimates the activity for each timepoint and each source point using the momentum information
%NOTE: Length of momentum was fixed as method of quantification because it seemed to produce better results
sourceData = nan(nSourcePoints, EEG.pnts);
sourceMomEstim = 'length';          %'largest' or 'length'
nanSpacePoints = [];
disp('Saving the results for each time point in a .txt. This will take a couple of minutes...');
for i = 1:nSourcePoints
    iMom = source.avg.mom{i};
    
    if isempty(iMom)
        nanSpacePoints = [nanSpacePoints, i];
        fprintf('WARNING: Could not reconstruct to a source level at the space point number %d\n', i);
        continue
    end
    
    if strcmp(sourceMomEstim, 'largest')
    
        %According to a mailing list of 2011 (https://mailman.science.ru.nl/pipermail/fieldtrip/2011-August/030064.html)
        %A way to quantify is taking the direction that explains most of the source variance. 
        %That is equivalent to taking the largest eigenvector of the source timeseries 
        %(which is a phrasing that is often used in papers, also on combining fMRI bold timeseries over multiple voxels).

        [~, ~, v] = svd(iMom, 'econ'); 
        sourceData(i, :) = v(:,1);

        %But it seems to have a sign ambiguity

    elseif strcmp(sourceMomEstim, 'length')
        %Alternatively, one can take the strength over all three directions for each timepoint.
        sourceData(i,:) = sqrt(sum(iMom.^2,1));
    end
    
    fprintf(fileID, '%.4f\n', sourceData(i,:));
end

%Convert them to single to save some memory
sourceData = single(sourceData);
fclose(fileID);

%% Handles the time-points that could not be reconstructed
nanTolerance = 0.03;        %Percentage of timepoints that are acceptable to lose
if length(nanSpacePoints)/nSourcePoints > nanTolerance
    %If more than nanTolerance (3% by default) of the space-points could not be reconstructed, send a warning
    fprintf('WARNING: Could not reconstruct more than %d%% of the signal space points (%.4f)\n', round(nanTolerance*100), length(nanSpacePoints)/nSourcePoints);
    disp('WARNING: Lack of those time points could affect the results obtained');
    disp('Please press "y" to continue without those space points (NOT RECOMMENDED), or any other key to discard the source estimation');
    ignoreWarning = input('', 's');
    
    if ~strcmpi(ignoreWarning, 'y')
        disp('ERROR: Could not reconstruct the signal in a source level in multiple time points. NOT RECONSTRUCTING');
        return
    end
    
    fprintf('WARNING: Continuing without those space points, even though it has more than %d%% of space points missing \n', round(nanTolerance*100));
end

%If less than the nanTolerance was obtained, or if the user ignored the warning, remove the timepoints with NaNs
fprintf('WARNING: Missing %.4f%% of the space points. It could affect the results obtained \n', (length(nanSpacePoints)/nSourcePoints)*100);


%% Plot to visualize the results (Would only do it for a given time point, or an average time window)

%If the user entered a non-empty array, create its corresponding plot
if ~isempty(FT_plotTimePoints)
    %Define the final source time points in seconds
    sourceTimes = (0: 1/EEG.srate : (size(sourceData, 2)-1)/EEG.srate);
    
    %If only one number is given, plot that time point
    if length(FT_plotTimePoints) == 1 && isnumeric(FT_plotTimePoints)
        %Looks for the closest time point (in seconds) to the one desired
        [~, pointToPlot] = min(abs(FT_plotTimePoints - sourceTimes));
        
        %Defines the source activity at the desired time point to be plotted
        m = sourceData(:, pointToPlot);
        figName = sprintf('%s_%dPoints_%.3fsTimePoint', FT_sourceMethod, FT_sourcePoints, FT_plotTimePoints);
        
    %If two numbers are given, average the window between those timepoints, and plot it
    elseif length(FT_plotTimePoints) == 2 && isnumeric(FT_plotTimePoints)
        %Checks that the second timepoint is greater than first
        if FT_plotTimePoints(1) > FT_plotTimePoints(2)
            %If the input was not valid, send a warning, end the script but change the status as completed (1)
            disp('WARNING: Could not plot the average of the timepoints given because the first number is greater than the second');
            disp('TIP: FT_plotTimePoints should be defined as [begin, end] in seconds');
            status = 1;
            return
        end
        
        %Looks for the closest time points (in seconds) to the ones desired
        [~, pointToPlot1] = min(abs(FT_plotTimePoints(1) - sourceTimes));
        [~, pointToPlot2] = min(abs(FT_plotTimePoints(2) - sourceTimes));
        
        timeToAvg = [pointToPlot1:pointToPlot2];
        m = mean(sourceData(:, timeToAvg), 2);
        figName = sprintf('%s_%dPoints_%.3f-%3fsTimePoint', FT_sourceMethod, FT_sourcePoints, FT_plotTimePoints);
    else
        
        %If an invalid input was given, send a warning, end the script but mark it as completed (1)
        disp('WARNING: Could not plot the source activity because the input was non-empy and not either one number or two');
        status = 1;
        return
    end
    
    %Plot the source activity in the desired time point/averaged time points
    figure('name', figName);
    ft_plot_mesh(source, 'vertexcolor', m);
    view([180 0]); h = light; set(h, 'position', [0 1 0.2]); lighting gouraud; material dull
    colorbar, colormap jet %caxis([0 0.035])%([-1, 1].*10^-6)
    
    %Save the figure using the saveStruct
    figName = strcat(saveStruct.Name(1:end-4), '_', figName, '.fig');
    fig1 = gcf;
    saveas(fig1, fullfile(saveStruct.Path, figName));
    close(fig1);
end

%If it made it this far, the script was completed succesfully
status = 1;

end