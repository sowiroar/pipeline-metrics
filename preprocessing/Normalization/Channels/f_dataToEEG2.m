function EEG = f_dataToEEG2(mData, vTime, sName, sPath)
%Description:
%Takes raw data and orders it in a EEG-like format
%INPUTS:
%mData = Matrix (M time, N channels, P epochs) of the desired EEG signal
%vTime = Vector (1, M time) of time in seconds of the corresponding EEG signal
%sName = String with the filename
%sPath = String with the path of the file
%OUTPUTS:
%EEG = Strcture with similar fields to an EEGLab structure

if (size(mData, 1) ~= length(vTime))
    disp('ERROR: the matrix Data and the time vector dimensions MUST match along one axis');
    return
end

mData = permute(mData, [2, 1, 3]);

nameParts = strsplit(sName, '.');
EEG.setname = nameParts{1};                     %Defines the setname
EEG.filename = strcat(sName);                   %Defines the filename (same as setname)
EEG.filepath = sPath;                           %Defines the path

%Defines the subject name
parts = strsplit(sName, '_');
EEG.subject = parts{1};

EEG.condition = '';
EEG.session = [];
EEG.comments = 'Example data. No idea what was done with this';
EEG.nbchan = size(mData, 1);
EEG.trials = size(mData, 3);
EEG.pnts = size(mData, 2);

%Gets the sampling rate via the vector time 'vTime'
idx1s = find(vTime == 1000);
EEG.srate = idx1s -1;

EEG.xmin = vTime(1)/1000;           %Time given in s (/1000 to pass from ms to s)
EEG.xmax = vTime(end)/1000;         %Time given in s (/1000 to pass from ms to s)
EEG.times = vTime;                  %Times in ms instead of s.
EEG.data = mData;

EEG.icaact = [];
EEG.icawinv = [];
EEG.icasphere = [];
EEG.icaweights = [];
EEG.icachansind = [];
EEG.chanlocs = [];
EEG.urchanlocs = [];
EEG.chaninfo = [];
EEG.ref = '';
EEG.event = [];
EEG.urevent = [];
EEG.epoch = [];
EEG.epochdescription = {};
EEG.reject = [];
EEG.stats = [];
EEG.specdata = [];
EEG.specicaact = [];
EEG.splinefile = '';
EEG.icasplinefile = '';
EEG.dipfit = [];
EEG.history = '...';
EEG.saved = 'yes';
EEG.etc = [];
EEG.run = [];

EEG = eeg_checkset(EEG);

end