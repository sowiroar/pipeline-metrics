import os
import subprocess
import shutil
import sys

SEPARATOR = "=" * 50

def run_matlab_script(script_name):
    print(f"\n--- Running MATLAB Script: {script_name} ---")
    matlab_cmd = shutil.which("matlab")
    if matlab_cmd is None:
        print("Warning: MATLAB executable was not found on your system PATH.")
        print("Please run the MATLAB script manually inside MATLAB:")
        print("  1. Open MATLAB")
        print(f"  2. Navigate to: {os.path.join(os.path.dirname(__file__), 'matlab')}")
        print(f"  3. Execute: {script_name}")
        return False
        
    matlab_dir = os.path.join(os.path.dirname(__file__), 'matlab')
    # Run MATLAB in batch mode
    cmd = [matlab_cmd, "-batch", f"{script_name}; exit"]
    print(f"Running command: {' '.join(cmd)} in cwd: {matlab_dir}")
    try:
        result = subprocess.run(cmd, cwd=matlab_dir, capture_output=True, text=True, check=True)
        print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error running MATLAB script {script_name}:")
        print(e.stdout)
        print(e.stderr)
        return False
    except Exception as ex:
        print(f"Unexpected error when launching MATLAB: {ex}")
        return False

def main():
    print(SEPARATOR)
    print("EEG Pipeline - Post-processing Feature Extraction")
    print(SEPARATOR)
    
    # 1. Run MATLAB Frequency extraction
    run_matlab_script("main_frecuency")
    
    # 2. Run MATLAB Complexity extraction
    run_matlab_script("main_complexity")
    
    python_dir = os.path.join(os.path.dirname(__file__), 'python')
    
    # 3. Run Python Aperiodic extraction
    print("\n--- Running Python Aperiodic Extraction ---")
    try:
        script_path = os.path.join(python_dir, "main_aperiodic.py")
        subprocess.run([sys.executable, script_path], check=True)
    except Exception as e:
        print(f"Error in aperiodic extraction: {e}")
        
    # 4. Run Python Connectivity extraction
    print("\n--- Running Python Connectivity Extraction ---")
    try:
        script_path = os.path.join(python_dir, "main_connectivity.py")
        subprocess.run([sys.executable, script_path], check=True)
    except Exception as e:
        print(f"Error in connectivity extraction: {e}")
        
    # 5. Consolidate all metrics
    print("\n--- Running Feature Consolidation ---")
    try:
        script_path = os.path.join(python_dir, "consolidate_features.py")
        subprocess.run([sys.executable, script_path], check=True)
    except Exception as e:
        print(f"Error in feature consolidation: {e}")
        
    print(f"\n{SEPARATOR}")
    print("Post-processing Run Completed.")
    print(SEPARATOR)

if __name__ == '__main__':
    main()
