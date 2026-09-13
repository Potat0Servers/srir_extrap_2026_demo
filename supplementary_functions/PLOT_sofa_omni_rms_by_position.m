%% Plot omni-channel RMS across all SOFA measurement positions

clear;
close all;
clc;

%% Paths and SOFA loading

script_dir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(script_dir, 'addpaths.m'));

sofa_file_name = 'roomToHallway_srcRoom_noLOS.sofa';
sofa_path = fullfile(script_dir, 'SOFAfiles', sofa_file_name);
fprintf('Loading %s\n', sofa_path);
sofa = SOFAload(sofa_path);

%% Calculate full-length omni RMS at every measurement position

n_measurements = size(sofa.Data.IR, 1);
measurement_indices = (1:n_measurements).';
omni_rms_linear = zeros(n_measurements, 1);
omni_rms_db = zeros(n_measurements, 1);

for measurement_idx = 1:n_measurements
    omni_ir = double(squeeze(sofa.Data.IR(measurement_idx,1,:)));
    omni_rms_linear(measurement_idx) = rms(omni_ir);
    omni_rms_db(measurement_idx) = amplitude_to_db(omni_rms_linear(measurement_idx));
end

clear sofa omni_ir

%% Plot RMS by measurement position

figure('Name', 'Omni RMS by position', 'NumberTitle', 'off');
plot(measurement_indices, omni_rms_db, '.-', 'LineWidth', 1.2, 'MarkerSize', 10);
xlabel('Measurement index');
ylabel('Omni RMS (dB re 1)');
title('Full-length omni-channel RMS by SOFA measurement position');
xlim([1 n_measurements]);
grid on
box on


function value_db = amplitude_to_db(value)

if value == 0
    value_db = -Inf;
else
    value_db = 20 * log10(abs(value));
end

end
