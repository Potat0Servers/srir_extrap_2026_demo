%% Plot directional T60 heatmaps for selected SOFA measurements

clear;
close all;
clc;

%% User settings

measurement_indices = [1 35 45 50 60 100];
sofa_file_name = 'roomToHallway_srcRoom_noLOS.sofa';
degree_resolution = 5;
direction_block_size = 128;
fit_range_db = [-5 -55];

%% Paths and SOFA loading

script_dir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(script_dir, 'addpaths.m'));

sofa_path = fullfile(script_dir, 'SOFAfiles', sofa_file_name);
fprintf('Loading %s\n', sofa_path);
sofa = SOFAload(sofa_path);
fs = double(sofa.Data.SamplingRate(1));
n_measurements = size(sofa.Data.IR, 1);

%% Calculate directional T60 maps

n_selected_measurements = numel(measurement_indices);
t60_maps = cell(n_selected_measurements, 1);
grid_dirs = [];

for selection_idx = 1:n_selected_measurements
    measurement_idx = measurement_indices(selection_idx);
    fprintf('Calculating directional T60 for measurement %d...\n', measurement_idx);
    srir_sn3d = double(squeeze(sofa.Data.IR(measurement_idx,:,:))).';

    [t60_maps{selection_idx}, current_grid_dirs] = calculate_directional_t60_map( ...
        srir_sn3d, ...
        fs, ...
        degree_resolution, ...
        direction_block_size, ...
        fit_range_db);

    if isempty(grid_dirs)
        grid_dirs = current_grid_dirs;
    end

    fprintf( ...
        'Measurement %d: %d/%d valid directional T60 values.\n', ...
        measurement_idx, ...
        nnz(isfinite(t60_maps{selection_idx})), ...
        numel(t60_maps{selection_idx}));
end

clear sofa srir_sn3d current_grid_dirs

%% Determine a shared colour scale

all_t60_values = vertcat(t60_maps{:});
finite_t60_values = all_t60_values(isfinite(all_t60_values));
common_colour_limits = [min(finite_t60_values), max(finite_t60_values)];
if common_colour_limits(1) == common_colour_limits(2)
    colour_padding = max(0.01 * abs(common_colour_limits(1)), eps);
    common_colour_limits = common_colour_limits + [-colour_padding, colour_padding];
end

%% Plot T60 heatmaps

for selection_idx = 1:n_selected_measurements
    measurement_idx = measurement_indices(selection_idx);
    figure_name = sprintf('Measurement %d T60 heatmap', measurement_idx);
    figure('Name', figure_name, 'NumberTitle', 'off');
    heatmap_plot_hammer( ...
        rad2deg(grid_dirs(:,1)), ...
        rad2deg(grid_dirs(:,2)), ...
        t60_maps{selection_idx});
    colormap(flipud(bone));
    set(gca, 'FontSize', 11);
    colour_bar = colorbar;
    xlabel(colour_bar, 'T60 (s)');
    title(sprintf('Measurement %d', measurement_idx));

    if ~isempty(common_colour_limits)
        clim(common_colour_limits);
    end
end


%% Directional T60 analysis

function [t60_map, grid_dirs] = calculate_directional_t60_map( ...
    srir_sn3d, ...
    fs, ...
    degree_resolution, ...
    direction_block_size, ...
    fit_range_db)

n_channels = size(srir_sn3d, 2);
ambisonic_order = sqrt(n_channels) - 1;

grid_dirs = grid2dirs(degree_resolution, degree_resolution, 0, 0);
grid_dirs_degrees = rad2deg(grid_dirs);
steering_matrix = getRSH(ambisonic_order, grid_dirs_degrees);
steering_matrix = steering_matrix ./ max(vecnorm(steering_matrix, 2, 1), eps);

srir_n3d = convert_N3D_SN3D(srir_sn3d, 'sn2n');
n_directions = size(grid_dirs, 1);
t60_map = nan(n_directions, 1);
time_vector = (0:size(srir_n3d, 1)-1) / fs;

for block_start = 1:direction_block_size:n_directions
    block_end = min(block_start + direction_block_size - 1, n_directions);
    directional_ir_block = srir_n3d * steering_matrix(:,block_start:block_end);
    edc_linear_block = flip(cumsum(flip(abs(directional_ir_block).^2, 1), 1), 1);
    edc_reference = max(edc_linear_block(1,:), eps);
    edc_db_block = 10 * log10(max(edc_linear_block ./ edc_reference, eps));

    for block_idx = 1:size(edc_db_block, 2)
        [t60_s, ~, success] = fit_decay_range( ...
            edc_db_block(:,block_idx).', ...
            time_vector, ...
            fit_range_db(1), ...
            fit_range_db(2));

        if success
            direction_idx = block_start + block_idx - 1;
            t60_map(direction_idx) = t60_s;
        end
    end
end

end


function [t60_s, fit_r2, success] = fit_decay_range( ...
    edc_db, ...
    time_vector, ...
    upper_db, ...
    lower_db)

fit_start = find(edc_db <= upper_db, 1, 'first');
fit_end = find(edc_db <= lower_db, 1, 'first');
success = ~isempty(fit_start) && ~isempty(fit_end) && fit_end > fit_start && (fit_end - fit_start + 1) >= 50;

if ~success
    t60_s = NaN;
    fit_r2 = NaN;
    return
end

fit_indices = fit_start:fit_end;
fit_time = time_vector(fit_indices);
fit_level = edc_db(fit_indices);
coefficients = polyfit(fit_time, fit_level, 1);
fitted_level = polyval(coefficients, fit_time);

residual_sum_squares = sum((fit_level - fitted_level).^2);
total_sum_squares = sum((fit_level - mean(fit_level)).^2);
fit_r2 = 1 - residual_sum_squares / max(total_sum_squares, eps);

success = coefficients(1) < 0 && isfinite(fit_r2);
if success
    t60_s = -60 / coefficients(1);
else
    t60_s = NaN;
    fit_r2 = NaN;
end

end
