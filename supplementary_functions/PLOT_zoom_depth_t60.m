clearvars;

clc;

%% User settings

measurement_index = 30;
N = 4;
zoom_depths = -3:0.05:3;
fit_range_db = [-5 -55];

%% Load SOFA file

script_dir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(script_dir, 'addpaths.m'));

sofa_file = fullfile(script_dir, 'SOFAfiles', 'roomToHallway_srcRoom_noLOS.sofa');
fprintf('Loading %s\n', sofa_file);
sofa = SOFAload(sofa_file);

fs = double(sofa.Data.SamplingRate(1));
srir = double(squeeze(sofa.Data.IR(measurement_index, :, :))).';

%% Calculate T60 over +X zoom depth

t60_values = zeros(size(zoom_depths));
for zoom_idx = 1:numel(zoom_depths)
    coord_change = [zoom_depths(zoom_idx) 0 0];
    [srir_zoom, ~, ~] = zooming(srir, N, coord_change, false);
    [~, edc_db, time_vector] = compute_omni_energy_decay_from_ir(srir_zoom(:, 1), fs);
    fit_indices = edc_db <= fit_range_db(1) & edc_db >= fit_range_db(2);
    fit_coefficients = polyfit(time_vector(fit_indices), edc_db(fit_indices), 1);
    t60_values(zoom_idx) = -60 / fit_coefficients(1);
end

%% Plot T60 over zoom depth

figure('Name', 'Omni T60 over zoom depth', 'NumberTitle', 'off', 'Color', 'w');
plot(zoom_depths, t60_values, '.-', 'LineWidth', 1.2, 'MarkerSize', 10);
xlabel('Zoom depth (+X)');
ylabel('T60 (s)');
title(sprintf('Omni-channel T60 over +X zoom depth | measurement %d', measurement_index));
xlim([zoom_depths(1) zoom_depths(end)]);
grid on;
box on;
