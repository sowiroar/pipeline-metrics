function [huberMean, huberStd] = f_HuberMean(iVector)
%Description:
%Function that calculates the Huber mean iteratively for a given input vector
%This function is a Minitab adaptation of an AMC script that can be found here:
%https://www.rsc.org/images/robustmean_tcm18-26300.doc
%
%For more information about the Huber mean, check:
%Analytical Methods Committee, 2001. Robust statistics: a method of coping with outliers. R. Soc. Chem. AMC Tech. Brief.
%
%INPUTS:
%iVector = A vector of 1xN whose values will be used to calculate the Huber Mean
%OUTPUTS:
%huberMean = The Huber mean (a number).
%huberStd = The Huber standard deviation (a number).
%Author: Jhony Mejia

%First, calculates the Median, Mean Absolute Deviation, and the Robust Standard Deviation
M = median(iVector);
vDiff = iVector - M;
MAD = median(abs(vDiff));
S = MAD/0.6745;

%Defines variables used for iteration
tol = 0.1;
iCount = 0;

huberVec = iVector;
%Iterates
while ((tol > 0.00001) && iCount < 100) || iCount < 10
    SA = S;
    low = M - 1.5*S;
    high = M + 1.5*S;
    
    %Winsorises raw data
    idxsMax = huberVec > high;
    huberVec(idxsMax) = high;
    idxsMin = huberVec < low;
    huberVec(idxsMin) = low;
    
    %Update estimates
    M = mean(huberVec);
    S = std(huberVec)/0.882;
    
    %Checks for sufficient convergence
    if SA > 0
        tol = abs(SA-S)/SA;
    else
        disp('ERROR: Problem with near zero SD - TERMINATED');
        return
    end
    
    iCount = iCount+1;
end

%Defines outputs
huberMean = M;
huberStd = S;
if iCount > 99
    disp('WARNING: Iteration did not converge');
end

end