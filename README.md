# BrainLat EEG Multi-Metric Processing & Post-Processing Pipeline

This repository contains the unified BIDS-compatible EEG data processing and feature extraction pipeline developed for RedLat/BrainLat research projects. The pipeline takes raw or semi-processed EEG datasets and computes frequency, complexity, aperiodic, and connectivity metrics, consolidating them into master tables ready for statistical and machine learning analyses.

---

## 📁 General Directory Structure

The repository is organized into a clean, hierarchical structure under the main `Pipeline/` folder:

```directory
Pipeline/
├── README.md                 # This global pipeline documentation
├── preprocessing/            # EEG Preprocessing Stages (Stages 1-3)
│   ├── README.md             # Documentation for preprocessing stages
│   └── DataPreproc/, Prepro/, etc. # MATLAB/EEGLAB scripts for preprocessing
└── postprocessing/           # EEG Post-Processing Feature Extraction (Stage 4)
    ├── README.md             # Documentation for post-processing stages
    ├── run_postprocessing.py # Main Python pipeline orchestrator
    ├── config/
    │   └── config.json       # Centralized BIDS configuration file
    ├── matlab/
    │   ├── main_frecuency.m  # Unified MATLAB script for frequency bands
    │   ├── main_complexity.m # Unified MATLAB script for complexity metrics
    │   ├── +complexity_functions/
    │   └── +frecuency_functions/
    └── python/
        ├── main_aperiodic.py # Unified Python script for aperiodic fits (FOOOF)
        ├── main_connectivity.py # Unified Python script for connectivity
        └── consolidate_features.py # Merges all metrics into a master table
```

---

## 🔄 Global Workflow

The pipeline is split into two major phases:

### Phase 1: Preprocessing (`Pipeline/preprocessing/`)
Handles the cleaning and preparation of EEG data, working primarily in sensor space and ending with source-space average ROI signals:
1. **Preprocessing / Bad Channel Interpolation**: Cleans raw data and interpolates artifactual sensors.
2. **Normalization / Patient Control Norm**: Normalizes subject power spectra compared to a reference healthy control group.
3. **Sourceavg ROI Transformation**: Projects sensor-space signals to cortical source regions (81 ROIs) using individual or template head models.

### Phase 2: Post-processing & Feature Extraction (`Pipeline/postprocessing/`)
Computes feature descriptors over the preprocessed sensor/source datasets and consolidates them:
1. **Frequency Power (MATLAB)**: Calculates Relative Power Density (RPD) and Absolute Power (EPP) for canonical and subject-specific bands.
2. **Complexity Metrics (MATLAB)**: Calculates fractal dimension, permutation entropy, spectral entropy, and sample entropy.
3. **Aperiodic Parameters (Python)**: Fits 1/f spectral models (Slope, Knee, Offset) using FOOOF.
4. **Connectivity & Graphs (Python)**: Computes network transitivity, efficiency, density, small-worldness, and exports flattened cross-channel connectivity matrices.
5. **Consolidation**: Runs an outer join on all metrics by Subject ID, exporting a single unified master table.

---

## 🚀 Getting Started

Please refer to the specific README files under the subdirectories for detailed usage instructions:
* For details about sensor cleaning, normalizations, and source space projections, see [preprocessing/README.md](preprocessing/README.md).
* For details on running feature extractions and using consolidated outputs, see [postprocessing/README.md](postprocessing/README.md).
