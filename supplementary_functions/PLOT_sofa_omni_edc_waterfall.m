clearvars;
clc;

%% Load SOFA file

scriptDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(scriptDir, 'addpaths.m'));

sofaFile = fullfile(scriptDir, 'SOFAfiles', 'roomToHallway_srcRoom_noLOS.sofa');
fprintf('Loading %s\n', sofaFile);
sofa = SOFAload(sofaFile);

%% Compute globally normalised omni EDCs

fs = double(sofa.Data.SamplingRate(1));
omniIr = double(squeeze(sofa.Data.IR(:,1,:)));
numMeasurements = size(omniIr, 1);
numSamples = size(omniIr, 2);
measurementIndices = (1:numMeasurements).';
timeSeconds = (0:numSamples-1) / fs;

initialEnergy = sum(abs(omniIr).^2, 2);
commonEdcReference = max(max(initialEnergy), eps);
edcDb = zeros(numMeasurements, numSamples);

for measurementIndex = 1:numMeasurements
    [edcLinear, ~, ~] = compute_omni_energy_decay_from_ir(omniIr(measurementIndex,:), fs);
    edcDb(measurementIndex,:) = 10 * log10(max(edcLinear / commonEdcReference, eps));
end

clear sofa omniIr edcLinear initialEnergy

numPlotTimePoints = min(3000, numel(timeSeconds));
plotIndices = unique(round(linspace(1, numel(timeSeconds), numPlotTimePoints)));

%% Plot the EDC surface and measurement contours

figure('Name', 'Omni EDC surface', 'NumberTitle', 'off', 'Color', 'w');
surf(timeSeconds(plotIndices), measurementIndices, edcDb(:, plotIndices), 'EdgeColor', 'none');
hold on;
for measurementIndex = 1:numel(measurementIndices)
    plot3(timeSeconds(plotIndices), measurementIndices(measurementIndex) * ones(size(plotIndices)), edcDb(measurementIndex, plotIndices), 'k', 'LineWidth', 0.25);
end
shading interp;
colormap(turbo);
colorbar;
xlabel('Time (s)');
ylabel('Measurement index');
zlabel('Globally normalized EDC (dB)');
title('Globally normalized omni-channel EDC by measurement position');
xlim([timeSeconds(1) timeSeconds(end)]);
ylim([measurementIndices(1) measurementIndices(end)]);
zlim([-80 0]);
clim([-80 0]);
view(45, 30);
grid on;
box on;
