%% Plot SH-channel impulse responses grouped by spherical-harmonic order
% This script loads two SOFA files and plots response-vs-time traces for all
% channels. Channels are grouped by spherical-harmonic order using ACN
% ordering: order n contains channel indices n^2+1 through (n+1)^2.

clear;
close all;
clc;

%% User settings
measurementIndexByFile = [1 1]; % 两个值分别是两个 SOFA 文件要绘制的 measurement/测点编号：roomToHallway 可取 1-101，6DoF 可取 1-21。
normalizeEachChannel = false;
lineWidth = 0.8;
timeWindowSeconds = 0.3;

sofaFileNames = {
    'roomToHallway_srcRoom_noLOS.sofa'
    '6DoF_SRIRs_eigenmike_SH_50percent_absorbers_enabled.sofa'
};

%% Paths
scriptDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(scriptDir, 'addpaths.m'));

sofaDir = fullfile(scriptDir, 'SOFAfiles');

%% Load and plot each SOFA file
for fileIndex = 1:numel(sofaFileNames)
    sofaPath = fullfile(sofaDir, sofaFileNames{fileIndex});
    fprintf('Loading %s\n', sofaPath);
    sofa = SOFAload(sofaPath);

    ir = double(sofa.Data.IR);
    [numMeasurements, numChannels, numSamples] = size(ir);

    measurementIndex = measurementIndexByFile(fileIndex);

    sampleRate = double(sofa.Data.SamplingRate);
    sampleRate = sampleRate(1);
    numPlotSamples = min(numSamples, max(1, round(timeWindowSeconds * sampleRate)));
    timeSeconds = (0:(numPlotSamples - 1)).' ./ sampleRate;

    responses = squeeze(ir(measurementIndex, :, 1:numPlotSamples)).';
    if normalizeEachChannel
        channelPeaks = max(abs(responses), [], 1); %#ok<UNRCH>
        channelPeaks(channelPeaks == 0) = 1;
        responses = responses ./ channelPeaks;
    end

    plotSofaBySHOrder( ...
        responses, ...
        timeSeconds, ...
        sofaFileNames{fileIndex}, ...
        shortSofaLabel(sofaFileNames{fileIndex}), ...
        measurementIndex, ...
        lineWidth);
end

%% Local functions
function label = shortSofaLabel(sofaFileName)
    if contains(sofaFileName, 'roomToHallway', 'IgnoreCase', true)
        label = 'R2H';
    elseif contains(sofaFileName, '6DoF', 'IgnoreCase', true)
        label = '6DoF';
    else
        [~, label] = fileparts(sofaFileName);
    end
end

function plotSofaBySHOrder(responses, timeSeconds, sofaFileName, sofaLabel, measurementIndex, lineWidth)
    [~, numChannels] = size(responses);

    maxCompleteOrder = floor(sqrt(numChannels)) - 1;

    commonYLimit = makeSymmetricLimit(responses);
    escapedLabel = strrep(sofaLabel, '_', '\_');

    for order = 0:maxCompleteOrder
        channelIndices = (order^2 + 1):((order + 1)^2);
        plotOneOrder( ...
            responses(:, channelIndices), ...
            timeSeconds, ...
            channelIndices, ...
            order, ...
            escapedLabel, ...
            measurementIndex, ...
            commonYLimit, ...
            lineWidth);
    end

    remainingChannels = ((maxCompleteOrder + 1)^2 + 1):numChannels;
    if ~isempty(remainingChannels)
        plotOneOrder( ...
            responses(:, remainingChannels), ...
            timeSeconds, ...
            remainingChannels, ...
            NaN, ...
            escapedLabel, ...
            measurementIndex, ...
            commonYLimit, ...
            lineWidth);
    end
end

function plotOneOrder(orderResponses, timeSeconds, channelIndices, order, escapedSofaName, measurementIndex, yLimit, lineWidth)
    numOrderChannels = numel(channelIndices);
    [numRows, numCols] = subplotGrid(numOrderChannels);

    if isnan(order)
        orderLabel = 'rem';
        figureName = sprintf('%s rem', escapedSofaName);
    else
        orderLabel = sprintf('O%d', order);
        figureName = sprintf('%s O%d', escapedSofaName, order);
    end

    figure('Name', figureName, 'Color', 'w');
    tiledlayout(numRows, numCols, 'TileSpacing', 'compact', 'Padding', 'compact');

    for localChannel = 1:numOrderChannels
        channelIndex = channelIndices(localChannel);
        nexttile;
        plot(timeSeconds, orderResponses(:, localChannel), 'LineWidth', lineWidth);
        grid on;
        ylim(yLimit);
        title(sprintf('%d', channelIndex));
        xlabel('Time (s)');
        ylabel('Response');
    end

    sgtitle(sprintf('%s %s m%d', escapedSofaName, orderLabel, measurementIndex));
end

function [numRows, numCols] = subplotGrid(numPlots)
    numCols = ceil(sqrt(numPlots));
    numRows = ceil(numPlots / numCols);
end

function yLimit = makeSymmetricLimit(values)
    peak = max(abs(values), [], 'all');
    if peak == 0
        peak = 1;
    end

    yLimit = [-peak peak] .* 1.05;
end
