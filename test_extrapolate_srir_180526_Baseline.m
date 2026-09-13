% Spatial room impulse response extrapolation using image source 
% reflections a from single spatial room impulse response
%
% Thomas McKenzie and Zhenxian Li, 2025-2026
% University of Edinburgh, UK, INSA de Lyon, France
% 
% Requirements:
% Spherical array processing toolbox: https://github.com/polarch/Spherical-Array-Processing
% Higher order ambisonics toolbox: https://github.com/polarch/Higher-Order-Ambisonics
% Binaural ambisonic preprocessing toolbox: https://github.com/thomas-mckenzie/binaural-ambisonic-preprocessing 
% mckenzie2025 binaural colouration model: https://sourceforge.net/p/amtoolbox/code/ci/mckenzie2025/tree/
% 6DoF dataset of SRIRs (choose eigenmike_SH version): https://zenodo.org/records/6382405 
% Genelec 8331A loudspeaker directivity dataset: https://zenodo.org/records/10255555   (detailed in this paper: https://aes2.org/publications/elibrary-page/?id=22373)


% clc;
clear workspace;
close all;


%% Init

% load binaural ambisonic decoder. Recommended settings [check in script]: 
% ambisonic_order = 4; 
% dualband_flag   = 1; 
% export_HRIRs    = 0; 
% ta_flag  = 1;
% aio_flag = 0;
% dfe_flag = 1;
% dbe_flag = 0; 

addpaths

% modified: cd to binaural-ambisonic-preprocessing-main so that relative paths in % modified
% load_ambisonic_configuration and its callees resolve correctly % modified
% cd(fullfile(fileparts(mfilename('fullpath')), 'binaural-ambisonic-preprocessing-main')); % modified

load_ambisonic_configuration; % modified
% cd(fileparts(mfilename('fullpath'))); % modified

% load SOFA file of 6dof SRIRs (choose eigenmike_SH version https://zenodo.org/records/6382405)
sofa1 = SOFAload('6DoF_SRIRs_eigenmike_SH_50percent_absorbers_enabled.sofa');
fs = sofa1.Data.SamplingRate;

%% Settings

dim_room = [7.87 5.75 2.91]; % room dimensions, from the ArXiv paper https://arxiv.org/pdf/2111.11882
ord_imgsrc = 2; % what order of image source to compute (recommended 2)

% Choose original and target SRIR source and receivers [fig1 ArXiv paper https://arxiv.org/pdf/2111.11882]:
% % original
idx_LS_src_orig=2;
idx_LS_rec_orig=1;
% target
idx_LS_src_tar=2;
idx_LS_rec_tar=5;

% Plotting
save_figs = false;
plotcutoff = fs/20; % how long to plot time-domain signals

% Flags
flag.src_directivity_DS = true; % implement source directivity for direct sound
flag.src_directivity_ERs = true; % implement source directivity for early reflections
flag.beamform_extract = true; % implement beamforming for extraction of arrivals

room_geometry_correction = true;  % correct geometry error in the reported measurements (recommended true)

%% Get original and target SRIRs

idx_LS_srcrec_orig = idx_LS_rec_orig*3-3+idx_LS_src_orig; % original
idx_LS_srcrec_tar = idx_LS_rec_tar*3-3+idx_LS_src_tar; % target

%read IR and postion
srir_orig = squeeze(sofa1.Data.IR(idx_LS_srcrec_orig,:,:))'; % original IR
srir_tar = squeeze(sofa1.Data.IR(idx_LS_srcrec_tar,:,:))'; % target IR (for evaluation)

% get source and receiver positions
src_rec.pos_src_orig = sofa1.SourcePosition(idx_LS_srcrec_orig,:);
src_rec.pos_rec_orig = sofa1.ListenerPosition(idx_LS_srcrec_orig,:);

src_rec.pos_src_tar = sofa1.SourcePosition(idx_LS_srcrec_tar,:);
src_rec.pos_rec_tar = sofa1.ListenerPosition(idx_LS_srcrec_tar,:);

src_rec.view_src_orig = sofa1.SourceView;


% %% Get original and target SRIRs

% idx_LS_srcrec_orig = idx_LS_rec_orig*3-3+idx_LS_src_orig; % original
% idx_LS_srcrec_tar = idx_LS_rec_tar*3-3+idx_LS_src_tar; % target

%read IR and postion
% srir_orig = squeeze(sofa1.Data.IR(idx_LS_srcrec_orig,:,:))'; % original IR

% % get source and receiver positions
% pos_src_orig = sofa1.SourcePosition(idx_LS_srcrec_orig,:);
% pos_list_orig = sofa1.ListenerPosition(idx_LS_srcrec_orig,:);
% 
% pos_src_tar = sofa1.SourcePosition(idx_LS_srcrec_tar,:);
% pos_list_tar = sofa1.ListenerPosition(idx_LS_srcrec_tar,:);

% Plot geometry and source-receiver positions of original and targets
SOFAplotGeometry(sofa1);   % plot the source and listen position
hold on;
% original [red]
h2 = line([src_rec.pos_src_orig(1) src_rec.pos_rec_orig(1)],[src_rec.pos_src_orig(2) src_rec.pos_rec_orig(2)],'Color','red');
% target [green]
h3 = line([src_rec.pos_src_tar(1) src_rec.pos_rec_tar(1)],[src_rec.pos_src_tar(2) src_rec.pos_rec_tar(2)],'Color','green');

%% Correct room geometry?
if room_geometry_correction
    % correct room geometry? negative means
    % the measured peak is detected earlier than ISM wall, so
    % -ve means ISM wall needs to come closer, and
    % +ve means ism wall should go further away
    % order:
    % floor z | ceiling z2 | back y | left x | front y2 | right x2
    correction_room_z = 0;
    correction_room_z2 = 0.21;
    correction_room_y = -0.28;
    correction_room_x = 0;
    correction_room_y2 = 0;
    correction_room_x2 = 0;

    % apply correction:
    dim_room = [dim_room(1)+correction_room_x+correction_room_x2 dim_room(2)+correction_room_y+correction_room_y2 dim_room(3)+correction_room_z+correction_room_z2]; % from the ArXiv paper
    src_rec.pos_src_orig(1) = src_rec.pos_src_orig(1) + correction_room_x;
    src_rec.pos_rec_orig(1) = src_rec.pos_rec_orig(1) + correction_room_x;
    src_rec.pos_src_orig(2) = src_rec.pos_src_orig(2) + correction_room_y;
    src_rec.pos_rec_orig(2) = src_rec.pos_rec_orig(2) + correction_room_y;
    src_rec.pos_src_orig(3) = src_rec.pos_src_orig(3) + correction_room_z;
    src_rec.pos_rec_orig(3) = src_rec.pos_rec_orig(3) + correction_room_z;

    src_rec.pos_src_tar(1) = src_rec.pos_src_tar(1) + correction_room_x;
    src_rec.pos_rec_tar(1) = src_rec.pos_rec_tar(1) + correction_room_x;
    src_rec.pos_src_tar(2) = src_rec.pos_src_tar(2) + correction_room_y;
    src_rec.pos_rec_tar(2) = src_rec.pos_rec_tar(2) + correction_room_y;
    src_rec.pos_src_tar(3) = src_rec.pos_src_tar(3) + correction_room_z;
    src_rec.pos_rec_tar(3) = src_rec.pos_rec_tar(3) + correction_room_z;
end


%% EXTRAPOLATE using function:
srir_new = extrapolate_srir_180526(srir_orig,fs,ord_imgsrc,src_rec,dim_room,flag);

%% ================ EVALUATION ================
% Compare new (extrapolated) and original SRIRs to target SRIR
plot_time_vector = 0:1/fs:(size(srir_orig,1)/fs-1/fs);

%% Time-domain: one figure 3 panels: original, extrapolated, target

figure;
subplot(3,1,1)
plot(plot_time_vector(1:plotcutoff),db(abs(srir_orig(1:plotcutoff,1))))
hold on;
title(['Original. RMS = ',num2str(db(rms(srir_orig(:,1))),4),'dB'])
ylim([-40 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(1:plotcutoff))])

subplot(3,1,2)
plot(plot_time_vector(1:plotcutoff),db(abs(srir_new(1:plotcutoff,1))))
hold on
title(['Extrapolated. RMS = ',num2str(db(rms(srir_new(:,1))),4),'dB'])
ylim([-40 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(1:plotcutoff))])

subplot(3,1,3)
plot(plot_time_vector(1:plotcutoff),db(abs(srir_tar(1:plotcutoff,1))))
hold on;
title(['Target. RMS = ',num2str(db(rms(srir_tar(:,1))),4),'dB'])
ylim([-40 0])
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(1:plotcutoff))])

% display values in command window
disp(['Original. RMS = ',num2str(db(rms(srir_orig(:,1))),4),'dB'])
disp(['Extrapolated. RMS = ',num2str(db(rms(srir_new(:,1))),4),'dB'])
disp(['Target. RMS = ',num2str(db(rms(srir_tar(:,1))),4),'dB'])



%% Time-domain: 2 figures: target vs original, target vs extrapolated

figure
hold on
ylim([-30 0])
plot(plot_time_vector(1:plotcutoff),db(abs(srir_tar(1:plotcutoff,1))))
plot(plot_time_vector(1:plotcutoff),db(abs(srir_orig(1:plotcutoff,1))))
legend({'Target','Original'})
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(1:plotcutoff))])
pbaspect([3 1 1]);
box on
grid on
if save_figs; exportgraphics(gcf, 'srir_extrap_TD_comparison_orig.pdf');end

figure
hold on
ylim([-30 0])
plot(plot_time_vector(1:plotcutoff),db(abs(srir_tar(1:plotcutoff,1))))
plot(plot_time_vector(1:plotcutoff),db(abs(srir_new(1:plotcutoff,1))))
legend({'Target','Extrapolated'})
ylabel('Magnitude (dB)')
xlabel('Time (s)')
xlim([0 max(plot_time_vector(1:plotcutoff))])
pbaspect([3 1 1]);
box on
grid on
if save_figs; exportgraphics(gcf, 'srir_extrap_TD_comparison_extrap.pdf');end

%% Render binaurally and predict binaural colouration
brir_orig = render_binaural(srir_orig,SH_ambisonic_binaural_decoder);
brir_new = render_binaural(srir_new,SH_ambisonic_binaural_decoder);
brir_tar = render_binaural(srir_tar,SH_ambisonic_binaural_decoder);

% reshape to use in model
brir_o = reshape(brir_orig,[],1,2);
brir_n = reshape(brir_new,[],1,2);
brir_t = reshape(brir_tar,[],1,2);

settings.smGL1 = 1; % smooth low frequencies in model [recommended here]

% Predict colouration - needs mckenzie2025 model
pbc2_orig = mckenzie2025(brir_o,brir_t,settings);
pbc2_new = mckenzie2025(brir_n,brir_t,settings);

% display values in command window
disp(['PBC (orig -> tar) = ', num2str(pbc2_orig,3)]);
disp(['PBC (new -> tar) = ', num2str(pbc2_new,3)]);

%% Frequency-domain (binaural): 2 figures: target vs original, target vs extrapolated

figure
subplot(1,2,1)
freqplot_smooth(brir_tar(:,1),fs)
hold on
freqplot_smooth(brir_orig(:,1),fs)
pbaspect([1.5 1 1]);
ylim([0 35])
xlim([40 20000])
title('Left')

subplot(1,2,2)
freqplot_smooth(brir_tar(:,2),fs)
hold on
freqplot_smooth(brir_orig(:,2),fs)
ylabel('')
yticklabels('')
pbaspect([1.5 1 1]);
ylim([0 35])
xlim([40 20000])
legend({'Target','Original'},'location','southwest')
title('Right')

aa=subplot(122);
aa.Position(1)=0.5;

if save_figs; exportgraphics(gcf, 'srir_extrap_FD_comparison_orig_bin.pdf');end

figure
subplot(1,2,1)
freqplot_smooth(brir_tar(:,1),fs)
hold on
freqplot_smooth(brir_new(:,1),fs)
pbaspect([1.5 1 1]);
ylim([0 35])
xlim([40 20000])
title('Left')

subplot(1,2,2)
freqplot_smooth(brir_tar(:,2),fs)
hold on
freqplot_smooth(brir_new(:,2),fs)
ylabel('')
yticklabels('')
pbaspect([1.5 1 1]);
ylim([0 35])
xlim([40 20000])
legend({'Target','Extrapolated'},'location','southwest')
title('Right')

aa=subplot(122);
aa.Position(1)=0.5;

if save_figs; exportgraphics(gcf, 'srir_extrap_FD_comparison_tar_bin.pdf');end

%% Plot horizontal DoA

srir_combined(:,:,1) =  srir_orig;
srir_combined(:,:,2) =  srir_new;
srir_combined(:,:,3) =  srir_tar;

figure;
[doa_hor,doa_hor_p,P_pwd] = plot_doa_horiz(srir_combined,fs);
yticklabels({'Original','Extrapolated','Target'})
set(gca,'FontSize',12)
pbaspect([3 1 1]);
if save_figs; exportgraphics(gcf, 'srir_extrap_hor_doa.pdf');end



%% Plot DoA 3D

figure;
[P_pwd_orig,doa_est_orig,~,grid_dirs] = get_pwd(srir_orig(1:fs*0.3,:),fs);
heatmap_plot_hammer(rad2deg(grid_dirs(:,1)),rad2deg(grid_dirs(:,2)),mag2db(P_pwd_orig));
colormap(flipud(bone))
set(gca,'FontSize',11)
k = colorbar;
xlabel(k,'Normalised power (dB)');
if save_figs; exportgraphics(gcf, 'srir_extrap_doa_original.pdf');end
title('Original')

figure
[P_pwd_new,doa_est_new,~,grid_dirs] = get_pwd(srir_new(1:fs*0.3,:),fs);
heatmap_plot_hammer(rad2deg(grid_dirs(:,1)),rad2deg(grid_dirs(:,2)),mag2db(P_pwd_new));
colormap(flipud(bone))
set(gca,'FontSize',11)
k = colorbar;
xlabel(k,'Normalised power (dB)');
if save_figs; exportgraphics(gcf, 'srir_extrap_doa_extrap.pdf');end
title('Extrapolated')

figure
[P_pwd_tar,doa_est_tar,~,grid_dirs] = get_pwd(srir_tar(1:fs*0.3,:),fs);
heatmap_plot_hammer(rad2deg(grid_dirs(:,1)),rad2deg(grid_dirs(:,2)),mag2db(P_pwd_tar));
colormap(flipud(bone))
set(gca,'FontSize',11)
k = colorbar;
xlabel(k,'Normalised power (dB)');
if save_figs; exportgraphics(gcf, 'srir_extrap_doa_target.pdf');end
title('Target')

% display values in command window
disp(['DoA (orig -> tar) = ',num2str(mean(abs(P_pwd_tar-P_pwd_orig)),3)]);
disp(['DoA (extrap -> tar) = ',num2str(mean(abs(P_pwd_tar-P_pwd_new)),3)]);

%% Horizontal spatial-time plot
figure('Position', [10 10 400 600])

spatialtimeplot_time = 0.05; %ms

subplot(3,1,1)
p_pwd_hor_orig = plot_doa_horiz_time(srir_orig(1:fs*spatialtimeplot_time,:),fs);
title('Original')

subplot(3,1,2)
p_pwd_hor_new = plot_doa_horiz_time(srir_new(1:fs*spatialtimeplot_time,:),fs);
title('Extrapolated')

subplot(3,1,3)
p_pwd_hor_tar = plot_doa_horiz_time(srir_tar(1:fs*spatialtimeplot_time,:),fs);
title('Target')

p_pwd_hor_all = [p_pwd_hor_orig p_pwd_hor_new p_pwd_hor_tar];
for fig1 = 1:3
subplot(3,1,fig1)
clim([min(db(p_pwd_hor_all(:))) max(db(p_pwd_hor_all(:)))-0])
end

% display values in command window
disp(['DoA temp/hor (orig -> tar) = ',num2str(mean(abs(p_pwd_hor_tar(:)-p_pwd_hor_orig(:))),3)]);
disp(['DoA temp/hor (extrap -> tar) = ',num2str(mean(abs(p_pwd_hor_tar(:)-p_pwd_hor_new(:))),3)]);



%% LISTEN

soundsc([srir_orig(:,1);srir_new(:,1);srir_tar(:,1)],fs)


%% declare functions
function out_SH = render_binaural(input,binaural_decoder) % render to a binaural audio

in_SH = input.';
out_SH = zeros(length(binaural_decoder(1,:,1))+length(in_SH)-1,length(binaural_decoder(1,1,:)));

% convolve each channel of the encoded signal with the decoder signal and sum the result
for i = 1:length(binaural_decoder(:,1,1))
    out_SH(:,1) = out_SH(:,1) + conv(binaural_decoder(i,:,1),in_SH(i,:))';
    out_SH(:,2) = out_SH(:,2) + conv(binaural_decoder(i,:,2),in_SH(i,:) )';
end
end

function [doa_est,normalized_doa_est_P_dB,P_pwd] = plot_doa_horiz(srir,fs)
% plot horizontal doa

% Tuneable parameters:
res_deg_azi = 2;
res_deg_ele = 90;
order = sqrt(size(srir,2))-1;
nSrc = 7; % 7 arrivals: direct sound + first-order reflections
numSamps = fs*0.3; % 0.3 seconds
highPassFilterFreq = 2000;
kappa = 40;

grid_dirs = grid2dirs(res_deg_azi,res_deg_ele,0,0); % Grid of directions to evaluate DoA estimation

% remove elevated directions -- only for a res_deg_ele of 90
grid_dirs = grid_dirs(2:end-1,:);

P_src = diag(ones(numSamps,1));
[~,filtHi,~] = ambisonic_crossover(highPassFilterFreq,fs);

doa_est = zeros(nSrc,2,length(srir(1,1,:)));
doa_est_P = zeros(nSrc,length(srir(1,1,:)));
P_pwd = zeros(size(grid_dirs,1),length(srir(1,1,:)));

for i = 1:size(srir,3)
    Y_src = filter(filtHi,1,srir(1:numSamps,:,i)); % high pass filter
    stVec = Y_src';
    sphCOV = stVec*P_src*stVec' + 1*eye((order+1)^2)/(4*pi);

    % DoA estimation
    [P_pwd(:,i), est_dirs_pwd,est_dirs_P] = sphPWDmap(sphCOV, grid_dirs, nSrc,kappa);
    est_dirs_pwd = est_dirs_pwd*180/pi; % convert to degs from rads

    % flip -ve values near -180 to +ve values
    negativeFlipLimit = -178;
    for j = 1:length(est_dirs_pwd(:,1))
        for k = 1:length(est_dirs_pwd(1,:))
            if est_dirs_pwd(j,k) < negativeFlipLimit
                est_dirs_pwd(j,k) = est_dirs_pwd(j,k) + 360;
            end
        end
    end
    doa_est(:,:,i) = est_dirs_pwd;
    doa_est_P(:,i) = est_dirs_P;
end

% normalized_doa_est_P = doa_est_P ./ max(doa_est_P,[],1); % NORMALISE
normalized_doa_est_P = doa_est_P; % DONT NORMALISE
normalized_doa_est_P_dB = mag2db(normalized_doa_est_P)/2;

% plot_thresh = -20; % for normalised powers
plot_thresh = min(normalized_doa_est_P_dB(:)); % for unnormalised powers

normalized_doa_est_P_dB( normalized_doa_est_P_dB < plot_thresh ) = plot_thresh;
cmap = flip(parula(256));
c_truncation = 20; c = cmap(c_truncation:end,:); % truncate yellow

doa_01 = rescale(normalized_doa_est_P_dB, 'InputMin',plot_thresh);
cspace = linspace(0,1,size(c,1));
for i = 1:size(srir,3)
    doa_color(:,:,i) = interp1(cspace, c(:,i), doa_01);
end

hold off
for i = nSrc:-1:1
    s = scatter(squeeze(doa_est(i,1,:)),1:size(srir,3),150,...
        squeeze(doa_color(i,:,:)),"x",'LineWidth',3);
    hold on
end

xlabel('Azimuth (°)');ylabel('');
xlim([negativeFlipLimit (negativeFlipLimit+360)]);xticks(-180:45:180);
colormap(c);
k = colorbar;
xlabel(k,'Normalised power (dB)');clim([plot_thresh 0]);
set(gcf, 'Color', 'w');pbaspect([1.7 1 1]);
box on;grid on;set(gca,'FontSize',16)

ylim([0.5 size(srir,3)+0.5]);
yticks(1:size(srir,3));
set(gca, 'YDir','reverse')
set(gca, 'XDir','reverse')
end

function [P_pwd,doa_est,doa_est_P,grid_dirs] = get_pwd(srir,fs)

degreeResolution = 2;
order = sqrt(size(srir,2))-1;
nSrc = 7; % 7 arrivals [DS and first order reflections]
% numSamps = fs*0.3; % 0.3 seconds
numSamps = size(srir,1);
highPassFilterFreq = 3000;
kappa = 40;

grid_dirs = grid2dirs(degreeResolution,degreeResolution,0,0); % Grid of directions to evaluate DoA estimation
P_src = diag(ones(numSamps,1));
[~,filtHi,~] = ambisonic_crossover(highPassFilterFreq,fs);

doa_est = zeros(nSrc,2);
doa_est_P = zeros(nSrc,1);
P_pwd = zeros(size(grid_dirs,1),1);

Y_src = filter(filtHi,1,srir(1:numSamps,:)); % high pass filter
stVec = Y_src';
sphCOV = stVec*P_src*stVec' + 1*eye((order+1)^2)/(4*pi);

% DoA estimation
[P_pwd(:), est_dirs_pwd,est_dirs_P] = sphPWDmap(sphCOV, grid_dirs, nSrc,kappa);

est_dirs_pwd = est_dirs_pwd*180/pi; % convert to degs from rads
% flip -ve values near -180 to +ve values
negativeFlipLimit = -170;
for j = 1:length(est_dirs_pwd(:,1))
    for k = 1:length(est_dirs_pwd(1,:))
        if est_dirs_pwd(j,k) < negativeFlipLimit
            est_dirs_pwd(j,k) = est_dirs_pwd(j,k) + 360;
        end
    end
end
doa_est(:,:) = est_dirs_pwd;
doa_est_P(:) = est_dirs_P;
end

function [P_pwd] = plot_doa_horiz_time(srir,fs)
% plot horizontal doa

% Tuneable parameters:
res_deg_azi = 10;
res_deg_ele = 90;
order = sqrt(size(srir,2))-1;
nSrc = 7;
numSamps = size(srir,1);
highPassFilterFreq = 2000;
kappa = 40;

grid_dirs = grid2dirs(res_deg_azi,res_deg_ele,0,0); % Grid of directions to evaluate DoA estimation
grid_dirs = grid_dirs(2:end-1,:); % remove elevated directions -- only for a res_deg_ele of 90

windowsize_ms = 4;
windowsize_samp = round(windowsize_ms/1000 * fs);
[~,filtHi,~] = ambisonic_crossover(highPassFilterFreq,fs);
P_src = diag(ones(windowsize_samp,1));

% % % No overlap:
% num_windows = numSamps/windowsize_samp;
% P_pwd = zeros(size(grid_dirs,1),num_windows);
% time_vec = 0:windowsize_ms:num_windows*windowsize_ms-windowsize_ms;
% for i = 1:num_windows
%     Y_src = filter(filtHi,1,srir((i-1)*windowsize_samp+1:i*windowsize_samp,:)); % high pass filter
%     stVec = Y_src';
%     sphCOV = stVec*P_src*stVec' + 1*eye((order+1)^2)/(4*pi);
% 
%     % DoA estimation
%     P_pwd(:,i) = sphPWDmap(sphCOV, grid_dirs, nSrc,kappa);
% end

% % % With overlap:
overlapFrac = 0.5;                     % <-- set the overlap amount (0–1)
hopsize     = round(windowsize_samp * (1 - overlapFrac));
num_windows = floor((numSamps - windowsize_samp) / hopsize) + 1; % Number of windows given overlap
w = tukeywin(windowsize_samp,overlapFrac);
P_pwd = zeros(size(grid_dirs,1), num_windows);
time_vec = ((0:num_windows-1) * hopsize) / fs * 1000;   % in ms

for i = 1:num_windows
    idx = (i-1)*hopsize + 1;
    frame = srir(idx : idx + windowsize_samp - 1, :);
    frame = frame.*w;
    Y_src = filter(filtHi, 1, frame);
    stVec = Y_src';
    sphCOV = stVec * P_src * stVec' + 1*eye((order+1)^2)/(4*pi);
    % DoA estimation
    P_pwd(:, i) = sphPWDmap(sphCOV, grid_dirs, nSrc, kappa);
end

%% Plot
surf(rad2deg(grid_dirs(:,1)),time_vec,flip(db(P_pwd)',2),'edgecolor','none')
view([0 90])
xlim([-180 180])
xlabel('Azimuth (°)');ylabel('Time (ms)');
k = colorbar;
xlabel(k,'Normalised power (dB)');
colormap(flipud(bone))
end