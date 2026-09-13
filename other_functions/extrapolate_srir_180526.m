function [srir_new] = extrapolate_srir_180526(srir_orig, fs, ord_ism, src_rec, dim_room, flag)
% extrapolate_srir
%
% Spatal extrapolation from a single SRIR to different source - receiver
% positions using the Image Source Method.
%
%   Input parameters:
%       srir_orig : Time-domain spatial room impulse response in Ambisonic
%                   format at the original source-receiver position,
%                   according to the following matrix dimensions:
%                   [# samples, # channels].
%       fs        : The sampling rate in Hz.
%       ord_ism   : The chosen order of the image source model.
%       src_rec   : A structure with information about the positions of the
%                   source and receivers:
%                   - pos_src_orig : [x y z] original position of the
%                       source in m
%                   - pos_rec_orig : [x y z] original position of the
%                       receiver in m
%                   - pos_src_tar : [x y z] target position of the
%                       source in m
%                   - pos_rec_tar : [x y z] target position of the
%                       receiver in m
%                   - view_src_orig : [x y z] the original source view in
%                       vector form
%       dim_room  : The dimensions of the room: [x y z] in m
%       flag      : An optional structure to choose the settings of the 
%                   code (logical - true or false):
%                   - flag.src_directivity_DS : to implement source
%                       directivity in the direct sound [default = true]
%                   - flag.src_directivity_ERs : to implement source
%                       directivity in the first-order early reflections
%                       [default = true]
%                   - flag.beamform_extract : to implement beamforming for
%                       directional extraction of arrivals [default = true]
%
%   Output parameters:
%       srir_new  : Time-domain spatial room impulse response in Ambisonic
%                   format at the target source-receiver position,
%                   according to the following matrix dimensions:
%                   [# samples, # channels].
%
%
% Requires:
% - Spherical Array Processing Toolbox (Politis, 2015)
%   (https://github.com/polarch/Spherical-Array-Processing)
%
% Thomas McKenzie, University of Edinburgh, 2025.
% thomas.mckenzie@ed.ac.uk


%% Initialise

if nargin < 6
    flag = struct();
end
if ~isfield(flag, 'src_directivity_DS')
    flag.src_directivity_DS     = true;
end
if ~isfield(flag, 'src_directivity_ERs')
    flag.src_directivity_ERs    = true;
end
if ~isfield(flag, 'beamform_extract')
    flag.beamform_extract       = true;
end

% Duration of window for each arrival extraction:
window_dur_ER_ms = 3; % how long to extract in ms (could do longer window for DS and shorter for others)
prewindow_ER_samp = fs*((window_dur_ER_ms/1000)/4); % num samples before calculated start sample of arrival (for arrival extraction)

window_dur_DS_ms = 3; % how long to extract in ms (could do longer window for DS and shorter for others)
prewindow_DS_samp = fs*((window_dur_DS_ms/1000)/4); % num samples before calculated start sample of arrival (for arrival extraction)

% Plots:
flag_plot = false; % plots for debugging
save_figs = false;
plotcutoff = fs/20; % how long to plot time-domain signals

if flag.src_directivity_DS
    % If using directional source, get source's direction:
    [src_view_orig(1), src_view_orig(2)] = cart2sph(src_rec.view_src_orig(1), src_rec.view_src_orig(2), src_rec.view_src_orig(3));
    src_view_orig(1) = rad2deg(src_view_orig(1));
    src_view_orig(2) = rad2deg(src_view_orig(2));
    src_view_orig(1) = src_view_orig(1) - 90; % rotate it 90 degrees - manual correction if using Arni 6DoF dataset

    % Shelving filters based on these measurements: (for the ARNI dataset, which uses
    % Genelec 8331A loudspeakers, this directivity is used: https://zenodo.org/records/10255555
    % (detailed in this paper: https://aes2.org/publications/elibrary-page/?id=22373)
    sofa_ls_directivity = SOFAload('LS_directivity_Calibrated_GENELEC_8331A.sofa');
    fs2 = sofa_ls_directivity.Data.SamplingRate;
end

%% Image source detection

% Original
[dist_ism_orig, toa_ism_orig, doa_ism_orig, dist_ism_orig_DS, toa_ism_orig_DS, doa_ism_orig_DS, flag_o1_ism_orig] = ism_calculate(src_rec.pos_rec_orig,src_rec.pos_src_orig,ord_ism,dim_room,fs,flag_plot);
if flag_plot
    view([0 90])
    xlim([-15 15+dim_room(1)])
    ylim([-12 12+dim_room(2)])
    set(gca,'FontSize',12)
    pbaspect([15+dim_room(1)+15 12+dim_room(2)+12 1])
    box on
    if save_figs; exportgraphics(gcf, 'srir_extrap_ism_orig.pdf'); end
end

% Target
[dist_ism_tar, toa_ism_tar, doa_ism_tar, dist_ism_tar_DS, toa_ism_tar_DS, doa_ism_tar_DS, ~] = ism_calculate(src_rec.pos_rec_tar,src_rec.pos_src_tar,ord_ism,dim_room,fs,flag_plot);
if flag_plot
    view([0 90])
    xlim([-15 15+dim_room(1)])
    ylim([-12 12+dim_room(2)])
    set(gca,'FontSize',12)
    pbaspect([15+dim_room(1)+15 12+dim_room(2)+12 20])
    box on
    if save_figs; exportgraphics(gcf, 'srir_extrap_ism_tar.pdf'); end
end

% Sort arrivals based on lowest distances (mean of original and target distances)
% This ensures the first (most important) arrivals are processed first.
[~,idx] = sort(mean([dist_ism_orig; dist_ism_tar]));

% If ISM is 2nd order, it seems to duplicate the direct sound path. Remove the index of the shortest path to get rid:
if ord_ism > 1 % if 2nd order or higher
    idx = idx(2:end);
end

% Sort
dist_ism_orig = dist_ism_orig(idx);
toa_ism_orig = toa_ism_orig(idx);
doa_ism_orig = doa_ism_orig(:,idx);

dist_ism_tar = dist_ism_tar(idx);
toa_ism_tar = toa_ism_tar(idx);
doa_ism_tar = doa_ism_tar(:,idx);

flag_o1_ism_orig = flag_o1_ism_orig(idx);

%% Compare measured and image source direct sound

% Calculate ToA of DS for measured and ISM:
[toa_meas_orig_DS,~] = find_direct_sound(abs(lowpass(highpass(srir_orig(:,1),700,fs),5000,fs)));
toa_diff_DS = toa_meas_orig_DS - toa_ism_orig_DS;

% PWD to estimate DoA of DS for original (measured)
% This will help to see if the image sources need rotation in any way (e.g. 90 degree rotation)
doa_meas_orig_DS = doa_pwd(srir_orig(toa_meas_orig_DS-prewindow_ER_samp:toa_meas_orig_DS-prewindow_ER_samp+window_dur_ER_ms/1000*fs,:),fs); % in degs
doa_meas_orig_DS = doa_meas_orig_DS(1,:);
% Calculate difference between DS DoA of measured and ISM:
doa_diff_DS = rad2deg(angdiff(deg2rad(doa_meas_orig_DS'), deg2rad(doa_ism_orig_DS)));

doa_diff_threshold = 45; % Threshold for correction (in degrees)
% If the measured and ISM DoA (of the DS) are offset:
if abs(doa_diff_DS(1,1)) > doa_diff_threshold
    doa_diff_DS_rnd = doa_diff_threshold*round(doa_diff_DS/doa_diff_threshold);
    disp(['DS DoA (meas) = ',num2str(doa_meas_orig_DS,3), ', DS DoA (ISM)', num2str(doa_ism_orig_DS',3),'. Mismatch detected. azi err = ',num2str(doa_diff_DS(1,1),3),'deg. Counter-rotating by ',num2str(doa_diff_DS_rnd(1,1)),' deg'])

    % Rotate ISM DoAs:
    doa_ism_orig_DS = doa_ism_orig_DS - doa_diff_DS_rnd;
    doa_ism_tar_DS = doa_ism_tar_DS - doa_diff_DS_rnd;

    doa_ism_orig = doa_ism_orig - doa_diff_DS_rnd;
    doa_ism_tar = doa_ism_tar - doa_diff_DS_rnd;
end

% Analyse how well matched the ISM and the measurement DS timing is

toa_diff_threshold = 0.1; % threshold for correction (in ms)
toa_diff_threshold_samp = toa_diff_threshold/1000 * fs;
% If the measured and ISM times are offset:
if abs(toa_diff_DS) > toa_diff_threshold_samp
    disp(['Mismatch between time of DS of meas and ISM: ',num2str(toa_diff_DS/fs*1000,3),' ms. Counter-delaying ISM by ',num2str(round(toa_diff_DS)),' samples'])

    % Counter-delay ISM times to nearest sample:
    toa_ism_orig_DS = toa_ism_orig_DS + round(toa_diff_DS);
    toa_ism_orig = toa_ism_orig + round(toa_diff_DS);
    toa_ism_tar_DS = toa_ism_tar_DS + round(toa_diff_DS);
    toa_ism_tar = toa_ism_tar + round(toa_diff_DS);
end

%% Plot:
% Put an x on the direct amplitude plot to see where our detected arrivals are
if flag_plot
        figure;hold on; plot(db(abs(srir_orig(1:plotcutoff,1)))); %plot(db(abs(srir_direct(:,1))));
        text(round(toa_ism_orig_DS),db(abs(srir_orig(round(toa_ism_orig_DS),1))),'x DS')
        for i = 1:size(toa_ism_orig,2)
            text(round(toa_ism_orig(1,i)),db(abs(srir_orig(round(toa_ism_orig(1,i)),1))),['x ', num2str(i)],'Clipping','on')
        end
    xlim([0 plotcutoff])
    ylim([-40 0])
end

%% ================ EXTRAPOLATION ================
% Window + beamform out the arrivals from the SRIR, rotate + EQ + delay + gain, and add back in

% Create the new SRIR:
    srir_arrival_removed = srir_orig;
    srir_unalt = srir_orig;

% Begin plot (is finished after extrapolation)
if flag_plot
    figure
    plot(srir_unalt(1:fs/10,1))
    hold on
    ylim([-1 1])
end

% Work out transform difference between original and target position
% Distance / gain - use the ratio of old to new distance to calculate gain -- e.g. if orig -> tar means an arrival increases in distance, level should decrease
dist_diff_transform_DS = (dist_ism_orig_DS ./ dist_ism_tar_DS);
dist_diff_transform = (dist_ism_orig ./ dist_ism_tar);

%% % % % % % % % EARLY REFLECTIONS:
for i = 1:length(toa_ism_orig) % For each IS
    if flag_plot
        text(toa_ism_orig(i)-prewindow_ER_samp,srir_arrival_removed(toa_ism_orig(i)-prewindow_ER_samp,1),['X',num2str(i)],'Color','green')
        text(toa_ism_orig(i)-prewindow_ER_samp+window_dur_ER_ms/1000*fs,srir_arrival_removed(toa_ism_orig(i)-prewindow_ER_samp+window_dur_ER_ms/1000*fs,1),['X',num2str(i)],'Color','red')
    end

    % Remove arrival
    flag_DS = 0;
    [srir_arrival,srir_arrival_removed] = srir_arrival_remove(srir_arrival_removed,srir_unalt,fs,toa_ism_orig(i)-prewindow_ER_samp,window_dur_ER_ms,flag.beamform_extract,doa_ism_orig(1,i),doa_ism_orig(2,i),flag_DS);

    % Get angle difference between the original and target DoA
    doa_rot = rad2deg(angdiff(deg2rad(doa_ism_orig(:,i)), deg2rad(doa_ism_tar(:,i))));

    % Rotate the arrival:
    srir_arrival_rot = rotateHOA_N3D(srir_arrival,doa_rot(1),doa_rot(2),0);

    if flag.src_directivity_ERs
        % Early Reflection Directivity (ie account for changes in loudspeaker's directivity)
        if flag_o1_ism_orig(i) % Only for first-order reflections

            % Calculate the difference between the ideal source view and the actual original and target source views:
            vec_src = azel2vec(src_view_orig(1),src_view_orig(2));
            vec_ref_orig = azel2vec(doa_ism_orig(1,i),doa_ism_orig(2,i));
            vec_ref_tar = azel2vec(doa_ism_tar(1,i),doa_ism_tar(2,i));

            ang_diff_orig = acosd(dot(vec_ref_orig, -vec_src));
            ang_diff_tar = acosd(dot(vec_ref_tar, -vec_src));

            % % DEBUG:
            % origin = [0,0,0];
            % figure;hold on;
            % plot3([origin(1) -vec_src(1)],[origin(2) -vec_src(2)],[origin(3) -vec_src(3)],'k-^', 'LineWidth',3);
            % plot3([origin(1) vec_ref_orig(1)],[origin(2) vec_ref_orig(2)],[origin(3) vec_ref_orig(3)],'r-^', 'LineWidth',3);
            % plot3([origin(1) vec_ref_tar(1)],[origin(2) vec_ref_tar(2)],[origin(3) vec_ref_tar(3)],'g-^', 'LineWidth',3);
            % grid on;
            % xlabel('X axis'), ylabel('Y axis'), zlabel('Z axis')
            % set(gca,'CameraPosition',[1 2 3]);
            % xlim([-1 1]); ylim([-1 1]);zlim([-1 1])

            shelf_gain = (ang_diff_orig - ang_diff_tar) / 6; % negative for dullen, positive for brighten

            % Scale from 0 degrees (ie straight on, so flat shelf filter) to 180
            % degrees (ie completely behind it, so 30dB shelf cut):
            shelf_filt = shelvingFilter(shelf_gain,0.8,1000,"highpass",SampleRate=fs); % approximate parameters based on Genelec 8331A
            srir_arrival_rot = shelf_filt(srir_arrival_rot); % apply the filter
        end
    end

    % Apply gain and add back in at new ToA
    srir_arrival_removed(toa_ism_tar(i)-prewindow_ER_samp+1:toa_ism_tar(i)-prewindow_ER_samp+size(srir_arrival,1),:) ...
        = srir_arrival_removed(toa_ism_tar(i)-prewindow_ER_samp+1:toa_ism_tar(i)-prewindow_ER_samp+size(srir_arrival,1),:) + ...
        srir_arrival_rot * dist_diff_transform(i);
end

%% % % % % % % % DIRECT SOUND:

% Extract DS from SRIR_unalt, don't use beamforming for residual removal:
% [srir_arrival,srir_arrival_removed] = srir_arrival_remove(srir_arrival_removed,srir_unalt,fs,toa_ism_orig_DS-prewindow_DS_samp,window_dur_DS_ms,0);
% Extract DS from SRIR_unalt, but remove DS beam from processed SRIR at DS ToA:
flag_DS = 1;
[srir_arrival,srir_arrival_removed] = srir_arrival_remove(srir_arrival_removed,srir_unalt,fs,toa_ism_orig_DS-prewindow_DS_samp,window_dur_DS_ms,flag.beamform_extract,doa_ism_orig_DS(1),doa_ism_orig_DS(2),flag_DS);

% Get angle difference between the original and target DoA
doa_rot = rad2deg(angdiff(deg2rad(doa_ism_orig_DS), deg2rad(doa_ism_tar_DS)));
% Rotate the arrival:
srir_arrival_rot = rotateHOA_N3D(srir_arrival,doa_rot(1),doa_rot(2),0);

if flag.src_directivity_DS
    % Direct Sound Directivity (ie account for changes in loudspeaker's directivity)

    % The target is 180 degrees from the view of the source (ie view of receiver) - so flip it
    src_view_tar = src_view_orig;
    src_view_tar(1) = src_view_tar(1)+180;

    % Calculate difference between the ideal source view and the actual original and target source views:
    rec_view_orig = rad2deg(angdiff(deg2rad(src_view_tar'), deg2rad(doa_ism_orig_DS)));
    rec_view_tar = rad2deg(angdiff(deg2rad(src_view_tar'), deg2rad(doa_ism_tar_DS)));

    % Scale from 0 degrees (ie straight on, so flat shelf filter) to 180
    % degrees (ie completely behind it, so 30dB shelf cut):
    % First from original, shelf boost to get to flat:
    ir_direc_orig = squeeze(sofa_ls_directivity.Data.IR(1,3241+round(abs(rec_view_orig(1))),:));
    shelf_filt_orig = ir2lowpass(ir_direc_orig,fs2,1,0);
    % % Approx version:
    % shelf_gain_orig = abs(rec_view_orig(1))/6;
    % shelf_filt_orig = shelvingFilter(shelf_gain_orig,0.8,1000,"highpass",SampleRate=fs);

    % Then from target, shelf cut to get to 'correct' directivity:
    % IR fit:
    ir_direc_tar = squeeze(sofa_ls_directivity.Data.IR(1,3241+round(abs(rec_view_tar(1))),:));
    shelf_filt_tar = ir2lowpass(ir_direc_tar,fs2,0,0);
    % % Approx version:
    % shelf_gain_tar = abs(rec_view_tar(1))/6;
    % shelf_filt_tar = shelvingFilter(-shelf_gain_tar,0.8,1000,"highpass",SampleRate=fs);

    % % DEBUG: Visualise the directivity filter?
    % irTest = zeros(fs*2,1);
    % irTest(10) = 0.9;
    % irFilt = shelf_filt_orig(irTest);
    % irFilt = shelf_filt_tar(irFilt);
    % figure;
    % freqplot(irTest,fs);
    % hold on;
    % freqplot(irFilt,fs);

    % Apply the filters:
    srir_arrival_rot = shelf_filt_orig(srir_arrival_rot);
    srir_arrival_rot = shelf_filt_tar(srir_arrival_rot);
end

% Set the residual up to the end of the target DS ToA to zero:
% (important for when the target source is further than the original source)
srir_arrival_removed(1:toa_ism_tar_DS-prewindow_DS_samp+size(srir_arrival,1),:) = 0;
srir_resid(1:toa_ism_tar_DS-prewindow_DS_samp+size(srir_arrival,1),:) = 0;

% Apply gain and add back in the DS at new ToA
srir_arrival_removed(toa_ism_tar_DS-prewindow_DS_samp+1:toa_ism_tar_DS-prewindow_DS_samp+size(srir_arrival,1),:) ...
    = srir_arrival_removed(toa_ism_tar_DS-prewindow_DS_samp+1:toa_ism_tar_DS-prewindow_DS_samp+size(srir_arrival,1),:) + ...
    srir_arrival_rot*dist_diff_transform_DS;

if flag_plot
    % Finish off the plot from earlier
    hold on
    plot(srir_arrival_removed(1:fs/10,1))
    ylim([-1 1])
    legend({'Original','Extrapolated'})
end

% assign new srir
    srir_new = srir_arrival_removed;


end


%% Other functions

function [locD,ValD,pks,lcs] = find_direct_sound(ir)
% Finds direct sound time and amplitude

absir = abs(ir) ./ max(abs(ir)); % normalise to max value
[pks,lcs]=findpeaks(absir,"MinPeakDistance",50,MinPeakHeight=0.05);  % find peak

% Return the index (loc) and value (val) of the first peak:
locD = lcs(1);
ValD = pks(1);
end

function [dist_ism, toa_ism, doa_ism, dist_DS_ism, toa_DS_ism, doa_DS_ism,flag_o1_ism] = ism_calculate(coord_rec,coord_src,ord_ism,dim_room,fs,flag_plot)
% Image source model

c = 343; % Speed of sound (m/s)

if flag_plot
    h = figure;
    plotRoom(dim_room,coord_rec,coord_src,h)
    hold on
end

Lx = dim_room(1);
Ly = dim_room(2);
Lz = dim_room(3);

x = coord_src(1);
y = coord_src(2);
z = coord_src(3);

% First-order ISM:
if ord_ism == 1
    xyz_src = [  x -y -z;...
        -x  y -z;...
        -x  -y  z;...
        x -y -z;...
        -x  y -z;...
        -x  -y  z].';

    xyz_room =  [0 0 0;...
        0 0 0;...
        0 0 0;...
        2*Lx 0 0;...
        0 2*Ly 0;...
        0 0 2*Lz].';

    coords_ism = xyz_room-xyz_src;

    for kk=1:size(xyz_src,2)
        coord_ism=coords_ism(:,kk);
        if flag_plot
            plot3(coord_ism(1),coord_ism(2),coord_ism(3),"g*")
        end
    end

else
    % Second or higher order ISM:
    xyz_src = [-x -y -z;...
        -x -y  z;...
        -x  y -z;...
        -x  y  z;...
        x -y -z;...
        x -y  z;...
        x  y -z;...
        x  y  z].';
    nVect = -(ord_ism-1):(ord_ism-1);
    lVect = -(ord_ism-1):(ord_ism-1);
    mVect = -(ord_ism-1):(ord_ism-1);

    coords_ism_tot=[];
    xyz_diff_lim =  [min(nVect)*2*Lx; min(lVect)*2*Ly; min(mVect)*2*Lz];
    for n = nVect
        for l = lVect
            for m = mVect
                xyz_diff = [n*2*Lx; l*2*Ly; m*2*Lz];
                coords_ism = xyz_diff - xyz_src;

                % Only want ISM up to specified order
                delete_ism=[];
                i2=0;
                for i1 = 1:size(xyz_src,2)
                    coord_imgsr = coords_ism(:,i1);
                    if ~isempty(coord_imgsr(coord_imgsr<xyz_diff_lim))
                        i2 = i2+1;
                        delete_ism(i2) = i1;
                    else
                    end
                end
                coords_ism(:,delete_ism) = [];

                coords_ism_tot = [coords_ism_tot  coords_ism];
                for kk=1:size(coords_ism,2)
                    coord_ism=coords_ism(:,kk);

                    if flag_plot
                        plot3(coord_ism(1),coord_ism(2),coord_ism(3),"k*")
                        % text(coord_ism(1),coord_ism(2),coord_ism(3),[num2str(n),',',num2str(l),',',num2str(m),',',num2str(kk)])
                        plot3([coord_ism(1);coord_rec(1)],[coord_ism(2);coord_rec(2)],[coord_ism(3);coord_rec(3)],'Color',[0.85 0.85 0.85])
                    end
                end
            end
        end
    end
    coords_ism = coords_ism_tot;

    % Also need to calculate 1st order ISs (need the flags for the source directivity processing):
    xyz_src = [x -y -z;...
        -x  y -z;...
        -x  -y  z;...
        x -y -z;...
        -x  y -z;...
        -x  -y  z].';
    xyz_room =  [0 0 0;...
        0 0 0;...
        0 0 0;...
        2*Lx 0 0;...
        0 2*Ly 0;...
        0 0 2*Lz].';
    coords_ism_o1 = xyz_room-xyz_src;
end

if flag_plot
    plot3(coord_src(1),coord_src(2),coord_src(3),"^",'LineWidth',2,'MarkerEdgeColor',[0.4660 0.6740 0.1880])
    plot3(coord_rec(1),coord_rec(2),coord_rec(3),"o",'LineWidth',2,'MarkerEdgeColor',[0.8500 0.3250 0.0980])
    view(0,90)
end

% Calculate ToAs:
for i = 1:size(coords_ism,2)
    coord_ism = coords_ism(:,i);

    % Calculate the ToA (in samples) at which the contribution occurs
    dist_ism(i) = norm((coord_ism(:)-coord_rec(:)),2); % distance from IS to receiver
    toa_ism(i) = round((fs/c).*dist_ism(i)); % in samples from beginning, time = 0

    xyz_diff = coord_ism-coord_rec';
    hyp = sqrt(xyz_diff(1)^2+xyz_diff(2)^2);
    elevation(i) = atan(xyz_diff(3)./(hyp+eps));
    azimuth(i) = atan2(xyz_diff(2),xyz_diff(1));
end

doa_ism = [azimuth; elevation]*180/pi;

% Calculate the ToA and DoA of the direct sound
dist_DS_ism = norm((coord_src(:)-coord_rec(:)),2); % distance from actual src to rec
toa_DS_ism = round((fs/c).*dist_DS_ism); % in samples from beginning, time = 0

xyz_diff = coord_src'-coord_rec';
hyp = sqrt(xyz_diff(1)^2+xyz_diff(2)^2);
elevation = atan(xyz_diff(3)./(hyp+eps));
azimuth = atan2(xyz_diff(2),xyz_diff(1));
doa_DS_ism = [azimuth; elevation]*180/pi;

% Find and flag all the first order ISs
if ord_ism == 1
    flag_o1_ism = ones(size(coords_ism,2),1);
else
    flag_o1_ism = flagMatchingRows(coords_ism, coords_ism_o1);
end
end

function [srir_arrival,srir_arrival_removed] = srir_arrival_remove(srir_in,srir_unalt,fs,time_arrival_samp,arrival_dur_ms,flag_beamform_extract,extract_az_deg,extract_el_deg,flag_DS)
% Window out part of the input SRIR, output the SRIR window and the SRIR with the window removed

% Ramp on and ramp off
arrival_window_samp = [5 10];

arrival_window = ones(arrival_dur_ms/1000*fs,size(srir_in,2));
arrival_window(1:arrival_window_samp(1),:) = repmat(linspace(0,1,arrival_window_samp(1))',1,size(srir_in,2));
arrival_window(end-arrival_window_samp(2)+1:end,:) = repmat(linspace(1,0,arrival_window_samp(2))',1,size(srir_in,2));

srir_extract_window = srir_in * 0;
srir_extract_window(time_arrival_samp+1:time_arrival_samp+arrival_dur_ms/1000*fs,:) = arrival_window;

% Remove window from SRIR
srir_arrival_removed = srir_in .* (1-srir_extract_window);

% Extract arrival from original (unaltered) SRIR
srir_arrival = srir_unalt(time_arrival_samp+1:time_arrival_samp+arrival_dur_ms/1000*fs,:) .* arrival_window;

if flag_beamform_extract

    % % plot (debug)
    % figure;
    % subplot(2,2,1);
    % [P_pwd,~,~,grid_dirs] = get_pwd(srir_arrival,fs);
    % heatmap_plot(rad2deg(grid_dirs(:,1)),rad2deg(grid_dirs(:,2)),P_pwd);
    % colormap(flipud(bone))
    % % clim([0 0.3])
    % set(gca,'FontSize',11);
    % k = colorbar;
    % xlabel(k,'Normalised power (dB)');
    % title('original');

    % Perform extraction and removal:
    if flag_DS == 1 % If DS, don't use the beamformed arrival (only use the beam-removed residual)
        [~, srir_arrival_residual] = beamform_extract_remove(srir_arrival, extract_az_deg, extract_el_deg);
    else % If early reflections, use both beamformed arrival and beam-removed residual
        [srir_arrival, srir_arrival_residual] = beamform_extract_remove(srir_arrival, extract_az_deg, extract_el_deg);
    end

    % Add the residual back to the overall residual SRIR
    srir_arrival_removed(time_arrival_samp+1:time_arrival_samp+arrival_dur_ms/1000*fs,:) = ...
        srir_arrival_removed(time_arrival_samp+1:time_arrival_samp+arrival_dur_ms/1000*fs,:) + ...
        srir_arrival_residual;

    % % Continue plot (debug)
    % subplot(2,2,2);
    % [P_pwd2,~,~,grid_dirs2] = get_pwd(srir_arrival_residual,fs);
    % heatmap_plot(rad2deg(grid_dirs2(:,1)),rad2deg(grid_dirs2(:,2)),P_pwd2);
    % colormap(flipud(bone))
    % % clim([0 0.3])
    % set(gca,'FontSize',11)
    % k = colorbar;
    % xlabel(k,'Normalised power (dB)');
    % title(['original with arrival removed']);
    %
    % subplot(2,2,3);
    % [P_pwd2,~,~,grid_dirs2] = get_pwd(srir_arrival,fs);
    % heatmap_plot(rad2deg(grid_dirs2(:,1)),rad2deg(grid_dirs2(:,2)),P_pwd2);
    % colormap(flipud(bone))
    % % clim([0 0.3])
    % set(gca,'FontSize',11)
    % k = colorbar;
    % xlabel(k,'Normalised power (dB)');
    % title(['arrival with beamform ']);
    %
    % subplot(2,2,4);
    % [P_pwd2,~,~,grid_dirs2] = get_pwd(srir_arrival_removed(time_arrival_samp+1:time_arrival_samp+arrival_dur_ms/1000*fs,:),fs);
    % heatmap_plot(rad2deg(grid_dirs2(:,1)),rad2deg(grid_dirs2(:,2)),P_pwd2);
    % colormap(flipud(bone))
    % % clim([0 0.3])
    % set(gca,'FontSize',11)
    % k = colorbar;
    % xlabel(k,'Normalised power (dB)');
    % title(['arrival removed. error = ', num2str(mean(abs(srir_in(time_arrival_samp+1:time_arrival_samp+arrival_dur_ms/1000*fs,:)-(srir_arrival_removed(time_arrival_samp+1:time_arrival_samp+arrival_dur_ms/1000*fs,:)+srir_arrival)),'all'),3)]);
    %%

end
end

function[doa_est,normalised_doa_est_P_dB,P_pwd,doa_est_P] = doa_pwd(srir,fs)
% Calculates DoA using planewave decomposition (PWD)

% Tuneable parameters:
res_deg_azi = 1;
res_deg_ele = 1;
order = sqrt(size(srir,2))-1;
nSrc = 1;
numSamps = size(srir,1);
highPassFilterFreq = 700;
kappa = 20;

% Grid of directions to evaluate DoA estimation
grid_dirs = grid2dirs(res_deg_azi,res_deg_ele,0,0);

% Remove elevated directions (only for a res_deg_ele of 90)
grid_dirs = grid_dirs(2:end-1,:);
P_src = diag(ones(numSamps,1));

doa_est = zeros(nSrc,2,length(srir(1,1,:)));
doa_est_P = zeros(nSrc,length(srir(1,1,:)));
P_pwd = zeros(size(grid_dirs,1),length(srir(1,1,:)));

for i = 1:size(srir,3)
    srir = highpass(srir,highPassFilterFreq,fs);
    srir = lowpass(srir,5000,fs);
    Y_src = srir(:,:,i);
    stVec = Y_src';
    sphCOV = stVec*P_src*stVec' + 1*eye((order+1)^2)/(4*pi);

    % DoA estimation
    [P_pwd(:,i), est_dirs_pwd,est_dirs_P] = sphPWDmap(sphCOV, grid_dirs, nSrc,kappa);
    est_dirs_pwd = est_dirs_pwd*180/pi; % Convert from radians to degrees

    % Flip -ve values near -180 to +ve values
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

% normalised_doa_est_P = doa_est_P ./ max(doa_est_P,[],1); % Normalise
normalised_doa_est_P = doa_est_P; % Don't normalise
normalised_doa_est_P_dB = mag2db(normalised_doa_est_P)/2;
end

function flags = flagMatchingRows(mainMatrix, otherMatrix)
% Preallocate flag array
numCols = size(mainMatrix, 2);
flags = zeros(numCols, 1);

% Loop through each col in mainMatrix
for i = 1:numCols
    % Check if this col exists in otherMatrix
    match = ismember(mainMatrix(:,i)', otherMatrix', 'rows');
    flags(i) = match;
end
end

function v = azel2vec(az, el)
% Converts azimuth (az) and elevation (el) in degrees to 3D unit vector
az_rad = deg2rad(az);
el_rad = deg2rad(el);
x = cos(el_rad) .* cos(az_rad);
y = cos(el_rad) .* sin(az_rad);
z = sin(el_rad);
v = [x; y; z];
end



function [out_beam, out_resid] = beamform_extract_remove(in, azDeg, elDeg)
% beamform in a direction and output the beam and the input with the beam
% subtracted
N = round(sqrt(size(in,2)) - 1);           % HOA order (because C = (N+1)^2 in 3-D)
azRad = deg2rad(azDeg);
elRad = deg2rad(elDeg);
Y = getRealSH_N3D(N, azRad, elRad);    % 1×C steering vector (unit-energy)

% Build Gaussian weights: w_n = exp(–n/σ) then expand to channel vector
% sigma = 5; % width of beam: 1 for wide, inf for narrow
% w_per_order = exp( -(0:N).' / sigma );   % column vector, (N+1)×1
% w_per_order = beamWeightsCardioid2Spherical(N);
w_per_order = ones(N+1,1); % or just ones for sharpest beam

w_vec      = expandWeights_ACN(w_per_order);  % 1×C, repeated per order
Yw         = Y .* w_vec;                 % apply taper

s = in * Yw.';                     % Decode: Ns×1 plane-wave signal
out_beam = s * Yw;                   % Encode: Ns×C steered HOA signal
out_resid = in - out_beam;

% fs = 48000;
%     figure;
% subplot(2,2,1);
% [P_pwd,~,~,grid_dirs] = get_pwd(in,fs);
% heatmap_plot(rad2deg(grid_dirs(:,1)),rad2deg(grid_dirs(:,2)),P_pwd);
% colormap(flipud(bone))
% clim([0 max(abs(P_pwd))])
% set(gca,'FontSize',11);
% k = colorbar;
% xlabel(k,'Normalised power (dB)');
% title(['original. Max = ',num2str(max(abs(P_pwd)),3)]);
% 
% subplot(2,2,2);
% [P_pwd2,~,~,grid_dirs2] = get_pwd(out_beam,fs);
% heatmap_plot(rad2deg(grid_dirs2(:,1)),rad2deg(grid_dirs2(:,2)),P_pwd2);
% colormap(flipud(bone))
% clim([0 max(abs(P_pwd))])
% set(gca,'FontSize',11)
% k = colorbar;
% xlabel(k,'Normalised power (dB)');
% title(['beam. Max = ',num2str(max(abs(P_pwd2)),3)]);
% 
% subplot(2,2,3);
% [P_pwd2,~,~,grid_dirs2] = get_pwd(out_resid,fs);
% heatmap_plot(rad2deg(grid_dirs2(:,1)),rad2deg(grid_dirs2(:,2)),P_pwd2);
% colormap(flipud(bone))
% clim([0 max(abs(P_pwd))])
% set(gca,'FontSize',11)
% k = colorbar;
% xlabel(k,'Normalised power (dB)');
% title(['residual. Max = ',num2str(max(abs(P_pwd2)),3)]);
% 
% subplot(2,2,4);
% [P_pwd2,~,~,grid_dirs2] = get_pwd(out_resid+out_beam,fs);
% heatmap_plot(rad2deg(grid_dirs2(:,1)),rad2deg(grid_dirs2(:,2)),P_pwd2);
% colormap(flipud(bone))
% clim([0 max(abs(P_pwd))])
% set(gca,'FontSize',11)
% k = colorbar;
% xlabel(k,'Normalised power (dB)');
% title(['reconstructed. error = ', num2str(mean(abs(in-(out_resid+out_beam)),'all'),3)]);

end

function Y = getRealSH_N3D(N, az, el)
% getRealSH_N3D  Compute real, N3D-normalized SH coefficients (ACN order)
%
%   Y = getRealSH_N3D(N, az, el)
%       N    : maximum SH order
%       az   : azimuth  (rad)
%       el   : elevation (rad)
theta = pi/2 - el;                % colatitude
nCh   = (N+1)^2;
Y     = zeros(1, nCh);            % pre-allocate

for n = 0:N
    % Associated Legendre polynomials P_n^m(cos θ), m = 0…n
    P = legendre(n, cos(theta), 'sch');   % 'sch' gives Schmidt-semi-norm.

    for m = -n:n
        idx = n*(n+1) + m + 1;    % ACN channel index (0-based → 1-based)
        Pnm = P(abs(m)+1);        % Retrieve correct order |m|

        % N3D normalization factor K_n^m
        K = sqrt((2*n+1)/(4*pi) * factorial(n-abs(m))/factorial(n+abs(m)));

        if m > 0
            Y(idx) = sqrt(2) * K * Pnm * cos( m * az );
        elseif m < 0
            Y(idx) = sqrt(2) * K * Pnm * sin( abs(m) * az );
        else % m == 0
            Y(idx) =         K * Pnm;
        end
    end
end
% Y is already N3D-normalized; ensure unit-energy for safety
Y = Y / norm(Y);
end

function wvec = expandWeights_ACN(w_order)
% expandWeights_ACN  Convert an (N+1)×1 vector of per-order weights
%                    into a 1×(N+1)^2 vector aligned to ACN channel order.
%
N = numel(w_order) - 1;           % highest order
wvec = zeros(1, (N+1)^2);
idx  = 1;
for n = 0:N
    numM = 2*n + 1;               % number of SHs for this order
    wvec(idx : idx+numM-1) = w_order(n+1);
    idx = idx + numM;
end
end

function [P_pwd,doa_est,doa_est_P,grid_dirs] = get_pwd(srir,fs)

degreeResolution = 2;
order = sqrt(size(srir,2))-1;
nSrc = 7;
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

function shelf = ir2lowpass(ir,fs,boostFlag,plotFlag)
% ir2lowpass computes the shelving filter coefficients for matlab's 
% function shelvingFilter such to match the frequency response of a
% measured IR (e.g. a loudspeaker directivity measurement). 
% 
% Inputs: 
% ir[length of IR x 1]              % must be mono
% fs[1 x 1]                         
% 
% Outputs:
% shelf                       % output of shelvingFilter() with the fit parameters
% 
if nargin<4 % default is cut
    plotFlag = 0; % 0 don't plot, 1 plot
end

if nargin<3 % default is cut
    boostFlag = 0; % 0 for cut, 1 for boost
end

% % Adjustable values:

% normalisation frequency range (to normalise IR to 0dB)
normFreqRange = [100 200];

% error frequency range (for calculating error between shelf and IR)
errFreqRange = [100 16500];

%% Function

% Compute frequency response of the measured IR
nfft = 2^nextpow2(length(ir));
% nfft = 512; % quicker
[H_measured, f] = freqz(ir, 1, nfft, fs);
mag_measured = 20*log10(abs(H_measured) + eps);  % in dB

% normalise:
offset = mean(mag_measured((f >= normFreqRange(1)) & (f <= normFreqRange(2))));
mag_measured = mag_measured - offset;

minfftBin = round(errFreqRange(1)/fs*nfft)+1;
maxfftBin = round(errFreqRange(2)/fs*nfft)+1;

% Objective function to minimise (squared error in dB)
objective = @(params) errorFunction(params, mag_measured, f, fs,minfftBin,maxfftBin);

% Initial guess: [Gain (dB), Q, CutoffFrequency (Hz)]
x0 = [6, 0.7, 1000];

% Set bounds: safer to avoid exactly Nyquist
nyquist = fs/2;
lb = [-30, 0.1, 100];               % Low shelf usually > 20 Hz
ub = [30, 10, nyquist * 0.9];      % Avoid Nyquist

% Optimisation
opts = optimset('Display','off');
% opts = optimset('Display','off', 'MaxFunEvals', 100, 'TolFun', 1e-2); % quicker

bestParams = fmincon(objective, x0, [], [], [], [], lb, ub, [], opts);

% Display optimised parameters
gain = bestParams(1);
Q = bestParams(2);
fc = bestParams(3);
% fprintf('Optimised Shelving Filter:\nGain = %.2f dB\nQ = %.2f\nCutoff = %.2f Hz\n', gain, Q, fc);

% Design and plot shelving filter
if boostFlag == 1 % if it's boost, make gain negative
    shelf = shelvingFilter(-gain,Q,fc,"highpass",SampleRate=fs);
else % if it's cut:
    shelf = shelvingFilter(gain,Q,fc,"highpass",SampleRate=fs);
end

if plotFlag
[h_filter, f_resp] = freqz(shelf, nfft, fs);

% Plot comparison
figure;
semilogx(f, mag_measured, 'b', 'LineWidth', 1.5); hold on;
semilogx(f_resp, 20*log10(abs(h_filter)+eps), 'r--', 'LineWidth', 1.5);
grid on;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
legend('Measured IR', 'Fitted Shelving Filter');
title('Shelving Filter Fit to Measured Impulse Response');
end
%% Error function
    function err = errorFunction(params, mag_measured, f, fs, minfftBin, maxfftBin)
        gain = params(1);
        Q = params(2);
        fc = params(3);
        try
            shelf = shelvingFilter(gain,Q,fc,"highpass",SampleRate=fs);

            nfft = length(f);
            h = freqz(shelf, nfft, fs);
            mag_shelf = 20*log10(abs(h) + eps);
            err = sum((mag_shelf(minfftBin:maxfftBin) - mag_measured(minfftBin:maxfftBin)).^2);

            % Penalise extreme designs even if valid
            if isnan(err) || isinf(err)
                err = 1e6;
            end
        catch
            err = 1e6;  % Large error so optimiser avoids it
        end
    end
end