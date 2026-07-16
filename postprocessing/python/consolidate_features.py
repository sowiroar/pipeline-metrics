import os
import json
import pandas as pd
import numpy as np
import sys

def clean_subject_id(val):
    if pd.isna(val):
        return ""
    # Convert to string, strip whitespace, and normalize
    return str(val).strip()

def main():
    # Load configuration
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, '..', 'config', 'config.json')
    if not os.path.exists(config_path):
        print(f"Error: Config file not found at {config_path}")
        sys.exit(1)
        
    with open(config_path, 'r') as f:
        config = json.load(f)
        
    output_root = config['output_root']
    if not os.path.isabs(output_root):
        output_root = os.path.abspath(os.path.join(os.path.dirname(config_path), output_root))
    countries = config['countries']
    subject_class = config['subject_class']
    stages = config['stages']
    
    for country in countries:
        print(f"Consolidating features for Country: {country}...")
        
        # We will hold all dataframes in a list and merge them on Subject_ID
        master_df = None
        
        # 1. Load Frequency, Complexity, and Aperiodic metrics for each stage
        for stage in stages:
            stage_dir = os.path.join(output_root, country, stage)
            if not os.path.exists(stage_dir):
                print(f"  Warning: Directory not found for stage {stage} at {stage_dir}. Skipping.")
                continue
            
            # (a) Frequency
            freq_file = os.path.join(stage_dir, f"{country}_{stage}_{subject_class}_Frecuency_metrics.csv")
            if os.path.exists(freq_file) and os.path.getsize(freq_file) > 2:
                print(f"  Loading Frequency metrics for stage {stage}...")
                try:
                    df = pd.read_csv(freq_file)
                    if not df.empty:
                        id_col = df.columns[0]
                        df['Subject_ID'] = df[id_col].apply(clean_subject_id)
                        df = df.drop(columns=[id_col])
                        # Prefix other columns
                        cols_to_rename = {col: f"{stage}_Freq_{col}" for col in df.columns if col != 'Subject_ID'}
                        df = df.rename(columns=cols_to_rename)
                        
                        if master_df is None:
                            master_df = df
                        else:
                            master_df = pd.merge(master_df, df, on='Subject_ID', how='outer', validate='one_to_one')
                except pd.errors.EmptyDataError:
                    print(f"    Warning: Empty file skipped: {freq_file}")
            
            # (b) Complexity
            comp_file = os.path.join(stage_dir, f"{country}_{stage}_{subject_class}_Complexity_metrics.csv")
            if os.path.exists(comp_file) and os.path.getsize(comp_file) > 2:
                print(f"  Loading Complexity metrics for stage {stage}...")
                try:
                    df = pd.read_csv(comp_file)
                    if not df.empty:
                        id_col = df.columns[0]
                        df['Subject_ID'] = df[id_col].apply(clean_subject_id)
                        df = df.drop(columns=[id_col])
                        cols_to_rename = {col: f"{stage}_Comp_{col}" for col in df.columns if col != 'Subject_ID'}
                        df = df.rename(columns=cols_to_rename)
                        
                        if master_df is None:
                            master_df = df
                        else:
                            master_df = pd.merge(master_df, df, on='Subject_ID', how='outer', validate='one_to_one')
                except pd.errors.EmptyDataError:
                    print(f"    Warning: Empty file skipped: {comp_file}")
            
            # (c) Aperiodic
            aper_file = os.path.join(stage_dir, f"{country}_{stage}_{subject_class}_Aperiodic_metrics.csv")
            if os.path.exists(aper_file) and os.path.getsize(aper_file) > 2:
                print(f"  Loading Aperiodic metrics for stage {stage}...")
                try:
                    df = pd.read_csv(aper_file)
                    if not df.empty:
                        id_col = df.columns[0]
                        df['Subject_ID'] = df[id_col].apply(clean_subject_id)
                        df = df.drop(columns=[id_col])
                        cols_to_rename = {col: f"{stage}_Aper_{col}" for col in df.columns if col != 'Subject_ID'}
                        df = df.rename(columns=cols_to_rename)
                        
                        if master_df is None:
                            master_df = df
                        else:
                            master_df = pd.merge(master_df, df, on='Subject_ID', how='outer', validate='one_to_one')
                except pd.errors.EmptyDataError:
                    print(f"    Warning: Empty file skipped: {aper_file}")

        # 2. Load Connectivity summary (graph metrics)
        conn_dir = os.path.join(output_root, country, 'SourceTransformation')
        conn_file = os.path.join(conn_dir, f"{country}_SourceTransformation_{subject_class}_Connectivity.csv")
        if os.path.exists(conn_file) and os.path.getsize(conn_file) > 2:
            print("  Loading Connectivity graph metrics...")
            try:
                df = pd.read_csv(conn_file)
                if not df.empty:
                    id_col = df.columns[0]
                    df['Subject_ID'] = df[id_col].apply(clean_subject_id)
                    df = df.drop(columns=[id_col])
                    cols_to_rename = {col: f"Connectivity_Graph_{col}" for col in df.columns if col != 'Subject_ID'}
                    df = df.rename(columns=cols_to_rename)
                    
                    if master_df is None:
                        master_df = df
                    else:
                        master_df = pd.merge(master_df, df, on='Subject_ID', how='outer', validate='one_to_one')
            except pd.errors.EmptyDataError:
                print(f"    Warning: Empty file skipped: {conn_file}")

        if master_df is None:
            print("  Error: No features found to consolidate!")
            continue
            
        # Clean Subject_ID column formatting in master
        master_df['Subject_ID'] = master_df['Subject_ID'].apply(clean_subject_id)
        
        # Save master summary table
        master_dir = os.path.join(output_root, country, 'Consolidated')
        os.makedirs(master_dir, exist_ok=True)
        summary_out_path = os.path.join(master_dir, f"{country}_master_summary_features.csv")
        master_df.to_csv(summary_out_path, index=False)
        print(f"  Saved consolidated summary features to: {summary_out_path}")
        
        # 3. Load large flattened omat connectivity matrix if exists
        omat_file = os.path.join(conn_dir, f"{country}_SourceTransformation_{subject_class}_Connectivity_omat_metrics.csv")
        if os.path.exists(omat_file) and os.path.getsize(omat_file) > 2:
            print("  Loading large flattened connectivity matrix (omat)...")
            try:
                df_omat = pd.read_csv(omat_file)
                if not df_omat.empty:
                    id_col = df_omat.columns[0]
                    df_omat['Subject_ID'] = df_omat[id_col].apply(clean_subject_id)
                    df_omat = df_omat.drop(columns=[id_col])
                    cols_to_rename = {col: f"Conn_Omat_{col}" for col in df_omat.columns if col != 'Subject_ID'}
                    df_omat = df_omat.rename(columns=cols_to_rename)
                    
                    # Merge with master to create the giant all-features table
                    full_master_df = pd.merge(master_df, df_omat, on='Subject_ID', how='outer', validate='one_to_one')
                    full_out_path = os.path.join(master_dir, f"{country}_master_all_features.csv")
                    full_master_df.to_csv(full_out_path, index=False)
                    print(f"  Saved consolidated all-features table (including flattened matrix) to: {full_out_path}")
            except pd.errors.EmptyDataError:
                print(f"    Warning: Empty file skipped: {omat_file}")

    print("Data consolidation finished successfully.")

if __name__ == '__main__':
    main()
