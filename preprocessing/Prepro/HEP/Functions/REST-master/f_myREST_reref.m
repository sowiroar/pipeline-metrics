function restEEG = f_myREST_reref(avgEEG, badChanIdxs)
%Description: 
%Function that performs REST Reref. Modified from the original version to avoid using the GUI
%Original version: Li Dong*, Fali Li, Qiang Liu, Xin Wen, Yongxiu Lai, Peng Xu and Dezhong Yao*. 
%   MATLAB Toolboxes for Reference Electrode Standardization Technique (REST) of Scalp EEG. Frontiers in Neuroscience, 2017:11(601).
%INPUTS:
%avgEEG = EEGLab structure with data already re-referenced
%badChansIdxs = Indexes labeled as 'badChannels'
%OUTPUTS:
%restEEG = EEGLab structure with data re-referenced using REST
%Author: Jhony Mejia

%Defines the channels that will be considered for re-referencing
channs = 1:avgEEG.nbchan;
channs(badChanIdxs) = [];

disp('----------------------------');
disp('Loading Lead Field...');
disp('Calculating leadfield based on 3-concentric spheres headmodel at once...');

G = dong_getleadfield(avgEEG, channs);
disp(['Lead Field Matrix: ',num2str(size(G,1)),' sources X ',num2str(size(G,2)),' channels']);


if length(size(avgEEG.data)) == 3
OrigData = avgEEG.data(channs,:);
    disp('********EEG.data is 3D epoched data!!!! Default of data demension is channels X timepoints X epochs!!!');
    disp('********Reshape to channels X timepoints');
else
    OrigData = avgEEG.data(channs,:);
end

disp(['EEG data: ',num2str(size(OrigData,1)),' channels X ',num2str(size(OrigData,2)),' time points'])
disp('Original reference is expected to be already average...');
OrigData = OrigData - repmat(mean(OrigData),size(OrigData,1),1);

disp('Re-referencing to REST...');
restData = dong_rest_refer(OrigData,G);

%Updates the relevant information in the restEEG
restEEG = avgEEG;
restEEG.data(channs,:,:) = restData;
restEEG.ref = 'REST';

disp('Completed...');

end