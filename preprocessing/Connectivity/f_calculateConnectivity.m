function [status, connectivityMat] = f_calculateConnectivity(iSetPath, iSetName, connIgnoreWSM)
%Description:
%Function that calculates connectivity metrics
%INPUTS:
%setPath            = Path of the .mat or .set to calculate the connectivity metrics
%setName            = Name of the .mat or .set to calculate the connectivity metrics
%connIgnoreWSM      = true if wants to ignore the Weighted Symbolic Metrics (2 in total). false otherwise
%OUTPUTS:
%status             = 1 if the script was completed successfully
%connectivityMat    = Structure with a .data Matrix of [nSourcePoints, nSourcePoints, nMetrics] 
%                   with the connectivity metrics information between each pair of points/channels.

%Defines the default outputs
status = 0;
connectivityMat = [];

%Defines the default inputs
if nargin < 3
    connIgnoreWSM = true;
end

%Loads the data normally if it is a .mat
if endsWith(iSetName, '.mat')
    disp('Loading the .mat at the following path (EEG_like structure expected):');
    disp(fullfile(iSetPath, iSetName));
    EEG_like = load(fullfile(iSetPath, iSetName));
    EEG_like = EEG_like.EEG_like;
    
%Or loads it using pop_loadset if it is a .set
elseif endsWith(iSetName, '.set')
    EEG = pop_loadset('filename', iSetName, 'filepath', iSetPath);
    
    %Uses the EEG data to create the expected EEG_like structure
    EEG_like.data = EEG.data;
    EEG_like.srate = EEG.srate;
    EEG_like.times = EEG.times;
    EEG_like.comments = EEG.comments;
    
end


%The metrics need that there are more points in time than points in space (sourcePoints or Channels)
if size(EEG_like.data, 1) > size(EEG_like.data, 2)
    disp('ERROR: To calculate the metrics, more points in time are needed than points in space (sourcePoints or Channels)');
    fprintf('Currently, there are %d points in time, and %d points in space\n', size(EEG_like.data, 2), size(EEG_like.data, 1));
    return
end


%Calculates the connectivity metrics using the EEG_like data [channels, time] OR [sourcePoints, time]
hoeffdingFromCopula = ~connIgnoreWSM;         %False if it is a metric that won't be calculated
[wsdm,wsgc,ham_dist,mimat,hdmat,cmimat,omat] = multi_fc(EEG_like.data', hoeffdingFromCopula);

%Concatenate the connectivity metrics in the third dimension
if connIgnoreWSM
    connectivityMetrics = cat(3, ham_dist,mimat,cmimat,omat);
    connectivityNames = {'ham_dist', 'mimat', 'cmimat', 'omat'};
else
    connectivityMetrics = cat(3, wsdm,wsgc,ham_dist,mimat,hdmat,cmimat,omat);
    connectivityNames = {'wsdm', 'wsgc', 'ham_dist', 'mimat', 'hdmat', 'cmimat', 'omat'};
end

%Defines the output 'connectivityMat' based on the EEG_like struct, and adds the connectivity info
connectivityMat = EEG_like;
connectivityMat.connectivityMetrics = connectivityMetrics;
connectivityMat.connectivityNames = connectivityNames;

%If it made it this far, the script was completed successfully
status = 1;

end