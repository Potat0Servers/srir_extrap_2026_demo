function MAIN_coupled_room_srir_comparison( ...
    idx_LS_rec_orig, ...
    idx_LS_rec_tar, ...
    plot_and_table, ...
    save_csv, ...
    save_directory, ...
    save_file_name, ...
    save_srir, ...
    save_srir_directory)
%MAIN_COUPLED_ROOM_SRIR_COMPARISON Run one measured receiver-position comparison.
%   It runs the coupled-room method and the one-room baseline, compares both
%   against the target SRIR, and saves the requested outputs.


%% Init and load SOFA file

addpaths;
SH_ambisonic_binaural_decoder = get_cached_ambisonic_decoder();


%% Experiment logging settings

evaluation_csv_file = string(fullfile(save_directory, save_file_name));

input_sofa_file = 'roomToHallway_srcRoom_noLOS.sofa';
sofa = SOFAload(input_sofa_file);
fs = sofa.Data.SamplingRate;


%% Shared parameters settings

% ISM order
ism_order = 1;


% Mode settings

% residual scaling
proposed_residual_scale_param.mode = "full";  % "off", "full", "after_cutoff"
proposed_residual_scale_param.start = 0.050;
proposed_residual_scale_param.fade = 0.010;
proposed_residual_scale_param.gain = 1;

% Propagation gain model for residual
proposed_residual_propagation_gain_param.model = "full_path";  % "fixed_distance", "full_path"
proposed_residual_propagation_gain_param.fixed_distance_m = 1.0;

% zooming
proposed_zoom_param.enabled = true;
proposed_zoom_param.preserve_omni_rms = true;
zoom_depth_coeff = 1;
zoom_distance = (idx_LS_rec_tar - idx_LS_rec_orig) * 0.05 * zoom_depth_coeff;
%zoom_distance = 1;
proposed_zoom_param.coord_change = [zoom_distance 0 0];

baseline_residual_scale_param = proposed_residual_scale_param;
baseline_residual_scale_param.mode = "off";


% Other flags
flag.src_directivity_DS = false;   % Source directivity for direct sound; not implemented
flag.src_directivity_ERs = false;  % Source directivity for early reflections; not implemented
flag.beamform_extract = true;      % Spatially extract arrivals using beamforming
flag.plot_ism = false;             % Plot image-source paths for debugging
flag.plot_zoom_directions = plot_and_table;  % Plot zooming sector directions



% Set window parameter (to extract arrivals)
window_param.window_ms = 3;
window_param.fade_in_samp = 5;
window_param.fade_out_samp = 10;
window_param.pre_ms = window_param.window_ms / 4;
window_param.window_samp = window_param.window_ms / 1000 * fs;
window_param.pre_samp = window_param.pre_ms / 1000 * fs;


% Restore propagation delay of sofa dataset
restore_propagation_delay = true;
coordinate_compensation = [2.1 2.83 0];

% Some calculation
sofa.ListenerPosition = sofa.ListenerPosition + coordinate_compensation;
sofa.SourcePosition = sofa.SourcePosition + coordinate_compensation;

srir_orig = squeeze(sofa.Data.IR(idx_LS_rec_orig,:,:))';
srir_tar = squeeze(sofa.Data.IR(idx_LS_rec_tar,:,:))';

fprintf('Receiver index: orig %d -> tar %d\n', idx_LS_rec_orig, idx_LS_rec_tar);

%% Method-specific configuration

% Proposed method: retain the real two-room geometry and aperture.
coupled_geom.c = 343;
coupled_geom.room_s.dim = [4.6 6.6 2.8];
coupled_geom.room_r.dim = [4.5 18 2.8];
coupled_geom.room_r.top_left_xy = [4.6 11.51];
coupled_geom.aperture.xy = [4.6 2.83];
coupled_geom.aperture.normal = [1 0 0];

coupled_geom.src.orig.pos = sofa.SourcePosition(idx_LS_rec_orig,:);
coupled_geom.src.tar.pos = sofa.SourcePosition(idx_LS_rec_tar,:);
coupled_geom.rec.orig.pos = sofa.ListenerPosition(idx_LS_rec_orig,:);
coupled_geom.rec.tar.pos = sofa.ListenerPosition(idx_LS_rec_tar,:);
coupled_geom.aperture.pos = [coupled_geom.aperture.xy, coupled_geom.rec.orig.pos(3)];
coupled_geom.src.view = sofa.SourceView;


% Baseline method: use the same coordinates but ignore the separating wall
% by replacing the source room with one virtual room spanning both rooms.
baseline_geom = coupled_geom;
baseline_geom.room_s.dim = [9.1 18 2.8];






%% Restore the measured delays once using the real dataset geometry.
% The resulting input and target SRIRs are shared unchanged by both methods.
if restore_propagation_delay
    srir_orig = restore_geometric_delay_extended( ...
        srir_orig, ...
        fs, ...
        coupled_geom.src.orig.pos, ...
        coupled_geom.rec.orig.pos, ...
        idx_LS_rec_orig, ...
        coupled_geom);

    srir_tar = restore_geometric_delay_extended( ...
        srir_tar, ...
        fs, ...
        coupled_geom.src.tar.pos, ...
        coupled_geom.rec.tar.pos, ...
        idx_LS_rec_tar, ...
        coupled_geom);
end


%% Run both methods

[srir_proposed, path_info] = extrapolate_srir_coupled_room( ...
    srir_orig, ...
    fs, ...
    idx_LS_rec_orig, ...
    idx_LS_rec_tar, ...
    coupled_geom, ...
    ism_order, ...
    window_param, ...
    flag, ...
    proposed_residual_propagation_gain_param, ...
    proposed_zoom_param, ...
    proposed_residual_scale_param);

[srir_baseline, ~] = extrapolate_srir_single_room_baseline( ...
    srir_orig, ...
    fs, ...
    baseline_geom, ...
    ism_order, ...
    window_param, ...
    flag, ...
    baseline_residual_scale_param);


%% Evaluation

evaluation_table = evaluate_srir_set( ...
    srir_orig, ...
    srir_baseline, ...
    srir_proposed, ...
    srir_tar, ...
    fs, ...
    SH_ambisonic_binaural_decoder, ...
    plot_and_table, ...
    path_info);


%% Save SRIRs (optional)

if save_srir
    out_dir = fullfile(save_srir_directory, sprintf('%d-%d', idx_LS_rec_orig, idx_LS_rec_tar));
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end

    save_srir_sofa(sofa, srir_orig, ...
        sofa.SourcePosition(idx_LS_rec_orig,:), ...
        sofa.ListenerPosition(idx_LS_rec_orig,:), ...
        fullfile(out_dir, 'original.sofa'));
    save_srir_sofa(sofa, srir_baseline, ...
        sofa.SourcePosition(idx_LS_rec_tar,:), ...
        sofa.ListenerPosition(idx_LS_rec_tar,:), ...
        fullfile(out_dir, 'baseline.sofa'));
    save_srir_sofa(sofa, srir_proposed, ...
        sofa.SourcePosition(idx_LS_rec_tar,:), ...
        sofa.ListenerPosition(idx_LS_rec_tar,:), ...
        fullfile(out_dir, 'proposed.sofa'));
    save_srir_sofa(sofa, srir_tar, ...
        sofa.SourcePosition(idx_LS_rec_tar,:), ...
        sofa.ListenerPosition(idx_LS_rec_tar,:), ...
        fullfile(out_dir, 'target.sofa'));

    fprintf('Saved SRIRs to %s\n', out_dir);
end


%% Save one-row experiment record

if save_csv
    experiment_config.OriginalIndex = idx_LS_rec_orig;
    experiment_config.TargetIndex = idx_LS_rec_tar;
    experiment_config.ProposedResidualScaleMode = proposed_residual_scale_param.mode;
    experiment_config.ProposedResidualScaleGain = proposed_residual_scale_param.gain;
    experiment_config.ProposedZoomEnabled = proposed_zoom_param.enabled;
    experiment_config.ProposedZoomPreserveOmniRMS = proposed_zoom_param.preserve_omni_rms;
    experiment_config.ProposedZoomDepthCoeff = zoom_depth_coeff;
    experiment_config.ProposedZoomDistance_m = zoom_distance;

    save_action = save_srir_experiment_csv(evaluation_table, experiment_config, evaluation_csv_file);
    fprintf('Experiment CSV %s: %s\n', char(save_action), char(evaluation_csv_file));
end
end


% reuse decoder to save time
function binaural_decoder = get_cached_ambisonic_decoder()
%GET_CACHED_AMBISONIC_DECODER Reuse one decoder across batch comparisons.

    persistent cached_binaural_decoder

    if isempty(cached_binaural_decoder)
        cached_binaural_decoder = load_ambisonic_decoder();
    end

    binaural_decoder = cached_binaural_decoder;
end


function binaural_decoder = load_ambisonic_decoder()
%LOAD_AMBISONIC_DECODER Load the decoder from its Ambisonic configuration.

    load_ambisonic_configuration;
    binaural_decoder = SH_ambisonic_binaural_decoder;
end
