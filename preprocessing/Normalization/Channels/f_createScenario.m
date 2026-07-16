function mData = f_createScenario(labels, scenario, value, position)
%Description:
%Function to create different scenarios to test the spatial normalization process
%INPUTS:
%scenario = Int representing the scenario type that wants to be created:
%       1 = One point, the rest is zeros
%       2 = Two points, same sign at opposite locations
%       3 = Two points, different sign at opposite locations
%       4 = Two consecutive points with same sign
%       5 = Two consecutive points with different sign
%value = Value to be added to the scenario
%position = Position for the desired scenario:
%       'front': Scenario will be put at the forefront
%       'posterior': Scenario will be put at the back of the head
%       'right': Scenario will be put at the right of the brain (laterally)
%       'left': Scenario will be put at the left of the brain (laterally)
%       'top': Scenario will be put at the top of the brain

nChans = length(labels);        %Number of channels of the desired data
mData = zeros(nChans,1);        %Initializes the data with all zeros
if scenario == 1
    if nChans == 128
        if strcmp(position, 'front')
            logIdx = strcmp(labels, 'C17');     %C17 o C21
        elseif strcmp(position, 'posterior')
            logIdx = strcmp(labels, 'A25');     %A25 o A23 o A19
        elseif strcmp(position, 'right')
            logIdx = strcmp(labels, 'B26');     %B26 o B22
        elseif strcmp(position, 'left')
            logIdx = strcmp(labels, 'D23');     %D23 o D19
        elseif strcmp(position, 'top')
            logIdx = strcmp(labels, 'A1');      %A1
        end
        mData(logIdx) = value;
    elseif nChans == 64
        if strcmp(position, 'front')
            logIdx = strcmp(labels, 'B1') | strcmp(labels, 'Fpz');      %B1 (Fpz) o B6 (Fz)
        elseif strcmp(position, 'posterior')
            logIdx = strcmp(labels, 'A28') | strcmp(labels, 'Iz');      %A28 (Iz) o A29 (Oz) o A31 (Pz)
        elseif strcmp(position, 'right')
            logIdx = strcmp(labels, 'B20') | strcmp(labels, 'T8');      %B20 (T8) o B18 (C4)
        elseif strcmp(position, 'left')
            logIdx = strcmp(labels, 'A15') | strcmp(labels, 'T7');      %A15 (T7) o A13 (C3)
        elseif strcmp(position, 'top')
            logIdx = strcmp(labels, 'B16') | strcmp(labels, 'Cz');     %B16 (Cz)
        end
        mData(logIdx) = value;
    end
end

end