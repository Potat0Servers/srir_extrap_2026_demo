%% Compare Proposed results from six original receiver positions

clearvars;
close all;
clc;


%% Load the saved sweep results

project_root = fileparts(fileparts(mfilename('fullpath')));
output_dir = fullfile(project_root, 'Results', 'proposed_sweep_comparison_positions_1_20_40_60_80_100');
results_csv = fullfile(project_root, 'Results', 'semi_full_experiment_18_08_2026.csv');
original_indices = [1 20 40 60 80 100];
target_indices = (1:101)';

if ~isfolder(output_dir)
    mkdir(output_dir);
end

results = readtable(results_csv);
results = results(ismember(results.OriginalIndex, original_indices), :);

results.Proposed_RMS_AbsError_dB = abs(results.Proposed_RMS_dB - results.Target_RMS_dB);
results.Proposed_T60_AbsError_s = abs(results.Proposed_T60_s - results.Target_T60_s);


%% Define the four target-relative metrics

metric_specs = {
    'Proposed_RMS_AbsError_dB', 'Absolute RMS error (dB)', 'Proposed RMS error across target receiver positions', 'proposed_rms_absolute_error';
    'Proposed_T60_AbsError_s', 'Absolute T60 error (s)', 'Proposed T60 error across target receiver positions', 'proposed_t60_absolute_error';
    'Proposed_PBC2ToTarget', 'PBC-2 to target', 'Proposed PBC-2 across target receiver positions', 'proposed_pbc2_to_target';
    'Proposed_EDCSimilarityRMSE_dB', 'EDC similarity RMSE (dB)', 'Proposed EDC similarity across target receiver positions', 'proposed_edc_similarity_rmse_to_target'
};

line_colours = lines(numel(original_indices));


%% Plot and save each metric

for metric_idx = 1:size(metric_specs, 1)
    metric_variable = metric_specs{metric_idx, 1};
    y_label_text = metric_specs{metric_idx, 2};
    figure_title = metric_specs{metric_idx, 3};
    output_stem = metric_specs{metric_idx, 4};

    figure_handle = figure('Name', figure_title, 'NumberTitle', 'off', 'Color', 'w');
    hold on;

    for original_idx = 1:numel(original_indices)
        original_index = original_indices(original_idx);
        current_results = sortrows(results(results.OriginalIndex == original_index, :), 'TargetIndex');
        plot(current_results.TargetIndex, current_results.(metric_variable), 'Color', line_colours(original_idx,:), 'LineWidth', 1.4, 'DisplayName', sprintf('Original %d', original_index));
    end

    boundary_line = xline(50.5, '--k', 'Room 1 / Room 2', 'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'center');
    boundary_line.HandleVisibility = 'off';
    hold off;

    xlabel('Target receiver index');
    ylabel(y_label_text);
    title(figure_title);
    legend('Location', 'best');
    xlim([target_indices(1), target_indices(end)]);
    grid on;
    box on;

    savefig(figure_handle, fullfile(output_dir, [output_stem '.fig']));
    print(figure_handle, fullfile(output_dir, [output_stem '.png']), '-dpng', '-r300');
end

fprintf('Created four six-curve sweep figures in %s\n', output_dir);
