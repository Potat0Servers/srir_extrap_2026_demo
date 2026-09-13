%% Compare the omni-channel EDCs at measurement positions 1 and 100

clearvars;
close all;
clc;

%% User settings

sofa_file_name = 'roomToHallway_srcRoom_noLOS.sofa';
measurement_indices_to_plot = [1 100];
omni_channel_index = 1;
plot_floor_db = -80;

%% Paths and SOFA loading

script_dir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(script_dir, 'addpaths.m'));

sofa_path = fullfile(script_dir, 'SOFAfiles', sofa_file_name);
fprintf('Loading %s\n', sofa_path);
sofa = SOFAload(sofa_path);

%% Compute globally normalised omni-channel EDCs

fs = double(sofa.Data.SamplingRate(1));
omni_ir = double(squeeze(sofa.Data.IR(:,omni_channel_index,:)));
n_measurements = size(omni_ir, 1);
n_samples = size(omni_ir, 2);

initial_energy = sum(abs(omni_ir).^2, 2);
common_edc_reference = max(max(initial_energy), eps);
n_curves = numel(measurement_indices_to_plot);
edc_db = zeros(n_curves, n_samples);

for curve_index = 1:n_curves
    measurement_index = measurement_indices_to_plot(curve_index);
    [edc_linear, ~, time_seconds] = compute_omni_energy_decay_from_ir(omni_ir(measurement_index,:), fs);
    edc_db(curve_index,:) = 10 * log10(max(edc_linear / common_edc_reference, eps));
end

clear sofa omni_ir edc_linear initial_energy

%% Plot the two decay curves

figure('Name', 'Omni EDC positions 1 and 100', 'NumberTitle', 'off', 'Color', 'w');
plot(time_seconds, edc_db(1,:), 'LineWidth', 1.5);
hold on
plot(time_seconds, edc_db(2,:), 'LineWidth', 1.5);
hold off

xlabel('Time (s)');
ylabel('Globally normalised EDC (dB)');
title('Omni-channel EDC comparison at measurement positions 1 and 100');
legend('Position 1 (smaller room)', 'Position 100 (larger room)', 'Location', 'southwest');
xlim([time_seconds(1) time_seconds(end)]);
ylim([plot_floor_db 0]);
grid on
box on
