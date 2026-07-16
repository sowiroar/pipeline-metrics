function status = f_updateParametersTxtConnect(paramToUpdate, params)
%Description:
%Function that updates the parameters.txt, with the desired paramToUpdate
%INPUTS:
%paramToUpdate = String with the desired parameter to update
%params = Structure with the parameters used (cureated in the f_mainConnectivity function)
%OUTPUTS:
%status = 1 if the script was completed succesfully. 0 otherwise

status = 1;

%Checks that the parameters.txt exists
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    status = 0;
    fprintf('The parameters.txt does not exist in the following path: \n %s \n', fullfile(params.newPath, 'parameters.txt') );
    disp('You should not get this error if you run the f_mainConnectivity function');
    return
end

%Checks that the paramToUpdate is a valid one
if ~ (strcmp(paramToUpdate, 'runConnectivity') || strcmp(paramToUpdate, 'connIgnoreWSM'))
    status = 0;
    fprintf('%s is not a valid parameter to update. For f_mainConnectivity the valid parameters are: \n', paramToUpdate);
    disp('runConnectivity');
    return
end

%Reads the original parameters.txt
txtParams = fileread(fullfile(params.newPath, 'parameters.txt'));

%If the desired parameter has not been written in the .txt, write it
initialIdx = strfind(txtParams, paramToUpdate);
if isempty(initialIdx)
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'a+');
    
    %If the parameter is runConnectivity, add its boolean
    if strcmp(paramToUpdate, 'runConnectivity')
        fprintf(fileID, '--------------------------------Connectivity Metrics-------------------------------------\n \n');
        fprintf(fileID, 'Step 1 [Connectivity Metrics]: \n ');
        fprintf(fileID, '\t -%s = %s (1) \n ', paramToUpdate, char(string(params.runConnectivity)));
        fprintf(fileID, '\t -%s = %s (1) \n ', 'connIgnoreWSM', char(string(params.connIgnoreWSM)));
        fprintf(fileID, '\n');
    end
    
    fclose(fileID);
    
%If the desired parameter appears more than once, let the user know
elseif length(initialIdx) > 1
    status = 0;
    disp('ERROR: The following key words for paramToUpdate should not be used to name folders:');
    disp('runConnectivity');
    disp('Please modify the name of the folders for being able to update the parameters.txt');
    return;
    
%If the desired parameter already existed, and it appears only once, modify it
else    
    %Extracts only the information of the given step
    stepInfo = txtParams(initialIdx:end);
    finalInfo = regexp(stepInfo, '\n \n');
    stepInfo = stepInfo(1:finalInfo-1);
    
    %On that information, look if the parameter value already existed
    paramValue = params.(paramToUpdate);
    paramValue = char(string(paramValue));
    
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
        
        %If the parameter to be updated was 'runConnectivity', didn't existed, and its value was true, add its info
        if strcmp(paramToUpdate, 'runConnectivity') && params.runConnectivity
            finalTxt = sprintf('%s; %s (1) \n', txtParams(1:finalNumParam+initialIdx-1), paramValue);
            finalTxt = sprintf('%s\t -%s = %d (1) \n ', finalTxt, 'connIgnoreWSM', char(string(params.connIgnoreWSM)));
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
    
    
    %Finally, if the parameter to be updated was 'filterAndResample', DID existed, and its value was true
    %Modify the info for Sampling Rate and Filtering Frequencies.
    if strcmp(paramToUpdate, 'runConnectivity') && strcmp(paramValue, 'true') && ~isempty(initialNumParam)
        status0 = f_updateParametersTxtConnect('connIgnoreWSM', params);
        status = (status*status0);
    end
    
end

end