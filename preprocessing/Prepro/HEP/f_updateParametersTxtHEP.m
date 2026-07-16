function status = f_updateParametersTxtHEP(paramToUpdate, params)
%Description:
%Function that updates the parameters.txt, with the desired paramToUpdate
%INPUTS:
%paramToUpdate = String with the desired parameter to update
%params = Structure with the parameters used (cureated in the f_mainPrepro function)
%OUTPUTS:
%status = 1 if the script was completed succesfully. 0 otherwise
%TODO: Chequear que esto corra bien

status = 1;

%Checks that the parameters.txt exists
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    status = 0;
    fprintf('The parameters.txt does not exist in the following path: \n %s \n', fullfile(params.newPath, 'parameters.txt') );
    disp('You should not get this error if you run the f_mainPrepro function');
    return
end

%Checks that the paramToUpdate is a valid one
if ~ (strcmp(paramToUpdate, 'filterAndResample') || strcmp(paramToUpdate, 'newSR') || ...
        strcmp(paramToUpdate, 'freqRange') || strcmp(paramToUpdate, 'reref_REST') || ... 
        strcmp(paramToUpdate, 'onlyBlinks') || strcmp(paramToUpdate, 'epochRange') || ...
        strcmp(paramToUpdate, 'jointProbSD') || strcmp(paramToUpdate, 'kurtosisSD') || ...
        strcmp(paramToUpdate, 'baselineRange'))
    status = 0;
    fprintf('%s is not a valid parameter to update. For f_mainPreproHEP the valid parameters are: \n', paramToUpdate);
    disp('filterAndResample, reref_REST, onlyBlinks, epochRange, jointProbSD, kurtosisSD, baselineRange');
    return
end

%Reads the original parameters.txt
txtParams = fileread(fullfile(params.newPath, 'parameters.txt'));

%If the desired parameter has not been written in the .txt, write it
initialIdx = strfind(txtParams, paramToUpdate);
if isempty(initialIdx)
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'a+');
    
    %If the parameter is filterAndResample, check if it was set to true or false
    if strcmp(paramToUpdate, 'filterAndResample')
        fprintf(fileID, 'Step 0 [Optional filtering and resampling]: \n ');
        fprintf(fileID, '\t -%s = %s (1) \n ', paramToUpdate, char(string(params.filterAndResample)));
        if params.filterAndResample
            %If it was true, specify the new Sampling Rate, and the bandpass filter used
            fprintf(fileID, '\t -%s = %d (1) \n ', 'newSR', params.newSR);
            fprintf(fileID, '\t -%s = [%.1f, %.1f] (1) \n ', 'freqRange', params.freqRange);
        end
        fprintf(fileID, '\n');
    
    %If the parameter is reref_REST, add that information
    elseif strcmp(paramToUpdate, 'reref_REST')
        fprintf(fileID, 'Step 2 [Average reference]: \n ');
        fprintf(fileID, '\t -%s = %s (1) \n \n', paramToUpdate, char(string(params.reref_REST)));
        
    %If the parameter is onlyBlinks, add that information  
    elseif strcmp(paramToUpdate, 'onlyBlinks')
        fprintf(fileID, 'Step 4 [Components rejection]: \n');
        fprintf(fileID, '\t -%s = %s (1) \n \n', paramToUpdate, char(string(params.onlyBlinks)));
    
    %If the parameter is epochRange, add that information  
    elseif strcmp(paramToUpdate, 'epochRange')
        fprintf(fileID, 'Step 6 [Epoch definition]: \n');
        fprintf(fileID, '\t -%s = [%.3f, %.3f] (1) \n \n', 'epochRange', params.epochRange);

    %If the parameter is jointProbSD or kurtosisSD, add that information
    elseif strcmp(paramToUpdate, 'jointProbSD')
        fprintf(fileID, 'Step 7 [Epoch rejection]: \n');
        fprintf(fileID, '\t -%s = %.2f (1) \n ', 'jointProbSD', params.(paramToUpdate));
    elseif strcmp(paramToUpdate, 'kurtosisSD')
        fprintf(fileID, '\t -%s = %.2f (1) \n \n', 'kurtosisSD', params.(paramToUpdate));
        %Works okay because 'kurtosisSD' is run just after 'jointProbSD'. A more elegant implementation would be recommended
    
    %If the parameter is epochRange, add that information  
    elseif strcmp(paramToUpdate, 'baselineRange')
        fprintf(fileID, 'Step 8 [Baseline removal]: \n');
        fprintf(fileID, '\t -%s = [%.3f, %.3f] (1) \n \n', 'baselineRange', params.baselineRange);
    end

    fclose(fileID);
    
%If the desired parameter appears more than once, let the user know
elseif length(initialIdx) > 1
    status = 0;
    disp('ERROR: The following key words for paramToUpdate should not be used to name folders:');
    disp('filterAndResample, burstCriterion, windowCriterion, onlyBlinks');
    disp('Please modify the name of the folders for being able to update the parameters.txt');
    return;
    
%If the desired parameter already existed, and it appears only once, modify it
else    
    %Extracts only the information of the given step
    stepInfo = txtParams(initialIdx:end);
    finalInfo = regexp(stepInfo, '\n \n');
    stepInfo = stepInfo(1:finalInfo-1);
    
    %On that information, look if the parameter value already existed
    %Corrects the conversion to char if two numbers are given as a vector []
    if strcmp(paramToUpdate, 'freqRange')
        paramValue = sprintf('%.1f, %.1f]', params.(paramToUpdate)(1), params.(paramToUpdate)(2));
    %Corrects the conversion to char for 'jointProbSD' or 'kurtosisSD'
    elseif strcmp(paramToUpdate, 'jointProbSD') || strcmp(paramToUpdate, 'kurtosisSD')
        paramValue = sprintf('%.2f', params.(paramToUpdate));
    %Corrects the conversion to char if two numbers are given as a vector []
    elseif strcmp(paramToUpdate, 'epochRange') || strcmp(paramToUpdate, 'baselineRange')
        paramValue = sprintf('%.3f, %.3f]', params.(paramToUpdate)(1), params.(paramToUpdate)(2));
    else
        paramValue = params.(paramToUpdate);
        paramValue = char(string(paramValue));
    end

    %Corrects the conversion to char if two numbers are given as a vector []
    if strcmp(paramToUpdate, 'freqRange') || strcmp(paramToUpdate, 'epochRange') || strcmp(paramToUpdate, 'baselineRange')
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
            finalNumParam = length(stepInfo);
        end
        
        %If the parameter to be updated was 'filterAndResample', didn't existed, and its value was true
        %Add the info for Sampling Rate and Filtering Frequencies as well.
        if strcmp(paramToUpdate, 'filterAndResample') && strcmp(paramValue, 'true')
            finalTxt = sprintf('%s; %s (1) \n', txtParams(1:finalNumParam+initialIdx-1), paramValue);
            finalTxt = sprintf('%s\t -%s = %d (1) \n ', finalTxt, 'newSR', params.newSR);
            finalTxt = sprintf('%s\t -%s = [%.1f, %.1f] (1) ', finalTxt, 'freqRange', params.freqRange);
            finalTxt = sprintf('%s%s', finalTxt, txtParams(finalNumParam+initialIdx:end));
        else
            %In any other case, just add the value
            if endsWith(paramValue, ']') && ~startsWith(paramValue, '[')
                %Had to add this special case for ranges, due to formatting problems with regexp
                finalTxt = sprintf('%s; [%s (1) %s', txtParams(1:finalNumParam+initialIdx-2), paramValue, ...
                    txtParams(finalNumParam+initialIdx-1:end));
            else
                finalTxt = sprintf('%s; %s (1) %s', txtParams(1:finalNumParam+initialIdx-2), paramValue, ...
                    txtParams(finalNumParam+initialIdx-1:end));
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
    
    %Finally, if the parameter to be updated was 'filterAndResample', DID existed, and its value was true
    %Modify the info for Sampling Rate and Filtering Frequencies.
    if strcmp(paramToUpdate, 'filterAndResample') && strcmp(paramValue, 'true') && ~isempty(initialNumParam)
        status0 = f_updateParametersTxtHEP('newSR', params);
        status1 = f_updateParametersTxtHEP('freqRange', params);
        status = (status*status0*status1);
    end
end

end