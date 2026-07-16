%Loads teh desired subject
a = pop_loadset('sub-30035_rs-HEP_eeg.set');

%Assigns its' corresponding channel labels and location
a.chanlocs = readlocs('BioSemi128_HeadCirc63cms.xyz');

%Saves it
%pop_saveset(a, 'ej128.set', pwd);