function status = f_updateParametersTxtNorm(paramToUpdate, params)
%Description:
%Function that updates the parameters.txt, with the desired paramToUpdate
%INPUTS:
%paramToUpdate = String with the desired parameter to update
%params = Structure with the parameters used (cureated in the f_mainNormalization function)
%OUTPUTS:
%status = 1 if the script was completed succesfully. 0 otherwise

status = 1;

%Checks that the parameters.txt exists
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    status = 0;
    fprintf('The parameters.txt does not exist in the following path: \n %s \n', fullfile(params.newPath, 'parameters.txt') );
    disp('You should not get this error if you run the f_mainPrepro function');
    return
end

%Checks that the paramToUpdate is a valid one
if ~ (strcmp(paramToUpdate, 'runSpatialNorm') || strcmp(paramToUpdate, 'fromXtoYLayout') || ...
        strcmp(paramToUpdate, 'headSizeCms') || strcmp(paramToUpdate, 'runPatientControlNorm') || ... 
        strcmp(paramToUpdate, 'controlLabel') || strcmp(paramToUpdate, 'minDurationS') || ...
        strcmp(paramToUpdate, 'normFactor'))
    status = 0;
    fprintf('%s is not a valid parameter to update. For f_mainPreproNormalization the valid parameters are: \n', paramToUpdate);
    disp('runSpatialNorm, runPatientControlNorm');
    return
end

%Reads the original parameters.txt
txtParams = fileread(fullfile(params.newPath, 'parameters.txt'));

%If the desired parameter has not been written in the .txt, write it
initialIdx = strfind(txtParams, paramToUpdate);
if isempty(initialIdx)
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'a+');
    
    %If the parameter is filterAndResample, check if it was set to true or false
    if strcmp(paramToUpdate, 'runSpatialNorm')
        fprintf(fileID, '-----------------------------------Normalization-----------------------------------------\n \n');
        fprintf(fileID, 'Step 1 [Spatial Normalization]: \n ');
        fprintf(fileID, '\t -%s = %s (1) \n ', paramToUpdate, char(string(params.runSpatialNorm)));
        if params.runSpatialNorm
            %If it was true, specify the interpolation performed, and the head size in cms used
            fprintf(fileID, '\t -%s = %s (1) \n ', 'fromXtoYLayout', params.fromXtoYLayout);
            fprintf(fileID, '\t -%s = %.1f (1) \n ', 'headSizeCms', params.headSizeCms);
        end
        fprintf(fileID, '\n');
        
    %If the parameter is burstCriterion or windowCriterion, add that information
    elseif strcmp(paramToUpdate, 'runPatientControlNorm')
        fprintf(fileID, 'Step 2 [Patient Control Normalization]: \n ');
        fprintf(fileID, '\t -%s = %s (1) \n ', paramToUpdate, char(string(params.runPatientControlNorm)));
        if params.runPatientControlNorm
            %If it was true, specify the controlLabel, the minDurationS in seconds that the subjects have, and the normalization factor used
            fprintf(fileID, '\t -%s = %s (1) \n ', 'controlLabel', params.controlLabel);
            fprintf(fileID, '\t -%s = %.1f (1) \n ', 'minDurationS', params.minDurationS);
            fprintf(fileID, '\t -%s = %s (1) \n ', 'normFactor', params.normFactor);
        end
        fprintf(fileID, '\n');
    end
    
    fclose(fileID);
    
%If the desired parameter appears more than once, let the user know
elseif length(initialIdx) > 1
    status = 0;
    disp('ERROR: The following key words for paramToUpdate should not be used to name folders:');
    disp('runSpatialNorm, runPatientControlNorm');
    disp('Please modify the name of the folders for being able to update the parameters.txt');
    return;
    
%If the desired parameter already existed, and it appears only once, modify it
else    
    %Extracts only the information of the given step
    stepInfo = txtParams(initialIdx:end);
    finalInfo = regexp(stepInfo, '\n \n');
    stepInfo = stepInfo(1:finalInfo-1);
    
    %On that information, look if the parameter value already existed
    if strcmp(paramToUpdate, 'headSizeCms') || strcmp(paramToUpdate, 'minDurationS')         %Corrects the conversion to char for 'headSizeCms' and 'minDurationS'
        paramValue = sprintf('%.1f', params.(paramToUpdate));
    else
        paramValue = params.(paramToUpdate);
        paramValue = char(string(paramValue));
    end
    
    [~, initialNumParam] = regexp(stepInfo, sprintf('= %s (', paramValue));
    if isempty(initialNumParam)
        [~, initialNumParam] = regexp(stepInfo, sprintf('; %s (', paramValue));
    end
    
    if isempty(initialNumParam)
        %If it didn't existed, add it's value preceded by a ';' and proceded by a '(1)'
        finalNumParam = regexp(stepInfo, '\n');
        if isempty(finalNumParam)
            finalNumParam = length(stepInfo); %+1
        end
        finalNumParam = finalNumParam(1);
        
        %If the parameter to be updated was 'runSpatialNorm', didn't existed, and its value was true
        %Add the info for fromXtoYLayout and headSizeCms as well.
        if strcmp(paramToUpdate, 'runSpatialNorm') && strcmp(paramValue, 'true')
            finalTxt = sprintf('%s; %s (1) \n', txtParams(1:finalNumParam+initialIdx-1), paramValue);
            finalTxt = sprintf('%s\t -%s = %s (1) \n ', finalTxt, 'fromXtoYLayout', params.fromXtoYLayout);
            finalTxt = sprintf('%s\t -%s = %.1f (1) ', finalTxt, 'headSizeCms', params.headSizeCms);
            finalTxt = sprintf('%s%s', finalTxt, txtParams(finalNumParam+initialIdx:end));
            
        %If the parameter to be updated was 'runPatientControlNorm', didn't existed, and its value was true
        %Add the info for controlLabel, minDurationS and normFactor as well.
        elseif strcmp(paramToUpdate, 'runPatientControlNorm') && strcmp(paramValue, 'true')
            finalTxt = sprintf('%s; %s (1) \n', txtParams(1:finalNumParam+initialIdx-1), paramValue);
            finalTxt = sprintf('%s\t -%s = %s (1) \n ', finalTxt, 'controlLabel', params.controlLabel);
            finalTxt = sprintf('%s\t -%s = %.1f (1) \n ', finalTxt, 'minDurationS', params.minDurationS);
            finalTxt = sprintf('%s\t -%s = %s (1) ', finalTxt, 'normFactor', params.normFactor);
            finalTxt = sprintf('%s%s', finalTxt, txtParams(finalNumParam+initialIdx:end));
            
        else
            %In any other case, just add the value
            finalTxt = sprintf('%s; %s (1) %s', txtParams(1:finalNumParam+initialIdx-2), paramValue, ...
                txtParams(finalNumParam+initialIdx-1:end));     %-1 arriba, 0 abajo
        end
        
    else
        %If it already existed, add 1 to the number in parentheses
        finalNumParam = regexp(stepInfo(initialNumParam:end), ')');
        numSubjectsParam = stepInfo(initialNumParam+1:initialNumParam+finalNumParam(1)-2);
        numSubjectsParam = str2double(numSubjectsParam) +1;
        
        %Add that info to the pre-existing one
        finalTxt = sprintf('%s%d%s', txtParams(1:initialIdx + initialNumParam -1), numSubjectsParam, ...
            txtParams(initialIdx + initialNumParam + finalNumParam -2 : end));
    end
    
    %Finally, over-write the existing file, with the info in finalTxt
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'w');
    fprintf(fileID, '%s', finalTxt);
    fclose(fileID);
    
    %Finally, if the parameter to be updated was 'runSpatialNorm', DID existed, and its value was true
    %Modify the info for fromXtoYLayout and headSizeCms.
    if strcmp(paramToUpdate, 'runSpatialNorm') && strcmp(paramValue, 'true') && ~isempty(initialNumParam)
        status0 = f_updateParametersTxtNorm('fromXtoYLayout', params);
        status1 = f_updateParametersTxtNorm('headSizeCms', params);
        status = (status*status0*status1);
        
    %If the parameter to be updated was 'runPatientControlNorm', DID existed, and its value was true
    %Modify the info for controlLabel, minDurationS and normFactor.
    elseif strcmp(paramToUpdate, 'runPatientControlNorm') && strcmp(paramValue, 'true') && ~isempty(initialNumParam)
        status0 = f_updateParametersTxtNorm('controlLabel', params);
        status1 = f_updateParametersTxtNorm('minDurationS', params);
        status2 = f_updateParametersTxtNorm('normFactor', params);
        status = (status*status0*status1*status2);
    end
    
end

end