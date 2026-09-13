function all_direction_beamform_waterfall( ...
    srirSn3d, ...
    sampleRate, ...
    azimuthDegrees, ...
    elevationDegrees, ...
    edcPlotRangeDb, ...
    figureTitle)

[numSamples, numChannels] = size(srirSn3d);

ambisonicOrder = sqrt(numChannels) - 1;
numDirections = numel(azimuthDegrees);
beamformingDirections = [azimuthDegrees(:), elevationDegrees * ones(numDirections, 1)];
steeringMatrix = getRSH(ambisonicOrder, beamformingDirections);
steeringMatrix = steeringMatrix ./ vecnorm(steeringMatrix, 2, 1);

srirN3d = convert_N3D_SN3D(srirSn3d, 'sn2n');
beamformedIrs = srirN3d * steeringMatrix;

edcDb = zeros(numSamples, numDirections);
for directionIndex = 1:numDirections
    [~, edcCurrentDb, timeSeconds] = compute_omni_energy_decay_from_ir(beamformedIrs(:, directionIndex), sampleRate);
    edcDb(:, directionIndex) = edcCurrentDb.';
end

numPlotTimePoints = min(3000, numSamples);
plotIndices = unique(round(linspace(1, numSamples, numPlotTimePoints)));
plotTimeSeconds = timeSeconds(plotIndices);
plotEdcDb = edcDb(plotIndices, :).';

figure('Name', figureTitle, 'NumberTitle', 'off', 'Color', 'w');
surf(plotTimeSeconds, azimuthDegrees, plotEdcDb, 'EdgeColor', 'none');
hold on;
for directionIndex = 1:numDirections
    directionAxis = azimuthDegrees(directionIndex) * ones(size(plotTimeSeconds));
    plot3( ...
        plotTimeSeconds, ...
        directionAxis, ...
        plotEdcDb(directionIndex, :), ...
        'k', ...
        'LineWidth', ...
        0.25);
end

shading interp;
colormap(turbo);
colorbar;
xlabel('Time (s)');
ylabel('Azimuth (deg)');
zlabel('Normalized EDC (dB)');
title(sprintf('%s | elevation %d%c | order %d', figureTitle, elevationDegrees, char(176), ambisonicOrder));
xlim([timeSeconds(1) timeSeconds(end)]);
ylim([azimuthDegrees(1) azimuthDegrees(end)]);
zlim(edcPlotRangeDb);
clim(edcPlotRangeDb);
view(45, 30);
grid on;
box on;

end
