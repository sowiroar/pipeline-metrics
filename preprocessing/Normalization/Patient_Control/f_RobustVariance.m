function robVar = f_RobustVariance(x)
%Description:
%Calculates the robust variance (e.g. Huber mean instead of normal mean) of a vector 'x'
%INPUTS:
%x = Vector of [1,n] whose robust variance wants to be calculated
%OUTPUTS:
%robVar = Robust Variance of the vector x

n = length(x);
xMean = f_HuberMean(x);         %Gets the Huber Mean of vector X
diffX = x - xMean;              %Substracts the Huber Mean of the vector X
sqDiffX = diffX.^2;              %Squares each value of the Huber-difference vector

robVar = sum(sqDiffX)/(n-1);

end