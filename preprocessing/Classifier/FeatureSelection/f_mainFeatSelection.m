function [status, finalStruct, newClassDxComparison, subjPerDx] = f_mainFeatSelection(paths, diagnostics, classDxComparison, ...
        classNumPermutations, classSignificance)
%Description:
%Function that performs feature selection using permutations and FDR correction
%INPUTS:
%paths                  = Structure with 2 fields: 'DiagnosticsName' and 'DiagnosticsPath'
%           Each field has a 1xM cell where M is the number of diagnoses of the databases.
%           Each field of the M diagnoses contains a cell of Nx1, 
%           where N is the number of subjects that the database(s) have per diagnosis
%diagnostics            = Cell of 1xM with a string in each field with the Names of the diagnostics
%classDxComparison      = Cell of 2x1, each field containing strings of the diagnostics to be compared ('' by default)
%classNumPermutations   = Integer with the number of permutations desired for the statistical tests (5000 by default)
%classSignificance      = Number with the level of significance desired (0.05 by default)
%
%OUTPUTS:
%status                 = 1 if the script was completed successfully, 0 otherwise
%finalStruct            = Structure containing the parameters used as fields, and the following fields:
%           rawConnectivityData: [subjects, diagnostic+features]  for the raw-uncorrected data
%           rawConnectivityLabels [diagnostic+featNames] for the raw-uncorrected data
%           permConnectivityData: Containing two subfields:
%                   smaller: Matrix of [subjects, diagnostic +  features that passed permutation tests dx1 > dx2]
%                   larger: Matrix of [subjects, diagnostic +  features that passed permutation tests dx1 < dx2]
%           permConnectivityLabels: Also has fields smaller and larger, and being [diagnostic+featNamesPerm]
%           fdrConnectivityData: Containing two subfields:
%                   smaller: Matrix of [subjects, diagnostic +  features that passed permutation tests AND FDR correction dx1 > dx2]
%                   larger: Matrix of [subjects, diagnostic +  features that passed permutation tests AND FDR correction dx1 < dx2]
%                   combined: Matrix of [subjects, diagnostic +  features that passed permutation tests AND FDR correction]
%           fdrConnectivityLabels: Also has fields smaller and larger, and being [diagnostic+featNamesFDR]    
%newClassDxComparison   = Cell of 2x1, each field containing strings of the diagnostics that were compared ({} if status is 0)
%subjPerDx              = Vector of 2x1, with the number of subjects per newClassDxComparison that were used ([0,0] if status is 0)

%Defines the default outputs
status = 0;
finalStruct = struct();
newClassDxComparison = {};
subjPerDx = zeros(1,2);

%Defines the default inputs
if nargin < 2 || ~isstruct(paths) || ~iscell(diagnostics)
    disp('ERROR: The structure "paths", and the cell "diagnostics" are required to run this script');
    disp('TIP: You should not get this error if you run f_mainClassifier');
    disp('Alternatively, type help f_mainFeatSelection for more information');
    return
end
if nargin < 3
    classDxComparison = {};
end
if nargin < 4
    classNumPermutations = 5000;
end
if nargin < 5
    classSignificance = 0.05;
end


%Checks that the input "paths" has the expected fields
structFieldNames = fieldnames(paths);
if ~ (strcmp(structFieldNames{1}, 'DiagnosticsName') && strcmp(structFieldNames{2}, 'DiagnosticsPath'))
    disp('ERROR: The structure "paths" is expected to have two fields: "DiagnosticsName" and "DiagnosticsPath"');
    disp('TIP: You should not get this error if you run f_mainConnectivity. Type help f_mainFeatSelection for more information');
    return
    
elseif length(paths.DiagnosticsName) ~= length(paths.DiagnosticsPath) || ...
        length(vertcat(paths.DiagnosticsName{:})) ~= length(vertcat(paths.DiagnosticsPath{:}))
    disp('ERROR: The two fields of the structure "paths" ("DiagnosticsName" and "DiagnosticsPath") MUST have equal length');
    disp('TIP: You should not get this error if you run f_mainConnectivity. Type help f_mainFeatSelection for more information');
    return
end


%Checks that the input "diagnostics" has at least 2 fields
if length(diagnostics) < 2
    disp('ERROR: "diagnostics" needs to have at least two diagnoses to perform the feature selection');
    disp('TIP: You should not get this error if you run f_mainConnectivity. Type help f_mainFeatSelection for more information');
    return
end


%If none pair of diagnosis to compare were given (classDxComparison), ask for them
if length(classDxComparison) ~= 2
    disp('WARNING: No pair of diagnosis to compare were given. These are the diagnoses available:');
    disp(diagnostics);
    
    %First, defines the first diagnosis
    cnExists = strcmpi(diagnostics, 'CN');
    if sum(cnExists) > 0 && (length(diagnostics) == 2)
        %Try to automatically define the Controls as the first diagnosis to compare
        fprintf('WARNING: Assuming that the label for controls diagnosis is: %s\n', diagnostics{cnExists});
        firstDx = diagnostics{cnExists};
        
    else
        %If could not define the controls, or more than 3 diagnoses are available, ask for the first diagnosis to compare
        disp('Please enter the first diagnosis that you want to compare against:');
        firstDx = input('', 's');
        
        %Checks that the user prompted a valid value (if not, gives the user the chance to run it again)
        firstDxExists = strcmpi(diagnostics, firstDx);
        if sum(firstDxExists) == 0
            fprintf('ERROR: The diagnosis you entered (%s) does not exist in the diagnoses given: \n', firstDx);
            disp(diagnostics);
            disp('Do you want to run this script again? (y/n)');
            repeatScript = input('', 's');
            if strcmpi(repeatScript, 'y')
                [status, finalStruct, newClassDxComparison, subjPerDx] = f_mainFeatSelection(paths, diagnostics, {}, ...
                    classNumPermutations, classSignificance);
            end
            return
        end
    end
    
    %Defines the second diagnosis
    if sum(cnExists) > 0 && (length(diagnostics) == 2)
        %Automatically define the second diagnosis to compare
        fprintf('WARNING: Assuming that the label for the diagnosis to compare against controls is: %s\n', diagnostics{~cnExists});
        secondDx = diagnostics{~cnExists};
        
    else
        %If could not define the controls, or more than 3 diagnoses are available, ask for the second diagnosis to compare
        disp('Please enter the second diagnosis that you want to compare against:');
        secondDx = input('', 's');
        
        %Checks that the user prompted a valid value (if not, gives the user the chance to run it again)
        secondDxExists = strcmpi(diagnostics, secondDx);
        if sum(secondDxExists) == 0
            fprintf('ERROR: The diagnosis you entered (%s) does not exist in the diagnoses given: \n', secondDx);
            disp(diagnostics);
            disp('Do you want to run this script again? (y/n)');
            repeatScript = input('', 's');
            if strcmpi(repeatScript, 'y')
                [status, finalStruct, newClassDxComparison, subjPerDx] = f_mainFeatSelection(paths, diagnostics, {}, ...
                    classNumPermutations, classSignificance);
            end
            return
        end
    end
    
    %If both diagnoses were prompted correctly, update classDxComparison
    classDxComparison = {firstDx, secondDx};
end


%Double checks that the diagnoses desired exist, and gets the number of subjects per desired diagnosis
for i = 1:2
    iDiagnosticIdx = strcmpi(diagnostics, classDxComparison{i});
    
    %Checks that the diagnosis given exists
    if sum(iDiagnosticIdx) == 0
        fprintf('ERROR: The diagnosis you entered (%s) does not exist in the diagnoses given: \n', iDiagnosticIdx);
        disp(diagnostics);
        disp('Do you want to run this script again? (y/n)');
        repeatScript = input('', 's');
        if strcmpi(repeatScript, 'y')
            [status, finalStruct, newClassDxComparison, subjPerDx] = f_mainFeatSelection(paths, diagnostics, {}, ...
                classNumPermutations, classSignificance);
        end
        return
    end
    
    %Defines the number of subjects of the desired diagnosis
    subjPerDx(i) = length(paths.DiagnosticsName{iDiagnosticIdx});
    if subjPerDx(i) == 0
        fprintf('ERROR: There are none subjects with the diagnosis: %s\n', classDxComparison{i});
        return
    end
    
    %Makes sure that the classDxCompariosn is exactly equal to the diagnostics values (if they were the same, it doesn't matter)
    classDxComparison{i} = diagnostics{iDiagnosticIdx};
end


%Makes sure that the classes to compare are not the same
if strcmp(classDxComparison{1}, classDxComparison{2})
    fprintf('ERROR: The two categories to compare are the same (%s)!', classDxComparison{1});
    disp('TIP: It does not make any sense to permute one category against itself. You might want to run a correlation instead');
    return
end

%Let the user know the comparison that will be made, and the number of subjects per diagnosis
fprintf('Comparing %s (%d subjects) against %s (%d subjects) for feature selection \n', classDxComparison{1}, ...
    subjPerDx(1), classDxComparison{2}, subjPerDx(2));


%Defines the paths and names for each condition to compare
condPaths = cell(1,2);
condNames = cell(1,2);
condPaths{1} = paths.DiagnosticsPath{strcmp(classDxComparison{1}, diagnostics)};
condNames{1} = paths.DiagnosticsName{strcmp(classDxComparison{1}, diagnostics)};
condPaths{2} = paths.DiagnosticsPath{strcmp(classDxComparison{2}, diagnostics)};
condNames{2} = paths.DiagnosticsName{strcmp(classDxComparison{2}, diagnostics)};

%Loads the subjects of each diagnosis and stack them in a matrix of [numSubjects, numFeatures]
dataToPermute = {[], []};
labelsToPermute = {{}, {}};
for i = 1:2
    %Iterates over the two conditions
    iCondFullFile = fullfile(condPaths{i}, condNames{i});
    
    for j = 1:subjPerDx(i)
        %For each condition, iterates over each .mat
        jFile = iCondFullFile{j};
        if ~exist(jFile, 'file')
            disp('ERROR: The following .mat does not exist:');
            disp(jFile);
            disp('TIP: You should not get this error if you run f_mainClassifier. Type help f_mainFeatSelection for more information');
            return
        end
        
        %Loads the current .mat
        j_EEG_like = load(jFile);
        j_EEG_like = j_EEG_like.EEG_like;
        
        
        %Checks that the loaded field has the needed fields
        if ~isfield(j_EEG_like, 'roiNames') || ~isfield(j_EEG_like, 'connectivityMetrics') || ~isfield(j_EEG_like, 'connectivityNames')
            disp('ERROR: The following file does not have the fields required for this step (roiNames, connectivityMetrics and connectivityNames):');
            disp(jFile);
            disp('TIP: You should not get this error if you run f_mainClassifier. Type help f_mainFeatSelection for more information');
            return
        end
        
        %Checks that the dimensions of roiNames and connectivityNames correspond to the ones of connectivityMetrics
        if length(j_EEG_like.roiNames) ~= size(j_EEG_like.connectivityMetrics, 1) || ...
                length(j_EEG_like.roiNames) ~= size(j_EEG_like.connectivityMetrics, 2) || ...
                length(j_EEG_like.connectivityNames) ~= size(j_EEG_like.connectivityMetrics, 3)
            disp('ERROR: The field "connectivityMetrics" is expected to have dimensions [rois, rois, connectivityMetrics]');
            fprintf('The expected dimensions were: [%d, %d, %d]. Instead it has the following dimensions: \n', ... 
                length(j_EEG_like.roiNames), length(j_EEG_like.roiNames), length(j_EEG_like.connectivityNames));
            disp(size(j_EEG_like.connectivityMetrics));
            disp('TIP: You should not get this error if you run f_mainClassifier. Type help f_mainFeatSelection for more information');
            return
        end
        
        %Checks that connectivityNames and roiNames are given in [1,n], instead of [n,1]
        if size(j_EEG_like.connectivityNames, 1) > 1 && size(j_EEG_like.connectivityNames, 2) == 1
            j_EEG_like.connectivityNames = j_EEG_like.connectivityNames';
        end
        if size(j_EEG_like.roiNames, 1) > 1 && size(j_EEG_like.roiNames, 2) == 1
            j_EEG_like.roiNames = j_EEG_like.roiNames';
        end
        
        
        %Takes the data of the upper triangle of the matrix (each is the same as the lower triangle)
        nMetrics = length(j_EEG_like.connectivityNames);
        nRois = length(j_EEG_like.roiNames);
        upperTriangleIdx = triu(true(size(j_EEG_like.connectivityMetrics(:,:,1))), 1);      %[nFeats, nFeats] with 1 in the upper triangle (without the diagonal) and 0 elsewhere
        upperTriangleIdx = repmat(upperTriangleIdx, [1,1,nMetrics]);                        %[nFeats, nFeats, nMetrics] for logical indexing of the upper triangle (without the diagonal) of each metric
        jData = j_EEG_like.connectivityMetrics(upperTriangleIdx)';                          %Gets unraveled vector with the connectivity metrics
        
        %Defines the labels of each metric
        nRoiVsRoiPerMetric = length(jData)/nMetrics;
        metricsLabels = repmat(j_EEG_like.connectivityNames, [nRoiVsRoiPerMetric,1]);
        roiVsRoiLabels = cell(nRoiVsRoiPerMetric, 1);
        roiIdx = 1;
        for k = 1:nRois
            for m = k+1:nRois
                %Create a label to know which ROIs are being compared
                roiVsRoiLabels{roiIdx} = strcat(j_EEG_like.roiNames{k}, '--VS--', j_EEG_like.roiNames{m});
                roiIdx = roiIdx+1;
            end
        end
        roiVsRoiLabels = repmat(roiVsRoiLabels, [1, nMetrics]);     %Repeats the metric to have the same dimension as metricsLabels
        jLabels = strcat(roiVsRoiLabels, '---', metricsLabels);    %Combines both roiVsRoiLabels and metricsLabels
        jLabels = {jLabels{:}};                                     %Unravels the vector to map which label corresponds to each point of jData
        
        
        %Checks that the current .mat has the same number of features as the rest of the .mats
        if ~isempty(dataToPermute{i})
            nFeatsToPermute = size(dataToPermute{i}, 2);
            if length(jData) ~= nFeatsToPermute
                fprintf('ERROR: The following .mat has %d features, but the rest of the subjects have %d features:\n', length(jData), nFeatsToPermute);
                disp(jFile);
                disp('TIP: You should not get this error if you run f_mainClassifier. Type help f_mainFeatSelection for more information');
                return
            end
            
            %Also checks that the feature names are exactly the same
            if ~isequal(labelsToPermute{i}, jLabels)
                disp('ERROR: The following .mat has labels that are different from the rest of the subjects:');
                disp(jFile);
                
                %Gets the ROIs of the rest of the subjects, and display them
                disp('The rest of the subjects have the following ROIs (in order):');
                restRoi = cellfun(@(x) strsplit(x, '--'), jLabels(1:nRoiVsRoiPerMetric), 'UniformOutput', false);   %roi1--VS--roi2---metric
                restRoi = vertcat(restRoi{:});
                restRoi = vertcat(restRoi(:,1), restRoi(:,3));      %Keep only roi1 and roi2
                restRoi = unique(restRoi', 'stable');                %'stable' so that unique does not sort the values
                disp(restRoi);
                disp('While this subject have the following ROIs (in order):');
                disp(EEG_like.roiNames);
                
                %Gets the connectivity metrics of the rest of the subjects, and display them
                disp('The rest of the subjects have the following connectivity metrics (in order):');
                restMetrics = cellfun(@(x) strsplit(x, '---'), jLabels(1:nRoiVsRoiPerMetric:length(jLabels)), 'UniformOutput', false);      %roi1--VS--roi2---metric
                restMetrics = vertcat(restMetrics{:});
                restMetrics = restMetrics(:,2)';      %Keep only the metrics
                disp(restMetrics);
                disp('While this subject have the following ROIs (in order):');
                disp(EEG_like.connectivityNames);
                
                %Send a final error
                disp('ERROR: Cannot continue because the features are not in the correct order');
                disp('TIP: You should not get this error if you run f_mainClassifier. Type help f_mainFeatSelection for more information');
                return
            end
        end
        
        %If everything is okay, update the data and labels fields (if labels are the same, it does not matter)
        dataToPermute{i} = vertcat(dataToPermute{i}, jData);
        labelsToPermute{i} = jLabels;
    end
end


%Check that the number of .mats correspond to the number of rows in dataToPermute
if (subjPerDx(1) ~= size(dataToPermute{1}, 1)) || (subjPerDx(2) ~= size(dataToPermute{2}, 1))
    fprintf('ERROR: The number of .mats [%d, %d] do not correspond to the number of rows [%d, %d] per diagnosis [%s, %s] \n', ...
        subjPerDx, size(dataToPermute{1}, 1), size(dataToPermute{2}, 1), classDxComparison{1}, classDxComparison{2});
    return
end

%Check that the number and order of features for each diagnosis is the same
if size(dataToPermute{1}, 2) ~= size(dataToPermute{2}, 2)
    fprintf('ERROR: The number of features (%d) of the first diagnosis (%s), is not equal (%d) to the second diagnosis \n', ...
        size(dataToPermute{1}, 1), classDxComparison{1}, size(dataToPermute{2}, 1), classDxComparison{2});
    return
end
if ~isequal(labelsToPermute{1}, labelsToPermute{2})
    disp('ERROR: The labels of the first diagnosis (1st column) is not equal to the ones of the second diagnosis (2nd column)');
    disp(horzcat(labelsToPermute{1}', labelsToPermute{2}'));
    return
end


%If everything was okay, run the permutation test with FDR correction for each feature 
rng(2022);          %Defines a seed to ensure reproducibility of the data
nFinalFeats = size(dataToPermute{1}, 2);
perms_larger = ones(1, nFinalFeats);
perms_smaller = ones(1, nFinalFeats);
parfor i = 1:nFinalFeats
    %Performs permutation tests to test if the first diagnosis has larger or smaller values than the second one
    [pLarge_c1_c2, ~, ~] = permutationTest(dataToPermute{1}(:,i)', dataToPermute{2}(:,i)', classNumPermutations, 'sidedness', 'larger');
    perms_larger(i) = pLarge_c1_c2;
    
    [pSmall_c1_c2, ~, ~] = permutationTest(dataToPermute{1}(:,i)', dataToPermute{2}(:,i)', classNumPermutations, 'sidedness', 'smaller');
    perms_smaller(i) = pSmall_c1_c2;
end


%Performs FDR correction for the larger and smaller p-values
[~, ~, ~, fdr_larger]=fdr_bh(perms_larger);
if length(fdr_larger) ~= length(perms_larger)
    disp('ERROR: Unexpected mismatch of dimensions after FDR correction');
    return
end

[~, ~, ~, fdr_smaller]=fdr_bh(perms_smaller);
if length(fdr_smaller) ~= length(perms_smaller)
    disp('ERROR: Unexpected mismatch of dimensions after FDR correction');
    return
end


%Gets indexes of the fdr that survived larger or smaller comparisons
fdr_bin_combined = (fdr_larger < classSignificance) | (fdr_smaller < classSignificance);
if sum(fdr_bin_combined) == 0
    %If none survived, use permutation features only (ignore FDR)
    fprintf('WARNING: None comparisons survived FDR correction. The lowest p-value after FDR is: %.4f\n', min([min(fdr_larger), min(fdr_smaller)]));
    disp('WARNING: Using the features that only survived permutation comparisons for the classifier (ignoring FDR corrections)');
    fdr_bin_combined = [];
    perm_bin_combined = (perms_larger < classSignificance) | (perms_smaller < classSignificance);
end


%Defines the final matrix data
finalData = vertcat(dataToPermute{1}, dataToPermute{2});        %Combines the data of both diagnoses
finalDx = vertcat(repmat(classDxComparison(1), [subjPerDx(1), 1]), repmat(classDxComparison(2), [subjPerDx(2), 1]));
finalData = horzcat(finalDx, num2cell(finalData));              %Adds the diagnosis as the first column
finalLabels = ['Diagnostic', labelsToPermute{1}];               %Adds 'Diagnostic' as the first label

%Defines the output structure with the parameters used and the raw data
finalStruct.classDxComparison = classDxComparison;
finalStruct.classSignificance = classSignificance;
finalStruct.classNumPermutations = classNumPermutations;
finalStruct.rawConnectivityData = finalData;
finalStruct.rawConnectivityLabels = finalLabels;
fprintf('Number of raw (uncorrected) features: %d \n', length(finalStruct.rawConnectivityLabels)-1);

%Adds the permutation-corrected data (NOTE: the 'true' is added in the indexing to keep the diagnostic column)
finalStruct.permConnectivityData.larger = finalData(:, horzcat(true, perms_larger < classSignificance));
finalStruct.permConnectivityLabels.larger = finalLabels(:, horzcat(true, perms_larger < classSignificance));
finalStruct.permConnectivityData.smaller = finalData(:, horzcat(true, perms_smaller < classSignificance));
finalStruct.permConnectivityLabels.smaller = finalLabels(:, horzcat(true, perms_smaller < classSignificance));
disp('Number of permutation-corrected features:');
fprintf('\t -larger: %d \t \t -smaller: %d \n', length(finalStruct.permConnectivityLabels.larger)-1, length(finalStruct.permConnectivityLabels.smaller)-1);

%Adds the fdr-corrected data (NOTE: the 'true' is added in the indexing to keep the diagnostic column)
finalStruct.fdrConnectivityData.larger = finalData(:, horzcat(true, fdr_larger < classSignificance));
finalStruct.fdrConnectivityLabels.larger = finalLabels(:, horzcat(true, fdr_larger < classSignificance));
finalStruct.fdrConnectivityData.smaller = finalData(:, horzcat(true, fdr_smaller < classSignificance));
finalStruct.fdrConnectivityLabels.smaller = finalLabels(:, horzcat(true, fdr_smaller < classSignificance));
disp('Number of permutation and fdr-corrected features:');
fprintf('\t -larger: %d \t \t -smaller: %d \n', length(finalStruct.fdrConnectivityLabels.larger)-1, length(finalStruct.fdrConnectivityLabels.smaller)-1);


%Combines the smaller and larger FDR-corrected data (or permutation only)
if ~isempty(fdr_bin_combined)
    finalStruct.fdrConnectivityData.combined = finalData(:, horzcat(true, fdr_bin_combined));
    finalStruct.fdrConnectivityLabels.combined = finalLabels(:, horzcat(true, fdr_bin_combined));
    disp('Final number of permutation and fdr-corrected features that survived smaller or larger comparisons:');
    disp(length(finalStruct.fdrConnectivityLabels.combined)-1);
else
    finalStruct.permConnectivityData.combined = finalData(:, horzcat(true, perm_bin_combined));
    finalStruct.permConnectivityLabels.combined = finalLabels(:, horzcat(true, perm_bin_combined));
    disp('Final number of permutation features that survived smaller or larger comparisons:');
    disp(length(finalStruct.permConnectivityLabels.combined)-1);
end


%If it made this far, the script was completed successfully
newClassDxComparison = classDxComparison;
status = 1;

end