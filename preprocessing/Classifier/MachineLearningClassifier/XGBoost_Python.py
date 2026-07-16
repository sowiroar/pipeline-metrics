#!/usr/bin/env python
# coding: utf-8



def f_buildXGBoostModel(csvPath, crossValSplits, savePath):
    '''
    Creates an XGBoost model with the csv given by path, and saves .jpg files with FeatureImportance and ROC curves of the model
    
    Parameters
    ----------
    csvPath : String
        String with the name of the .csv that contains the data to train the model
        NOTE: It must be of size [nSubjects, 1+nFeatures], where the first column corresponds to the diagnostics/groups/labels
    crossValSplits : Int
        Integer with the number of cross validation splits desired to create the ROC curves (5 by default)
    savePath : String
        String with the path where the .jpg figures of FeatureImportance and ROC curves will be saved
    
    Returns
    -------
    Nothing. Saves the .jpg files
    '''
    
    
    #os to check that the csvPath is valid
    import os
    if not os.path.isfile(csvPath):
        raise Exception('ERROR: The file entered by parameter does not exist')
    
    
    
    print('Installing and importing required packages...')
    #Installs required modules, if the file does exist
    import subprocess
    import sys
    
    def install(package):
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        
    install('mlxtend==0.18.0')
    install('xgboost')
    install('plotly==5.5.0')
    install('shap')
    install('kaleido')
    
    
    
    #Imports required packages
    #Pandas for loading the .csv
    import pandas as pd
    
    #train_test_split for spliting the data
    from sklearn.model_selection import train_test_split
    
    #mlxtend for feature selection and xgboost for the machine learning model
    from mlxtend.feature_selection import SequentialFeatureSelector as SFS
    from mlxtend.plotting import plot_sequential_feature_selection as plot_sfs
    from xgboost import XGBClassifier
    import xgboost as xgb
    
    #plt for plotting feature importance
    import matplotlib.pyplot as plt
    
    #Multiple packages for evaluating the model performance
    import numpy as np
    import plotly.graph_objects as go
    #from tqdm.notebook import tqdm
    from sklearn.model_selection import RepeatedKFold
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import roc_auc_score, roc_curve
    
    #SHAP for feature importance
    import shap
    
    #Stratified K-Fold for CV and creating ROC curves
    from sklearn.model_selection import StratifiedKFold
    
    
    
    
    #Loads the desired .csv
    subj = pd.read_csv(csvPath)
    
    
    
    #Replaces the output category names for numbers rather than strings
    X = subj
    y = X.iloc[:,0]
    y_labels = pd.unique(y)
    if len(y_labels) > 2:
        print('ERROR: Expected a maximum of 2 classes in the first column')
        print('The first column MUST be the output variable (diagnostic, group, etc). For this file it is called: ' + subj.columns[0])
        print('And its unique values are: ' + str(y_labels))
        raise Exception("Wrong column name or wrong number of classes_diagnostics_groups")
        #return
              
    for idx, uniqueLabel in enumerate(y_labels):
        y = y.replace(uniqueLabel, idx)
    
    X = X.drop(X.columns[[0]], axis=1)
    
    
    
    #Splits data into stratified training and test sets (80/20)
    testSplit = 0.3;
    rng = np.random.RandomState(2022)     #Defines a seed to ensure reproducibility
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=testSplit, random_state=42, stratify=y)

    

    #Defines parameters for XGBoosting models
    params = {
        'eval_metric' : 'logloss',
        'objective'   : 'binary:logistic',
        'use_label_encoder':False
    }
    
    
    
    #Trains a XGBoosting classifier and performs feature importance analysis
    print('\n \n Training an XGBoost model to estimate Feature Importance using Sequential Feature Selection...')
    lr = XGBClassifier(random_state=42, 
                       seed = 2022, 
                       use_label_encoder=params['use_label_encoder'], 
                       objective=params['objective'],
                       eval_metric=params['eval_metric'])
    #Use only one CPU (n_jobs=1 is slower, but should work. n_jobs=-1 created some errors)
    sfs = SFS(lr, 
              k_features="best", 
              forward=True, 
              floating=False, 
              scoring='f1',
              verbose=2,
              cv=crossValSplits,
              n_jobs=1)
    
    sfs = sfs.fit(X_train, y_train)
    
    
    
    #PLots feature importance
    plt.rcParams["figure.figsize"] = (20,10)
    fig, ax = plot_sfs(sfs.get_metric_dict(), kind='std_err')
    plt.title('Sequential Forward Selection (w. StdErr)')
    
    #Adds some info about the most important features, as well as the best F1-score
    txt1 = ('Best features: ' + str(sfs.k_feature_names_))
    txt2 = ('F1-score obtained with the best features only: ' + str(sfs.k_score_))
    
    # these are matplotlib.patch.Patch properties
    props = dict(boxstyle='round', facecolor='wheat', alpha=0.8)
    
    # place text box 1 in bottom left in axes coords
    ax.text(0.05, 0.05, txt1, transform=ax.transAxes, fontsize=14,
            verticalalignment='top', bbox=props)
    
    # place text box 2 in bottom left in axes coords
    ax.text(0.05, 0.11, txt2, transform=ax.transAxes, fontsize=14,
            verticalalignment='top', bbox=props)
    
    
    plt.grid()
    #plt.show()
    fig.savefig(savePath + '_AllFeaturesImportance.jpg', bbox_inches='tight')
    plt.close(fig)
    
    
    #Defines new subsets ONLY with the most important features in the test set
    lista = list(sfs.k_feature_names_)
    
    Xsel = X_test[lista]
    
    
    
    #Defines folds divisions for cross-validation in the test set
    print('\n \n Performing cross-validation in the Test set to obtain ROC curves...')
    cv    = StratifiedKFold(n_splits=crossValSplits, shuffle = True, random_state = 42)
    folds = [(train,test) for train, test in cv.split(Xsel, y_test)]
    #folds = [(train,test) for train, test in cv.split(Xsel, y_train)]
    metrics = ['auc', 'fpr', 'tpr', 'thresholds']
    results = {
        'train': {m:[] for m in metrics},
        'val'  : {m:[] for m in metrics},
        'test' : {m:[] for m in metrics}
    }
    
    
        
    
    #Creates XGBoosting Cross-Validation models, and saves the ROC curve
    #params.pop('use_label_encoder')         #Removes 'use_label_encoder' because the way of training the XGBoost model does not support it
    plt.rcParams["figure.figsize"] = (10,10)
    dtest = xgb.DMatrix(Xsel, label=y_test)
    #dtest = xgb.DMatrix(Xsel_test, label=y_test)
    print('Test labels: ' + str(dtest.get_label()))
    for train, test in folds:
        dtrain = xgb.DMatrix(Xsel.iloc[train,:], label=y_test.iloc[train])
        #dtrain = xgb.DMatrix(Xsel.iloc[train,:], label=y_train.iloc[train])
        print('Training labels: ' + str(dtrain.get_label()))
        
        dval   = xgb.DMatrix(Xsel.iloc[test,:], label=y_test.iloc[test])
        #dval   = xgb.DMatrix(Xsel.iloc[test,:], label=y_train.iloc[test])
        print('Validation labels: ' + str(dval.get_label()))
        
        model  = xgb.train(
            dtrain                = dtrain,
            params                = params, 
            evals                 = [(dtrain, 'train'), (dval, 'val')],
            num_boost_round       = 1000,
            verbose_eval          = False,
            early_stopping_rounds = 10
        )
        sets = [dtrain, dval, dtest]
        print(results.keys())
        for i,ds in enumerate(results.keys()):
            y_preds              = model.predict(sets[i])
            labels               = sets[i].get_label()
            fpr, tpr, thresholds = roc_curve(labels, y_preds)
            results[ds]['fpr'].append(fpr)
            results[ds]['tpr'].append(tpr)
            results[ds]['thresholds'].append(thresholds)
            results[ds]['auc'].append(roc_auc_score(labels, y_preds))
    kind = 'test'
    c_fill      = 'rgba(52, 152, 219, 0.2)'
    c_line      = 'rgba(52, 152, 219, 0.5)'
    c_line_main = 'rgba(41, 128, 185, 1.0)'
    c_grid      = 'rgba(189, 195, 199, 0.5)'
    c_annot     = 'rgba(149, 165, 166, 0.5)'
    c_highlight = 'rgba(192, 57, 43, 1.0)'
    fpr_mean    = np.linspace(0, 1, 100)
    interp_tprs = []
    for i in range(crossValSplits):
        fpr           = results[kind]['fpr'][i]
        tpr           = results[kind]['tpr'][i]
        interp_tpr    = np.interp(fpr_mean, fpr, tpr)
        interp_tpr[0] = 0.0
        interp_tprs.append(interp_tpr)
    tpr_mean     = np.mean(interp_tprs, axis=0)
    tpr_mean[-1] = 1.0
    tpr_std      = np.std(interp_tprs, axis=0)
    tpr_upper    = np.clip(tpr_mean+tpr_std, 0, 1)
    tpr_lower    = tpr_mean-tpr_std
    auc          = np.mean(results[kind]['auc'])
    fig = go.Figure([
        go.Scatter(
            x          = fpr_mean,
            y          = tpr_upper,
            line       = dict(color=c_line, width=1),
            hoverinfo  = "skip",
            showlegend = False,
            name       = 'upper'),
        go.Scatter(
            x          = fpr_mean,
            y          = tpr_lower,
            fill       = 'tonexty',
            fillcolor  = c_fill,
            line       = dict(color=c_line, width=1),
            hoverinfo  = "skip",
            showlegend = False,
            name       = 'lower'),
        go.Scatter(
            x          = fpr_mean,
            y          = tpr_mean,
            line       = dict(color=c_line_main, width=2),
            hoverinfo  = "skip",
            showlegend = True,
            name       = f'AUC: {auc:.3f}')
    ])
    fig.add_shape(
        type ='line', 
        line =dict(dash='dash'),
        x0=0, x1=1, y0=0, y1=1
    )
    fig.update_layout(
        template    = 'plotly_white', 
        title_x     = 0.5,
        xaxis_title = "1 - Specificity",
        yaxis_title = "Sensitivity",
        width       = 600,
        height      = 600,
        legend      = dict(
            yanchor="bottom", 
            xanchor="right", 
            x=0.95,
            y=0.01,
        )
    )
    fig.update_yaxes(
        range       = [0, 1],
        gridcolor   = c_grid,
        scaleanchor = "x", 
        scaleratio  = 1,
        linecolor   = 'black')
    fig.update_xaxes(
        range       = [0, 1],
        gridcolor   = c_grid,
        constrain   = 'domain',
        linecolor   = 'black')
    
    fig.write_image(savePath + "_ROC_Curve.jpg")
    
        
    
    #Executes SHAP for feature importance and saves the figure
    print('\n \n Estimating feature importance using SHAP...')
    explainer = shap.TreeExplainer(model)
    shap_values = explainer.shap_values(Xsel)
    shap.summary_plot(shap_values, Xsel, plot_type="bar", show=False)
    fig = plt.gcf()
    fig.savefig(savePath + '_SHAP_BestFeaturesImportance.jpg', bbox_inches='tight')




# Run the f_buildXGBoostModel function, with the desired parameters
import argparse
# parse the commandline to get the desired parameters 
parser = argparse.ArgumentParser()

# data organization parameters
parser.add_argument('-f', '--fileName', required=True, help='File name of the .csv that will be used to create the model')
parser.add_argument('-cv', '--crossValidationSplits', required=True, help='Number of splits to be used in the Cross Validation for ROC curves')
parser.add_argument('-s', '--savePath', required=True, help='Path where the .jpg figures with FeatureImportance and ROC Curves will be saved')
args = parser.parse_args()

csvPath = args.fileName
crossValSplits = int(args.crossValidationSplits)
savePath = args.savePath


#csvPath = 'F:/Pavel/Estandarizacion/Bases_de_Datos/RS_SQZ-BrainLat/analysis_RS/Classifier_Nohdmat/Step0_FeatureSelection/fdr_finalFeatures_HC__VS__SQZ.csv'
#crossValSplits = 5
#savePath = 'F:/Pavel/Estandarizacion/Bases_de_Datos/RS_SQZ-BrainLat/analysis_RS/Classifier_Nohdmat/Step0_FeatureSelection/fdr_finalFeatures_HC__VS__SQZ'

f_buildXGBoostModel(csvPath, crossValSplits, savePath)