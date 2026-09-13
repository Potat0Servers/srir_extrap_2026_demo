%% Plot directional T60 across all SOFA measurement positions

clear;
clc;

%% User settings

sofa_file_name = 'roomToHallway_srcRoom_noLOS.sofa';
azimuth_degrees = (0:3:357).';
elevation_degrees = 0;
fit_range_db = [-5 -55];

%% Paths and SOFA loading

script_dir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(script_dir, 'addpaths.m'));

sofa_path = fullfile(script_dir, 'SOFAfiles', sofa_file_name);
fprintf('Loading %s\n', sofa_path);
sofa = SOFAload(sofa_path);

%% Directional steering setup

fs = double(sofa.Data.SamplingRate(1));
n_measurements = size(sofa.Data.IR, 1);
n_channels = size(sofa.Data.IR, 2);
n_samples = size(sofa.Data.IR, 3);
ambisonic_order = sqrt(n_channels) - 1;

n_directions = numel(azimuth_degrees);
beamforming_directions = [azimuth_degrees, elevation_degrees * ones(n_directions, 1)];
steering_matrix = getRSH(ambisonic_order, beamforming_directions);
steering_matrix = steering_matrix ./ max(vecnorm(steering_matrix, 2, 1), eps);
time_vector = (0:n_samples-1) / fs;

%% Calculate directional T60 at every position

measurement_indices = 1:n_measurements;
directional_t60 = nan(n_directions, n_measurements);

for measurement_idx = 1:n_measurements
    fprintf('Calculating directional T60 for measurement %d/%d...\n', measurement_idx, n_measurements);
    srir_sn3d = double(squeeze(sofa.Data.IR(measurement_idx,:,:))).';
    srir_n3d = convert_N3D_SN3D(srir_sn3d, 'sn2n');
    directional_ir = srir_n3d * steering_matrix;
    edc_linear = flip(cumsum(flip(abs(directional_ir).^2, 1), 1), 1);
    edc_reference = max(edc_linear(1,:), eps);
    edc_db = 10 * log10(max(edc_linear ./ edc_reference, eps));

    for direction_idx = 1:n_directions
        [t60_s, ~, success] = fit_decay_range( ...
            edc_db(:,direction_idx).', ...
            time_vector, ...
            fit_range_db(1), ...
            fit_range_db(2));

        if success
            directional_t60(direction_idx,measurement_idx) = t60_s;
        end
    end
end

clear sofa srir_sn3d srir_n3d directional_ir edc_linear edc_reference edc_db

valid_t60_count = nnz(isfinite(directional_t60));
fprintf('Calculated %d/%d valid directional T60 values.\n', valid_t60_count, numel(directional_t60));

%% Plot one directional T60 waterfall

finite_t60 = directional_t60(isfinite(directional_t60));

plot_limits_s = [min(finite_t60), max(finite_t60)];
if plot_limits_s(1) == plot_limits_s(2)
    plot_padding_s = max(0.01 * abs(plot_limits_s(1)), eps);
    plot_limits_s = plot_limits_s + [-plot_padding_s, plot_padding_s];
end

figure('Name', 'Directional T60 waterfall', 'NumberTitle', 'off', 'Color', 'w');
surf(measurement_indices, azimuth_degrees, directional_t60, 'EdgeColor', 'none');
hold on
for measurement_idx = 1:n_measurements
    plot3( ...
        measurement_idx * ones(size(azimuth_degrees)), ...
        azimuth_degrees, ...
        directional_t60(:,measurement_idx), ...
        'k', ...
        'LineWidth', ...
        0.25);
end
hold off

shading interp
colormap(turbo)
colour_bar = colorbar;
ylabel(colour_bar, 'Directional T60 (s)');
xlabel('Measurement index');
ylabel('Azimuth (deg)');
zlabel('Directional T60 (s)');
title(sprintf('Horizontal directional T60 | %g to %g dB fit | elevation %d%c | order %d', fit_range_db(1), fit_range_db(2), elevation_degrees, char(176), ambisonic_order));
xlim([measurement_indices(1) measurement_indices(end)]);
ylim([azimuth_degrees(1) azimuth_degrees(end)]);
zlim(plot_limits_s);
clim(plot_limits_s);
view(45, 30)
grid on
box on

%% T60 fitting

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
