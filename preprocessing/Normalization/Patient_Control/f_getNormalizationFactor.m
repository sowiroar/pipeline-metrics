function [status, normFactor] = f_getNormalizationFactor(data, metric)
%Description:
%Function that normalizes the given data using the desired metric.
%The metrics and their description are taken from:
%N. Bigdely-Shamlo, G. Ibagon, C. Kothe and T. Mullen, "Finding the Optimal Cross-Subject EEG Data Alignment Method 
%for Analysis and BCI," 2018 IEEE International Conference on Systems, Man, and Cybernetics (SMC), 2018, pp. 1110-1115, 
%doi: 10.1109/SMC.2018.00196.
%
%The metrics that start with 'RSTD-CH' were taken from:
%Bigdely-Shamlo, N., Touryan, J., Ojeda, A., Kothe, C., Mullen, T., & Robbins, K. "Automated EEG mega-analysis I: Spectral 
%and amplitude characteristics across studies" NeuroImage, 2020. doi: 10.1016/j.neuroimage.2019.116361
%
%INPUTS:
%data = Matrix of [Channels, Time, Subjects] with the data [already averaged per epochs] that wants to be normalized
%metric = String with the desired metric that wants to be calculated to normalize.
%       'UN_ALL': Uniform scaling of channel data by dividing by the robust standard deviation of concatenated channel data
%       'PER_CH': Dividing each channel by the MAD of its continuous activity across the whole recording
%       'UN_CH_HB': Uniform scaling of all channels by dividing all channel data by the Huber mean of channel robust standard 
%                   deviation values (same scaling applied to all channels).
%       'RSTD_EP_Mean': Normalizes by taking the mean of each N subject's robust standard deviation per channel individually
%       'RSTD_EP_Huber': Normalizes by taking the Huber mean of each N subject's robust standard deviation per channel individually
%       'RSTD_EP_L2': Normalizes by taking the Euclidean mean of each N subject's robust standard deviation per channel individually
%       'ZCA_ROB': Sphering the data using the channel covariance matrix C_Robust computed on all time points using the geometric 
%                   median of channel covariance matrices each computed at a single time point. The sphering matrix is given by: 
%                   S_ZCA-robust = C_Robust ^ -1/2
%       'ZCA_COR_ROB': Sphering the data using the channel covariance matrix C_Robust, defined in 'ZCA-ROB', where the sphering 
%                   matrix is defined as: S_ZCA-COR-Robust = (P_Robust
%                   ^ -1/2) * (V_Robust ^ -1/2). P_Roubst is the robust channel correlation matrix and V_Robust is the robustly 
%                   estimated diagonal channel covariance matrix such that C_Robust = (V_Robust^1/2) * P_Robust * (V_Robust^1/2) 
%OUTPUTS:
%status     = 1 if the script was completed successfully, 0 otherwise
%normFactor = The factor that is used to normalize the data (the denominator)
%Author: Jhony Mejia

%Initializes the default outputs
normFactor = [];
status = 0;

if strcmp(metric, 'UN_ALL')
    nShape = size(data);
    nTotal = numel(data);
    
    %Reorders data so the last dimension is the 'channels' data
    if length(nShape) == 2
        reordered = permute(data, [2, 1]);
    elseif length(nShape) == 3
        reordered = permute(data, [2, 3, 1]);
    end
    
    %Concatenates channels
    catChannels = reshape(reordered, [1,nTotal]);
    
    %Calculates the median absolute deviation across concatenated channels, and its' corresponding robust standard deviation
    madCatChannels = mad(catChannels, 1);
    robustStd = 1.4826*madCatChannels;
    
    %Applies the normalization
    normFactor = robustStd;
    
elseif strcmp(metric, 'PER_CH')
    nShape = size(data);
    nTotal = numel(data);
    nChans = nShape(1);
    
    %Reorders data so the last dimension is the 'channels' data
    if length(nShape) == 2
        reordered = permute(data, [2, 1]);
    elseif length(nShape) == 3
        reordered = permute(data, [2, 3, 1]);
    end
    
    %Concatenates per channel
    catPerChannel = reshape(reordered, [nTotal/nChans, nChans]);
    
    %Calculates the median absolute deviation across concatenated channels
    madPerChannels = mad(catPerChannel, 1);
    
    %Applies the normalization per channel
    normFactor = madPerChannels';
    
elseif strcmp(metric, 'UN_CH_HB')
    nShape = size(data);
    nTotal = numel(data);
    nChans = nShape(1);
    
    %Reorders data so the last dimension is the 'channels' data
    if length(nShape) == 2
        reordered = permute(data, [2, 1]);
    elseif length(nShape) == 3
        reordered = permute(data, [2, 3, 1]);
    end
    
    %Concatenates per channel
    catPerChannel = reshape(reordered, [nTotal/nChans, nChans]);
    
    %Calculates the median absolute deviation across concatenated channels
    madPerChannels = mad(catPerChannel, 1);
    
    %Calculates the robust standard deviation per channel
    robustStdPerChan = madPerChannels*1.4826;
    
    %Calculates the Huber mean of the robustStd values per channel
    [huberMean, ~] = f_HuberMean(robustStdPerChan);
    
    %Normalizes the data
    normFactor = huberMean;
    
elseif startsWith(metric, 'RSTD_EP')
    %Reorders the data so the Median Absolute Deviation (MAD) is calculated across time per channel 
    %(and per epoch if more than one is given)
    nShape = size(data);
    if length(nShape) == 2
        reordered = permute(data, [2, 1]);
    elseif length(nShape) == 3
        reordered = permute(data, [2, 1, 3]);
    end
    
    %Calculates the MAD, and the Robust Standard Deviation to define the 'amplitude vector'
    amplitudeVector = mad(reordered, 1);
    amplitudeVector = shiftdim(amplitudeVector).*1.4826;        %shiftdim is similar to squeeze, but removes rows of 1 (e.g. transforms column vectors in row vectors)
    
    %Then, the 'amplitude vector' is given as input to the desired metric
    if strcmp(metric, 'RSTD_EP_Mean')
        iMean = mean(amplitudeVector);
        
        normFactor = iMean';
        
    elseif strcmp(metric, 'RSTD_EP_Huber')
        %Calculates the Huber Mean for each subject
        nEpochs = size(amplitudeVector, 2);
        iMean = zeros(1, nEpochs);
        for i = 1:nEpochs
            iMean(i) = f_HuberMean(amplitudeVector(:,i));
        end
        
        normFactor = iMean';
        
    elseif strcmp(metric, 'RSTD_EP_L2')
        %Calculates the Euclidean Mean for each subject
        nEpochs = size(amplitudeVector, 2);
        iNorm = zeros(1, nEpochs);
        for i = 1:nEpochs
            iNorm(i) = norm(amplitudeVector(:,i));
        end
        
        normFactor = iNorm';
    else
        fprintf(['ERROR: Please enter a valid metric.\nType help f_NormalizeChannels to see the metrics available' ...
            ' with a short description for each one of them. \n']);
        return
    end
    
    %Finally, take the mean of the RSTD metrics (because they have nSubjects metrics)
    normFactor = mean(normFactor);
    
else
    fprintf(['ERROR: Please enter a valid metric.\nType help f_NormalizeChannels to see the metrics available' ...
        ' with a short description for each one of them. \n']);
    return
end

%If it made it this far, the script was completed succesfully
status = 1;

end