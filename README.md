# Water Potability: Classification & Comparative Analysis

A comparative study of supervised learning architectures designed to predict water potability. This project contrasts the interpretability of Decision Tree (DT) classifiers against the predictive robustness of Random Forest (RF) ensemble methods, with a specific focus on optimizing for public health safety through metric selection.

## Overview
This project provides a complete machine learning pipeline in MATLAB to predict water potability. It compares a single Optimised Decision Tree against a Random Forest Ensemble. The process includes data cleaning, Exploratory Data Analysis (EDA), hyperparameter tuning, and final model evaluation.

## Methodology
The project follows a rigorous machine learning pipeline, detailed in the accompanying research report:

* **Data Preprocessing:** Handled missing observations (dropping approx. 38.7% of original data to prevent imputation bias) and addressed feature skewness (specifically in the `Solids` variable) using Z-score normalization to stabilize model inputs.
* **Model Optimisation:** 
    * **Decision Tree:** Implemented 5-fold cross-validation and a grid search to optimize `MinLeafSize`.
    * **Random Forest:** Utilised Out-of-Bag (OOB) error estimation and grid search to determine the optimal ensemble size.
* **Evaluation Framework:** Evaluated performance based on the quantitative cost of error (Type I vs. Type II), utilizing F1-Score, AUC-ROC, and Confusion Matrices to determine real-world implementation suitability.

## Software & Technical Requirements
* **Software:** MATLAB (Recommended version: R2021a or later).
* **Required Toolboxes:** Statistics and Machine Learning Toolbox (Required for `fitctree`, `TreeBagger`, and `perfcurve`).
* **Reproducibility:** The script uses `rng(42)` to ensure stratified data splits and Random Forest results are consistent across runs.

## Data Dictionary
| Feature | Definition |
| :--- | :--- |
| **ph** | pH of water (0 to 14) |
| **Hardness** | Capacity of water to precipitate soap (mg/L) |
| **Solids** | Total dissolved solids (ppm) |
| **Chloramines** | Amount of Chloramines (ppm) |
| **Sulfate** | Amount of Sulfates dissolved (mg/L) |
| **Conductivity** | Electrical conductivity of water ($\mu$S/cm) |
| **Organic_carbon** | Amount of organic carbon (ppm) |
| **Trihalomethanes** | Amount of Trihalomethanes ($\mu$g/L) |
| **Turbidity** | Measure of light emitting property of water (NTU) |
| **Potability** | Indicates if safe for human consumption (1 = Potable, 0 = Not potable) |

## Pipeline Setup & Execution
1. Ensure `water_potability.csv` is in the same directory as `MLProjectCodes.m`.
2. Open MATLAB and navigate to the project folder.
3. Run `MLProjectCodes.m`. The script executes in 7 phases:
    - **Phases 1-3:** Preprocessing and EDA.
    - **Phase 4:** Data Partitioning (70% Train/30% Test) and Z-Score Normalization.
    - **Phase 5:** Decision Tree training and Grid Search optimization.
    - **Phase 6:** Random Forest training and Ensemble Size optimization.
    - **Phase 7:** Final comparative visualization (ROC Curves/Comparison Table).

## Repository Structure
* **`ML Project Poster.pdf`**: Technical documentation and results.
* **`MLProjectCodes.m`**: Complete MATLAB implementation.
* **`ML Project Supplementary Material.pdf`**: Detailed statistical data.
* **`water_potability.csv`**: Raw dataset.
* **`README.md`**: Project documentation.
