%Loads the desired .set
a = pop_loadset('ej64.set');

%Extracts the data
data = a.data;

%% Applies the desired normalization
%NOTE: Works well for multiple epochs or one epoch (e.g. raw records or grand averages)
metric = 'RSTD_EP_L2';       %'UN_ALL', 'PER_CH', 'UN_CH_HB', 'RSTD_EP_Mean', 'RSTD_EP_Huber', 'RSTD_EP_L2'
newData = f_NormalizeData(data, metric);