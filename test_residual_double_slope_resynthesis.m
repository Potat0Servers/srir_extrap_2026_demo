

close all;
clearvars;
clc;

%% Initialisation

scriptDir = fileparts(mfilename('fullpath'));
run(fullfile(scriptDir, 'addpaths.m'));
load_ambisonic_configuration;
scriptDir = fileparts(mfilename('fullpath'));
close all;

%% Load the SRIR

sofaFile = fullfile( ...
    scriptDir, ...
    'SOFAfiles', ...
    'roomToHallway_srcRoom_noLOS.sofa');

if ~isfile(sofaFile)
    error('SOFA file not found: %s', sofaFile);
end

fprintf('Loading %s\n', sofaFile);
sofa_orig = SOFAload(sofaFile);

fs = double(sofa_orig.Data.SamplingRate);
fs = fs(1);

num_measurements = size(sofa_orig.Data.IR, 1);
num_channels = size(sofa_orig.Data.IR, 2);
num_samples = size(sofa_orig.Data.IR, 3);

fprintf( ...
    'Loaded %d measurements, %d channels, %d samples at %.0f Hz.\n', ...
    num_measurements, ...
    num_channels, ...
    num_samples, ...
    fs);



%% Experiment settings

% Start with measurement positions 1 and 100.
measurement_indices = [1 100];

% Treat the response after this time as late reverberation.
late_start_ms = 250;

% Use a 20 ms transition when splicing it back into the original SRIR.
crossfade_ms = 20;

% Change the decay only within this range; an empty limit uses that boundary.
scale_start_ms = 250;
scale_end_ms = [];

% Pull the original decay slope towards the target.
t60_orig = 1;
t60_target = 1.3;


%% Main processing: decorrelate first, then change the decay

processing_stage_names = ["Original", "Decorrelated", "Decay-scaled"];
num_processing_stages = numel(processing_stage_names);
num_responses = num_processing_stages * numel(measurement_indices);
late_start_sample = round(late_start_ms * 1e-3 * fs) + 1;
crossfade_length_samples = min( ...
    round(crossfade_ms * 1e-3 * fs), ...
    num_samples - late_start_sample + 1);

edc_linear = zeros(num_samples, num_responses);
response_names = strings(1, num_responses);
srir_stages_by_position = cell(numel(measurement_indices), num_processing_stages);

for position_idx = 1:numel(measurement_indices)
    measurement_idx = measurement_indices(position_idx);

    % SOFA stores measurement x channel x sample; convert it to sample x channel.
    srir = double(squeeze(sofa_orig.Data.IR(measurement_idx, :, :))).';
    late_srir = srir(late_start_sample:end,:);

    % First make a late tail with a different waveform.
    late_decorrelated = decorrelate_residual(late_srir, fs);

    % Splice the tail back while keeping the part before the late start unchanged.
    srir_decorrelated = splice_processed_late_tail( ...
        srir, ...
        late_decorrelated, ...
        late_start_sample, ...
        crossfade_length_samples);

    % Then change T60 over the selected range of the full SRIR.
    srir_decay_scaled = scale_srir_decay( ...
        srir_decorrelated, ...
        fs, ...
        t60_orig, ...
        t60_target, ...
        scale_start_ms, ...
        scale_end_ms);

    % Keep the original, decorrelated, and T60-adjusted response at each position.
    srir_stages = {srir, srir_decorrelated, srir_decay_scaled};
    srir_stages_by_position(position_idx,:) = srir_stages;

    for stage_idx = 1:num_processing_stages
        response_idx = (position_idx - 1) * num_processing_stages + stage_idx;
        [edc_linear_current, ~] = compute_omni_energy_decay_from_ir(srir_stages{stage_idx}(:,1), fs);
        edc_linear(:,response_idx) = edc_linear_current(:);
        response_names(response_idx) = "Measurement " + measurement_idx + " - " + processing_stage_names(stage_idx);
    end
end


%% Plot omni EDCs with a shared reference

plot_common_reference_edc(edc_linear, fs, response_names);

%% Calculate the evaluation table for position 1 -> 100

% In this draft table, Baseline is decorrelated and Proposed is decay-scaled.
evaluation_table = evaluate_srir_set( ...
    srir_stages_by_position{1,1}, ...
    srir_stages_by_position{1,2}, ...
    srir_stages_by_position{1,3}, ...
    srir_stages_by_position{end,1}, ...
    fs, ...
    SH_ambisonic_binaural_decoder, ...
    false);


function srir_out = splice_processed_late_tail( ...
    srir_original, ...
    late_processed, ...
    late_start_sample, ...
    crossfade_length_samples)

    % Splice the processed tail back with an equal-power crossfade.
    srir_out = srir_original;
    late_indices = late_start_sample:size(srir_original,1);
    srir_out(late_indices,:) = late_processed;

    crossfade_phase = linspace(0, pi / 2, crossfade_length_samples).';
    fade_out = cos(crossfade_phase);
    fade_in = sin(crossfade_phase);
    crossfade_indices = late_start_sample:(late_start_sample + crossfade_length_samples - 1);
    srir_out(crossfade_indices,:) = ...
        fade_out .* srir_original(crossfade_indices,:) + ...
        fade_in .* late_processed(1:crossfade_length_samples,:);

end


function plot_common_reference_edc(edc_linear, fs, response_names)
    % All curves use one shared reference instead of separate normalisation.
    common_reference = max(edc_linear(1,:));
    edc_common_db = 10 * log10( ...
        max( ...
            edc_linear / max(common_reference, eps), ...
            eps));
    time_vector = (0:size(edc_linear,1)-1) / fs;
    colours = lines(size(edc_linear,2));

    figure('Name', 'Omni EDC comparison', 'NumberTitle', 'off');
    hold on
    for idx = 1:size(edc_common_db,2)
        plot( ...
            time_vector, ...
            edc_common_db(:,idx), ...
            'LineWidth', ...
            1.4, ...
            'Color', ...
            colours(idx,:));
    end
    hold off

    title('Omni EDC: common energy reference');
    xlabel('Time (s)');
    ylabel('Energy decay (dB)');
    legend(cellstr(response_names), 'Location', 'best');
    ylim([-80 5]);
    xlim([0 time_vector(end)]);
    grid on
    box on
end
