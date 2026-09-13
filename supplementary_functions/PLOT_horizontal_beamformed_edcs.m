%% Plot horizontal beamformed energy decay curves from multiple SOFA positions

clear;
close all;
clc;

%% User settings

measurementIndices = 1:10:101; % 支持数组输入；当前选择测点 1, 11, ..., 101
sofaFileName = 'roomToHallway_srcRoom_noLOS.sofa';
azimuthDegrees = 0:3:357;
elevationDegrees = 0;
edcPlotRangeDb = [-80 0];

%% Paths and SOFA loading

scriptDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(scriptDir, 'addpaths.m'));

sofaPath = fullfile(scriptDir, 'SOFAfiles', sofaFileName);
fprintf('Loading %s\n', sofaPath);
sofa = SOFAload(sofaPath);
sampleRate = double(sofa.Data.SamplingRate(1));

%% Plot one all-direction waterfall for every selected position

for measurementIndex = measurementIndices
    srirSn3d = double(squeeze(sofa.Data.IR(measurementIndex, :, :))).';
    figureTitle = sprintf('Measurement %d', measurementIndex);
    all_direction_beamform_waterfall( ...
        srirSn3d, ...
        sampleRate, ...
        azimuthDegrees, ...
        elevationDegrees, ...
        edcPlotRangeDb, ...
        figureTitle);
end

clear sofa;
