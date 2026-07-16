function [newData, distanceToNearest] = f_spatiallyNormalize(mData, originalSplines, destinationSplines, type, varargin)
%Description:
%Functions that takes 'vData' in a given 'originalSplines' configuration and
%returns a version of 'vData' in the 'destinationSplines' configuration
%INPUTS:
%mData = Vector of [originalChannels, time, epochs]
%originalSplines = Name of the '.spl' original configuration of the splines (created using the 'setup' method of 'headplot' of EEGLab)
%destinationSplines = Name of the '.spl' destination configuration of the splines (created using the 'setup' method of 'headplot' of EEGLab)
%type = 1 if wants to correct for mean, 2 if wants to omit the mean correction, 
%       and 3 if wants to assign the closest neighbour value
%OUTPUTS:
%newData = Version of vData in the new configuration given by [destinationSplines] (still a 1-D vector)
%distanceToNearest = Vector with the distance (in cms) between the grid points and the desired destination point
%Author: Jhony Mejia
%

%Check that both splines' files exist
if ~exist(originalSplines) || ~exist(destinationSplines)
   error(sprintf('headplot(): spline_file "%s" not found. Run headplot in "setup" mode\n',...
       spline_file));
end

%Some optional values of the original 'headplot' function.
DEFAULT_MESH      = ['mheadnew.mat'];      % upper head model file (987K)
DEFAULT_LIGHTS = [-125  125  80; ...
                  125  125  80; ...
                  125 -125 125; ...
                  -125 -125 125];    % default lights at four cornersg = finputcheck( varargin, { ...
g = finputcheck( varargin, { ...
       'cbar'       'real'   [0 Inf]         []; % Colorbar value must be 0 or axis handle.'
       'lighting'   'string' { 'on','off' }  'on';
       'verbose'    'string' { 'on','off' }  'on';
       'maplimits'  { 'string','real' }  []  'absmax'; 
       'title'      'string' []              '';
       'lights'     'real'   []              DEFAULT_LIGHTS;
       'view'       { 'string','real' }   [] [143 18];
       'colormap'   'real'   []              jet(256);
       'transform'  'real'   []              [];
       'meshfile'   {'string','struct' } []  DEFAULT_MESH;
       'electrodes' 'string' { 'on','off' }  'on';            
       'electrodes3d' 'string' { 'on','off' }  'off';            
       'material'     'string'            [] 'dull';
       'orilocs'    { 'string','struct' } [] '';            
       'labels'     'integer' [0 1 2]        0 }, 'headplot');

%Loads the original and destination files
oriSpline = load(originalSplines, '-mat');
desSpline = load(destinationSplines, '-mat');

%Checks that the data has correct dimensions
if isfield(oriSpline, 'indices')
  try
      mData = mData(oriSpline.indices, :, :);
  catch
      error('problem of index or electrode number with splinefile'); 
  end
end
nChan = size(mData, 1);
if nChan ~= length(oriSpline.Xe)
  close;
  error('headplot(): Number of values in spline file should equal number of electrodes')
end

% change electrode if necessary
% -----------------------------
if ~isempty(g.orilocs)
  eloc_file = readlocs( g.orilocs );
  fprintf('Using original electrode locations on head...\n');
  oriSpline.indices = find(~cellfun('isempty', { eloc_file.X } ));
  newElect(:,1) = [ eloc_file(oriSpline.indices).X ]'; % attention inversion before
  newElect(:,2) = [ eloc_file(oriSpline.indices).Y ]';
  newElect(:,3) = [ eloc_file(oriSpline.indices).Z ]';        

  % optional transformation
  % -----------------------
  if ~isempty(g.transform)
      transmat  = traditionaldipfit( g.transform ); % arno
      newElect  = transmat*[ newElect ones(size(newElect,1),1)]';
      newElect  = newElect(1:3,:)';
  end
end

% --------------
% load mesh file
% --------------
[newPOS POS TRI1 TRI2 NORM index1 center] = getMeshData(g.meshfile);        %Function added at the end of this script (taken from headplot)

%Defines the ratio between X,Y,Z coordinates and cms
ratio = 100/(100.2676*2);       %100cms of head diameter / 100.2676 of cartesian coordinates
minXY = (min(newPOS(:,1:2))) - min(desSpline.newElect(:,1:2));
maxDiff = ratio*minXY;
fprintf('Max Difference between Mesh and Electrodes position = %.1fcms in X, %.1fcms in Y \n', maxDiff);

%%%%%%%%%%%%%%%%%%%%%%%%%%
% Perform interpolation
%%%%%%%%%%%%%%%%%%%%%%%%%%

%Defines the dimensions to iterate over
nEpochs = size(mData, 3);
nTimes = size(mData, 2);
newChans = size(desSpline.newElect, 1);
newData = zeros(newChans, nTimes, nEpochs);

%Iterates over all data (always over all channels) to generate the new values
lamd = 0.1;
oriG = pinv([(oriSpline.G + lamd);ones(1,nChan)]);
nOriGx = size(oriSpline.gx,1);
invDesGx = pinv(desSpline.gx);           %invGx is now [64, 6067]
nDesGx = size(desSpline.gx,2);
desG = [(desSpline.G+lamd); ones(1,newChans)];

distanceToNearest = [];
if type == 2    %Ignores the mean correction
    for i = 1:nEpochs
        for j = 1:nTimes
            rng(2021);

            %Takes the data across channels of a single timepoint of a given epoch, and represents them into a 6067-points space
            tempData = squeeze(mData(:, j, i));
            meanval = mean(tempData); tempData = tempData - meanval; % make mean zero
            C = oriG * [tempData(:);0]; % fixing division error
            P = zeros(1,nOriGx);
            for k = 1:nOriGx
                P(k) = dot(C, oriSpline.gx(k,:));
            end
            P = P + meanval;

            %Moves the values from a 6067-point space to the desired configuration/layout
            originalValues = P;

            projectedVals = zeros(1, nDesGx);           %projectedVals is the C values
            for k = 1:nDesGx
                projectedVals(k) = dot(originalValues, invDesGx(k,:));
            end

            temp1 = [projectedVals,0];
            calculatedValues = temp1*desG;
            finalCalculated = calculatedValues;

            %Assigns the new calculated values to the newData matrix
            newData(:,j,i) = finalCalculated;
        end
    end

elseif type == 1    %Performs the mean correction
    for i = 1:nEpochs
        parfor j = 1:nTimes
            rng(2021);

            %Takes the data across channels of a single timepoint of a given epoch, and represents them into a 6067-points space
            tempData = squeeze(mData(:, j, i));
            meanval = mean(tempData); tempData = tempData - meanval; % make mean zero
            C = oriG * [tempData(:);0]; % fixing division error
            P = zeros(1,nOriGx);
            for k = 1:nOriGx
                P(k) = dot(C, oriSpline.gx(k,:));
            end
            P = P + meanval;

            %Moves the values from a 6067-point space to the desired configuration/layout
            originalValues = P - meanval;

            projectedVals = zeros(1, nDesGx);           %projectedVals is the C values
            for k = 1:nDesGx
                projectedVals(k) = dot(originalValues, invDesGx(k,:));
            end

            temp1 = [projectedVals,0];
            calculatedValues = temp1*desG;
            finalCalculated = calculatedValues + meanval;

            %Assigns the new calculated values to the newData matrix
            newData(:,j,i) = finalCalculated;
        end
    end
elseif type == 3
    distanceToNearest = zeros(1, nDesGx);
    for i = 1:nEpochs
        for j = 1:nTimes
            rng(2021);

            %Takes the data across channels of a single timepoint of a given epoch, and represents them into a 6067-points space
            tempData = squeeze(mData(:, j, i));
            meanval = mean(tempData); tempData = tempData - meanval; % make mean zero
            C = oriG * [tempData(:);0]; % fixing division error
            P = zeros(1,nOriGx);
            for k = 1:nOriGx
                P(k) = dot(C, oriSpline.gx(k,:));
            end
            P = P + meanval;
            
            %Assigns the closest value of the 6067-point space to the new configuration
            calculatedVals = zeros(1, newChans);
            for k = 1:newChans
                iCoords = desSpline.newElect(k,:);
                tempDiff = newPOS - iCoords;
                diffSq = tempDiff.^2;
                l2Norm = sqrt(sum(diffSq, 2));
                [val, idx] = min(l2Norm);
                distanceToNearest(k) = val*ratio;
                calculatedVals(k) = P(idx);
            end
            
            %Assigns the new calculated values to the newData matrix
            newData(:,j,i) = calculatedVals;
        end
    end
end

%Finally, checks that both newData and mData are of the same size (Except the channels dimension)
finalSize = size(newData);
for i = 2: length(finalSize)
    if size(mData, i) ~= finalSize(i)
        disp('ERROR: Unexpected Error. The newData and original data must have the same dimensions except for channels');
        newData = [];
        return
    end
end

end

% get mesh information
% --------------------
function [newPOS POS TRI1 TRI2 NORM index1 center] = getMeshData(meshfile);
if isdeployed
    addpath( fullfile( ctfroot, 'EEGLAB', 'functions', 'supportfiles') );
end
        
if ~isstruct(meshfile)
    if ~exist(meshfile)
        if isdeployed
            meshfile = fullfile( ctfroot, 'EEGLAB', 'functions', 'supportfiles', meshfile);
            if ~exist(meshfile)
                error(sprintf('headplot(): deployed mesh file "%s" not found\n',meshfile));
            end
        else
            error(sprintf('headplot(): mesh file "%s" not found\n',meshfile));
        end
    end
    fprintf('Loaded mesh file %s\n',meshfile);
    try
        meshfile = load(meshfile,'-mat');
    catch,
        meshfile = [];
        meshfile.POS  = load('mheadnewpos.txt', '-ascii');
        meshfile.TRI1 = load('mheadnewtri1.txt', '-ascii'); % upper head
        %try, TRI2 = load('mheadnewtri2.txt', '-ascii'); catch, end; % lower head
        %index1 = load('mheadnewindex1.txt', '-ascii');
        meshfile.center = load('mheadnewcenter.txt', '-ascii');
    end
end;        
        
if isfield(meshfile, 'vol')
    if isfield(meshfile.vol, 'r')
        [X Y Z] = sphere(50);
        POS  = { X*max(meshfile.vol.r) Y*max(meshfile.vol.r) Z*max(meshfile.vol.r) };
        TRI1 = [];
    else
        POS  = meshfile.vol.bnd(1).pnt;
        TRI1 = meshfile.vol.bnd(1).tri;
    end
elseif isfield(meshfile, 'bnd')
    POS  = meshfile.bnd(1).pnt;
    TRI1 = meshfile.bnd(1).tri;
elseif isfield(meshfile, 'TRI1')
    POS  = meshfile.POS;
    TRI1 = meshfile.TRI1;
    try TRI2   = meshfile.TRI2;   end  % NEW
    try center = meshfile.center; end  % NEW
elseif isfield(meshfile, 'vertices')
    POS  = meshfile.vertices;
    TRI1 = meshfile.faces;
else
    error('Unknown Matlab mesh file');
end
if exist('index1') ~= 1, index1 = sort(unique(TRI1(:))); end
if exist('TRI2')   ~= 1, TRI2 = []; end
if exist('NORM')   ~= 1, NORM = []; end
if exist('TRI1')   ~= 1, error('Variable ''TRI1'' not defined in mesh file'); end
if exist('POS')    ~= 1, error('Variable ''POS'' not defined in mesh file'); end
if exist('center') ~= 1, center = [0 0 0]; disp('Using [0 0 0] for center of head mesh'); end
newPOS = POS(index1,:);
end