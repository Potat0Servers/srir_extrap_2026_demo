%% Plot target-sweep evaluation results from the saved CSV file

clearvars;
close all;
clc;


%% Load the saved results

project_root = fileparts(fileparts(mfilename('fullpath')));
results_dir = fullfile(project_root, 'Results', 'target_sweep_from_position_75');
results_csv = fullfile(project_root, 'Results', 'semi_full_experiment_18_08_2026.csv');

if ~isfolder(results_dir)
    mkdir(results_dir);
end

results = readtable(results_csv);
results = sortrows(results(results.OriginalIndex == 75, :), 'TargetIndex');
target_indices = results.TargetIndex;

results.Baseline_RMS_AbsError_dB = abs(results.Baseline_RMS_dB - results.Target_RMS_dB);
results.Proposed_RMS_AbsError_dB = abs(results.Proposed_RMS_dB - results.Target_RMS_dB);
results.Baseline_T60_AbsError_s = abs(results.Baseline_T60_s - results.Target_T60_s);
results.Proposed_T60_AbsError_s = abs(results.Proposed_T60_s - results.Target_T60_s);


%% Define the four target-relative metrics

metric_specs = {
    'Baseline_RMS_AbsError_dB', 'Proposed_RMS_AbsError_dB', 'Absolute RMS error (dB)', 'RMS error across target receiver positions', 'rms_absolute_error';
    'Baseline_T60_AbsError_s', 'Proposed_T60_AbsError_s', 'Absolute T60 error (s)', 'T60 error across target receiver positions', 't60_absolute_error';
    'Baseline_PBC2ToTarget', 'Proposed_PBC2ToTarget', 'PBC-2 to target', 'PBC-2 across target receiver positions', 'pbc2_to_target';
    'Baseline_EDCSimilarityRMSE_dB', 'Proposed_EDCSimilarityRMSE_dB', 'EDC similarity RMSE (dB)', 'EDC similarity across target receiver positions', 'edc_similarity_rmse_to_target'
};


%% Plot and save each metric

for metric_idx = 1:size(metric_specs, 1)
    baseline_values = results.(metric_specs{metric_idx, 1});
    proposed_values = results.(metric_specs{metric_idx, 2});
    y_label_text = metric_specs{metric_idx, 3};
    figure_title = metric_specs{metric_idx, 4};
    output_stem = metric_specs{metric_idx, 5};

    figure_handle = figure('Name', figure_title, 'NumberTitle', 'off', 'Color', 'w');
    plot(target_indices, baseline_values, 'LineWidth', 1.4);
    hold on;
    plot(target_indices, proposed_values, 'LineWidth', 1.4);
    xline( ...
        50.5, ...
        '--k', ...
        'Room 1 / Room 2', ...
        'LabelVerticalAlignment', ...
        'bottom', ...
        'LabelHorizontalAlignment', ...
        'center');
    hold off;

    xlabel('Target receiver index');
    ylabel(y_label_text);
    title(figure_title);
    legend('Baseline', 'Proposed', 'Location', 'best');
    xlim([target_indices(1), target_indices(end)]);
    grid on;
    box on;

    savefig(figure_handle, fullfile(results_dir, [output_stem '.fig']));
    print(figure_handle, fullfile(results_dir, [output_stem '.png']), '-dpng', '-r300');
end

fprintf('Created four target-sweep comparison figures from %s\n', results_csv);
