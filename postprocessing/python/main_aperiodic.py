import numpy as np
import pandas as pd
import os
import json
import scipy.io
from glob import glob
import mne
import fooof
from neurodsp.spectral import compute_spectrum
import sys

EEG_TXT_PATTERN = '*eeg.txt'


def main():
    # Load configuration
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, '..', 'config', 'config.json')
    if not os.path.exists(config_path):
        print(f"Error: Config file not found at {config_path}")
        sys.exit(1)
        
    with open(config_path, 'r') as f:
        config = json.load(f)
        
    db_root = config['database_root']
    if not os.path.isabs(db_root):
        db_root = os.path.abspath(os.path.join(os.path.dirname(config_path), db_root))
        
    output_root = config['output_root']
    if not os.path.isabs(output_root):
        output_root = os.path.abspath(os.path.join(os.path.dirname(config_path), output_root))
    countries = config['countries']
    subject_class = config['subject_class']
    fs_default = config.get('fs', 512)
    stages = config['stages']
    
    for country in countries:
        for stage in stages:
            print(f"Processing Country: {country}, Stage: {stage}...")
            
            # Read participants
            tsv_path = os.path.join(db_root, country, 'participants.tsv')
            if not os.path.exists(tsv_path):
                print(f"  Warning: participants.tsv not found at {tsv_path}. Skipping.")
                continue
                
            participants = pd.read_csv(tsv_path, sep='\t')
            subjects = list(participants['subject_id'])
            
            aper_df = pd.DataFrame()
            error_list = []
            
            for subj in subjects:
                print(f"  Processing Subject: {subj}")
                subj_clean = subj.strip()
                
                try:
                    eeg_data = None
                    fs = fs_default
                    
                    if stage == 'Preprocessing':
                        search_patron = os.path.join(db_root, country, 'analysis_RS', 'Preprocessing', 'Step6_BadChanInterpolation', subj_clean, 'eeg', '*eeg.set')
                        found = glob(search_patron)
                        if not found:
                            search_patron = os.path.join(db_root, country, 'analysis_RS', 'Preprocessing', 'Step6_BadChanInterpolation', subj_clean, 'eeg', EEG_TXT_PATTERN)
                            found = glob(search_patron)
                            if found:
                                eeg_data = np.loadtxt(found[0]).T
                        else:
                            raw = mne.io.read_raw_eeglab(found[0], preload=True, verbose=False)
                            eeg_data = raw.get_data()
                            fs = raw.info['sfreq']
                            
                    elif stage == 'Normalization':
                        search_patron = os.path.join(db_root, country, 'analysis_RS', 'Normalization', 'Step2_PatientControlNorm', subj_clean, 'eeg', '*eeg.set')
                        found = glob(search_patron)
                        if not found:
                            search_patron = os.path.join(db_root, country, 'analysis_RS', 'Normalization', 'Step2_PatientControlNorm', subj_clean, 'eeg', EEG_TXT_PATTERN)
                            found = glob(search_patron)
                            if found:
                                eeg_data = np.loadtxt(found[0]).T
                        else:
                            raw = mne.io.read_raw_eeglab(found[0], preload=True, verbose=False)
                            eeg_data = raw.get_data()
                            fs = raw.info['sfreq']
                            
                    elif stage == 'SourceTransformation':
                        search_patron = os.path.join(db_root, country, 'analysis_RS', 'SourceTransformation', 'Step2_SourceAvgROI', subj_clean, 'eeg', '*eeg.mat')
                        found = glob(search_patron)
                        if found:
                            eeglab_raw = scipy.io.loadmat(found[0])
                            eeg_data = eeglab_raw['EEG_like']['data'][0][0]
                        else:
                            search_patron = os.path.join(db_root, country, 'analysis_RS', 'SourceTransformation', 'Step2_SourceAvgROI', subj_clean, 'eeg', EEG_TXT_PATTERN)
                            found = glob(search_patron)
                            if found:
                                eeg_data = np.loadtxt(found[0]).T
                                
                    elif stage == 'SourceNoNormalizedTransformation':
                        search_patron = os.path.join(db_root, country, 'analysis_RS', 'SourceNoNormalizedTransformation', f'*{subj_clean}_*Rois.txt')
                        found = glob(search_patron)
                        if found:
                            eeg_data = np.loadtxt(found[0]).T
                            
                    else:
                        print(f"  Unknown stage: {stage}")
                        continue
                        
                    if eeg_data is None:
                        print(f"    Warning: No EEG data found for subject {subj}")
                        error_list.append(subj)
                        continue
                        
                    # Compute spectrum
                    f, psd = compute_spectrum(eeg_data, fs)
                    
                    # Fit FOOOF Group
                    fg = fooof.FOOOFGroup(aperiodic_mode='knee', verbose=False)
                    fg.fit(freqs=f, power_spectra=psd, freq_range=[0.5, 40])
                    
                    fit_error = fg.get_params('error')
                    aperiodic_params = fg.get_params('aperiodic_params')
                    
                    subj_index = subj.ljust(11, ' ')
                    for i in range(aperiodic_params.shape[0]):
                        aper_df.loc[subj_index, f"Slope_C_{i+1}"] = aperiodic_params[i, 2]
                        aper_df.loc[subj_index, f"Knee_C_{i+1}"] = aperiodic_params[i, 1]
                        aper_df.loc[subj_index, f"Offset_C_{i+1}"] = aperiodic_params[i, 0]
                        aper_df.loc[subj_index, f"Error_C_{i+1}"] = fit_error[i]
                        
                except Exception as e:
                    print(f"    Error processing subject {subj}: {e}")
                    error_list.append(subj)
                    
            # Save results
            feat_dir = os.path.join(output_root, country, stage)
            os.makedirs(feat_dir, exist_ok=True)
            
            output_csv = os.path.join(feat_dir, f"{country}_{stage}_{subject_class}_Aperiodic_metrics.csv")
            aper_df.to_csv(output_csv)
            print(f"  Saved aperiodic metrics to: {output_csv}")
            
            if len(error_list) > 0:
                error_file = os.path.join(feat_dir, f"{country}_{stage}_{subject_class}_Aperiodic_error_list.txt")
                with open(error_file, 'w') as f_err:
                    for err_subj in error_list:
                        f_err.write(f"{err_subj}\n")

    print("Aperiodic feature extraction finished successfully.")

if __name__ == '__main__':
    main()
