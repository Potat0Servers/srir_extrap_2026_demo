% 06/07/2026
% Single-room baseline for the coupled-room transition dataset.
% The measured SRIRs still come from the real coupled rooms, but the model
% treats the complete transition as one room and ignores the dividing wall.

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

order_ISM_single_room = 1;     % ISM order for the virtual single room

idx_LS_rec_orig=1;         % original receiver position
idx_LS_rec_tar=20;          % target receiver position
fprintf('Receiver index: orig %d -> tar %d\n', idx_LS_rec_orig, idx_LS_rec_tar);
% 1 speaker position only
% 101 receiver positions in total (1~101)
% The physical room boundary in the dataset is deliberately ignored.

% geometry
geom.c = 343;                           % speed of sound in m/s
geom.room_s.dim = [9.1 6.6 2.8];        % virtual single-room geometry
geom.aperture.xy = [4.6 2.83];          % real aperture position, used only for dataset delay restoration
% note: origin set at the bottom-left corner of the virtual room


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


% Residual scaling is disabled for the single-room comparison regression.
residual_scale_param.mode = "off";
residual_scale_param.start = 0.050;
residual_scale_param.fade = 0.010;
residual_scale_param.gain = 1;

% Other Flags

flag.src_directivity_DS = false;     % implement source directivity for direct sound
% true: direct sound becomes brighter or darker with the loudspeaker orientation.
% false: direct sound only shifts in time and changes in amplitude.

flag.src_directivity_ERs = false;    % implement source directivity for early reflections

flag.beamform_extract = true;       % implement beamforming for extraction of arrivals

flag.plot_ism = true;   % plot the virtual single-room ISM paths




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
geom.aperture.pos = [geom.aperture.xy(1) geom.aperture.xy(2) geom.rec.orig.pos(3)];
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

% draw the virtual single-room boundary
geom.room_s.corners_xy = [0 0; geom.room_s.dim(1) 0; geom.room_s.dim(1) geom.room_s.dim(2); 0 geom.room_s.dim(2); 0 0];        
h_room_s = line(geom.room_s.corners_xy(:,1),geom.room_s.corners_xy(:,2),'Color','black','LineWidth',1.5,'LineStyle','--');

% adjust field of view
room_plot_margin = 0.5;
xlim([min(geom.room_s.corners_xy(:,1))-room_plot_margin max(geom.room_s.corners_xy(:,1))+room_plot_margin]);
ylim([min(geom.room_s.corners_xy(:,2))-room_plot_margin max(geom.room_s.corners_xy(:,2))+room_plot_margin]);

% draw source-receiver arrows
% original [red]
h2 = line([geom.src.orig.pos(1) geom.rec.orig.pos(1)],[geom.src.orig.pos(2) geom.rec.orig.pos(2)],'Color','red');
% target [green]
h3 = line([geom.src.tar.pos(1) geom.rec.tar.pos(1)],[geom.src.tar.pos(2) geom.rec.tar.pos(2)],'Color','green');

%% Virtual single-room SRIR extrapolation

% The caller supplies one virtual room spanning both physical rooms, so
% receiver positions on either side of the real wall are treated alike.
[srir_new, path_info] = extrapolate_srir_single_room_baseline( ...
    srir_orig, ...
    fs, ...
    geom, ...
    order_ISM_single_room, ...
    window_param, ...
    flag, ...
    residual_scale_param);





%% ================ EVALUATION ================
% Compare new (extrapolated) and original SRIRs to target SRIR

plot_time_vector = 0:1/fs:(size(srir_orig,1)/fs-1/fs);
plot_idx = 1:min(plotcutoff, size(srir_orig,1));

safe_db = @(x) 20*log10(max(abs(x), eps));

eval_single_baseline.rms.orig = rms(srir_orig(:,1));
eval_single_baseline.rms.new = rms(srir_new(:,1));
eval_single_baseline.rms.tar = rms(srir_tar(:,1));

eval_single_baseline.rms_db.orig = db(eval_single_baseline.rms.orig);
eval_single_baseline.rms_db.new = db(eval_single_baseline.rms.new);
eval_single_baseline.rms_db.tar = db(eval_single_baseline.rms.tar);

eval_single_baseline.error.orig_to_tar = rms(srir_orig(:,1) - srir_tar(:,1));
eval_single_baseline.error.new_to_tar = rms(srir_new(:,1) - srir_tar(:,1));

eval_single_baseline.error_db.orig_to_tar = db(eval_single_baseline.error.orig_to_tar);
eval_single_baseline.error_db.new_to_tar = db(eval_single_baseline.error.new_to_tar);

% display values in command window
disp(['Original. RMS = ',num2str(eval_single_baseline.rms_db.orig,4),'dB'])
disp(['Extrapolated. RMS = ',num2str(eval_single_baseline.rms_db.new,4),'dB'])
disp(['Target. RMS = ',num2str(eval_single_baseline.rms_db.tar,4),'dB'])
disp(['Waveform error (orig -> tar) = ',num2str(eval_single_baseline.error_db.orig_to_tar,4),'dB'])
disp(['Waveform error (new -> tar) = ',num2str(eval_single_baseline.error_db.new_to_tar,4),'dB'])

%% Arrival table

num_paths = numel(path_info.path_id);

eval_single_baseline.arrival_table = table( ...
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

disp(eval_single_baseline.arrival_table)

%% Time-domain: one figure 3 panels: original, extrapolated, target

figure;
subplot(3,1,1)
plot(plot_time_vector(plot_idx),safe_db(srir_orig(plot_idx,1)))
hold on;
title(['Single-room baseline: Original. RMS = ',num2str(eval_single_baseline.rms_db.orig,4),'dB'])
ylim([-55 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

subplot(3,1,2)
plot(plot_time_vector(plot_idx),safe_db(srir_new(plot_idx,1)))
hold on
title(['Single-room baseline: Extrapolated. RMS = ',num2str(eval_single_baseline.rms_db.new,4),'dB'])
ylim([-55 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

subplot(3,1,3)
plot(plot_time_vector(plot_idx),safe_db(srir_tar(plot_idx,1)))
hold on;
title(['Single-room baseline: Target. RMS = ',num2str(eval_single_baseline.rms_db.tar,4),'dB'])
ylim([-55 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

if save_figs; exportgraphics(gcf, 'singleRoomBaseline_TD_three_panel.pdf');end

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
if save_figs; exportgraphics(gcf, 'singleRoomBaseline_TD_comparison_orig.pdf');end

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
if save_figs; exportgraphics(gcf, 'singleRoomBaseline_TD_comparison_extrap.pdf');end

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
title('Single-room baseline: original SRIR with calculated arrival time marked')
ylim([-50 0])
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
title('Single-room baseline: extrapolated SRIR with calculated arrival time marked')
ylim([-50 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(plot_idx))])
box on
grid on

if save_figs; exportgraphics(gcf, 'singleRoomBaseline_arrival_markers.pdf');end

%% Frequency-domain (omni): 2 figures: target vs original, target vs extrapolated

figure
freqplot_smooth(srir_tar(:,1),fs)
hold on
freqplot_smooth(srir_orig(:,1),fs)
pbaspect([1.5 1 1]);
xlim([40 20000])
ylim([-70 20])
legend({'Target','Original'},'location','southwest')
title(['Single-room baseline: omni target vs original. Waveform error = ', ...
    num2str(eval_single_baseline.error_db.orig_to_tar,4),'dB'])
if save_figs; exportgraphics(gcf, 'singleRoomBaseline_FD_comparison_orig_omni.pdf');end

figure
freqplot_smooth(srir_tar(:,1),fs)
hold on
freqplot_smooth(srir_new(:,1),fs)
pbaspect([1.5 1 1]);
xlim([40 20000])
ylim([-70 20])
legend({'Target','Extrapolated'},'location','southwest')
title(['Single-room baseline: omni target vs extrapolated. Waveform error = ', ...
    num2str(eval_single_baseline.error_db.new_to_tar,4),'dB'])
if save_figs; exportgraphics(gcf, 'singleRoomBaseline_FD_comparison_extrap_omni.pdf');end
