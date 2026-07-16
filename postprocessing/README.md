# EEG Post-processing & Feature Extraction Stage

This directory contains the code to extract frequency, complexity, aperiodic, and connectivity descriptors across different stages of the preprocessed EEG dataset, and to merge them into consolidated Master Tables.

---

## ⚙️ Configuration (`config/config.json`)

All stages are controlled by a central configuration file. Make sure to edit this file before running:

```json
{
  "database_root": "path/to/eeg_bids_root",
  "output_root": "path/to/save/postprocessing_outputs",
  "countries": ["Cuba_58"],
  "subject_class": "CN",
  "fs": 512,
  "eeglab_path": "",
  "stages": [
    "Preprocessing",
    "Normalization",
    "SourceTransformation",
    "SourceNoNormalizedTransformation"
  ]
}
```

*   `database_root`: Root folder of your BIDS-like dataset.
*   `output_root`: Folder where individual script outputs and consolidated master tables will be saved.
*   `countries`: List of dataset subfolders (e.g. countries/cohorts) to process.
*   `subject_class`: Suffix class of subjects (e.g., `CN` for control, `AD` for Alzheimer's, etc.).
*   `fs`: Default sampling frequency of the recording.
*   `eeglab_path`: Path to your MATLAB EEGLAB installation (optional, required only for sensor-space stages).
*   `stages`: List of processing folders/stages to extract features from.

---

## 💻 Codebase Details

### 1. MATLAB Scripts (`matlab/`)
*   **[main_frecuency.m](matlab/main_frecuency.m)**: Calculates Relative Power Density (RPD) and Absolute Power (EPP) for canonical bands (Delta, Theta, Alpha 1, Alpha 2, Beta 1, Beta 2, Gamma, Total) and subject-specific bands (e.g., individual Alpha frequency peaks) across all channels/ROIs.
*   **[main_complexity.m](matlab/main_complexity.m)**: Extracts complexity features from signals, including:
    *   Fractal Dimension (`FD`)
    *   Permutation Entropy (`PE`)
    *   Spectral Entropy (`WMEAN`)
    *   Sample Entropy (`SSV`)
*   **`+complexity_functions/` and `+frecuency_functions/`**: MATLAB packages containing core mathematical libraries for entropy and spectral analyses.

### 2. Python Scripts (`python/`)
*   **[main_aperiodic.py](python/main_aperiodic.py)**: Fits the 1/f aperiodic component of power spectra using the knee model via **FOOOF (fitting oscillations & one-over-f)** to extract:
    *   Aperiodic `Slope`
    *   Aperiodic `Knee`
    *   Aperiodic `Offset`
    *   Fit `Error`
*   **[main_connectivity.py](python/main_connectivity.py)**: Loads cross-channel connectivity matrices (Source avg ROI coherence matrices) and extracts:
    *   Graph-theoretical summaries: Transitivity, global efficiency, density, small-worldness (using `bctpy` and `networkx`).
    *   Flattened connectivity matrices: Upper triangle (3,403 elements) and full cross-channel connections.
*   **[consolidate_features.py](python/consolidate_features.py)**: Consolidates outputs from all extraction scripts into single master CSV tables.

### 3. Orchestration
*   **[run_postprocessing.py](run_postprocessing.py)**: Sequentially launches MATLAB scripts in batch mode (`-batch`) and executes the Python scripts in subprocesses. Run this file to execute the complete feature extraction flow:
    ```bash
    python Pipeline/postprocessing/run_postprocessing.py
    ```

---

## 📊 Consolidated Master Output Tables

When feature consolidation runs, it creates a `Consolidated/` folder inside your country output directory with two main tables:

### 1. `[Country]_master_summary_features.csv`
*   **Rows**: 1 row per Subject (e.g. 24 rows).
*   **Columns**: ~6,700 variables.
*   **Contains**: RPD/EPP power values, complexity metrics, aperiodic parameters across all stages, and connectivity graph summaries.
*   **Best For**: General statistical testing, regressions, and group comparisons.

### 2. `[Country]_master_all_features.csv`
*   **Rows**: 1 row per Subject.
*   **Columns**: ~10,100 variables.
*   **Contains**: All columns from the summary table + the entire flattened upper triangle of the cross-channel connectivity matrices (adding ~3,400 connections).
*   **Best For**: Machine Learning classification models, feature selection, and high-dimensional network analyses.

---

## 🔍 How to Filter Consolidated Data in Pandas

All columns in the master tables (except `Subject_ID`) are structured with a clear naming convention:
`{Stage}_{FeatureType}_{Variable}`

This structure makes it very easy to filter columns in Python using **Pandas**:

### Example A: Keep only a specific Stage (e.g., `SourceTransformation`)
To isolate metrics from a single stage while keeping the `Subject_ID` column, use a regular expression filter:

```python
import pandas as pd

# Load the consolidated file
df = pd.read_csv("Cuba_58_master_all_features.csv")

# Filter columns belonging to 'SourceTransformation' stage
df_stage = df.filter(regex="Subject_ID|SourceTransformation")
print(f"Shape: {df_stage.shape}")
```

### Example B: Keep only a specific Metric Type (e.g., Complexity `_Comp_`)
To analyze complexity metrics across all processing stages:

```python
# Filter columns containing '_Comp_' or the subject identifier
df_comp = df.filter(regex="Subject_ID|_Comp_")
print(f"Complexity columns: {list(df_comp.columns[:5])}")
```

### Example C: Python List Comprehension Filter
For customized conditional filtering:

```python
# Keep columns that belong to 'SourceNoNormalizedTransformation' or 'Subject_ID'
cols_to_keep = [col for col in df.columns if "SourceNoNormalizedTransformation" in col or col == "Subject_ID"]
df_filtered = df[cols_to_keep]
```
