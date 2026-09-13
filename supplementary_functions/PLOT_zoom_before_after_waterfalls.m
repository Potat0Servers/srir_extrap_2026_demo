clearvars;
clc;

%% User settings

measurementIndex = 30;
N = 4;
zoomDepth = 1;
azimuthDegrees = 0:3:357;
elevationDegrees = 0;
edcPlotRangeDb = [-80 0];

%% Load SOFA file

scriptDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(scriptDir, 'addpaths.m'));

sofaFile = fullfile(scriptDir, 'SOFAfiles', 'roomToHallway_srcRoom_noLOS.sofa');
fprintf('Loading %s\n', sofaFile);
sofa = SOFAload(sofaFile);

sampleRate = double(sofa.Data.SamplingRate(1));
srirSn3d = double(squeeze(sofa.Data.IR(measurementIndex, :, :))).';

%% Zoom toward +X

coordChange = [zoomDepth 0 0];
[srirZoomSn3d, ~, ~] = zooming(srirSn3d, N, coordChange);

%% Plot before and after zoom

beforeTitle = sprintf('Before zoom | measurement %d', measurementIndex);
all_direction_beamform_waterfall( ...
    srirSn3d, ...
    sampleRate, ...
    azimuthDegrees, ...
    elevationDegrees, ...
    edcPlotRangeDb, ...
    beforeTitle);

afterTitle = sprintf('After +X zoom %.2f | measurement %d', zoomDepth, measurementIndex);
all_direction_beamform_waterfall( ...
    srirZoomSn3d, ...
    sampleRate, ...
    azimuthDegrees, ...
    elevationDegrees, ...
    edcPlotRangeDb, ...
    afterTitle);
