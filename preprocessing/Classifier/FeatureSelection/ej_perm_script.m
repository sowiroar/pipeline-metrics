%Defines parameters and loads data
classNumPermutations = 5000;
classSignificance  = 0.05;
dataToPermute = load('dataToPermute.mat');
dataToPermute = dataToPermute.dataToPermute;

%If everything was okay, run the permutation test with FDR correction for each feature 
rng(2022);          %Defines a seed to ensure reproducibility of the data
nFinalFeats = size(dataToPermute{1}, 2);
perms_larger = ones(1, nFinalFeats);
fdr_larger = ones(1, nFinalFeats);
perms_smaller = ones(1, nFinalFeats);
fdr_smaller = ones(1, nFinalFeats);
fdr_bin_combined = zeros(1, nFinalFeats) == 1;
bin_larger = ones(1, nFinalFeats);
bin_smaller = ones(1, nFinalFeats);
parfor i = 1:nFinalFeats
    %Performs permutation tests to test if the first diagnosis has larger or smaller values than the second one
    [pLarge_c1_c2, ~, ~] = permutationTest(dataToPermute{1}(:,i)', dataToPermute{2}(:,i)', classNumPermutations, 'sidedness', 'larger');
    perms_larger(i) = pLarge_c1_c2;
    
    [pSmall_c1_c2, ~, ~] = permutationTest(dataToPermute{1}(:,i)', dataToPermute{2}(:,i)', classNumPermutations, 'sidedness', 'smaller');
    perms_smaller(i) = pSmall_c1_c2;
    
    
    %Performs FDR correction for the larger and smaller p-values
    [binLarge_c1_c2, ~, ~, fLarge_c1_c2]=fdr_bh(pLarge_c1_c2, classSignificance);
    fdr_larger(i) = fLarge_c1_c2;
    bin_larger(i) = binLarge_c1_c2;
    
    [binSmall_c1_c2, ~, ~, fSmall_c1_c2]=fdr_bh(pSmall_c1_c2, classSignificance);
    fdr_smaller(i) = fSmall_c1_c2;
    bin_smaller(i) = binSmall_c1_c2;
    
    
    %Add indexes of the fdr that survived larger or smaller comparisons
    if (fLarge_c1_c2 < classSignificance) || (fSmall_c1_c2 < classSignificance)
        fdr_bin_combined(i) = true;
    end
end

%Checks if FDR correctly modified the p-values
if sum(bin_larger) == sum(perms_larger < classSignificance)
    fprintf('WARNING: The number of significant features before and after FDR correction is the same (%d)\n', sum(bin_larger));
end
if isequal(fdr_larger, perms_larger)
    disp('ERROR: The p-values before and after FDR are EXACTLY the same!');
end