%Script that calculates the metrics of feature stability of a given dataset
iSub = 'ej64.set';      %Subject that wants to be studied

%Type of metric that wants to be calculated
%'VAR_EXP', 'TOT_VAR', 'DIST', 'COR_DIST', 'SPR_COR_DIST', 'COS_DIST', and their Robust (ROB) versions
%'VAR_EXP_ROB', 'TOT_VAR_ROB', 'DIST_ROB', REMAINING: 'COR_DIST_ROB', 'SPR_COR_DIST_ROB', 'COS_DIST_ROB'
type = 'COS_DIST_ROB';       

%% Loads the data and performs the metric's calculation
EEG = pop_loadset(iSub);
data = EEG.data;
outMetric = f_CalculateMetrics(data, type);