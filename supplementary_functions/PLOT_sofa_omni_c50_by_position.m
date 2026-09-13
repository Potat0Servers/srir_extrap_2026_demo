%% Plot omni-channel C50 across all SOFA measurement positions

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
fs = double(sofa.Data.SamplingRate(1));

%% Calculate omni C50 at every measurement position

n_measurements = size(sofa.Data.IR, 1);
measurement_indices = (1:n_measurements).';
direct_samples = zeros(n_measurements, 1);
omni_c50_db = zeros(n_measurements, 1);

for measurement_idx = 1:n_measurements
    omni_ir = double(squeeze(sofa.Data.IR(measurement_idx,1,:)));
    direct_samples(measurement_idx) = detect_direct_arrival(omni_ir, fs);
    omni_c50_db(measurement_idx) = calculate_c50( ...
        omni_ir, ...
        fs, ...
        direct_samples(measurement_idx));
end

clear sofa omni_ir

%% Plot C50 by measurement position

figure('Name', 'Omni C50 by position', 'NumberTitle', 'off');
plot(measurement_indices, omni_c50_db, '.-', 'LineWidth', 1.2, 'MarkerSize', 10);
xlabel('Measurement index');
ylabel('Omni C50 (dB)');
title('Omni-channel C50 by SOFA measurement position');
xlim([1 n_measurements]);
grid on
box on


function direct_sample = detect_direct_arrival(omni_ir, fs)

detection_signal = abs(lowpass(highpass(omni_ir, 700, fs), 5000, fs));
peak_value = max(detection_signal);
detection_signal = detection_signal / peak_value;

[~, peak_locations] = findpeaks( ...
    detection_signal, ...
    'MinPeakDistance', ...
    50, ...
    'MinPeakHeight', ...
    0.05);

if isempty(peak_locations)
    direct_sample = find(detection_signal >= 0.05, 1, 'first');
else
    direct_sample = peak_locations(1);
end

end


function c50_db = calculate_c50(omni_ir, fs, direct_sample)

split_sample = min( ...
    numel(omni_ir), ...
    direct_sample + round(0.050 * fs) - 1);

early_energy = sum(abs(omni_ir(direct_sample:split_sample)).^2);
late_energy = sum(abs(omni_ir(split_sample+1:end)).^2);
c50_db = energy_ratio_to_db(early_energy, late_energy);

end


function ratio_db = energy_ratio_to_db(numerator, denominator)

ratio_db = 10 * log10(max(numerator, eps) / max(denominator, eps));

end
