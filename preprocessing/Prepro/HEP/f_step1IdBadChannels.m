function [badChanIdxs, badChanLbls] = f_step1IdBadChannels(pathStep0, nameStep0, chanInfo)
%Function that allows the user to perform bad channel identification in a Graphical User Interface (GUI)
%INPUTS:
%pathStep0: Path of the .set to be analyzed (Ideally the marked .set of Step 0)
%nameStep0: Name of the .set to be analyzed (Ideally the marked .set of Step 0)
%chanInfo: Information about bad channels. Can be:
%   -Emtpy/not given: There is no information about the channels
%   -A table (read from a .tsv format) containing channel information
%   -A vector with the indexes of the bad channels
%OUTPUTS:
%badChanIdxs: Indexes of the channels that were selected as bad channels by the user
%badChanLbls: Labels of the channels that were selected as bad channels by the user
% created by agus & agus, Oct 14 2016

%Define the chanTable as empty if it was not given by the user
if nargin < 3
    chanInfo = [];
end

%Defines cut offs for visualization
lowerVal = -100;
higherVal = 100;


%Loads the .set of the desired subject
EEG = pop_loadset('filename', nameStep0, 'filepath', pathStep0);
tempData = EEG.data;
chanLbls = {EEG.chanlocs(:).labels};
tempLbls = chanLbls;


%If the channel table is not empty, use it
if ~isempty(chanInfo)
    %Check if it is a table (taken from a .tsv)
    if istable(chanInfo)
        bad_channels = [];
        colNames = chanInfo.Properties.VariableNames;
        
        %The tsv file MUST have a name and status column
        if sum(strcmp(colNames, 'name')) * sum(strcmp(colNames, 'status')) == 0
            disp('WARNING: The channels.tsv does not have a BIDS format');
            disp('It must have a name and status column:');
            disp('In name, it must be specified the label of each channel');
            disp('In status it should be specified if the quality is good or 1; or bad or 0');
        
        else
            %If it has those columns, iterate over the channels of the .tsv, and add the bad channels
            chansTsv = chanInfo.name;
            statusTsv = chanInfo.status;
            for i = 1:length(chansTsv)
                %If the i-th channel of the tsv exists in the .set and is marked as a bad channel, add it
                tsvVsReal = strcmp(chanLbls, chansTsv{i});
                if (sum(tsvVsReal) > 0) && (strcmp('bad', statusTsv{i}) || strcmp('0', statusTsv{i}))
                    pos = find(tsvVsReal);
                    tempLbls{pos} = strcat(chansTsv{i}, ' - MARKED');
                    tempData(pos,:) = lowerVal;
                    bad_channels = [bad_channels pos]; %#ok
                    disp(['Added bad channel from .tsv: ', num2str(pos), '-', chanLbls{pos}])
                end
            end
            
            %Additionally, if it has the 'type' column, ask the user if non-EEG channels should be eliminated
            if sum(strcmp(colNames, 'type')) == 1
                disp('Do you want to eliminate non-EEG channels using the .tsv information? (y/n)');
                nonEEG = input('', 's');
                if strcmpi(nonEEG, 'y')
                    typeTsv = chanInfo.type;
                    for i = 1:length(chansTsv)
                        tsvVsReal = strcmp(chanLbls, chansTsv{i});
                        %If the i-th channel of the tsv exists and is not an EEG channel, label them as bad channels
                        if (sum(tsvVsReal) > 0) && ~(strcmpi('EEG', typeTsv{i}))
                            pos = find(tsvVsReal);
                            tempLbls{pos} = strcat(chansTsv{i}, ' - MARKED');
                            tempData(pos,:) = lowerVal;
                            bad_channels = [bad_channels pos]; %#ok
                            disp(['Added bad channel from .tsv: ', num2str(pos), '-', chanLbls{pos}])
                        end
                    end
                end
            end
                
            
            %If there was not a single bad channel in the tsv, notify the user
            if isempty(bad_channels)
                disp('WARNING: The .tsv did not have any bad channel. Please inspect the data and select the bad channels in the figure prompted');
            else
                fprintf('%d channels were succesfully added as bad channels', length(bad_channels));
                disp('You can check how the channels labeled as bad looked like by unselecting them, or you can eliminate more channels if you wish in the figure prompted')
            end
        end              
    end
    
else
    %If there is not any information about the channels, initialize them as an empty array
    bad_channels = [];
end
    

%Automatically mark channels without locations as bad channels (non-EEG channels)
emptychans = find(cellfun('isempty', { EEG.chanlocs.theta }));
if ~isempty(emptychans)
    disp('Marking channels without locations (non-EEG channels)');
    for i = 1:length(emptychans)
        pos = emptychans(i);
        %If the empty channel has not
        if ~ismember(pos, bad_channels)
            tempLbls{pos} = strcat(chanLbls{pos}, ' - MARKED');
            tempData(pos,:) = lowerVal;
            bad_channels = [bad_channels pos];
            disp(['Added bad channel (without location): ', num2str(round(pos)), '-', chanLbls{round(pos)}]);
        end
    end
end


%Creates the figure to let the user visualize the data and select bad channels
figure('Units', 'normalized', 'Position', [0, .3, 1, .62]);
while 1
    %Iteratively show the channel's data as a heatmap, with high and low values being possible noise.
    clf
    imagesc(tempData); h1=gca; caxis([lowerVal, higherVal]); set(h1,'xtick',[], 'ytick', 1:length(chanLbls), 'yticklabel', tempLbls);
    title(['Select bad channels (will be excluded from ICA decomposition) for: ', nameStep0, '. Close this window once you have finished selecting bad channels']);
    h2 = axes('position',[0.1 0.03 0.8 0.05]); x = [-2 -1 0]; imagesc(x, 1, x);
    set(h2,'xtick',x,'xticklabel',{'<100','0','>100'},'ytick',[]);
    title('Scale. Please click the rows of the channels you consider as bad on the heatmap above (bad channels are usually consistently dark blue or yellow). Remember to select non-EEG channels as well. If you want to unmark/unselect a bad channel, just click on it');
    axes(h1);

    %Will ask the user to click a new channel until the window is closed
    try
        pos = ginput(1);
        if (round(pos(2)) > length(chanLbls)+1) || (round(pos(2)) < 0) || pos(1) < 0
            %Makes sure that the user is clicking within bounds
            disp('Please click inside the colorbar')
        else
            if ismember(round(pos(2)),bad_channels)
                %If the selected channel WAS on the list of bad channels, remove it
                tempData(round(pos(2)),:) = EEG.data(round(pos(2)),:);
                tempLbls{round(pos(2))} = chanLbls{round(pos(2))};
                bad_channels(bad_channels == (round(pos(2)) )) = []; %#ok
                disp(['Deleted bad channel: ', num2str(round(pos(2))), '-', chanLbls{round(pos(2))}])
            else
                %If the selected channel was NOT on the list of bad channels, add it
                tempData(round(pos(2)),:) = lowerVal;
                tempLbls{round(pos(2))} = strcat(chanLbls{round(pos(2))}, ' - MARKED');
                bad_channels = [bad_channels round(pos(2))]; %#ok
                disp(['Added bad channel: ', num2str(round(pos(2))), '-', chanLbls{round(pos(2))}])
            end
        end

    %If the window is closed, get out of the while
    catch
        break
    end
end


%Checks if the user identified any bad channel
if isempty(bad_channels)
    %If there are none, ask the user if he really wants to continue without identifying bad channels
    disp('WARNING: You did not select any channel as bad. If there is a bad channel, it might affect your results');
    disp('Are you sure you want to continue with the preprocessing (y), or do you want to repeat this step (any key)?');
    rerunStep1 = input('', 's');
    if strcmpi(rerunStep1, 'y')
        badChanIdxs = [];
        badChanLbls = {};
    else
        disp('---------------Re running Step 1 (Identifying bad channels)-----------------');
        [badChanIdxs, badChanLbls] = f_step1IdBadChannels(pathStep0, nameStep0, chanInfo);
    end
else
    badChanIdxs = sort(bad_channels);
    badChanLbls = chanLbls(badChanIdxs);
end
    

end