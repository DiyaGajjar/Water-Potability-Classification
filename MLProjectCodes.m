%% PHASE 1: PREPROCESSING & CLEANING
clear; clc; close all; % Clear the workspace to ensure a fresh start

%% 1.1 LOAD the DATASET
% Use 'detectImportOptions' to keep the original column names (e.g., 'pH')
% instead of letting MATLAB rename them to generic names like 'Var1'.
opts = detectImportOptions('water_potability.csv');
opts.VariableNamingRule = 'preserve';
data = readtable('water_potability.csv', opts);

fprintf('Data Loaded: %d rows, %d columns.\n', height(data), width(data));

%% 1.2 REMOVE DUPLICATES
% Duplicate rows are bad because they can cause "Data Leakage" (the model
% memorises repeated answers), therefore remove them to ensure every sample is unique.
[data, ~] = unique(data, 'rows');

fprintf('Duplicates Removed. Current Size: %d rows.\n', height(data));

%% RAW DATA VISUALISATION (EVIDENCE GATHERING)
% Investigate the raw data, check for skewness, outliers and missing values
fprintf('\n--- GENERATING RAW DATA VISUALISATIONS ---\n');

%% 1.3 HISTOGRAMS (Check for Skewness)
% Use subplots to show each variable on its own scale for easier analysis
figure('Name', 'Raw Data Distributions', 'Color', 'w', 'Position', [50, 50, 1400, 900]);

for i = 1:9
    subplot(3, 3, i); % Create a 3x3 grid
    
    % Plots the i-th variable for each subplot so that each variable has
    % its own y axis range 
    histogram(data.(i), 30, 'FaceColor', '#0072BD', 'EdgeColor', 'none');
    
    title(data.Properties.VariableNames{i});
    xlabel('Raw Value'); ylabel('Frequency');
    grid on; % Makes it easier to read the Y-axis scale
end

sgtitle('Raw Feature Distributions (Evidence of Skewness)');

%% 1.4 BOX PLOTS (Outlier Visualisation)
% Create a box plot for each variable 
% Use 'r+' (Red Plus signs) to make outliers clearly visible.
figure('Name', 'Feature Outliers', 'Color', 'w', 'Position', [50, 50, 1400, 900]);

for i = 1:9
    subplot(3, 3, i);
    % Use data{:,i} to extract column safely
    % 'Symbol', 'r+' makes outliers appear as Red Crosses (High Visibility)
    boxplot(data{:, i}, 'Labels', {''}, 'Symbol', 'r+'); 
    
    title(data.Properties.VariableNames{i});
    ylabel('Raw Value');
    grid on;
end

%% 1.5 CHECK FOR OUTLIERS MATHEMATICALLY (IQR METHOD)
% Calculate exactly how many outliers exist to confirm the Box Plots.
fprintf('\n--- OUTLIER ANALYSIS (IQR Method) ---\n');
fprintf('%-20s | %-10s \n', 'Variable', 'Outliers');

varNames = data.Properties.VariableNames;
% Loop through predictor columns
for i = 1:width(data)-1
    colName = varNames{i};       
    colData = data.(colName);    
    
    % Calculate Quartiles (ignoring NaNs for this check)
    Q1 = quantile(colData, 0.25); 
    Q3 = quantile(colData, 0.75);
    IQR_val = Q3 - Q1;           
    
    % Define Statistical Fences (1.5 * IQR)
    lower_bound = Q1 - 1.5 * IQR_val;
    upper_bound = Q3 + 1.5 * IQR_val;
    
    % Count data points outside the fences
    num_outliers = sum((colData < lower_bound) | (colData > upper_bound));
    fprintf('%-20s | %5d \n', colName, num_outliers);
end
fprintf('CONCLUSION: Significant outliers confirmed. Mean Imputation is unsafe.\n');

%% 1.6 CHECK FOR MISSING VALUES AND REPLACE WITH MEDIAN VALUE 
% Quantify the missing data. Then, apply Median Imputation
% because it is robust to the heavy tails (outliers) we just detected.

fprintf('\n--- FIXING MISSING VALUES ---\n');

% Define the variables to check 
varsToFix = {'ph', 'Sulfate', 'Trihalomethanes'};

for i = 1:length(varsToFix)
    name = varsToFix{i};
    
    % Explicitly count missing values (NaNs)
    num_missing = sum(isnan(data.(name)));
    
    if num_missing > 0
        % Calculate the median (ignoring NaNs)
        medVal = median(data.(name), 'omitnan');
        
        % Fill in the missing values with the median value 
        data.(name) = fillmissing(data.(name), 'constant', medVal);
        
        % Report the specific action taken
        fprintf('ACTION: Found %d missing values in "%s". Filled with Median (%.2f).\n', ...
            num_missing, name, medVal);
    else
        fprintf('STATUS: Variable "%s" is complete (No missing values).\n', name);
    end
end

% Confirm dataset is now 100% cleaned
total_missing = sum(sum(ismissing(data)));
if total_missing == 0
    fprintf('SUCCESS: All missing values have been resolved.\n');
else
    warning('CRITICAL: %d missing values still remain!', total_missing);
end

%% PHASE 2: EXPLORATORY DATA ANALYSIS USING THE CLEANED DATASET 
%% 2.1 DESCRIPTIVE STATISTICS (POST-CLEANING CHECK)
% Calculate statistics on the CLEAN data to ensure imputation 
% did not distort the natural distribution. We compare Mean/Skewness to raw data.
% This table is needed for the 'Supplementary Material'.

fprintf('\n--- GENERATING DESCRIPTIVE STATISTICS (CLEANED DATASET) ---\n');

% Extract features (Columns 1-9) excluding the Target
features = data(:, 1:end-1); 
X_mat = features{:,:}; 

% Calculate key metrics
% Skewness > 1: Data is non-normal (validates Random Forest choice)
% Kurtosis > 3: Heavy tails (confirms presence of outliers)
StatsTable = table(mean(X_mat)', median(X_mat)', std(X_mat)', skewness(X_mat)', kurtosis(X_mat)', ...
    'RowNames', features.Properties.VariableNames, ...
    'VariableNames', {'Mean', 'Median', 'StdDev', 'Skewness', 'Kurtosis'});

disp(StatsTable); % Display table in Command Window

f = figure('Name','Descriptive Statistics','Color','w', 'Position',[100 100 800 400]);
uitable(f, 'Data', table2cell(StatsTable), ...
            'ColumnName', StatsTable.Properties.VariableNames, ...
            'RowName', StatsTable.Properties.RowNames, ...
            'Units','Normalized', 'Position',[0 0 1 1]);

%% 2.2 HISTOGRAMS
% To visually confirm that filling missing values (Median Imputation)
% preserved the distribution shapes and didn't create artificial spikes.
% We use GREEN to signify this is the "Clean/Safe" dataset.

figure('Name', 'Cleaned Distributions', 'Color', 'w', 'Position', [50, 50, 1400, 900]);

for i = 1:9
    subplot(3, 3, i); % Create 3x3 grid
    
    % Plot Histogram
    % 'FaceColor' is Green (#77AC30) to distinguish from Raw data
    histogram(data.(i), 30, 'EdgeColor', 'none', 'FaceColor', '#77AC30'); 
    
    title(data.Properties.VariableNames{i});
    xlabel('Cleaned Value'); ylabel('Freq');
    grid on;
end
sgtitle('Cleaned Feature Distributions (Post-Imputation Verification)');

%% 2.3 BOX PLOTS 
% Imputation fixes missing values, but it DOES NOT remove outliers.
% We plot this to prove that "Heavy Tails" (Red Crosses) still exist.
% SCIENTIFIC CONCLUSION: Since outliers remain, we must use a robust model
% (Random Forest) rather than Linear Regression (which is sensitive to outliers).

figure('Name', 'Cleaned Outliers', 'Color', 'w', 'Position', [50, 50, 1400, 900]);

for i = 1:9
    subplot(3, 3, i);
    
    % Plot Boxplot on separate axes to verify true scale
    % 'Symbol', 'r+' forces outliers to appear as RED CROSSES
    boxplot(data.(i), 'Labels', {''}, 'Symbol', 'r+'); 
    
    title(data.Properties.VariableNames{i});
    ylabel('Cleaned Value');
    grid on;
end
sgtitle('Cleaned Data Box Plots (Evidence of Retained Outliers)');

%% 2.4 CORRELATION MATRIX A: STANDARD VIEW (High Visibility)
% Use a diverging Red-White-Blue scale to maximise contrast.
% - Red  = Negative Relationship
% - Blue = Positive Relationship
% - White = Independent (No Relationship)

figure('Name', 'Correlation (Standard)', 'Color', 'w', 'Position', [100, 100, 1000, 800]);

% Create Custom "Deep Red - White - Deep Blue" Colormap
% Using darker shades (0.8) makes the white text inside the boxes readable.
color_neg = [0.8, 0.0, 0.0];  % Deep Red
color_mid = [1.0, 1.0, 1.0];  % Pure White
color_pos = [0.0, 0.0, 0.8];  % Deep Blue

% Build the gradient math
R = [linspace(color_neg(1), color_mid(1), 128)'; linspace(color_mid(1), color_pos(1), 128)'];
G = [linspace(color_neg(2), color_mid(2), 128)'; linspace(color_mid(2), color_pos(2), 128)'];
B = [linspace(color_neg(3), color_mid(3), 128)'; linspace(color_mid(3), color_pos(3), 128)'];
high_contrast_map = [R, G, B];

% Generate Heatmap
h1 = heatmap(features.Properties.VariableNames, features.Properties.VariableNames, ...
    corr(table2array(features)), 'Colormap', high_contrast_map);

% Apply Settings
h1.Title = 'Pearson Correlation (Standard Scale -1 to +1)';
h1.ColorLimits = [-1, 1];     % Keep standard limits to check for strong correlations
h1.CellLabelFormat = '%.2f';  % Show 2 decimal places

%% 2.5 CORRELATION MATRIX (ZOOMED)
% Natural correlations in this dataset are low (< 0.2), making them
% invisible on a standard scale. Change teh range of the heat map to +/- 0.2 to 
% visually reveal the structure of relationships (e.g., Solids vs Sulfate).
% - Deep Red  = Negative Correlation
% - Pure White = Zero Correlation
% - Deep Blue = Positive Correlation

fprintf('Generating Zoomed Red-White-Blue Correlation Matrix...\n');

figure('Name', 'Correlation (Zoomed)', 'Color', 'w', 'Position', [100, 100, 1000, 800]);

% Create Custom "Deep Red - White - Deep Blue" Colormap
% We use darker shades (0.8 intensity) so white text stands out.
color_neg = [0.8, 0.0, 0.0];  % Deep Red
color_mid = [1.0, 1.0, 1.0];  % Pure White
color_pos = [0.0, 0.0, 0.8];  % Deep Blue

% Build the gradient (128 steps per side)
R = [linspace(color_neg(1), color_mid(1), 128)'; linspace(color_mid(1), color_pos(1), 128)'];
G = [linspace(color_neg(2), color_mid(2), 128)'; linspace(color_mid(2), color_pos(2), 128)'];
B = [linspace(color_neg(3), color_mid(3), 128)'; linspace(color_mid(3), color_pos(3), 128)'];
custom_map = [R, G, B];

% Generate Heatmap
features = data(:, 1:end-1);
h = heatmap(features.Properties.VariableNames, features.Properties.VariableNames, ...
    corr(table2array(features)), 'Colormap', custom_map);

% Change the range 
% Standard limit is [-1, 1]. We shrink it to [-0.2, 0.2].
% This means a correlation of 0.2 will show as MAXIMUM BLUE.
h.ColorLimits = [-0.2, 0.2]; 

% Formatting
h.Title = 'Pearson Correlation (Zoomed to +/- 0.2)';
h.CellLabelFormat = '%.2f';   % Show 2 decimal places
h.FontSize = 10;

%% 2.6 CLASS DISTRIBUTION CHECK (IMBALANCE ANALYSIS)
% Calculate the exact ratio of Potable vs Not Potable water.
% A split of 60/40 is "Imbalanced". This means 'Accuracy' can be misleading.
% If the model predicts Class 0 for everything, it gets 61% accuracy (Null Accuracy).
% Therefore, we will prioritize F1-Score during evaluation.

fprintf('\n--- CLASS BALANCE ANALYSIS ---\n');

% 1. Count the samples in each class
% 'groupcounts' automatically counts 0s and 1s in the Target column
class_counts = groupcounts(data, 'Potability');

num_unsafe = class_counts.GroupCount(1); % Class 0 (Not Potable)
num_safe   = class_counts.GroupCount(2); % Class 1 (Potable)
total_samples = height(data);

% Calculate Percentages
pct_unsafe = (num_unsafe / total_samples) * 100;
pct_safe   = (num_safe / total_samples) * 100;

% Print the math check to the Command Window
fprintf('Not Potable (0): %d samples (%.1f%%)\n', num_unsafe, pct_unsafe);
fprintf('Potable (1):     %d samples (%.1f%%)\n', num_safe, pct_safe);
fprintf('Total:           %d samples (%.1f%%)\n', total_samples, pct_unsafe + pct_safe);

% Visualize Class Balance (Figure for Poster)
figure('Name', 'Class Balance', 'Color', 'w', 'Position', [100, 100, 600, 400]);

% Create Bar Chart
% X-axis = [0, 1], Y-axis = [Count 0, Count 1]
b = bar([0, 1], [num_unsafe, num_safe], 'FaceColor', 'flat');

% Color Code: Orange for Warning (Unsafe), Green for Safe
b.CData(1,:) = [0.85, 0.33, 0.1]; % Deep Orange
b.CData(2,:) = [0.47, 0.67, 0.19]; % Forest Green

% Add Labels
xticklabels({'Not Potable (0)', 'Potable (1)'});
ylabel('Number of Samples');
t = title(sprintf('Class Distribution (%.1f%% vs %.1f%%)', pct_unsafe, pct_safe));
t.Position(2) = t.Position(2) + 0.05 * max([num_unsafe, num_safe]);  % shift upward
grid on;

% Add Text Numbers on top of the bars for readability
text(0, num_unsafe, num2str(num_unsafe), 'Vert', 'bottom', 'Horiz', 'center', 'FontSize', 12);
text(1, num_safe, num2str(num_safe), 'Vert', 'bottom', 'Horiz', 'center', 'FontSize', 12);

%% PHASE 3: LINEARITY & SEPARABILITY ANALYSIS
% Investigate the relationship between features and the Target.
% Visually investigate wether the classes (0 vs 1) are linearly separable.
% This serves as the 'hypothesis validation' for why Linear Regression fails.

fprintf('\n--- GENERATING TARGET ANALYSIS PLOTS ---\n');

%% 3.1 OVERLAID HISTOGRAMS
% Plot Potable vs Not Potable on the same axis, show wether 
% Safe water (Green) is "nested" inside Unsafe water (Red).
% This overlap proves that a simple linear threshold cannot separate them.

% Create a large HD figure to fit 9 plots
figure('Name', 'Class Overlap All', 'Color', 'w', 'Position', [50, 50, 1400, 900]);

% Select ALL 9 feature names automatically (Columns 1 to 9)
varsOfInterest = data.Properties.VariableNames(1:9); 

% Loop through all 9 features
for i = 1:9
    subplot(3, 3, i); % Change grid to 3x3 to fit all 9 plots
    featName = varsOfInterest{i}; 
    
    hold on; % Keep plot open to layer Red and Green
    
    % Plot NOT POTABLE (Class 0) in Red
    histogram(data.(featName)(data.Potability == 0), 30, ...
        'FaceColor', 'r', 'FaceAlpha', 0.4, 'EdgeColor', 'none');
    
    % Plot POTABLE (Class 1) in Green
    histogram(data.(featName)(data.Potability == 1), 30, ...
        'FaceColor', 'g', 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    
    % Formatting
    title([featName ' Class Overlap']);
    xlabel(featName); 
    ylabel('Frequency'); 
    
    % Only show legend on the first plot to avoid cluttering the grid
    if i == 1
        legend({'Not Potable', 'Potable'}, 'Location', 'best');
    end
    
    grid on;
    hold off;
end

sgtitle('Non-Linearity Proof: High Class Overlap Across All Features');

%% 3.2 CORRELATION WITH TARGET
% Calculate the correlation of every feature with 
% the Target (Potability). If the bars are near 0, it proves there is 
% NO LINEAR relationship. This justifies using Random Forest.

figure('Name', 'Target Correlation', 'Color', 'w', 'Position', [100, 100, 800, 500]);

% Prepare Raw Data
X_mat = data{:, 1:end-1};        % Raw Features (Cols 1-9)
y_vec = double(data.Potability); % Target (0/1)

% Calculate Pearson Correlation
% Note: Correlation calculates the linear relationship. It does not 
% care about scale, so calculating on Raw Data is scientifically valid.
target_corr = corr(X_mat, y_vec);

% Plot Bar Chart
b = bar(target_corr, 'FaceColor', '#7E2F8E'); % Purple bars

% Formatting
xticklabels(data.Properties.VariableNames(1:9));
xtickangle(45); % Tilt labels
ylabel('Pearson Correlation');
title('Feature Correlation with Target (Low = Non-Linear)');
grid on;

% Zoom y-axis to show how small the correlations are (e.g., +/- 0.15)
ylim([-0.1, 0.1]); 

% Add Text Numbers on bars
text(1:9, target_corr, num2str(target_corr, '%.3f'), ...
    'Vert', 'bottom', 'Horiz', 'center', 'FontSize', 10);

%% PHASE 4: TRAIN/TEST SPLIT & NORMALISATION
% Prepare the final datasets for modelling. 
% split the data first, then normalise. This is critical to prevent "Data Leakage"

fprintf('\n--- STARTING PHASE 4: DATA PREPARATION ---\n');

%% 4.1 SEPARATE FEATURES AND TARGET
% Separate the input variables from the output label (Potability).

% Extract Features (Columns 1 to 9)
X_raw = data{:, 1:end-1}; 

% Extract Target (Column 10) and convert to Categorical
Y = categorical(data.Potability); 

fprintf('Separated Features and Target.\n');

%% 4.2 STRATIFIED SPLIT (70% TRAIN / 30% TEST)
% Use a "Stratified" split to ensure that the ratio of 
% Potable (1) vs Not Potable (0) is exactly the same in both the 
% Training set and the Test set.

% Set a fixed random seed so results are reproducible every time
rng(42); 

% Create the partition (Hold out 30% for testing)
cv = cvpartition(Y, 'HoldOut', 0.30);

% Extract the RAW Training Data using the partition
XTrain_raw = X_raw(training(cv), :);
YTrain     = Y(training(cv));

% Extract the RAW Test Data using the partition
XTest_raw  = X_raw(test(cv), :);
YTest      = Y(test(cv));

fprintf('Split Complete: %d Training samples, %d Testing samples.\n', ...
    length(YTrain), length(YTest));


%% 4.3 Z-SCORE NORMALISATION (PREVENTING DATA LEAKAGE)
% Must normalise because 'Solids' (~60,000) is huge compared 
% to 'pH' (~7). If we don't, the model will ignore pH.
% CRITICAL: We calculate the Mean and Std Dev from the TRAINING set only.

fprintf('Applying Normalisation (Using Training stats only)...\n');

% Normalise training data & save the parameters (Mean and Sigma)
[XTrain, mu, sigma] = normalize(XTrain_raw);

% Normalise test data using the training parameters
XTest = (XTest_raw - mu) ./ sigma;

%% PHASE 5: MODEL 1 - DECISION TREE
% Investigate the performance of a Decision Tree Classifier.
% Start with a 'Default' tree to establish a baseline. 
% Default trees often overfit (grow too complex) so investigate that and then perform 
% Hyperparameter Optimisation (Grid Search) to prune the tree and 
% improve generalisation on unseen data.

fprintf('\n--- PHASE 5: DECISION TREE ---\n');

%% 5.1 TRAIN "DEFAULT" DECISION TREE (BASELINE)
% Train a standard tree without any pruning parameters.
% This tree is expected to be overfitting
fprintf('\n--- TRAINING DEFAULT DECISION TREE (BASELINE) ---\n');

tic; % Start timer to measure computational cost
mdl_Default = fitctree(XTrain, YTrain); % Train tree with NO limits (Default)
time_def = toc; % Stop timer

% Evaluate on TRAINING Set (To check for Overfitting)
% We predict on the data the model just learned. 
% If this accuracy is ~100%, the model has memorised the data.
preds_Train = predict(mdl_Default, XTrain);
acc_Train_Def = sum(preds_Train == YTrain) / length(YTrain); 

% Evaluate on TEST Set (Unseen Data)
% Predict on new data to measure real-world performance (Generalisation).
% [UPDATED]: We now request 'scores_Def' (Probabilities) to calculate AUC
[preds_Def, scores_Def] = predict(mdl_Default, XTest);
acc_Def = sum(preds_Def == YTest) / length(YTest);

% Calculate F1 Score (Harmonic Mean of Precision & Recall)
% Create Confusion Matrix to get True Positives (TP), False Positives (FP), etc.
cmDef = confusionmat(YTest, preds_Def);

% Precision = TP / (TP + FP) -> Accuracy of positive predictions
prec_Def = cmDef(2,2) / (cmDef(2,2) + cmDef(1,2)); 

% Recall = TP / (TP + FN) -> Ability to find all positive samples
rec_Def  = cmDef(2,2) / (cmDef(2,2) + cmDef(2,1)); 

% F1 Score balances Precision and Recall (crucial for imbalanced data)
f1_Def   = 2 * (prec_Def * rec_Def) / (prec_Def + rec_Def); 

% Calculate AUC (Area Under Curve)
% Use the scores for the positive class (Column 2) against the True Labels
[~, ~, ~, auc_Def] = perfcurve(YTest, scores_Def(:,2), '1');

% Calculate Model Complexity
% 'PruneList' helps estimate the max depth of the unpruned tree.
depth_Def = max(mdl_Default.PruneList) - 1; 
% 'NumNodes' counts total splits. High nodes = High Variance.
nodes_Def = mdl_Default.NumNodes;

% Display Baseline Results
fprintf('DEFAULT TREE METRICS:\n');
fprintf('  Training Time:     %.4f sec\n', time_def);
fprintf('  Tree Depth:        %d (Deep structure implies Overfitting)\n', depth_Def);
fprintf('  Total Nodes:       %d (High complexity)\n', nodes_Def);
fprintf('  Training Accuracy: %.2f%% (High = Overfitting)\n', acc_Train_Def * 100);
fprintf('  Testing Accuracy:  %.2f%%\n', acc_Def * 100);
fprintf('  F1-Score:          %.4f\n', f1_Def);
fprintf('  AUC:               %.4f\n', auc_Def);

% Visualisation: Default Confusion Matrix
figure('Name', 'Default DT', 'Color', 'w', 'Position', [100, 100, 500, 400]);
cm = confusionchart(YTest, preds_Def);
cm.Title = sprintf('Default Tree (Leaf: 1, F1: %.2f)', f1_Def);

%% 5.2.1 HYPERPARAMETER OPTIMISATION (GRID SEARCH)
% Fix the overfitting identified above and limit tree complexity.
% Tune 'MinLeafSize' (Minimum samples per leaf).
% - Small Leaf (1) = Complex (Overfitting)
% - Large Leaf (100) = Simple (Underfitting)
% Use 5-Fold Cross-Validation to find the optimal balance.

fprintf('\n--- STARTING GRID SEARCH OPTIMISATION ---\n');

leaf_sizes = [1, 5, 10, 20, 50, 70, 100]; % The Grid of values to test
num_grids = length(leaf_sizes);
cv_errors = zeros(num_grids, 1); % Array to store error rates

tic; % Start timer for tuning process
for i = 1:num_grids
    current_leaf = leaf_sizes(i);
    
    % Train a Cross-Validated Tree
    % 'KFold', 5: Splits training data into 5 folds (Train on 4, Validate on 1).
    % This creates a robust estimate of performance without using the Test set.
    t = fitctree(XTrain, YTrain, ...
        'MinLeafSize', current_leaf, ...
        'KFold', 5);
    
    % Calculate Validation Loss (Average Classification Error across 5 folds)
    cv_errors(i) = kfoldLoss(t);
    
    fprintf('  Tested Leaf Size: %3d | Validation Error: %.4f\n', ...
        current_leaf, cv_errors(i));
end
tune_time = toc;

% Find the Best Parameter (Lowest Validation Error)
[min_err, idx] = min(cv_errors);
best_leaf = leaf_sizes(idx);

fprintf('OPTIMAL RESULT: Best Leaf Size is %d (Found in %.2f sec)\n', ...
    best_leaf, tune_time);

% Visualise Optimisation Curve (Bias-Variance Trade-off)
figure('Name', 'DT Optimization', 'Color', 'w');
plot(leaf_sizes, cv_errors, 'b-o', 'LineWidth', 2);
xlabel('Min Leaf Size'); ylabel('Cross-Validation Error');
title(sprintf('Hyperparameter Tuning (Optimal: %d)', best_leaf));
grid on; hold on;
plot(best_leaf, min_err, 'r*', 'MarkerSize', 15);

%% 5.2.2 HYPERPARAMETER OPTIMISATION (EXTENDED GRID SEARCH)
% Previous tests showed the error dropping at Leaf Size 100.
% To find the true global minimum, extend the search range to 200 with 
% intervals of 25. This covers the full spectrum from 
% high variance (Leaf 1) to potential high bias (Leaf 200).

fprintf('\n--- STARTING EXTENDED GRID SEARCH OPTIMISATION ---\n');

% Define the Extended Grid
% Keep small numbers (1, 5, 10) to visualise the initial overfitting.
% Then jump to 25 and go up to 200 in steps of 25.
leaf_sizes = [1, 5, 10, 25, 50, 75, 100, 125, 150, 175, 200]; 

num_grids = length(leaf_sizes);
cv_errors = zeros(num_grids, 1); % Array to store error rates

tic; % Start timer for tuning process
for i = 1:num_grids
    current_leaf = leaf_sizes(i);
    
    % Train a Cross-Validated Tree
    % 'fitctree' builds the model.
    % 'KFold', 5: Automatically splits training data into 5 folds.
    t = fitctree(XTrain, YTrain, ...
        'MinLeafSize', current_leaf, ...
        'KFold', 5);
    
    % Calculate Validation Loss (Average Classification Error)
    cv_errors(i) = kfoldLoss(t);
    
    fprintf('  Tested Leaf Size: %3d | Validation Error: %.4f\n', ...
        current_leaf, cv_errors(i));
end
tune_time = toc;

% Find the Best Parameter (Lowest Validation Error)
[min_err, idx] = min(cv_errors);
best_leaf = leaf_sizes(idx);

fprintf('OPTIMAL RESULT: Best Leaf Size is %d (Found in %.2f sec)\n', ...
    best_leaf, tune_time);

% Visualise Optimisation Curve (Bias-Variance Trade-off)
figure('Name', 'DT Optimization', 'Color', 'w');
plot(leaf_sizes, cv_errors, 'b-o', 'LineWidth', 2);
xlabel('Min Leaf Size'); ylabel('Cross-Validation Error');
title(sprintf('Hyperparameter Tuning (Optimal: %d)', best_leaf));
grid on; hold on;

% Highlight the best point with a red star
plot(best_leaf, min_err, 'r*', 'MarkerSize', 15);
legend('Validation Curve', 'Optimal Point');

%% 5.3 TRAIN FINAL "OPTIMISED" MODEL
% Retrain the model on the FULL training set using 
% the optimised parameter (Best Leaf Size) found in the Grid Search.

fprintf('\n--- TRAINING OPTIMISED TREE ---\n');

% Start Timer
% Measure training time to see if optimisation made it faster or slower.
tic;

% Train the Model using the best parameter
% 'MinLeafSize': Use the optimized value to prune the tree and stop overfitting.
% 'SplitCriterion': Gini Diversity Index ('gdi') is the standard for classification.
mdl_Opt = fitctree(XTrain, YTrain, ...
    'MinLeafSize', best_leaf, ... 
    'SplitCriterion', 'gdi'); 

% Stop Timer
time_opt = toc;

% Evaluate on TRAINING Set (To check for Overfitting)
% Predict on the data the model just learned. 
% If this accuracy drops compared to the Default tree, it is GOOD.
% It means the model was stopped from "memorising" the noise.
preds_Train_Opt = predict(mdl_Opt, XTrain);
acc_Train_Opt = sum(preds_Train_Opt == YTrain) / length(YTrain);

% Evaluate on TEST Set (Unseen Data)
% Apply the optimised model to unseen data to measure real-world generalization.
% Request 'scores_Opt' (2nd output) for AUC calculation
[preds_Opt, scores_Opt] = predict(mdl_Opt, XTest);

% Calculate Accuracy
% Accuracy = (Correct Predictions) / (Total Predictions)
acc_Opt = sum(preds_Opt == YTest) / length(YTest);

% Calculate Precision, Recall, and F1-Score (Crucial for Imbalance)
% Generate Confusion Matrix to get TP, FP, TN, FN
cmOpt = confusionmat(YTest, preds_Opt);

% Precision = TP / (TP + FP) (How many predicted "Safe" were actually Safe?)
prec_Opt = cmOpt(2,2) / (cmOpt(2,2) + cmOpt(1,2));

% Recall = TP / (TP + FN) (How many actual "Safe" samples did we find?)
rec_Opt  = cmOpt(2,2) / (cmOpt(2,2) + cmOpt(2,1));

% F1-Score = Harmonic Mean of Precision and Recall
f1_Opt   = 2 * (prec_Opt * rec_Opt) / (prec_Opt + rec_Opt);

% Safety check for NaN (if model predicts 0 for everything)
if isnan(f1_Opt), f1_Opt = 0; end

% Calculate AUC (Area Under Curve)
% Measures separability. 0.5 = Random, 1.0 = Perfect.
[~, ~, ~, auc_Opt] = perfcurve(YTest, scores_Opt(:,2), '1');

% Calculate optimised complexity
% 'PruneList' helps estimate depth. This should be LOWER than the Default Tree.
depth_Opt = max(mdl_Opt.PruneList) - 1; 
% 'NumNodes' counts splits. Fewer nodes = Simpler Model = Better Generalisation.
nodes_Opt = mdl_Opt.NumNodes;

% Display Results
fprintf('OPTIMISED TREE METRICS:\n');
fprintf('  Training Time:     %.4f sec\n', time_opt);
fprintf('  Tree Depth:        %d (Should be simpler than Default)\n', depth_Opt);
fprintf('  Total Nodes:       %d (Reduced complexity)\n', nodes_Opt);
fprintf('  Training Accuracy: %.2f%% (Gap with Test should be small)\n', acc_Train_Opt * 100);
fprintf('  Testing Accuracy:  %.2f%%\n', acc_Opt * 100);
fprintf('  F1-Score:          %.4f\n', f1_Opt);
fprintf('  AUC:               %.4f\n', auc_Opt); 

% Visualisation: Optimised Confusion Matrix
figure('Name', 'Optimized DT', 'Color', 'w', 'Position', [100, 100, 500, 400]);
cm = confusionchart(YTest, preds_Opt);
cm.Title = sprintf('Optimised Tree (Leaf: %d, F1: %.2f)', best_leaf, f1_Opt);

%% 5.4 VISUALISATION: FEATURE IMPORTANCE (SINGLE TREE)
% Calculate 'Predictor Importance' to see which features were 
% used for splits. This sums the Gini Impurity decrease for each feature.
% Features with 0 importance were 'pruned' away as noise.

fprintf('\n--- GENERATING FEATURE IMPORTANCE ---\n');

% Calculate importance scores from the Optimised Model
imp = predictorImportance(mdl_Opt);

% Sort high to low for a clean chart
[sorted_imp, idx] = sort(imp, 'descend');

% Get the variable names (excluding the Target column)
varNames = data.Properties.VariableNames(1:end-1);

% Plot bar chart
figure('Name', 'DT Feature Importance', 'Color', 'w');
bar(sorted_imp, 'FaceColor', '#0072BD'); % Professional Blue

% Formatting
xticks(1:length(imp));
xticklabels(varNames(idx));
xtickangle(45); % Tilt text so it fits
ylabel('Importance Score (Gini Importance)');
title('Decision Tree Feature Importance');
grid on;

%% 5.5 FINAL COMPARISON TABLE
% A side-by-side comparison table to quantitatively prove 
% that optimisation reduced complexity (nodes) and stabilised performance.
% We add AUC here to satisfy the project requirements.

fprintf('\n--- FINAL COMPARISON TABLE ---\n');

% Create a table comparing Default vs Optimised metrics
% We include Training Accuracy, Test Accuracy, F1, AUC, Depth, and Nodes.
Comparison = table([acc_Train_Def; acc_Train_Opt], ... % Check Overfitting
                   [acc_Def; acc_Opt], ...             % Check Real Performance
                   [f1_Def; f1_Opt], ...               % Check Class Balance handling
                   [auc_Def; auc_Opt], ...             % [ADDED] Check Discriminative Power
                   [depth_Def; depth_Opt], ...         % Check Depth Complexity
                   [nodes_Def; nodes_Opt], ...         % Check Structural Complexity
    'RowNames', {'Default Tree', 'Optimized Tree'}, ...
    'VariableNames', {'Train_Acc', 'Test_Acc', 'F1_Score', 'AUC', 'Depth', 'Nodes'});

% Display and Save
disp(Comparison);

%% 5.6 VISUALISATION: ROC CURVE COMPARISON (DEFAULT VS OPTIMISED)
% The ROC Curve visualises the trade-off between True Positive Rate 
% (Sensitivity) and False Positive Rate (1-Specificity).
% By plotting both curves, we can visually compare the discriminative power 
% of the Default (Overfit) tree vs the Optimized (Pruned) tree.

fprintf('\n--- GENERATING ROC CURVES ---\n');

% Get Probability Scores for Default Tree
[~, scores_Def] = predict(mdl_Default, XTest);
[Xroc_Def, Yroc_Def, ~, auc_Def] = perfcurve(YTest, scores_Def(:,2), '1');

% Get Probability Scores for Optimized Tree
[~, scores_Opt] = predict(mdl_Opt, XTest);
[Xroc_Opt, Yroc_Opt, ~, auc_Opt] = perfcurve(YTest, scores_Opt(:,2), '1');

% Plot Both Curves
figure('Name', 'DT ROC Comparison', 'Color', 'w');
hold on;

% Plot Default Tree (Dashed Blue Line)
plot(Xroc_Def, Yroc_Def, '--', 'LineWidth', 2, 'Color', '#0072BD');

% Plot Optimized Tree (Solid Green Line)
plot(Xroc_Opt, Yroc_Opt, '-', 'LineWidth', 2, 'Color', '#77AC30');

% Plot Random Guess Line (Diagonal Black)
plot([0 1], [0 1], 'k:', 'LineWidth', 1.5); 

% Formatting
xlabel('False Positive Rate (1 - Specificity)');
ylabel('True Positive Rate (Sensitivity)');
title('ROC Curve Comparison: Default vs Optimized');
grid on;

% Add Legend with AUC scores
legend({sprintf('Default Tree (AUC = %.2f)', auc_Def), ...
        sprintf('Optimized Tree (AUC = %.2f)', auc_Opt), ...
        'Random Guess'}, ...
        'Location', 'SouthEast');

hold off;

%% 5.7 VISUALISATION: TREE MAP (STRUCTURE)
% Decision Trees are "White Box" models. We can visualise the rules.
% Since the optimised tree is simple (Leaf 100), this chart will be readable.

fprintf('Generating Tree Map (Check Window)...\n');

% Retrain a temporary model just for visualisation
% We pass 'PredictorNames' so the boxes say "pH" instead of "x1"
feature_names = data.Properties.VariableNames(1:end-1);
mdl_Viz = fitctree(XTrain, YTrain, ...
    'MinLeafSize', best_leaf, ...
    'PredictorNames', feature_names); 

% Open the tree viewer
view(mdl_Viz, 'Mode', 'graph'); 

%% PHASE 6: MODEL 2 - RANDOM FOREST
% Train, tune, and evaluate a Random Forest Classifier.
% Random Forest utilises 'Bagging' (Bootstrap Aggregation)
% to reduce the high variance observed in the single Decision Tree.
% We optimise the 'Number of Trees' to balance performance with computational cost.

fprintf('\n--- STARTING PHASE 6: RANDOM FOREST ANALYSIS ---\n');

%% 6.1 HYPERPARAMETER TUNING (GRID SEARCH - NUMBER OF TREES)
% Find the optimal number of trees (Ensemble Size).
% - Too few: High Variance (Unstable).
% - Too many: Diminishing returns, slow training.
% METHOD: Use Out-of-Bag (OOB) Error (Lecture Slide 16).
% The OOB samples act as an internal validation set, so we don't need K-Fold CV.

fprintf('\n--- TUNING NUMBER OF TREES (GRID SEARCH) ---\n');

% Test a wide range with good granularity (Steps of 25)
num_trees_grid = [50, 75, 100, 125, 150, 175, 200]; 
oob_errors = zeros(length(num_trees_grid), 1);

tic; % Start timer
for i = 1:length(num_trees_grid)
    n_trees = num_trees_grid(i);
    
    % Train Random Forest
    % 'Method': classification
    % 'OOBPrediction': 'on' (Calculates error on leftover data)
    rf_temp = TreeBagger(n_trees, XTrain, YTrain, ...
        'Method', 'classification', ...
        'OOBPrediction', 'on');
    
    % Get the final OOB Error (Last value in the error curve)
    oob_errors(i) = oobError(rf_temp, 'Mode', 'ensemble');
    
    fprintf('  Tested Trees: %3d | OOB Error: %.4f\n', n_trees, oob_errors(i));
end
tune_time = toc;

% Find Optimal Number of Trees (Lowest Error)
[min_err, idx] = min(oob_errors);
best_n_trees = num_trees_grid(idx);

fprintf('OPTIMAL RESULT: Best Number of Trees is %d (Found in %.2f sec)\n', ...
    best_n_trees, tune_time);

% Visualise OOB Error Curve 
figure('Name', 'RF Optimization', 'Color', 'w');
plot(num_trees_grid, oob_errors, 'b-o', 'LineWidth', 2);
xlabel('Number of Trees'); ylabel('OOB Error Rate');
title(sprintf('Random Forest Tuning (Optimal: %d Trees)', best_n_trees));
grid on; hold on;

% Highlight the optimal point
plot(best_n_trees, min_err, 'r*', 'MarkerSize', 15);
legend('OOB Error Curve', 'Optimal Point');

%% 6.3 TRAIN FINAL RANDOM FOREST
% Train the "champion" model using the optimal tree count.
% Enable 'OOBPredictorImportance' to answer the question: "Which features matter?"

fprintf('\n--- TRAINING FINAL RANDOM FOREST (%d Trees) ---\n', best_n_trees);

tic;
% Train final model
mdl_RF = TreeBagger(best_n_trees, XTrain, YTrain, ...
    'Method', 'classification', ...
    'OOBPrediction', 'on', ...
    'OOBPredictorImportance', 'on'); % Required for feature importance
time_rf = toc;

% Evaluate on TRAINING set (check for overfitting)
% RF usually has high training accuracy (~100%), but OOB Error is the real validation.
preds_Train_RF = predict(mdl_RF, XTrain);
preds_Train_RF = categorical(preds_Train_RF); 
acc_Train_RF = sum(preds_Train_RF == YTrain) / length(YTrain);

% Evaluate on TEST set (unseen data)
% Get labels and scores for AUC
[preds_RF_cell, scores_RF] = predict(mdl_RF, XTest);
preds_RF = categorical(preds_RF_cell);

% Calculate Accuracy
acc_RF = sum(preds_RF == YTest) / length(YTest);

% Calculate Precision, Recall, F1
cmRF = confusionmat(YTest, preds_RF);
prec_RF = cmRF(2,2) / (cmRF(2,2) + cmRF(1,2));
rec_RF  = cmRF(2,2) / (cmRF(2,2) + cmRF(2,1));
f1_RF   = 2 * (prec_RF * rec_RF) / (prec_RF + rec_RF);

if isnan(f1_RF), f1_RF = 0; end

% Calculate AUC (Area Under Curve) AND Curve Points
% 'Xroc_RF' and 'Yroc_RF' are needed for the plot in Section 6.6
[Xroc_RF, Yroc_RF, ~, auc_RF] = perfcurve(YTest, scores_RF(:,2), '1');

% Display results
fprintf('RANDOM FOREST METRICS:\n');
fprintf('  Training Time:     %.4f sec\n', time_rf);
fprintf('  Training Accuracy: %.2f%%\n', acc_Train_RF * 100);
fprintf('  Testing Accuracy:  %.2f%%\n', acc_RF * 100);
fprintf('  F1-Score:          %.4f\n', f1_RF);
fprintf('  AUC:               %.4f\n', auc_RF);

%% 6.4 VISUALISATION: CONFUSION MATRIX
figure('Name', 'RF Performance', 'Color', 'w', 'Position', [100, 100, 600, 500]);
cm = confusionchart(YTest, preds_RF);
cm.Title = sprintf('Random Forest (Trees: %d, F1: %.2f)', best_n_trees, f1_RF);
cm.RowSummary = 'row-normalized'; 

%% 6.5 VISUALISATION: FEATURE IMPORTANCE
% This graph answers "Which chemicals drive the decision?"
fprintf('\n--- GENERATING FEATURE IMPORTANCE ---\n');

imp_RF = mdl_RF.OOBPermutedPredictorDeltaError;
[sorted_imp, idx] = sort(imp_RF, 'descend');
varNames = data.Properties.VariableNames(1:end-1);

figure('Name', 'RF Feature Importance', 'Color', 'w');
bar(sorted_imp, 'FaceColor', '#77AC30'); % Green for "Solution"
xticks(1:length(imp_RF));
xticklabels(varNames(idx));
xtickangle(45);
ylabel('Importance (OOB Delta Error)');
title('Random Forest Feature Importance');
grid on;

%% 6.6 VISUALISATION: ROC CURVE
figure('Name', 'ROC Curve', 'Color', 'w');
plot(Xroc_RF, Yroc_RF, 'LineWidth', 2, 'Color', '#77AC30'); 
xlabel('False Positive Rate'); ylabel('True Positive Rate');
title(sprintf('Random Forest ROC Curve (AUC = %.2f)', auc_RF));
grid on; hold on;
plot([0 1], [0 1], 'k--'); 
legend('Random Forest', 'Random Guess', 'Location', 'SouthEast');

%% 6.7 FINAL RESULTS SAVING
Results_RF = table(best_n_trees, time_rf, acc_RF, f1_RF, auc_RF, ...
    'VariableNames', {'Num_Trees', 'Train_Time', 'Test_Accuracy', 'F1_Score', 'AUC'});

disp(Results_RF);
writetable(Results_RF, 'RF_Final_Results.csv');

fprintf('Phase 6 Complete. Random Forest Optimized & Evaluated.\n');

%% PHASE 7: FINAL MODEL COMPARISON (DT vs RF)
% Compare the Single Optimized Tree against the Random Forest.
% Quantitatively prove that the Ensemble method (RF) 
% outperforms the Single Learner (DT) in terms of AUC and F1-Score,
% but we also highlight the trade-off in Training Time and Complexity.

fprintf('\n--- GENERATING FINAL COMPARISON (DT vs RF) ---\n');

%% 7.1 RE-CALCULATE METRICS (SAFETY CHECK)
% Ensure to have the latest ROC points for both models before plotting.

% Optimized Decision Tree Metrics
[~, scores_DT] = predict(mdl_Opt, XTest);
[X_DT, Y_DT, ~, auc_DT] = perfcurve(YTest, scores_DT(:,2), '1');

% Random Forest Metrics
[~, scores_RF] = predict(mdl_RF, XTest);
[X_RF, Y_RF, ~, auc_RF] = perfcurve(YTest, scores_RF(:,2), '1');


%% 7.2 MASTER COMPARISON TABLE
% Aggregate ALL key metrics into one table for the "Results" section.

Model_Name = {'Decision Tree (Optimized)'; 'Random Forest (Ensemble)'};

% Training Time (Computational Cost)
Train_Time = [time_opt; time_rf]; 

% Training Accuracy (Check for Memorisation/Overfitting)
Train_Acc  = [acc_Train_Opt; acc_Train_RF] * 100; 

% Testing Accuracy (Real-World Performance)
Test_Acc   = [acc_Opt; acc_RF] * 100;

% F1-Score (Balance for Imbalanced Data)
F1_Score   = [f1_Opt; f1_RF]; 

% AUC (Discriminative Power)
AUC        = [auc_DT; auc_RF];

% Create the Table
Final_Table = table(Train_Time, Train_Acc, Test_Acc, F1_Score, AUC, ...
    'RowNames', Model_Name, ...
    'VariableNames', {'Train_Time_Sec', 'Train_Accuracy', 'Test_Accuracy', 'F1_Score', 'AUC'});

disp('=== FINAL RESULTS ===');
disp(Final_Table);

%% 7.3 ROC CURVE COMPARISON
% This plot visually demonstrates the "Performance Gain".
% The RF line (Green) should be higher/smoother than the DT line (Blue).

figure('Name', 'Final ROC Comparison', 'Color', 'w');
hold on;

% Plot Decision Tree (Blue)
plot(X_DT, Y_DT, 'Color', '#0072BD', 'LineWidth', 2, ...
    'DisplayName', sprintf('Decision Tree (AUC=%.2f)', auc_DT));

% Plot Random Forest (Green)
plot(X_RF, Y_RF, 'Color', '#77AC30', 'LineWidth', 3, ...
    'DisplayName', sprintf('Random Forest (AUC=%.2f)', auc_RF));

% Plot Random Guess (Black Dashed)
plot([0 1], [0 1], 'k--', 'LineWidth', 1.5, 'DisplayName', 'Random Guess');

% Formatting
xlabel('False Positive Rate (1 - Specificity)'); 
ylabel('True Positive Rate (Sensitivity)');
title('Final Comparison: Single Tree vs Random Forest');
legend('Location', 'SouthEast');
grid on;
hold off;

fprintf('PROJECT COMPLETE.\n');
