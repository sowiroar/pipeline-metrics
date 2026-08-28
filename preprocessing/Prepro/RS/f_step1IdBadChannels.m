function [badChanIdxs, badChanLbls] = f_step1IdBadChannels(pathStep0, nameStep0, chanInfo)
%Function that allows the user to perform bad channel identification in a Graphical User Interface (GUI)
%INPUTS:
%pathStep0 = Path of the .set that wants to be analyzed (either filtered and resampled, or just a copy of the original .set)
%nameStep0 = Name of the .set that wants to be analyzed (either filtered and resampled, or just a copy of the original .set)
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
%EEG.chanlocs = readlocs('/users/yqb22198/Downloads/biosemi64.ced');
%EEG.chanlocs =pop_chanedit(EEG, 'lookup','/users/yqb22198/Documents/MATLAB/eeglab2022.1/plugins/dipfit/standard_BEM/elec/standard_1005.elc');
%pop_select(EEG, 'nochannel', [65])
%pop_select(EEG, 'nochannel', [66])
%pop_select(EEG, 'nochannel', [67])
%pop_select(EEG, 'nochannel', [68])
%pop_select(EEG, 'nochannel', [69])
%pop_select(EEG, 'nochannel', [70])
%pop_select(EEG, 'nochannel', [71])
%pop_select(EEG, 'nochannel', [72])
EEG = eeg_checkset( EEG );

tempData = EEG.data;
%EEG.chanlocs = pop_chanedit(EEG, 'load',{'/users/yqb22198/Downloads/Mahsa.locs','filetype','autodetect'});
%EEG=pop_chanedit(EEG, 'lookup','/users/yqb22198/Documents/MATLAB/eeglab2022.1/plugins/dipfit/standard_BEM/elec/standard_1005.elc','load',{'/users/yqb22198/Downloads/chans.ced','filetype','autodetect'});
%EEG=pop_chanedit(EEG, 'lookup','/users/yqb22198/Documents/MATLAB/eeglab2022.1/plugins/dipfit/standard_BEM/elec/standard_1005.elc','load',{'/users/yqb22198/Downloads/Mahsa.locs','filetype','loc'},'convert',{'sph2all'})
%[EEG] = eeg_store(EEG, CURRENTSET);
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
                if (sum(tsvVsReal) > 0) && (strcmpi('bad', statusTsv{i}) || strcmp('0', statusTsv{i}))
                    pos = find(tsvVsReal);
                    tempLbls{pos} = strcat(chansTsv{i}, ' - MARKED');
                    tempData(pos,:) = lowerVal;
                    bad_channels = [bad_channels pos];
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


%Check if running in batch mode (no display available)
isBatchMode = ~usejava('desktop') || ~usejava('jvm');

if isBatchMode
    %BATCH MODE: Skip GUI, use only the channels from .tsv and auto-detected non-EEG channels
    disp('Running in batch mode: skipping interactive channel selection GUI.');
    disp(['Auto-identified ' num2str(length(bad_channels)) ' bad channels from .tsv and non-EEG detection.']);
else
    %INTERACTIVE MODE: Creates the figure to let the user visualize the data and select bad channels
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
end


%Checks if the user identified any bad channel
if isempty(bad_channels)
    if isBatchMode
        %In batch mode, just continue without bad channels
        disp('WARNING: No bad channels identified in batch mode. Continuing without bad channels.');
        badChanIdxs = [];
        badChanLbls = {};
    else
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
    end
else
    badChanIdxs = sort(bad_channels);
    badChanLbls = chanLbls(badChanIdxs);
end
    

end