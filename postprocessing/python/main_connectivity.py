import scipy.io as sio
import numpy as np
import pandas as pd
import os
import json
import sys
from glob import glob
import bct
import networkx as nx

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
    
    # We will process connectivity. It is usually based on Stage 3 results stored under Connectivity/
    for country in countries:
        print(f"Processing Connectivity for Country: {country}...")
        
        # Read participants
        tsv_path = os.path.join(db_root, country, 'participants.tsv')
        if not os.path.exists(tsv_path):
            print(f"  Warning: participants.tsv not found at {tsv_path}. Skipping.")
            continue
            
        participants = pd.read_csv(tsv_path, sep='\t')
        subjects = list(participants['subject_id'])
        
        # DataFrames for graph metrics
        conn_metrics_df = pd.DataFrame()
        
        # DataFrames for flattened matrices
        upper_triangle_indices = np.triu_indices(82)
        cols_upper = [f"ROIS_{i}_vs_ROI_{j}" for i, j in zip(*upper_triangle_indices)]
        cols_full = [f"ROIS_{i}_vs_ROI_{j}" for i in range(82) for j in range(82)]
        
        omat_upper_df = pd.DataFrame(columns=cols_upper)
        omat_full_df = pd.DataFrame(columns=cols_full)
        
        error_list = []
        for subj in subjects:
            print(f"  Processing Subject: {subj}")
            subj_clean = subj.strip()
            subj_padded = subj.ljust(11, ' ')
            
            search_patron = os.path.join(db_root, country, 'analysis_RS', 'Connectivity', 'Step1_ConnectivityMetrics', subj_clean, 'eeg', '*eeg.mat')
            found = glob(search_patron)
            if not found:
                print(f"    Warning: Connectivity mat file not found for {subj}")
                error_list.append(subj)
                continue
                
            try:
                mat = sio.loadmat(found[0])
                c = mat['EEG_like'][0][0][9] # Connectivity matrices: (ROIs, ROIs, metrics)
                names = [mat['EEG_like'][0][0][10][0][i][0] for i in range(mat['EEG_like'][0][0][10][0].shape[0])]
                
                # Check for error condition
                if np.all(c[:, :, 0] == 1):
                    print(f"    Error: Connectivity matrix contains all ones for {subj}")
                    error_list.append(subj)
                    continue
                
                # Load mimat, cmimat, omat
                mimat = c[:, :, 1]
                cmimat = c[:, :, 2]
                
                # Find omat index dynamically
                if 'omat' in names:
                    omat_index = names.index('omat')
                else:
                    omat_index = 3 # fallback to original index 3
                omat = c[:, :, omat_index].astype(np.float64)
                
                # --- Compute Graph Metrics ---
                # Transitivity
                conn_metrics_df.loc[subj_padded, 'transitivity_mimat'] = bct.transitivity_wu(mimat)
                conn_metrics_df.loc[subj_padded, 'transitivity_cmimat'] = bct.transitivity_wu(cmimat)
                conn_metrics_df.loc[subj_padded, 'transitivity_omat'] = bct.transitivity_wu(omat)
                
                # Global Efficiency
                conn_metrics_df.loc[subj_padded, 'global_efficiency_mimat'] = bct.efficiency_wei(mimat, local=False)
                conn_metrics_df.loc[subj_padded, 'global_efficiency_cmimat'] = bct.efficiency_wei(cmimat, local=False)
                conn_metrics_df.loc[subj_padded, 'global_efficiency_omat'] = bct.efficiency_wei(omat, local=False)
                
                # Density
                g_mimat = nx.Graph(mimat)
                g_cmimat = nx.Graph(cmimat)
                g_omat = nx.Graph(omat)
                
                conn_metrics_df.loc[subj_padded, 'density_mimat'] = bct.density_und(g_mimat)[0]
                conn_metrics_df.loc[subj_padded, 'density_cmimat'] = bct.density_und(g_cmimat)[0]
                conn_metrics_df.loc[subj_padded, 'density_omat'] = bct.density_und(g_omat)[0]
                
                # Small-Worldness
                # np.nanmean(clustering / np.nanmean(distance))
                try:
                    conn_metrics_df.loc[subj_padded, 'small_worldness_mimat'] = np.nanmean(bct.clustering_coef_wu(mimat) / np.nanmean(bct.distance_wei(mimat)))
                except Exception:
                    conn_metrics_df.loc[subj_padded, 'small_worldness_mimat'] = np.nan
                try:
                    conn_metrics_df.loc[subj_padded, 'small_worldness_cmimat'] = np.nanmean(bct.clustering_coef_wu(cmimat) / np.nanmean(bct.distance_wei(cmimat)))
                except Exception:
                    conn_metrics_df.loc[subj_padded, 'small_worldness_cmimat'] = np.nan
                try:
                    conn_metrics_df.loc[subj_padded, 'small_worldness_omat'] = np.nanmean(bct.clustering_coef_wu(omat) / np.nanmean(bct.distance_wei(omat)))
                except Exception:
                    conn_metrics_df.loc[subj_padded, 'small_worldness_omat'] = np.nan
                
                # --- Flattened Matrices ---
                # Upper triangle
                uni_array_omat_upper = omat[upper_triangle_indices].flatten()
                omat_upper_df.loc[subj_padded, cols_upper] = uni_array_omat_upper
                
                # Full matrix
                omat_full_df.loc[subj_padded, cols_full] = omat.flatten()
                
            except Exception as e:
                print(f"    Error processing subject {subj}: {e}")
                error_list.append(subj)
                
        # Save results under [output_root]/[country]/SourceTransformation (to match pipeline style)
        feat_dir = os.path.join(output_root, country, 'SourceTransformation')
        os.makedirs(feat_dir, exist_ok=True)
        
        output_conn_csv = os.path.join(feat_dir, f"{country}_SourceTransformation_{subject_class}_Connectivity.csv")
        output_omat_upper_csv = os.path.join(feat_dir, f"{country}_SourceTransformation_{subject_class}_Connectivity_omat_metrics.csv")
        output_omat_full_csv = os.path.join(feat_dir, f"{country}_SourceTransformation_{subject_class}_Connectivity_omat_full_metrics.csv")
        
        conn_metrics_df.to_csv(output_conn_csv, float_format="%.10f")
        omat_upper_df.to_csv(output_omat_upper_csv, float_format="%.10f")
        omat_full_df.to_csv(output_omat_full_csv, float_format="%.10f")
        
        print(f"  Saved connectivity graph summaries to: {output_conn_csv}")
        print(f"  Saved flattened omat (upper triangle) to: {output_omat_upper_csv}")
        print(f"  Saved flattened omat (full matrix) to: {output_omat_full_csv}")
        
        if len(error_list) > 0:
            error_file = os.path.join(feat_dir, f"{country}_SourceTransformation_{subject_class}_Connectivity_error_list.txt")
            with open(error_file, 'w') as f_err:
                for err_subj in error_list:
                    f_err.write(f"{err_subj}\n")
                    
    print("Connectivity feature extraction finished successfully.")

if __name__ == '__main__':
    main()
