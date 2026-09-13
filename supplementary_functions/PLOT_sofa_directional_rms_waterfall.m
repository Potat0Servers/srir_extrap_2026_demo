%% Plot directional RMS across all SOFA measurement positions

clear;
close all;
clc;

%% User settings

sofa_file_name = 'roomToHallway_srcRoom_noLOS.sofa';
azimuth_degrees = (0:3:357).';
elevation_degrees = 0;

%% Paths and SOFA loading

script_dir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(script_dir, 'addpaths.m'));

sofa_path = fullfile(script_dir, 'SOFAfiles', sofa_file_name);
fprintf('Loading %s\n', sofa_path);
sofa = SOFAload(sofa_path);

%% Directional steering setup

n_measurements = size(sofa.Data.IR, 1);
n_channels = size(sofa.Data.IR, 2);
n_samples = size(sofa.Data.IR, 3);
ambisonic_order = sqrt(n_channels) - 1;

n_directions = numel(azimuth_degrees);
beamforming_directions = [azimuth_degrees, elevation_degrees * ones(n_directions, 1)];
steering_matrix = getRSH(ambisonic_order, beamforming_directions);
steering_matrix = steering_matrix ./ max(vecnorm(steering_matrix, 2, 1), eps);

%% Calculate full-length directional RMS at every position

measurement_indices = 1:n_measurements;
directional_rms_linear = zeros(n_directions, n_measurements);

for measurement_idx = 1:n_measurements
    srir_sn3d = double(squeeze(sofa.Data.IR(measurement_idx,:,:))).';
    srir_n3d = convert_N3D_SN3D(srir_sn3d, 'sn2n');
    channel_mean_square = (srir_n3d' * srir_n3d) / n_samples;
    directional_mean_square = real(sum(conj(steering_matrix) .* (channel_mean_square * steering_matrix), 1));
    directional_rms_linear(:,measurement_idx) = sqrt(max(directional_mean_square, 0)).';
end

directional_rms_db = -inf(size(directional_rms_linear));
positive_rms = directional_rms_linear > 0;
directional_rms_db(positive_rms) = 20 * log10(directional_rms_linear(positive_rms));

clear sofa srir_sn3d srir_n3d channel_mean_square directional_mean_square

%% Plot one directional RMS waterfall

finite_rms_db = directional_rms_db(isfinite(directional_rms_db));
plot_limits_db = [min(finite_rms_db), max(finite_rms_db)];
if plot_limits_db(1) == plot_limits_db(2)
    plot_padding_db = max(0.01 * abs(plot_limits_db(1)), eps);
    plot_limits_db = plot_limits_db + [-plot_padding_db, plot_padding_db];
end

figure('Name', 'Directional RMS waterfall', 'NumberTitle', 'off', 'Color', 'w');
surf(measurement_indices, azimuth_degrees, directional_rms_db, 'EdgeColor', 'none');
hold on
for measurement_idx = 1:n_measurements
    plot3( ...
        measurement_idx * ones(size(azimuth_degrees)), ...
        azimuth_degrees, ...
        directional_rms_db(:,measurement_idx), ...
        'k', ...
        'LineWidth', ...
        0.25);
end
hold off

shading interp
colormap(turbo)
colour_bar = colorbar;
ylabel(colour_bar, 'Directional RMS (dB re 1)');
xlabel('Measurement index');
ylabel('Azimuth (deg)');
zlabel('Directional RMS (dB re 1)');
title(sprintf('Full-length horizontal directional RMS | elevation %d%c | order %d', elevation_degrees, char(176), ambisonic_order));
xlim([measurement_indices(1) measurement_indices(end)]);
ylim([azimuth_degrees(1) azimuth_degrees(end)]);
zlim(plot_limits_db);
clim(plot_limits_db);
view(45, 30)
grid on
box on
