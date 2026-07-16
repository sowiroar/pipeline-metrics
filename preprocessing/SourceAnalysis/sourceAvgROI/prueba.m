nRois = length(roiNames);
usedROIlabels = zeros(1, nRois);
indicesT_Reg = zeros(1, nSourcePoints);
predictedROIlabel = interp.tissue;
for i = 1:nRois
    iRoiLabel = strcmp(roiNames{i}, interp.tissuelabel);
    pointsLabel = predictedROIlabel == find(iRoiLabel);
    indicesT_Reg(pointsLabel) = i;
    
    un = unique(indicesT_Reg);
    fprintf('i = %d: ', i);
    fprintf(sprintf('%d, ', un));
    fprintf('\n');
end