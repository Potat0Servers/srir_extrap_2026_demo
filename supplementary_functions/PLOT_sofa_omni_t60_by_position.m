
clearvars;
clc;

%% 初始化

scriptDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(scriptDir, 'addpaths.m'));

%% 读入同一个 SOFA

sofaFile = fullfile( ...
    scriptDir, ...
    'SOFAfiles', ...
    'roomToHallway_srcRoom_noLOS.sofa');

fprintf('Loading %s\n', sofaFile);
sofa = SOFAload(sofaFile);

fs = double(sofa.Data.SamplingRate);
fs = fs(1);
num_measurements = size(sofa.Data.IR, 1);

%% 逐测点计算 omni T60

measurement_indices = (1:num_measurements).';
t60_values = zeros(num_measurements, 1);
fit_range_db = [-5 -55];

for measurement_idx = 1:num_measurements
    omni_ir = double(squeeze(sofa.Data.IR(measurement_idx, 1, :)));
    [~, edc_db, time_vector] = compute_omni_energy_decay_from_ir(omni_ir, fs);

    % 用指定 dB 区间的衰减斜率外推 T60。
    fit_indices = edc_db <= fit_range_db(1) & edc_db >= fit_range_db(2);
    fit_coefficients = polyfit(time_vector(fit_indices), edc_db(fit_indices), 1);
    t60_values(measurement_idx) = -60 / fit_coefficients(1);
end

%% 画 101 个测点的变化

figure('Name', 'Omni T60 by position', 'NumberTitle', 'off');
plot(measurement_indices, t60_values, '.-', 'LineWidth', 1.2, 'MarkerSize', 10);
xlabel('Measurement index');
ylabel('T60 (s)');
title(sprintf('Omni-channel T60 by measurement position (%g to %g dB fit)', fit_range_db(1), fit_range_db(2)));
xlim([1 num_measurements]);
grid on
box on
