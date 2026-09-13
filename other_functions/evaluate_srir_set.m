function evaluation_table = evaluate_srir_set( ...
    srir_orig, ...
    srir_baseline, ...
    srir_proposed, ...
    srir_target, ...
    fs, ...
    binaural_decoder, ...
    display_enabled, ...
    path_info)
%EVALUATE_SRIR_SET Compare four SRIRs and optionally plot the results.
%   It reports omni room metrics plus binaural loudness and PBC-2 colouration
%   for the original, baseline, proposed, and target responses.

    if nargin < 7
        display_enabled = true;
    end
    if nargin < 8
        path_info = [];
    end

%% Response setup

    response_names = ["Original"; "Baseline"; "Proposed"; "Target"];
    srirs = {srir_orig, srir_baseline, srir_proposed, srir_target};
    n_responses = numel(srirs);

    validate_generated_srirs(srir_baseline, srir_proposed);

%% Metric preallocation

    omni = cell(n_responses, 1);
    brir = cell(n_responses, 1);
    direct_sample = zeros(n_responses, 1);
    rms_db = zeros(n_responses, 1);
    integrated_loudness_lufs = zeros(n_responses, 1);
    waveform_error_db = zeros(n_responses, 1);
    c50_db = zeros(n_responses, 1);
    drr_db = zeros(n_responses, 1);
    t60_s = zeros(n_responses, 1);
    t60_fit_r2 = zeros(n_responses, 1);
    t60_fit_range = strings(n_responses, 1);
    edc_similarity_rmse_db = zeros(n_responses, 1);
    edc_linear = zeros(size(srir_orig, 1), n_responses);
    edc_aligned_db = cell(n_responses, 1);

%% Per-response room and binaural metrics

    for idx = 1:n_responses
        omni{idx} = srirs{idx}(:,1);
        direct_sample(idx) = detect_direct_arrival(omni{idx}, fs);

        rms_db(idx) = amplitude_to_db(rms(omni{idx}));
        c50_db(idx) = calculate_c50( ...
            omni{idx}, ...
            fs, ...
            direct_sample(idx));
        drr_db(idx) = calculate_drr( ...
            omni{idx}, ...
            fs, ...
            direct_sample(idx));

        [t60_s(idx), t60_fit_r2(idx), t60_fit_range(idx), ...
            edc_aligned_db{idx}] = estimate_t60( ...
                omni{idx}, ...
                fs, ...
                direct_sample(idx));

        [edc_linear_current, ~] = ...
            compute_omni_energy_decay_from_ir(omni{idx}, fs);
        edc_linear(:,idx) = edc_linear_current(:);

        brir{idx} = render_binaural(srirs{idx}, binaural_decoder);
        integrated_loudness_lufs(idx) = ...
            integratedLoudness(brir{idx}, fs);
    end

%% Target-relative error metrics

    for idx = 1:n_responses
        waveform_error_db(idx) = amplitude_to_db( ...
            rms(omni{idx} - omni{4}));
        edc_similarity_rmse_db(idx) = calculate_edc_similarity( ...
            edc_aligned_db{idx}, ...
            edc_aligned_db{4});
    end

    % Target-to-target comparisons are exactly zero by definition.
    waveform_error_db(4) = -Inf;
    edc_similarity_rmse_db(4) = 0;

    pbc2_to_target = calculate_pbc2_to_target(brir, fs);

    direct_arrival_ms = (direct_sample - 1) / fs * 1000;

%% Assemble and display evaluation results

    evaluation_table = table( ...
        response_names, ...
        rms_db, ...
        integrated_loudness_lufs, ...
        waveform_error_db, ...
        pbc2_to_target, ...
        c50_db, ...
        drr_db, ...
        t60_s, ...
        t60_fit_r2, ...
        t60_fit_range, ...
        edc_similarity_rmse_db, ...
        direct_arrival_ms, ...
        'VariableNames', ...
        { ...
            'Response', ...
            'RMS_dB', ...
            'IntegratedLoudness_LUFS', ...
            'WaveformErrorToTarget_dB', ...
            'PBC2ToTarget', ...
            'C50_dB', ...
            'DRR_dB', ...
            'T60_s', ...
            'T60Fit_R2', ...
            'T60FitRange', ...
            'EDCSimilarityRMSE_dB', ...
            'DirectArrival_ms'});

    if display_enabled
        fprintf('\nNumerical evaluation (omni metrics use channel 1):\n');
        disp(evaluation_table);
        fprintf( ...
            ['Integrated loudness is relative to digital full scale; ' ...
             'it is not an absolute SPL measurement.\n']);
        fprintf( ...
            ['Lower PBC2ToTarget, WaveformErrorToTarget_dB and ' ...
             'EDCSimilarityRMSE_dB indicate closer agreement with the target.\n']);
    end

%% Plot comparisons

    if display_enabled
        plot_time_domain_comparison(omni, fs, rms_db, response_names);
        plot_common_reference_edc(edc_linear, fs, response_names);
        plot_pbc2(pbc2_to_target, response_names);
        plot_t60_heatmaps(srirs, fs);
        plot_rms_heatmaps(srirs);
        if ~isempty(path_info)
            plot_arrival_markers(srir_orig, srir_proposed, path_info, fs);
        end
    end
end


%% Generated-result validation

function validate_generated_srirs(srir_baseline, srir_proposed)
%VALIDATE_GENERATED_SRIRS Check both generated SRIRs for non-finite samples.

    if any(~isfinite(srir_baseline), 'all') || any(~isfinite(srir_proposed), 'all')
        error( ...
            'evaluate_srir_set:NonFiniteGeneratedSRIR', ...
            'Generated baseline and proposed SRIRs must contain only finite values.');
    end
end


%% Direct-arrival detection

function direct_sample = detect_direct_arrival(omni_ir, fs)
%DETECT_DIRECT_ARRIVAL Find the first strong peak in a band-limited omni IR.

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

    if isempty(direct_sample)
        error( ...
            'evaluate_srir_set:NoDirectArrival', ...
            'The direct arrival could not be detected.');
    end
end


%% Clarity and direct-to-reverberant metrics

function c50_db = calculate_c50(omni_ir, fs, direct_sample)
%CALCULATE_C50 Compare energy before and after 50 ms from the direct arrival.

    split_sample = min( ...
        numel(omni_ir), ...
        direct_sample + round(0.050 * fs) - 1);

    early_energy = sum(abs(omni_ir(direct_sample:split_sample)).^2);
    late_energy = sum(abs(omni_ir(split_sample+1:end)).^2);
    c50_db = energy_ratio_to_db(early_energy, late_energy);
end


function drr_db = calculate_drr(omni_ir, fs, direct_sample)
%CALCULATE_DRR Compare direct-window energy with the rest of the omni IR.

    direct_half_window = round(0.0025 * fs);
    direct_start = max(1, direct_sample - direct_half_window);
    direct_end = min( ...
        numel(omni_ir), ...
        direct_sample + direct_half_window);

    direct_energy = sum(abs(omni_ir(direct_start:direct_end)).^2);
    reverberant_energy = ...
        sum(abs(omni_ir(1:direct_start-1)).^2) + ...
        sum(abs(omni_ir(direct_end+1:end)).^2);

    drr_db = energy_ratio_to_db(direct_energy, reverberant_energy);
end


%% Decay estimation

function [t60_s, fit_r2, fit_range, edc_db] = ...
        estimate_t60(omni_ir, fs, direct_sample)
%ESTIMATE_T60 Fit the post-arrival decay from -5 to -55 dB.

    analysis_ir = omni_ir(direct_sample:end);
    [~, edc_db, time_vector] = ...
        compute_omni_energy_decay_from_ir(analysis_ir, fs);

    [t60_s, fit_r2, success] = fit_decay_range( ...
        edc_db, ...
        time_vector, ...
        -5, ...
        -55);
    fit_range = "-5 to -55 dB";

    if ~success
        t60_s = NaN;
        fit_r2 = NaN;
        fit_range = "Unavailable";
    end
end


function [t60_s, fit_r2, success] = ...
        fit_decay_range(edc_db, time_vector, upper_db, lower_db)
%FIT_DECAY_RANGE Fit one straight decay line between two dB limits.

    fit_start = find(edc_db <= upper_db, 1, 'first');
    fit_end = find(edc_db <= lower_db, 1, 'first');
    success = ~isempty(fit_start) && ~isempty(fit_end) && ...
        fit_end > fit_start && (fit_end - fit_start + 1) >= 50;

    if ~success
        t60_s = NaN;
        fit_r2 = NaN;
        return
    end

    fit_indices = fit_start:fit_end;
    fit_time = time_vector(fit_indices);
    fit_level = edc_db(fit_indices);
    coefficients = polyfit(fit_time, fit_level, 1);
    fitted_level = polyval(coefficients, fit_time);

    residual_sum_squares = sum((fit_level - fitted_level).^2);
    total_sum_squares = sum((fit_level - mean(fit_level)).^2);
    fit_r2 = 1 - residual_sum_squares / max(total_sum_squares, eps);

    success = coefficients(1) < 0 && isfinite(fit_r2);
    if success
        t60_s = -60 / coefficients(1);
    else
        t60_s = NaN;
        fit_r2 = NaN;
    end
end


%% Decay similarity

function similarity_rmse_db = ...
        calculate_edc_similarity(candidate_edc_db, target_edc_db)
%CALCULATE_EDC_SIMILARITY Measure EDC error over the target decay range.

    comparison_length = min( ...
        numel(candidate_edc_db), ...
        numel(target_edc_db));
    candidate_edc_db = candidate_edc_db(1:comparison_length);
    target_edc_db = target_edc_db(1:comparison_length);

    comparison_start = find(target_edc_db <= -5, 1, 'first');
    comparison_end = find(target_edc_db <= -60, 1, 'first');

    if isempty(comparison_start)
        comparison_start = 1;
    end
    if isempty(comparison_end)
        comparison_end = comparison_length;
    end

    comparison_end = min(comparison_end, comparison_length);
    if comparison_end <= comparison_start
        similarity_rmse_db = NaN;
        return
    end

    difference_db = candidate_edc_db( ...
        comparison_start:comparison_end) - target_edc_db( ...
        comparison_start:comparison_end);
    similarity_rmse_db = sqrt(mean(difference_db.^2));
end


%% Binaural rendering and colouration

function brir = render_binaural(srir, binaural_decoder)
%RENDER_BINAURAL Decode one SRIR and sum the channel responses for both ears.

    n_output_samples = size(srir,1) + size(binaural_decoder,2) - 1;
    brir = zeros(n_output_samples, 2);

    for channel_idx = 1:size(srir,2)
        for ear_idx = 1:2
            decoder_ir = squeeze( ...
                binaural_decoder(channel_idx,:,ear_idx));
            brir(:,ear_idx) = brir(:,ear_idx) + ...
                conv(srir(:,channel_idx), decoder_ir(:));
        end
    end
end


function pbc2_to_target = calculate_pbc2_to_target(brir, fs)
%CALCULATE_PBC2_TO_TARGET Compare each binaural response with the target.

    pbc2_to_target = zeros(numel(brir), 1);
    target_model_input = reshape(brir{4}, [], 1, 2);

    settings.fs = fs;
    settings.smGL1 = 1;
    settings.nOctSm = 3;
    settings.norm = false;

    for idx = 1:3
        candidate_model_input = reshape(brir{idx}, [], 1, 2);
        pbc2_to_target(idx) = mckenzie2025( ...
            candidate_model_input, ...
            target_model_input, ...
            settings);
    end

    pbc2_to_target(4) = 0;
end


%% Comparison plots

function plot_time_domain_comparison(omni, fs, rms_db, response_names)
%PLOT_TIME_DOMAIN_COMPARISON Plot the first 50 ms of all four omni responses.

    plot_duration_s = 0.050;
    y_limits_db = [-55 0];
    n_plot_samples = min( ...
        numel(omni{1}), ...
        max(1, round(plot_duration_s * fs)));
    plot_idx = 1:n_plot_samples;
    time_vector = (plot_idx - 1) / fs;
    plot_end_time = max(time_vector(end), 1 / fs);

    figure('Name', 'Omni time-domain comparison', 'NumberTitle', 'off');
    layout = tiledlayout( ...
        4, ...
        1, ...
        'TileSpacing', ...
        'compact', ...
        'Padding', ...
        'compact');

    for idx = 1:numel(omni)
        nexttile(layout);
        magnitude_db = 20 * log10(max(abs(omni{idx}(plot_idx)), eps));
        plot(time_vector, magnitude_db, 'LineWidth', 1.0);

        title( ...
            sprintf( ...
                '%s. RMS = %.4g dB', ...
                char(response_names(idx)), ...
                rms_db(idx)));
        ylabel('Magnitude (dB)');
        xlabel('Time (s)');
        ylim(y_limits_db);
        xlim([0 plot_end_time]);
        grid on
        box on
    end
end


function plot_common_reference_edc(edc_linear, fs, response_names)
%PLOT_COMMON_REFERENCE_EDC Plot all EDCs against one shared energy reference.

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


function plot_pbc2(pbc2_to_target, response_names)
%PLOT_PBC2 Plot the target-relative PBC-2 values as a bar chart.

    figure('Name', 'PBC-2 colouration comparison', 'NumberTitle', 'off');
    bar(1:numel(pbc2_to_target), pbc2_to_target);
    set( ...
        gca, ...
        'XTick', ...
        1:numel(pbc2_to_target), ...
        'XTickLabel', ...
        cellstr(response_names));
    ylabel('PBC-2 colouration to target');
    title('McKenzie 2025 predicted binaural colouration');
    grid on
    box on
end


function plot_rms_heatmaps(srirs)
%PLOT_RMS_HEATMAPS Plot directional RMS maps with shared colour limits.

    heatmap_names = ["Original"; "Baseline"; "Proposed"; "Target"];
    n_responses = numel(srirs);
    rms_maps_db = cell(n_responses, 1);
    grid_dirs = [];

    for idx = 1:n_responses
        [rms_maps_db{idx}, current_grid_dirs] = calculate_directional_rms_map(srirs{idx});
        if isempty(grid_dirs)
            grid_dirs = current_grid_dirs;
        end
    end

    all_rms_values_db = vertcat(rms_maps_db{:});
    finite_rms_values_db = all_rms_values_db(isfinite(all_rms_values_db));
    common_colour_limits = [];

    if isempty(finite_rms_values_db)
        warning( ...
            'evaluate_srir_set:NoDirectionalRMS', ...
            'No valid directional RMS values were available for the heatmaps.');
    else
        common_colour_limits = [min(finite_rms_values_db), max(finite_rms_values_db)];
        if common_colour_limits(1) == common_colour_limits(2)
            colour_padding = max(0.01 * abs(common_colour_limits(1)), eps);
            common_colour_limits = common_colour_limits + [-colour_padding, colour_padding];
        end
    end

    figure('Name', 'Directional RMS heatmaps', 'NumberTitle', 'off');
    layout = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'tight');

    for idx = 1:n_responses
        nexttile(layout);
        heatmap_plot_hammer(rad2deg(grid_dirs(:,1)), rad2deg(grid_dirs(:,2)), rms_maps_db{idx});
        set(gca, 'FontSize', 11);
        title(heatmap_names(idx));

        if ~isempty(common_colour_limits)
            clim(common_colour_limits);
        end
    end

    colormap(flipud(bone));
    colour_bar = colorbar;
    colour_bar.Layout.Tile = 'east';
    colour_bar.Label.String = 'Directional RMS (dB re 1)';
    title(layout, 'Directional RMS');
end


%% Directional RMS analysis

function [rms_map_db, grid_dirs] = calculate_directional_rms_map(srir)
%CALCULATE_DIRECTIONAL_RMS_MAP Beamform one SRIR into a directional RMS map.

    degree_resolution = 5;

    n_samples = size(srir, 1);
    n_channels = size(srir, 2);
    ambisonic_order = sqrt(n_channels) - 1;
    if ambisonic_order ~= round(ambisonic_order)
        error( ...
            'evaluate_srir_set:IncompleteSHSet', ...
            'The SRIR channel count must be a complete spherical-harmonic set.');
    end

    grid_dirs = grid2dirs(degree_resolution, degree_resolution, 0, 0);
    grid_dirs_degrees = rad2deg(grid_dirs);
    steering_matrix = getRSH(ambisonic_order, grid_dirs_degrees);
    steering_matrix = steering_matrix ./ max(vecnorm(steering_matrix, 2, 1), eps);

    srir_n3d = convert_N3D_SN3D(srir, 'sn2n');
    channel_mean_square = (srir_n3d' * srir_n3d) / n_samples;
    directional_mean_square = real(sum(conj(steering_matrix) .* (channel_mean_square * steering_matrix), 1));
    directional_rms = sqrt(max(directional_mean_square, 0)).';

    rms_map_db = -inf(size(directional_rms));
    positive_rms = directional_rms > 0;
    rms_map_db(positive_rms) = 20 * log10(directional_rms(positive_rms));
end


function plot_t60_heatmaps(srirs, fs)
%PLOT_T60_HEATMAPS Plot directional T60 maps with shared colour limits.

    heatmap_names = ["Original"; "Baseline"; "Proposed"; "Target"];
    n_responses = numel(srirs);
    t60_maps = cell(n_responses, 1);
    grid_dirs = [];

    for idx = 1:n_responses
        [t60_maps{idx}, current_grid_dirs] = calculate_directional_t60_map(srirs{idx}, fs);
        if isempty(grid_dirs)
            grid_dirs = current_grid_dirs;
        end
    end

    all_t60_values = vertcat(t60_maps{:});
    finite_t60_values = all_t60_values(isfinite(all_t60_values));
    common_colour_limits = [];

    if isempty(finite_t60_values)
        warning( ...
            'evaluate_srir_set:NoDirectionalT60', ...
            'No valid directional T60 values were available for the heatmaps.');
    else
        common_colour_limits = [min(finite_t60_values), max(finite_t60_values)];
        if common_colour_limits(1) == common_colour_limits(2)
            colour_padding = max(0.01 * abs(common_colour_limits(1)), eps);
            common_colour_limits = common_colour_limits + [-colour_padding, colour_padding];
        end
    end

    figure('Name', 'Directional T60 heatmaps', 'NumberTitle', 'off');
    layout = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'tight');

    for idx = 1:n_responses
        nexttile(layout);
        heatmap_plot_hammer(rad2deg(grid_dirs(:,1)), rad2deg(grid_dirs(:,2)), t60_maps{idx});
        set(gca, 'FontSize', 11);
        title(heatmap_names(idx));

        if ~isempty(common_colour_limits)
            clim(common_colour_limits);
        end
    end

    colormap(flipud(bone));
    colour_bar = colorbar;
    colour_bar.Layout.Tile = 'east';
    colour_bar.Label.String = 'T60 (s)';
    title(layout, 'Directional T60');
end


%% Directional T60 analysis

function [t60_map, grid_dirs] = calculate_directional_t60_map(srir, fs)
%CALCULATE_DIRECTIONAL_T60_MAP Beamform one SRIR and fit T60 by direction.

    degree_resolution = 5;
    direction_block_size = 128;

    n_channels = size(srir, 2);
    ambisonic_order = sqrt(n_channels) - 1;
    if ambisonic_order ~= round(ambisonic_order)
        error( ...
            'evaluate_srir_set:IncompleteSHSet', ...
            'The SRIR channel count must be a complete spherical-harmonic set.');
    end

    grid_dirs = grid2dirs(degree_resolution, degree_resolution, 0, 0);
    grid_dirs_degrees = rad2deg(grid_dirs);
    steering_matrix = getRSH(ambisonic_order, grid_dirs_degrees);
    steering_matrix = steering_matrix ./ max(vecnorm(steering_matrix, 2, 1), eps);

    srir_n3d = convert_N3D_SN3D(srir, 'sn2n');
    n_directions = size(grid_dirs, 1);
    t60_map = nan(n_directions, 1);
    time_vector = (0:size(srir, 1)-1) / fs;

    for block_start = 1:direction_block_size:n_directions
        block_end = min(block_start + direction_block_size - 1, n_directions);
        directional_ir_block = srir_n3d * steering_matrix(:,block_start:block_end);
        edc_linear_block = flip(cumsum(flip(abs(directional_ir_block).^2, 1), 1), 1);
        edc_reference = max(edc_linear_block(1,:), eps);
        edc_db_block = 10 * log10(max(edc_linear_block ./ edc_reference, eps));

        for block_idx = 1:size(edc_db_block, 2)
            [t60_s, ~, success] = fit_decay_range( ...
                edc_db_block(:,block_idx).', ...
                time_vector, ...
                -5, ...
                -55);

            if success
                direction_idx = block_start + block_idx - 1;
                t60_map(direction_idx) = t60_s;
            end
        end
    end
end


%% Scalar conversion helpers

function value_db = amplitude_to_db(value)
%AMPLITUDE_TO_DB Convert one linear amplitude to decibels.

    if value == 0
        value_db = -Inf;
    else
        value_db = 20 * log10(abs(value));
    end
end


function ratio_db = energy_ratio_to_db(numerator, denominator)
%ENERGY_RATIO_TO_DB Convert one energy ratio to decibels safely.

    ratio_db = 10 * log10(max(numerator, eps) / max(denominator, eps));
end


function plot_arrival_markers(srir_orig, srir_proposed, path_info, fs)
%PLOT_ARRIVAL_MARKERS Mark calculated arrival times on two omni responses.

    plotcutoff = fs / 20;
    plot_time_vector = 0:1/fs:(size(srir_orig, 1) / fs - 1/fs);
    plot_idx = 1:min(plotcutoff, size(srir_orig, 1));
    safe_db = @(x) 20 * log10(max(abs(x), eps));

    figure('Name', 'Arrival time markers', 'NumberTitle', 'off');

    subplot(2, 1, 1)
    plot(plot_time_vector(plot_idx), safe_db(srir_orig(plot_idx, 1)))
    hold on
    arrival_marker_y = ylim;
    valid_orig_toa = path_info.toa.orig_samp( ...
        path_info.toa.orig_samp >= 1 & path_info.toa.orig_samp <= plot_idx(end));
    for i_marker = 1:numel(valid_orig_toa)
        marker_t = (valid_orig_toa(i_marker) - 1) / fs;
        line([marker_t marker_t], arrival_marker_y, ...
            'Color', [0.8500 0.3250 0.0980], 'LineStyle', '--', 'LineWidth', 0.8);
    end
    title('Original SRIR with calculated arrival time marked')
    ylim([-50 0])
    if path_info.residual_scale.mode == "after_cutoff" && ...
            isfinite(path_info.residual_scale.start_time_sec)
        residual_cutoff_t = path_info.residual_scale.start_time_sec;
        line([residual_cutoff_t residual_cutoff_t], ylim, ...
            'Color', [0.4940 0.1840 0.5560], 'LineStyle', '--', 'LineWidth', 1.5);
    end
    ylabel('Magnitude (dB)')
    xlabel('Time (s)')
    xlim([0 max(plot_time_vector(plot_idx))])
    box on
    grid on

    subplot(2, 1, 2)
    plot(plot_time_vector(plot_idx), safe_db(srir_proposed(plot_idx, 1)))
    hold on
    arrival_marker_y = ylim;
    valid_tar_toa = path_info.toa.tar_samp( ...
        path_info.toa.tar_samp >= 1 & path_info.toa.tar_samp <= plot_idx(end));
    for i_marker = 1:numel(valid_tar_toa)
        marker_t = (valid_tar_toa(i_marker) - 1) / fs;
        line([marker_t marker_t], arrival_marker_y, ...
            'Color', [0.4660 0.6740 0.1880], 'LineStyle', '--', 'LineWidth', 0.8);
    end
    title('Extrapolated SRIR with calculated arrival time marked')
    ylim([-50 0])
    if path_info.residual_scale.mode == "after_cutoff" && ...
            isfinite(path_info.residual_scale.start_time_sec)
        residual_cutoff_t = path_info.residual_scale.start_time_sec;
        line([residual_cutoff_t residual_cutoff_t], ylim, ...
            'Color', [0.3010 0.7450 0.9330], 'LineStyle', '--', 'LineWidth', 1.5);
    end
    ylabel('Magnitude (dB)')
    xlabel('Time (s)')
    xlim([0 max(plot_time_vector(plot_idx))])
    box on
    grid on
end
