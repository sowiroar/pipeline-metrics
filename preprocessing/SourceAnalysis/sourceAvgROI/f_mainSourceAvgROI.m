function [status, roiMat] = f_mainSourceAvgROI(pathStep1, nameStep1, sourceROIatlas, saveStructTxt)
%Description:
%Function that performs averaging of the source level by regions defined by ROI
%INPUTS:
%pathStep1      = Path of the channels to source step where the .mat should be 
%nameStep1      = Name of the channels to source step of the .mat
%sourceROIatlas = String with the name of the Atlas that the user wants to use ('AAL-116' by default)
%saveStructTxt  = "Struct" Matlab type file containing two fields:
%                       Path:  Path to save the solutions 
%                       Name:  Name to save the solutions
%           It will save a .txt of [nTimes x nROIs, 1],
%           and a will save a 'Name-ROInames.mat' with a cell of [nROIs] with the ROIs names
%OUTPUTS:
%status         = 1 if the script was completed successfully
%roiMat         = Structure with a .data matrix of [nROIs, nTimes] with the data already averaged by ROIs at a source level

%Defines the default outputs
status = 0;
roiMat = [];

%Defines the default inputs
if nargin < 3 || isempty(sourceROIatlas)
    sourceROIatlas = 'AAL-116';
end

%Checks that sourceROIatlas have valid values
if ~strcmp(sourceROIatlas, 'AAL-116')
    disp('ERROR: The only atlas currently supported is AAL-116');
    disp('TIP: IF you want to add another atlas, modify f_mainSourceAvgROI');
    return
end

%Loads the .mat of the previous step
sourceMat = load(fullfile(pathStep1, nameStep1));
sourceMat = sourceMat.EEG_like;
sourceData = sourceMat.data;
nSourcePoints = size(sourceData,1);

%Currently, there are only two cases: The source data was created using BMA or FieldTrip
if strcmpi(sourceMat.sourceTransfMethod, 'BMA')
    %Load the .mat with information to move from the source space to average ROIs
    %NOTE: For BMA, the mapping from source points to ROI must be created manually
    %NOTE: Currently, for BMA only mapping from 5656 points to AAL-116 is available
    reg2 = load(fullfile('ROIatlas', strcat(sourceROIatlas, '.mat')));
    indicesT_Reg = [];      %For each nSourcePoint, identifies its corresponding each non-empty region

    %Label each nSourcePoint by region
    for i=1:length(reg2.roi)
        iROI = reg2.roi(i);
        if ~isempty(iROI.indices)
            indicesT_Reg(end+1:end+length(iROI.indices)) = i;
        end
    end
    
    %Defines the roiNames
    roiNames = {reg2.roi(:).names};
    
    
    
elseif strcmpi(sourceMat.sourceTransfMethod, 'FT_eLoreta') || strcmpi(sourceMat.sourceTransfMethod, 'FT_MNE')
    %If the method was any of the FieldTrip options, use another FieldTrip function to average per ROI
    
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
    
    %Read the atlas (AAL-116)
    atlas = ft_read_atlas(fullfile(ftPath, 'template', 'atlas', 'aal', 'ROI_MNI_V4.nii'));
    
    %Read the mesh used
    if nSourcePoints == 8196
        sourcemodel = ft_read_headshape(fullfile(ftPath, 'template', 'sourcemodel', 'cortex_8196.surf.gii'));
    elseif nSourcePoints == 5124
        sourcemodel = ft_read_headshape(fullfile(ftPath, 'template', 'sourcemodel', 'cortex_5124.surf.gii'));
    else
        fprintf('ERROR: The FieldTrip option should only produce source transformations of 8196 or 5124, not %d', nSourcePoints);
    end
    
    %Interpolates from the sourcemodel grid used to the atlas chosen
    cfg = [];
    cfg.interpmethod = 'nearest';   %nearest
    cfg.parameter = 'tissue';
    [interp] = ft_sourceinterpolate(cfg, atlas, sourcemodel);
    
    
    %Loads the ROIs used for AAL-116 (82 regions)
    roiNames = load(fullfile('ROIatlas', strcat(sourceROIatlas, '_usedROIs.mat')));
    roiNames = roiNames.roiNames;
    
    %Looks for the ROIs labels that correspond to the 82 regions desired for AAL-116
    nRois = length(roiNames);
    indicesT_Reg = zeros(1, nSourcePoints);
    predictedROIlabel = interp.tissue;
    for i = 1:nRois
        iRoiLabel = strcmp(roiNames{i}, interp.tissuelabel);
        pointsLabel = predictedROIlabel == find(iRoiLabel);
        indicesT_Reg(pointsLabel) = i;
    end    
    
end


%Checks that indicesT and indicesT_Reg have the same dimensions than the sourceData
if length(indicesT_Reg) ~= nSourcePoints
    fprintf('ERROR: The source file has %d points, but the atlas has %d points', nSourcePoints, length(indicesT_Reg));
    disp('TIP: The current version of the software only supports 5656 points');
    disp('If you wish to add other models, please modify the f_mainChansToSource and the f_mainSourceAvgRoi scripts');
    return
end


%Fills the new roiData [nRois, nTimes]
nRois = length(roiNames);
nTimes = size(sourceData, 2);
roiData = nan(nRois, nTimes);
for i = 1:nRois
    iRoiIdx = indicesT_Reg == i;
    if sum(iRoiIdx) > 0
        %Averages the nSourcePoints that correspond to the i-th ROI
        roiData(i, :) = mean(sourceData(iRoiIdx, :));
    end
end


%Saves the averaged per ROI data in a .txt file
fileID = fopen(fullfile(saveStructTxt.Path, saveStructTxt.Name), 'w');
for i = 1:nTimes
    iTime = roiData(:,i);
    for j = 1:nRois
        %For each time, writes its corresponding value per ROI separated by a tab
        fprintf(fileID,'%.4f\t', iTime(j));
    end
    %For each new time, write it in a separate line
    fprintf(fileID,'\n');
end
fclose(fileID);

%Saves the ROI names in a .txt
roiNameTxt = strcat(saveStructTxt.Name(1:end-4), '-ROInames.txt');
fileID2 = fopen(fullfile(saveStructTxt.Path, roiNameTxt),'w');
for i = 1:nRois
    fprintf(fileID2,'%d-%s\n', i, roiNames{i});
    fprintf(fileID2,'\n');
end
fclose(fileID2);


%Finally, modifies the roiData, so that it only contains  non-empty or non-NaN regions
finalRois = unique(indicesT_Reg);
%For the FieldTrip option, unknown points will be assigned to 0
if length(finalRois) == 83 && ismember(0, finalRois)
    idxZeros = indicesT_Reg == 0;
    fprintf('WARNING: %d of %d source points were not assigned to any ROI. Discarding those points. \n', sum(idxZeros), nSourcePoints);
    finalRois(finalRois==0) = [];
%If more than 82 ROIs were created, there was something wrong
elseif length(finalRois) ~= 82
    fprintf('ERROR: Unexpected error. The number of ROIs expected for AAL-116 is 82, but got %d instead', length(finalRois));
    return
end
%For the BMA option, empty ROIs will not be saved in the .mat
finalRoiData = roiData(finalRois, :);
finalRoiNames = roiNames(finalRois);


%Updates the sourceMat structure with the averaged by ROIs values
roiMat = sourceMat;
roiMat.data = finalRoiData;
roiMat.roiNames = finalRoiNames;
roiMat.sourceROIatlas = sourceROIatlas;

%If it made it this far, the script was completed sucessfully
status = 1;

end