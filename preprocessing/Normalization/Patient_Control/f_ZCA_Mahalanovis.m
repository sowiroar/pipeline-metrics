function [whiteX, whiteMatrix] = f_ZCA_Mahalanovis(x, epsilon, meanCentered)
%Description:
%Function that performs ZCA-Mahalanovis whitening of the given matrix x.
%Code based on Stanford's tutorial for PCA Whitening:
%http://ufldl.stanford.edu/tutorial/unsupervised/PCAWhitening/
%
%INPUTS:
%x = Matrix of MxN, where M are Variables and N are observations (Does not need to be normalized or mean centered)
%epsilon = The value to prevent dividing by eigenvalues equal to zero (1e-5 by default)
%meanCentered = Boolean to indicate if the values of X are already mean centered per column (False by default)
%OUTPTUS:
%whiteX = The whitened version of 'x'
%whiteMatrix = The matrix used to whiten 'x'
%Author: Jhony Mejia

if nargin < 2
    epsilon = 1e-5;
end
if nargin < 3
    meanCentered = false;
end

%If the data has not been mean-centered, center it.
if ~meanCentered
    avg = mean(x, 1);     %Compute the mean for each observation (e.g. one value per column)
    x = x - repmat(avg, size(x, 1), 1);     %Centers the mean of each observation
end

sigma = x * x' / size(x, 2);        %Calculates the correlation matrix

%Calculates the eigenvalues and eigenvectors of the correlation matrix
[U,S,~] = svd(sigma);
%U  will contain the eigenvectors of sigma (one eigenvector per column, sorted in order from top to bottom eigenvector)
%S diagonals are the eigenvalues of the corresponding eigenvectors (also sorted from top to bottom)
%Third argument (V) is not of interest in this case

%Calculates the whitening matrix
whiteMatrix = U * diag(1./sqrt(diag(S) + epsilon)) * U';

%Whitens the matrix X.
whiteX = whiteMatrix * x;


end