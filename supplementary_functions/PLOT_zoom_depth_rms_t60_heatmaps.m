%% Plot directional RMS and T60 heatmaps over +X zoom depth

clear;
clc;

%% User settings

measurement_index = 30;
N = 4;
zoom_depths = 0:0.5:4;
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

srir_sn3d = double(squeeze(sofa.Data.IR(measurement_index, :, :))).';
clear sofa

n_available_channels = size(srir_sn3d, 2);
available_order = sqrt(n_available_channels) - 1;

n_required_channels = (N + 1)^2;

%% Directional steering setup

grid_dirs = grid2dirs(degree_resolution, degree_resolution, 0, 0);
grid_dirs_degrees = rad2deg(grid_dirs);
steering_matrix = getRSH(N, grid_dirs_degrees);
steering_matrix = steering_matrix ./ max(vecnorm(steering_matrix, 2, 1), eps);

%% Calculate directional maps over +X zoom depth

n_zoom_depths = numel(zoom_depths);
rms_maps_db = cell(n_zoom_depths, 1);
t60_maps = cell(n_zoom_depths, 1);

for zoom_idx = 1:n_zoom_depths
    zoom_depth = zoom_depths(zoom_idx);
    coord_change = [zoom_depth 0 0];
    fprintf('Calculating maps for measurement %d at +X zoom depth %.1f...\n', measurement_index, zoom_depth);

    [srir_zoom_sn3d, ~, ~] = zooming(srir_sn3d, N, coord_change, false);
    srir_zoom_n3d = convert_N3D_SN3D(srir_zoom_sn3d, 'sn2n');
    rms_maps_db{zoom_idx} = calculate_directional_rms_map(srir_zoom_n3d, steering_matrix);
    t60_maps{zoom_idx} = calculate_directional_t60_map( ...
        srir_zoom_n3d, ...
        steering_matrix, ...
        fs, ...
        direction_block_size, ...
        fit_range_db);

    fprintf( ...
        'Zoom depth %.1f: %d/%d valid directional T60 values.\n', ...
        zoom_depth, ...
        nnz(isfinite(t60_maps{zoom_idx})), ...
        numel(t60_maps{zoom_idx}));
end

clear srir_sn3d srir_zoom_sn3d srir_zoom_n3d

%% Determine shared colour scales

all_rms_values_db = vertcat(rms_maps_db{:});
finite_rms_values_db = all_rms_values_db(isfinite(all_rms_values_db));
rms_colour_limits = [min(finite_rms_values_db), max(finite_rms_values_db)];
if rms_colour_limits(1) == rms_colour_limits(2)
    colour_padding_db = max(0.01 * abs(rms_colour_limits(1)), eps);
    rms_colour_limits = rms_colour_limits + [-colour_padding_db, colour_padding_db];
end

all_t60_values = vertcat(t60_maps{:});
finite_t60_values = all_t60_values(isfinite(all_t60_values));
t60_colour_limits = [min(finite_t60_values), max(finite_t60_values)];
if t60_colour_limits(1) == t60_colour_limits(2)
    colour_padding_s = max(0.01 * abs(t60_colour_limits(1)), eps);
    t60_colour_limits = t60_colour_limits + [-colour_padding_s, colour_padding_s];
end

%% Plot paired RMS and T60 heatmaps

for zoom_idx = 1:n_zoom_depths
    zoom_depth = zoom_depths(zoom_idx);
    figure_name = sprintf('Measurement %d | +X zoom depth %.1f', measurement_index, zoom_depth);
    figure('Name', figure_name, 'NumberTitle', 'off', 'Color', 'w');
    colormap(flipud(bone));

    subplot(1, 2, 1);
    heatmap_plot_hammer( ...
        grid_dirs_degrees(:,1), ...
        grid_dirs_degrees(:,2), ...
        rms_maps_db{zoom_idx});
    set(gca, 'FontSize', 11);
    rms_colour_bar = colorbar;
    xlabel(rms_colour_bar, 'Directional RMS (dB re 1)');
    title(sprintf('RMS | point %d | +X zoom %.1f', measurement_index, zoom_depth));
    if ~isempty(rms_colour_limits)
        clim(rms_colour_limits);
    end

    subplot(1, 2, 2);
    heatmap_plot_hammer( ...
        grid_dirs_degrees(:,1), ...
        grid_dirs_degrees(:,2), ...
        t60_maps{zoom_idx});
    set(gca, 'FontSize', 11);
    t60_colour_bar = colorbar;
    xlabel(t60_colour_bar, 'T60 (s)');
    title(sprintf('T60 | point %d | +X zoom %.1f', measurement_index, zoom_depth));
    if ~isempty(t60_colour_limits)
        clim(t60_colour_limits);
    end
end

fprintf('Created %d figures with paired directional RMS and T60 heatmaps.\n', n_zoom_depths);

%% Directional RMS analysis

function rms_map_db = calculate_directional_rms_map(srir_n3d, steering_matrix)

n_samples = size(srir_n3d, 1);
channel_mean_square = (srir_n3d' * srir_n3d) / n_samples;
directional_mean_square = real(sum(conj(steering_matrix) .* (channel_mean_square * steering_matrix), 1));
directional_rms = sqrt(max(directional_mean_square, 0)).';

rms_map_db = -inf(size(directional_rms));
positive_rms = directional_rms > 0;
rms_map_db(positive_rms) = 20 * log10(directional_rms(positive_rms));

end

%% Directional T60 analysis

function t60_map = calculate_directional_t60_map( ...
    srir_n3d, ...
    steering_matrix, ...
    fs, ...
    direction_block_size, ...
    fit_range_db)

n_directions = size(steering_matrix, 2);
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
