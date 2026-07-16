function outMetric = f_CalculateMetrics(data, type)
%Description:
%Function that calculates a metric to assess the quality of the normalization process
%The metrics and their description are taken from:
%N. Bigdely-Shamlo, G. Ibagon, C. Kothe and T. Mullen, "Finding the Optimal Cross-Subject EEG Data Alignment Method 
%for Analysis and BCI," 2018 IEEE International Conference on Systems, Man, and Cybernetics (SMC), 2018, pp. 1110-1115, 
%doi: 10.1109/SMC.2018.00196.
%
%INPUTS:
%data = Matrix of [channels, time, epochs] containing the data to be assessed
%type = String with the type of metric that wants to be calculated:
%       VAR_EXP: Percent variance explained estimate using a jackknife procedure
%       TOT_VAR: Residual variance
%       DIST: Average distance normalized by average pattern norm
%       COR_DIST: Correlation distance using Pearson correlation
%       SPR_COR_DIST: Correlation distance using Spearman correlation
%       COS_DIST: Cosine distance
%   And all the previous options with _ROB at the end
%OUTPUTS:
%outMetric: Metric that measures the quality of the normalized data

oriSize = size(data);
reorderedData = permute(data, [3,2,1]);         %Sends the channel dimension to the last dimension. [epochs, time, channels]
reorderedData = reshape(reorderedData, [oriSize(3), oriSize(2)*oriSize(1)]);

outMetric = [];

if startsWith(type, 'VAR_EXP')
    nEpochs = oriSize(3);
    outVector = zeros(nEpochs, 1);
    
    %Iterates over epochs to calculate the variance explained by the i-th epoch
    if strcmp(type, 'VAR_EXP')
        for i = 1:nEpochs
            temp = reorderedData;
            temp(i,:) = [];                         %Removes the i-th epoch
            temp = mean(temp);                      %Averages across epochs
            varAvg = std(temp).^2;                  %Takes the variance over the averaged epochs except the i-th epoch
            varI = std(reorderedData(i,:)).^2;      %Takes the variance of the i-th epoch
            outVector(i) = 100*(1- (varAvg/varI) );     %Calculates the variance explained by the i-th epoch and stores it in outVector
        end
        outMetric = mean(outVector);
        
    %Same, but with Huber Mean instead of normal mean whenever possible
    elseif (strcmp(type, 'VAR_EXP_ROB'))
        %3 subjects with 64 channels and 240s with a sampling rate of 512 points take 15 minutes
        fprintf('WARNING: This will take a really long time (%dmins aprox)\n', round(mult(oriSize)*20/(3*64*512*240)));
        nTimexChans = size(reorderedData, 2);
        for i = 1:nEpochs
            temp = reorderedData;
            temp(i,:) = [];                                     %Removes the i-th epoch
            tempAvg = zeros(nTimexChans, 1);
            parfor j = 1:nTimexChans
                tempAvg(j) = f_HuberMean(temp(:,j));                           %Averages (using Huber Mean) across epochs
            end
            varAvg = f_RobustVariance(tempAvg);                    %Takes the variance (using Huber Mean) over the averaged epochs except the i-th epoch
            varI = f_RobustVariance(reorderedData(i,:));        %Takes the variance (using Huber Mean) of the i-th epoch
            outVector(i) = 100*(1- (varAvg/varI) );     %Calculates the variance explained by the i-th epoch and stores it in outVector
            
            fprintf('Epoch #%d of %d completed\n', i, nEpochs);
        end
        outMetric = mean(outVector);
        
    else
        disp('ERROR: Please enter a valid type of metric. Type help f_CalculateMetrics for more info');
        return
    end
    
    
elseif startsWith(type, 'TOT_VAR')  
    %Calculates the norm of each epoch
    nEpochs = oriSize(3);
    normEpochs = zeros(nEpochs, 1);
    for i = 1:nEpochs
        normEpochs(i) = norm(reorderedData(i,:));
    end
    
    %Calculates the variance per epoch
    if strcmp(type, 'TOT_VAR')                  %Normal Variance
        varEpochs = std(reorderedData, 0, 2).^2;
    elseif strcmp(type, 'TOT_VAR_ROB')          %Robust Variance (e.g. using Huber Mean)
        varEpochs = zeros(nEpochs, 1);
        for i = 1:nEpochs
            varEpochs(i) = f_RobustVariance(reorderedData(i,:));
        end
    else
        disp('ERROR: Please enter a valid type of metric. Type help f_CalculateMetrics for more info');
        return
    end
    
    %Divides the variance per epoch by the norm per epoch
    outMetric = sum(-varEpochs./normEpochs);
    
    
elseif startsWith(type, 'DIST')
    nEpochs = oriSize(3);
    pairwiseNorm = zeros(nEpochs, nEpochs-1);
    
    %For each epoch, calculate the pairwise norm (except the norm with itself)
    for i = 1:nEpochs
        iNorm = norm(reorderedData(i,:));
        cont = 0;
        for j = 1:nEpochs
            if i == j
                continue
            end
            cont = cont+1;
            ijDiff = reorderedData(i,:) - reorderedData(j,:);
            pairwiseNorm(i,cont) = norm(ijDiff);
        end
        
        pairwiseNorm(i,:) = pairwiseNorm(i,:)./iNorm;
    end
    
    if strcmp(type, 'DIST')                 %Normal Average
        outMetric = -mean(mean(pairwiseNorm));
    elseif strcmp(type, 'DIST_ROB')         %Huber Mean average
        avgDistPerEpoch = zeros(nEpochs, 1);
        for i = 1:nEpochs
            avgDistPerEpoch(i) = f_HuberMean(pairwiseNorm(i,:));
        end
        outMetric = -f_HuberMean(avgDistPerEpoch);
    else
        disp('ERROR: Please enter a valid type of metric. Type help f_CalculateMetrics for more info');
        return
    end
    
elseif startsWith(type, 'COR_DIST')
    nEpochs = oriSize(3);
    
    %For each epoch, calculate the pairwise correlation (except the norm with itself)
    pairwiseCorr = corr(reorderedData', 'type', 'Pearson');
    pairwiseCorr(logical(eye(size(pairwiseCorr)))) = [];          % Removes the diagonal (the correlation of an epoch with itself)
    pairwiseCorr = reshape(pairwiseCorr, nEpochs, nEpochs-1);     % Reshapes the matrix to the desired dimensions
    
    if strcmp(type, 'COR_DIST')
        outMetric = mean(mean(pairwiseCorr));
    elseif strcmp(type, 'COR_DIST_ROB')
        avgCorrPerEpoch = zeros(nEpochs, 1);
        for i = 1:nEpochs
            avgCorrPerEpoch(i) = f_HuberMean(pairwiseCorr(i,:));
        end
        outMetric = f_HuberMean(avgCorrPerEpoch);
    else
        disp('ERROR: Please enter a valid type of metric. Type help f_CalculateMetrics for more info');
        return
    end
    
elseif startsWith(type, 'SPR_COR_DIST')
    nEpochs = oriSize(3);
    
    %For each epoch, calculate the pairwise correlation (except the norm with itself)
    pairwiseCorr = corr(reorderedData', 'type', 'Spearman');
    pairwiseCorr(logical(eye(size(pairwiseCorr)))) = [];          % Removes the diagonal (the correlation of an epoch with itself)
    pairwiseCorr = reshape(pairwiseCorr, nEpochs, nEpochs-1);     % Reshapes the matrix to the desired dimensions
    
    if strcmp(type, 'SPR_COR_DIST')
        outMetric = mean(mean(pairwiseCorr));
    elseif strcmp(type, 'SPR_COR_DIST_ROB')
        avgCorrPerEpoch = zeros(nEpochs, 1);
        for i = 1:nEpochs
            avgCorrPerEpoch(i) = f_HuberMean(pairwiseCorr(i,:));
        end
        outMetric = f_HuberMean(avgCorrPerEpoch);
    else
        disp('ERROR: Please enter a valid type of metric. Type help f_CalculateMetrics for more info');
        return
    end
    
elseif startsWith(type, 'COS_DIST')
    nEpochs = oriSize(3);
    pairwiseNorm = zeros(nEpochs, nEpochs-1);
    
    %For each epoch, calculate the cosine distance (except with itself)
    for i = 1:nEpochs
        cont = 0;
        for j = 1:nEpochs
            if i == j
                continue
            end
            cont = cont+1;
            ijCos = getCosineSimilarity(reorderedData(i,:), reorderedData(j,:));
            pairwiseNorm(i,cont) = ijCos;
        end
    end
    
    if strcmp(type, 'COS_DIST')
        outMetric = -mean(mean(pairwiseNorm));
    elseif strcmp(type, 'COS_DIST_ROB')         %Huber Mean average
        avgDistPerEpoch = zeros(nEpochs, 1);
        for i = 1:nEpochs
            avgDistPerEpoch(i) = f_HuberMean(pairwiseNorm(i,:));
        end
        outMetric = -f_HuberMean(avgDistPerEpoch);
    else
        disp('ERROR: Please enter a valid type of metric. Type help f_CalculateMetrics for more info');
        return
    end
    
else
    disp('ERROR: Please enter a valid type of metric. Type help f_CalculateMetrics for more info');
    return;
end

end