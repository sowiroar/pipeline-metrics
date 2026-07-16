%Script to explore what 'headplot' does
%% Loads the example dataset of 64 original labels.
a = pop_loadset('ej64.set');

%% Has to be run once only. Creates a 'splines64.spl' file for the given channel locations
%headplot('setup', a.chanlocs, 'splines64.spl');

%% Explore what the splines64.mat file has
load('splines64.spl', '-mat')
%'ElectrodeNames' has the original labels of the channels (64,3 char array)
%'G' is something of the shape [channels, channels] (64,64 in this case)
%'gx' is of shape 6067x64 (the original mesh had 6114 points)
%headplot_versin is equal to 2
%newElect is apparentely the new channels coordinates [channels, 3] (X,Y,Z; after CALCULATING THEIR PROJECTIONS TO THE SPHERE)
%Transform is the Tailarach transformations matrix (translate, rotate and scale)
%Xe, Ye and Ze are of size (64, 1). Those are the new normalized coordinates with respect to the head center of the original electrodes after aligning them to the mesh model template.

%The function that does the magic is:
%gx = fastcalcgx(x,y,z,Xe,Ye,Ze);
%Which takes the x, y, z coordinates of the unit sphere (6067) and Xe, Ye, Ze (64, the electrodes' locations)

%% Runs to see how the values are projected into the new surface
headplot(a.data, 'splines64.mat');

%% Notes of how it works and what to do
%The values P are the ones plotted in the head (size 6067). (takes values in 64 space, applies the g(x) to move them to a 6067 space)
%The intensities are rescaled in W (actually what is plotted)
meanval = mean(values); values = values - meanval; % make mean zero
onemat = ones(enum,1);
lamd = 0.1;
C = pinv([(G + lamd);ones(1,enum)]) * [values(:);0]; % fixing division error
P = zeros(1,size(gx,1));
for j = 1:size(gx,1)
P(j) = dot(C,gx(j,:));
end
P = P + meanval;


%What I need is: Given a P, return to the 'originalValues'. To do so:
originalValues = P - meanval;       %NOTE: In practice, I won't have meanval (so probably they won't be centered in 0)
                                    %Since I am adding and substracting it, it won't have much of a deal (I hope)
%originalValues = P;
                                    
invGx = pinv(gx);           %invGx is now [64, 6067]
projectedVals = zeros(1, size(gx,2));           %projectedVals is the C values
for j = 1:size(gx,2)
    projectedVals(j) = dot(originalValues, invGx(j,:));
end

calculatedValues = projectedVals*(G+lamd);
%temp1 = [projectedVals,0];
%temp2 = [(G+lamd); ones(1,64)];
%calculatedValues = temp1*temp2;
finalCalculated = calculatedValues + meanval;
%finalCalculated = calculatedValues;

%% Calculates the percentage difference between the original vs calculated values
realOriginal = values + meanval;
absDiff = abs(finalCalculated - realOriginal);
percentageError = 100*absDiff./realOriginal;

plot(realOriginal, finalCalculated, '*r'), 
hold on,
plot([min(realOriginal), max(realOriginal)], [min(realOriginal), max(realOriginal)])
plot([min(realOriginal), max(realOriginal)], [0, 0], 'k')
plot([0, 0], [min(realOriginal), max(realOriginal)], 'k')
xlabel('Original Data');
ylabel('Predicted Data');

%% Looks for the nearest point available, and put that single value

%Apparentely, the equivalent spaces are 'newElect' and 'newPos'
%So for each original coordinate looks for the nearest neighbour
nOri = size(newElect, 1);
calculatedVals = zeros(1, nOri);
for i = 1:nOri
    iCoords = newElect(i,:);
    tempDiff = newPOS - iCoords;
    diffSq = tempDiff.^2;
    l2Norm = sum(diffSq, 2);
    [val, idx] = min(l2Norm);
    calculatedVals(i) = P(idx);
end

realOriginal = values + meanval;
absDiff = abs(calculatedVals - realOriginal);
percentageError = 100*absDiff./realOriginal;

plot(realOriginal, finalCalculated, '*r'), 
hold on,
plot([min(realOriginal), max(realOriginal)], [min(realOriginal), max(realOriginal)])
plot([min(realOriginal), max(realOriginal)], [0, 0], 'k')
plot([0, 0], [min(realOriginal), max(realOriginal)], 'k')
xlabel('Original Data');
ylabel('Predicted Data');