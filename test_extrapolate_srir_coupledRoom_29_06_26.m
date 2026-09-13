% 20/06/2026
% A basic version of coupled-room ISM algorithm

close all
clear workspace


%% Init

% add code and module paths
addpaths;

%
load_ambisonic_configuration; 



% load SRIR (SOFA file)
sofa_orig = SOFAload('roomToHallway_srcRoom_noLOS.sofa');

fs = sofa_orig.Data.SamplingRate;           % get sample rate



%% Parameters and Settings

order_ISM_room_s = 1;          % ISM order for room of source

idx_LS_rec_orig=55;         % original receiver position
idx_LS_rec_tar=90;          % target receiver position
fprintf('Receiver index: orig %d -> tar %d\n', idx_LS_rec_orig, idx_LS_rec_tar);
% 1 speaker position only
% 101 receiver positions in total (1~101)
% (50 in the first room, 1 at the aperture)

% geometry
geom.c = 343;                           % speed of sound in m/s
geom.room_s.dim = [4.6 6.6 2.8];        % room geometry
geom.room_r.dim = [4.5 18 2.8];         % hallway geometry
geom.room_r.top_left_xy = [4.6 11.51];
geom.aperture.xy = [4.6 2.83];          % aperture coordinate. Taking the center of the door
geom.aperture.normal = [1 0 0];         % Aperture direction. from source room to receiver room
% note: origin set at the bottom-left corner of source room


% Windowing parameters
window_param.window_ms = 3;
window_param.fade_in_samp = 5;
window_param.fade_out_samp = 10;

window_param.pre_ms = window_param.window_ms / 4;
window_param.window_samp = window_param.window_ms / 1000 * fs;
window_param.pre_samp = window_param.pre_ms / 1000 * fs;

% Plotting settings
save_figs = false;
plotcutoff = fs/20;     % how long to plot time-domain signals

% coordinate_compensation
% Correct the offset caused by the chosen origin. This places the origin at
% the room's lower-left corner (lower-right in the thesis figure).
coordinate_compensation = [2.1 2.83 0];


restore_propagation_delay = true;  % this dataset is onset-aligned; restore geometric delay for ISM processing

% Residual propagation-gain configuration for Room-2 -> Room-2 extrapolation.
% "fixed_distance" uses a regularised aperture-to-receiver gain; "full_path"
% uses the direct path as the residual representative.
residual_propagation_gain_param.model = "full_path"; % "fixed_distance", "full_path"
residual_propagation_gain_param.fixed_distance_m = 1.0;

zoom_param.enabled = false;
zoom_param.coord_change = [0 0 0];


% Residual scaling configuration.  "full" scales the complete residual;
% "after_cutoff" starts residual scaling this many seconds after the
% original direct sound and crossfades over .fade seconds; "off" disables it.
residual_scale_param.mode = "after_cutoff"; % "off", "full", "after_cutoff"
residual_scale_param.start = 0.050;          % seconds after direct sound
residual_scale_param.fade = 0.010;           % crossfade duration in seconds
residual_scale_param.gain = 1;               % overwritten for active cases

% Other Flags

flag.src_directivity_DS = false;     % implement source directivity for direct sound
% true: direct sound becomes brighter or darker with the loudspeaker orientation.
% false: direct sound only shifts in time and changes in amplitude.

flag.src_directivity_ERs = false;    % implement source directivity for early reflections

flag.beamform_extract = true;       % implement beamforming for extraction of arrivals

flag.plot_ism = true;   % Only used in orig-in-different-room scenario (subject to extend)




%% Get original and target SRIRs

% new sofa with compensated coordinates
sofa_corr = sofa_orig;
sofa_corr.ListenerPosition = sofa_orig.ListenerPosition + coordinate_compensation;
sofa_corr.SourcePosition   = sofa_orig.SourcePosition   + coordinate_compensation;


% get source and receiver positions
geom.src.orig.pos = sofa_corr.SourcePosition(idx_LS_rec_orig,:);
geom.src.tar.pos = sofa_corr.SourcePosition(idx_LS_rec_tar,:);
geom.rec.orig.pos = sofa_corr.ListenerPosition(idx_LS_rec_orig,:);
geom.rec.tar.pos = sofa_corr.ListenerPosition(idx_LS_rec_tar,:);
geom.aperture.pos = [geom.aperture.xy(1) geom.aperture.xy(2) geom.rec.orig.pos(3)];  % aperture position. Taking the center of the door
geom.src.view = sofa_corr.SourceView;       % Source direction. For example (0, -1, 0)


% read IR at given position
srir_orig = squeeze(sofa_corr.Data.IR(idx_LS_rec_orig,:,:))'; % original IR
srir_tar = squeeze(sofa_corr.Data.IR(idx_LS_rec_tar,:,:))'; % target IR (for evaluation)

if restore_propagation_delay
    srir_orig = restore_geometric_delay_extended(srir_orig, fs, geom.src.orig.pos, geom.rec.orig.pos, idx_LS_rec_orig, geom);
    srir_tar = restore_geometric_delay_extended(srir_tar, fs, geom.src.tar.pos, geom.rec.tar.pos, idx_LS_rec_tar, geom);
end





% Plot geometry and source-receiver positions of original and targets
SOFAplotGeometry(sofa_corr); % plot the source and listen position
hold on;

% draw source room boundary
geom.room_s.corners_xy = [0 0; geom.room_s.dim(1) 0; geom.room_s.dim(1) geom.room_s.dim(2); 0 geom.room_s.dim(2); 0 0];        
h_room_s = line(geom.room_s.corners_xy(:,1),geom.room_s.corners_xy(:,2),'Color','black','LineWidth',1.5,'LineStyle','--');

% draw hallway boundary
geom.room_r.corners_xy = [geom.room_r.top_left_xy; ...
                    geom.room_r.top_left_xy + [geom.room_r.dim(1) 0]; ...
                    geom.room_r.top_left_xy + [geom.room_r.dim(1) -geom.room_r.dim(2)]; ...
                    geom.room_r.top_left_xy + [0 -geom.room_r.dim(2)]; ...
                    geom.room_r.top_left_xy];
h_room_r = line(geom.room_r.corners_xy(:,1),geom.room_r.corners_xy(:,2),'Color','blue','LineWidth',1.5,'LineStyle','--');

% adjust field of view
all_room_corners_xy = [geom.room_s.corners_xy; geom.room_r.corners_xy];
room_plot_margin = 0.5;
xlim([min(all_room_corners_xy(:,1))-room_plot_margin max(all_room_corners_xy(:,1))+room_plot_margin]);
ylim([min(all_room_corners_xy(:,2))-room_plot_margin max(all_room_corners_xy(:,2))+room_plot_margin]);

% draw source-receiver arrows
% original [red]
h2 = line([geom.src.orig.pos(1) geom.rec.orig.pos(1)],[geom.src.orig.pos(2) geom.rec.orig.pos(2)],'Color','red');
% target [green]
h3 = line([geom.src.tar.pos(1) geom.rec.tar.pos(1)],[geom.src.tar.pos(2) geom.rec.tar.pos(2)],'Color','green');

% draw aperture position
h_aper = plot(geom.aperture.pos(1),geom.aperture.pos(2),'kp','MarkerFaceColor','yellow','MarkerSize',12);



%% Proposed coupled-room SRIR extrapolation

[srir_new, path_info] = extrapolate_srir_coupled_room( ...
    srir_orig, ...
    fs, ...
    idx_LS_rec_orig, ...
    idx_LS_rec_tar, ...
    geom, ...
    order_ISM_room_s, ...
    window_param, ...
    flag, ...
    residual_propagation_gain_param, ...
    zoom_param, ...
    residual_scale_param);



%% ================ EVALUATION ================
% Compare new (extrapolated) and original SRIRs to target SRIR

plot_time_vector = 0:1/fs:(size(srir_orig,1)/fs-1/fs);
plot_idx = 1:min(plotcutoff, size(srir_orig,1));

safe_db = @(x) 20*log10(max(abs(x), eps));

eval_coupled.rms.orig = rms(srir_orig(:,1));
eval_coupled.rms.new = rms(srir_new(:,1));
eval_coupled.rms.tar = rms(srir_tar(:,1));

eval_coupled.rms_db.orig = db(eval_coupled.rms.orig);
eval_coupled.rms_db.new = db(eval_coupled.rms.new);
eval_coupled.rms_db.tar = db(eval_coupled.rms.tar);

eval_coupled.error.orig_to_tar = rms(srir_orig(:,1) - srir_tar(:,1));
eval_coupled.error.new_to_tar = rms(srir_new(:,1) - srir_tar(:,1));

eval_coupled.error_db.orig_to_tar = db(eval_coupled.error.orig_to_tar);
eval_coupled.error_db.new_to_tar = db(eval_coupled.error.new_to_tar);

% Omni-channel Schroeder energy decay curves.  Keep the linear EDCs so all
% three responses can be converted using one shared energy reference.
[eval_coupled.edc.linear.orig, ~, ...
    eval_coupled.edc.time_sec] = ...
    compute_omni_energy_decay_from_ir(srir_orig(:,1), fs);
[eval_coupled.edc.linear.new, ~] = ...
    compute_omni_energy_decay_from_ir(srir_new(:,1), fs);
[eval_coupled.edc.linear.tar, ~] = ...
    compute_omni_energy_decay_from_ir(srir_tar(:,1), fs);

edc_common_reference = max([ ...
    eval_coupled.edc.linear.orig(1), ...
    eval_coupled.edc.linear.new(1), ...
    eval_coupled.edc.linear.tar(1), ...
    eps]);

eval_coupled.edc.common_db.orig = 10*log10(max( ...
    eval_coupled.edc.linear.orig / edc_common_reference, eps));
eval_coupled.edc.common_db.new = 10*log10(max( ...
    eval_coupled.edc.linear.new / edc_common_reference, eps));
eval_coupled.edc.common_db.tar = 10*log10(max( ...
    eval_coupled.edc.linear.tar / edc_common_reference, eps));

% display values in command window
disp(['Original. RMS = ',num2str(eval_coupled.rms_db.orig,4),'dB'])
disp(['Extrapolated. RMS = ',num2str(eval_coupled.rms_db.new,4),'dB'])
disp(['Target. RMS = ',num2str(eval_coupled.rms_db.tar,4),'dB'])
disp(['Waveform error (orig -> tar) = ',num2str(eval_coupled.error_db.orig_to_tar,4),'dB'])
disp(['Waveform error (new -> tar) = ',num2str(eval_coupled.error_db.new_to_tar,4),'dB'])

%% Arrival table

num_paths = numel(path_info.path_id);

eval_coupled.arrival_table = table( ...
    path_info.path_id(:), ...
    path_info.toa.orig_samp(:), ...
    path_info.toa.tar_samp(:), ...
    path_info.dist.orig(:), ...
    path_info.dist.tar(:), ...
    path_info.gain(:), ...
    path_info.reflection_order(:), ...
    path_info.was_extracted(:), ...
    path_info.was_added(:), ...
    'VariableNames', { ...
        'PathID', ...
        'OrigTotalToA_Samp', ...
        'TargetTotalToA_Samp', ...
        'OrigTotalDist_m', ...
        'TargetTotalDist_m', ...
        'Gain', ...
        'ReflectionOrder', ...
        'WasExtracted', ...
        'WasAdded'});

disp(eval_coupled.arrival_table)

%% Omni-channel energy decay curves

figure('Name', 'Omni EDC comparison', 'NumberTitle', 'off');
plot(eval_coupled.edc.time_sec, eval_coupled.edc.common_db.orig, ...
    'LineWidth', 1.2)
hold on
plot(eval_coupled.edc.time_sec, eval_coupled.edc.common_db.new, ...
    'LineWidth', 1.2)
plot(eval_coupled.edc.time_sec, eval_coupled.edc.common_db.tar, ...
    'LineWidth', 1.2)
if path_info.residual_scale.mode == "after_cutoff" && ...
        isfinite(path_info.residual_scale.start_time_sec)
    xline(path_info.residual_scale.start_time_sec, '--', ...
        'Residual zoom start', ...
        'Color', [0.4940 0.1840 0.5560], ...
        'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
end
title('Omni EDC: common energy reference')
ylabel('Energy decay (dB)')
xlabel('Time (s)')
legend({'Original','Proposed','Target'}, 'Location', 'southwest')
xlim([0 eval_coupled.edc.time_sec(end)])
ylim([-80 0])
box on
grid on

if save_figs; exportgraphics(gcf, 'coupledRoom_EDC_omni.pdf');end

%% Time-domain: one figure 3 panels: original, extrapolated, target

figure;
subplot(3,1,1)
plot(plot_time_vector(plot_idx),safe_db(srir_orig(plot_idx,1)))
hold on;
title(['Original. RMS = ',num2str(eval_coupled.rms_db.orig,4),'dB'])
ylim([-55 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

subplot(3,1,2)
plot(plot_time_vector(plot_idx),safe_db(srir_new(plot_idx,1)))
hold on
title(['Extrapolated. RMS = ',num2str(eval_coupled.rms_db.new,4),'dB'])
ylim([-55 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

subplot(3,1,3)
plot(plot_time_vector(plot_idx),safe_db(srir_tar(plot_idx,1)))
hold on;
title(['Target. RMS = ',num2str(eval_coupled.rms_db.tar,4),'dB'])
ylim([-55 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

if save_figs; exportgraphics(gcf, 'coupledRoom_TD_three_panel.pdf');end

%% Time-domain: 2 figures: target vs original, target vs extrapolated

figure
hold on
ylim([-50 0])
plot(plot_time_vector(plot_idx),safe_db(srir_tar(plot_idx,1)))
plot(plot_time_vector(plot_idx),safe_db(srir_orig(plot_idx,1)))
legend({'Target','Original'})
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
pbaspect([3 1 1]);
box on
grid on
if save_figs; exportgraphics(gcf, 'coupledRoom_TD_comparison_orig.pdf');end

figure
hold on
ylim([-50 0])
plot(plot_time_vector(plot_idx),safe_db(srir_tar(plot_idx,1)))
plot(plot_time_vector(plot_idx),safe_db(srir_new(plot_idx,1)))
legend({'Target','Extrapolated'})
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
pbaspect([3 1 1]);
box on
grid on
if save_figs; exportgraphics(gcf, 'coupledRoom_TD_comparison_extrap.pdf');end

%% Arrival marker plot

figure;
subplot(2,1,1)
plot(plot_time_vector(plot_idx),safe_db(srir_orig(plot_idx,1)))
hold on
arrival_marker_y = ylim;
valid_orig_toa = path_info.toa.orig_samp(path_info.toa.orig_samp >= 1 & path_info.toa.orig_samp <= plot_idx(end));
for i_marker = 1:numel(valid_orig_toa)
    marker_t = (valid_orig_toa(i_marker)-1) / fs;
    line([marker_t marker_t], arrival_marker_y, 'Color', [0.8500 0.3250 0.0980], 'LineStyle', '--', 'LineWidth', 0.8);
end
title('Original SRIR with calculated arrival time marked')
ylim([-50 0])
if path_info.residual_scale.mode == "after_cutoff" && ...
        isfinite(path_info.residual_scale.start_time_sec)
    residual_cutoff_t = path_info.residual_scale.start_time_sec;
    line([residual_cutoff_t residual_cutoff_t], ylim, ...
        'Color', [0.4940 0.1840 0.5560], ...
        'LineStyle', '--', ...
        'LineWidth', 1.5);
end
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

subplot(2,1,2)
plot(plot_time_vector(plot_idx),safe_db(srir_new(plot_idx,1)))
hold on
arrival_marker_y = ylim;
valid_tar_toa = path_info.toa.tar_samp(path_info.toa.tar_samp >= 1 & path_info.toa.tar_samp <= plot_idx(end));
for i_marker = 1:numel(valid_tar_toa)
    marker_t = (valid_tar_toa(i_marker)-1) / fs;
    line([marker_t marker_t], arrival_marker_y, 'Color', [0.4660 0.6740 0.1880], 'LineStyle', '--', 'LineWidth', 0.8);
end
title('Extrapolated SRIR with calculated arrival time marked')
ylim([-50 0])
if path_info.residual_scale.mode == "after_cutoff" && ...
        isfinite(path_info.residual_scale.start_time_sec)
    residual_cutoff_t = path_info.residual_scale.start_time_sec;
    line([residual_cutoff_t residual_cutoff_t], ylim, ...
        'Color', [0.3010 0.7450 0.9330], ...
        'LineStyle', '--', ...
        'LineWidth', 1.5);
end
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

if save_figs; exportgraphics(gcf, 'coupledRoom_arrival_markers.pdf');end

%% Frequency-domain (omni): 2 figures: target vs original, target vs extrapolated

figure
freqplot_smooth(srir_tar(:,1),fs)
hold on
freqplot_smooth(srir_orig(:,1),fs)
pbaspect([1.5 1 1]);
xlim([40 20000])
ylim([-70 20])
legend({'Target','Original'},'location','southwest')
title(['Omni channel: target vs original. Waveform error = ', ...
    num2str(eval_coupled.error_db.orig_to_tar,4),'dB'])
if save_figs; exportgraphics(gcf, 'coupledRoom_FD_comparison_orig_omni.pdf');end

figure
freqplot_smooth(srir_tar(:,1),fs)
hold on
freqplot_smooth(srir_new(:,1),fs)
pbaspect([1.5 1 1]);
xlim([40 20000])
ylim([-70 20])
legend({'Target','Extrapolated'},'location','southwest')
title(['Omni channel: target vs extrapolated. Waveform error = ', ...
    num2str(eval_coupled.error_db.new_to_tar,4),'dB'])
if save_figs; exportgraphics(gcf, 'coupledRoom_FD_comparison_extrap_omni.pdf');end
