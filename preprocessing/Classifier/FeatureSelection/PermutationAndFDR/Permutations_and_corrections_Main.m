%%Statistical analysis : In this script we are comparing inverse solutions from two groups AD-DF and looking for the statistical differences between them.

%The permutationTest have three options. It can be made using the flag sideness as 'larger', 'smaller' or 'both'. In this example we are using 'larger'. 
%See permutationTest help for more information.

%The correction of the permutationTest is performed using a procedure for controlling the false discovery rate (FDR).
%See fdr_bh function help for more information

%%Input Variables: 

%averaged_subject_wise_solution_AD (matrix with the inverse solutions AD
%     --matrix dimensions(number_subjects x voxels_number)

%averaged_subject_wise_solution_DF (matrix with the inverse solutions DF
%     --matrix dimensions(number_subjects x voxels_number)

%%Outputs of the script:

% From the permutationTest:
%- perms_Larger_AD_DF: the resulting p-value for every voxel

% From the correction proceeding:
%-corrected_Larger_AD_DF: All adjusted p-values less than or equal to the desired false discovery rate are significant. In this case we used the
%default value for the false discovery rate in the fdr_bh function which is 0.05. 

%-binary_corrected_Larger_AD_DF:  A binary vector or matrix of the same size as the input "pvals." If the ith element of h is 1, 
%then the test that produced the ith p-value in pvals is significant (i.e.,the null hypothesis of the test is rejected).


% number_of_permutations=15000;
number_of_permutations=10;


%%Comparison AD-DF subject wise
%option LARGER

%Two conditions: AD, DF. [subjects, features]
%Compara control VS enfermedad
%Parameters:
%number_of_permutations = 15k (default) (parámetro)
%sidedness = hacer 'larger' y 'smaller' (no parámetro)
%significance = 0.05 (default) (parámetro)
averaged_subject_wise_solution_AD = load('F:\Pavel\Estandarizacion\Bases_de_Datos\RS_SQZ-BrainLat\analysis_RS\Connectivity\Step1_ConnectivityMetrics\sub-10001\eeg\c1_t2_n2_s6_sub-10001_rs_eeg.mat');
averaged_subject_wise_solution_AD = averaged_subject_wise_solution_AD.EEG_like.connectivityMetrics(:)';
averaged_subject_wise_solution_DF = load('F:\Pavel\Estandarizacion\Bases_de_Datos\RS_SQZ-BrainLat\analysis_RS\Connectivity\Step1_ConnectivityMetrics\sub-10002\eeg\c1_t2_n2_s6_sub-10002_rs_eeg.mat');
averaged_subject_wise_solution_DF = averaged_subject_wise_solution_DF.EEG_like.connectivityMetrics(:)';


voxels_number=size(averaged_subject_wise_solution_DF, 2);
%Devolver las 3 cosas y los nombres de lo significativo
perms_Larger_AD_DF = zeros(voxels_number,1);
corrected_Larger_AD_DF=zeros(voxels_number,1);
binary_corrected_Larger_AD_DF=zeros(voxels_number,1);

for j=1:voxels_number   %voxels
    [p_AD_DF, observeddifferenceAD_DF, effectsizeAD_DF] = permutationTest(averaged_subject_wise_solution_AD(:,j)', averaged_subject_wise_solution_DF(:,j)',number_of_permutations,'sidedness','larger');
    perms_Larger_AD_DF(j)=p_AD_DF;
    %perms_Larger_AD_DF < 0.05
    [h_AD_DF_larger, crit_p, adj_ci_cvrg, adj_p_AD_DF_larger]=fdr_bh(perms_Larger_AD_DF(j)); %, significance?
    corrected_Larger_AD_DF(j)=adj_p_AD_DF_larger;
    binary_corrected_Larger_AD_DF(j)=h_AD_DF_larger;
end