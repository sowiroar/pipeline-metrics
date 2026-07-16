function status = f_updateParametersTxtSource(paramToUpdate, params)
%Description:
%Function that updates the parameters.txt, with the desired paramToUpdate
%INPUTS:
%paramToUpdate = String with the desired parameter to update
%params = Structure with the parameters used (cureated in the f_mainSourceTransformation function)
%OUTPUTS:
%status = 1 if the script was completed succesfully. 0 otherwise

status = 1;

%Checks that the parameters.txt exists
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    status = 0;
    fprintf('The parameters.txt does not exist in the following path: \n %s \n', fullfile(params.newPath, 'parameters.txt') );
    disp('You should not get this error if you run the f_mainSourceTransformation function');
    return
end

%Checks that the paramToUpdate is a valid one
if ~ (strcmp(paramToUpdate, 'selectSourceTime') || strcmp(paramToUpdate, 'avgSourceTime') || ...
        strcmp(paramToUpdate, 'sourceTransfMethod') || strcmp(paramToUpdate, 'BMA_MCwarming') || ...
        strcmp(paramToUpdate, 'BMA_MCsamples') || strcmp(paramToUpdate, 'BMA_MET') || ... 
        strcmp(paramToUpdate, 'BMA_OWL') || strcmp(paramToUpdate, 'FT_sourcePoints') || ...
        strcmp(paramToUpdate, 'sourceROIatlas') )
    status = 0;
    fprintf('%s is not a valid parameter to update. For f_mainSourceTransformation the valid parameters are: \n', paramToUpdate);
    disp('selectSourceTime, avgSourceTime, sourceTransfMethod, sourceROIatlas');
    return
end

%Reads the original parameters.txt
txtParams = fileread(fullfile(params.newPath, 'parameters.txt'));

%If the desired parameter has not been written in the .txt, write it
initialIdx = strfind(txtParams, paramToUpdate);
if isempty(initialIdx)
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'a+');
    
    %If the parameter is selectSourceTime or avgSourceTime, add that information as well as avgSourceTime
    if strcmp(paramToUpdate, 'selectSourceTime')
        fprintf(fileID, '-------------------------------Source Transformation-------------------------------------\n \n');
        fprintf(fileID, 'Step 0 [Optional Time Selection and Averaging]: \n ');
        fprintf(fileID, '\t -%s = [%.3f, %.3f] (1) \n ', paramToUpdate, params.selectSourceTime);
    elseif strcmp(paramToUpdate, 'avgSourceTime')
        fprintf(fileID, '\t -%s = %s (1) \n ', paramToUpdate, char(string(params.avgSourceTime)));
        fprintf(fileID, '\n');
        %Works okay because 'avgSourceTime' is run just after 'selectSourceTime'. A more elegant implementation would be recommended
  
    %If the parameter is sourceTransfMethod, check if it was BMA
    elseif strcmp(paramToUpdate, 'sourceTransfMethod')
        if isempty(strfind(txtParams, 'Step 0 [Optional Time Selection and Averaging]:'))
            fprintf(fileID, '-------------------------------Source Transformation-------------------------------------\n \n');
        end
        fprintf(fileID, 'Step 1 [Channels To Source]: \n ');
        fprintf(fileID, '\t -%s = %s (1) \n ', paramToUpdate, params.sourceTransfMethod);
        if strcmpi(params.sourceTransfMethod, 'BMA')
            %If it was BMA, specify the warming and sampling iterations, the method to explore the solutions, 
            %and the lower Occam's Window value
            fprintf(fileID, '\t -%s = %d (1) \n ', 'BMA_MCwarming', params.BMA_MCwarming);
            fprintf(fileID, '\t -%s = %d (1) \n ', 'BMA_MCsamples', params.BMA_MCsamples);
            fprintf(fileID, '\t -%s = %s (1) \n ', 'BMA_MET', params.BMA_MET);
            fprintf(fileID, '\t -%s = %d (1) \n ', 'BMA_OWL', params.BMA_OWL);
        elseif strcmpi(params.sourceTransfMethod, 'FT_eLoreta') || strcmpi(params.sourceTransfMethod, 'FT_MNE')
            %If it was a FieldTrip method, specify the number of source points
            fprintf(fileID, '\t -%s = %d (1) \n ', 'FT_sourcePoints', params.FT_sourcePoints);
        end
        fprintf(fileID, '\n');
        
    %If the parameter is sourceROIatlas, add that information
    elseif strcmp(paramToUpdate, 'sourceROIatlas')
        fprintf(fileID, 'Step 2 [Source Average ROI]: \n ');
        fprintf(fileID, '\t -%s = %s (1) \n ', paramToUpdate, params.sourceROIatlas);
        fprintf(fileID, '\n');
    end
    
    fclose(fileID);
    
%If the desired parameter appears more than once, let the user know
elseif length(initialIdx) > 1
    status = 0;
    disp('ERROR: The following key words for paramToUpdate should not be used to name folders:');
    disp('sourceTransfMethod, sourceROIatlas');
    disp('Please modify the name of the folders for being able to update the parameters.txt');
    return;
    
%If the desired parameter already existed, and it appears only once, modify it
else    
    %Extracts only the information of the given step
    stepInfo = txtParams(initialIdx:end);
    finalInfo = regexp(stepInfo, '\n \n');
    stepInfo = stepInfo(1:finalInfo-1);
    
    %On that information, look if the parameter value already existed
    if strcmp(paramToUpdate, 'selectSourceTime')       %Corrects the conversion to char if two numbers are given as a vector []
        paramValue = sprintf('%.3f, %.3f]', params.(paramToUpdate)(1), params.(paramToUpdate)(2));
    else
        paramValue = params.(paramToUpdate);
        paramValue = char(string(paramValue));
    end
    
    if strcmp(paramToUpdate, 'selectSourceTime')       %Corrects the conversion to char if two numbers are given as a vector []
        [~, initialNumParam] = regexp(stepInfo, sprintf('%s (', paramValue));
    else
        [~, initialNumParam] = regexp(stepInfo, sprintf('= %s (', paramValue));
        if isempty(initialNumParam)
            [~, initialNumParam] = regexp(stepInfo, sprintf('; %s (', paramValue));
        end
    end
    
    if isempty(initialNumParam)
        %If it didn't existed, add it's value preceded by a ';' and proceded by a '(1)'
        finalNumParam = regexp(stepInfo, '\n');
        if isempty(finalNumParam)
            finalNumParam = length(stepInfo); %+1
        end
        finalNumParam = finalNumParam(1);
        
            
        %If the parameter to be updated was 'sourceTransfMethod', didn't existed, and its value was true
        %Add the info for BMA_MCwarming, BMA_MCsamples, BMA_MET, and BMA_OWL
        if strcmp(paramToUpdate, 'sourceTransfMethod') && strcmp(paramValue, 'BMA')
            finalTxt = sprintf('%s; %s (1) \n', txtParams(1:finalNumParam+initialIdx-1), paramValue);
            finalTxt = sprintf('%s\t -%s = %d (1) \n ', finalTxt, 'BMA_MCwarming', params.BMA_MCwarming);
            finalTxt = sprintf('%s\t -%s = %d (1) \n', finalTxt, 'BMA_MCsamples', params.BMA_MCsamples);
            finalTxt = sprintf('%s\t -%s = %s (1) \n', finalTxt, 'BMA_MET', params.BMA_MET);
            finalTxt = sprintf('%s\t -%s = %d (1) ', finalTxt, 'BMA_OWL', params.BMA_OWL);
            finalTxt = sprintf('%s%s', finalTxt, txtParams(finalNumParam+initialIdx:end));
            
        elseif strcmp(paramToUpdate, 'sourceTransfMethod') && ...
                (strcmp(paramValue, 'FT_eLoreta') || strcmp(paramValue, 'FT_MNE'))
            finalTxt = sprintf('%s; %s (1) \n', txtParams(1:finalNumParam+initialIdx-1), paramValue);
            finalTxt = sprintf('%s\t -%s = %d (1) ', finalTxt, 'FT_sourcePoints', params.FT_sourcePoints);
            finalTxt = sprintf('%s%s', finalTxt, txtParams(finalNumParam+initialIdx:end));
            
        
        else
            %In any other case, just add the value
            if endsWith(paramValue, ']') && ~startsWith(paramValue, '[')
                %Had to add this special case for ranges, due to formatting problems with regexp
                finalTxt = sprintf('%s; [%s (1) %s', txtParams(1:finalNumParam+initialIdx-2), paramValue, ...
                    txtParams(finalNumParam+initialIdx-1:end));   %-2 arriba, -1 acá
            else
                finalTxt = sprintf('%s; %s (1) %s', txtParams(1:finalNumParam+initialIdx-2), paramValue, ...
                    txtParams(finalNumParam+initialIdx-1:end));     %-1 arriba, 0 abajo
            end
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
    %Modify the info for BMA_MCwarming, BMA_MCsamples, BMA_MET and BMA_OWL.
    if strcmp(paramToUpdate, 'sourceTransfMethod') && strcmp(paramValue, 'BMA') && ~isempty(initialNumParam)
        status0 = f_updateParametersTxtSource('BMA_MCwarming', params);
        status1 = f_updateParametersTxtSource('BMA_MCsamples', params);
        status2 = f_updateParametersTxtSource('BMA_MET', params);
        status3 = f_updateParametersTxtSource('BMA_OWL', params);
        status = (status*status0*status1*status2*status3);
        
    elseif strcmp(paramToUpdate, 'sourceTransfMethod') && ~isempty(initialNumParam) && ...
            (strcmp(paramValue, 'FT_eLoreta') || strcmp(paramValue, 'FT_MNE'))
        status0 = f_updateParametersTxtSource('FT_sourcePoints', params);
        status = status*status0;
    end
    
end

end