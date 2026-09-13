function srir_delayed = restore_geometric_delay_extended(srir, fs, pos_src, pos_rec, idx_rec, geom)
%RESTORE_GEOMETRIC_DELAY_EXTENDED Put back the dataset's removed travel delay.
%   It uses direct distance for receiver indices 1-50 and a path through the
%   aperture for indices 51-101.

%% Delay-model setup

    c = 343;
    if nargin >= 6 && isstruct(geom) && isfield(geom, 'c') && ~isempty(geom.c)
        c = geom.c;
    end

    window_dur_ms = 3;
    prewindow_samp = round(fs * ((window_dur_ms / 1000) / 4));

%% Detect the measured direct-sound onset

    ir = abs(lowpass(highpass(srir(:,1), 700, fs), 5000, fs));
    peak_norm = max(ir);
    absir = ir ./ peak_norm;
    [~, lcs] = findpeaks(absir, "MinPeakDistance", 50, MinPeakHeight = 0.05);

    toa_meas = lcs(1);

%% Calculate the geometric onset

    if idx_rec <= 50
        dist_geom = norm(pos_src(:) - pos_rec(:));
        delay_model = 'single-room direct';
    else
        pos_aperture = geom.aperture.pos(:);
        dist_geom = norm(pos_src(:) - pos_aperture) + norm(pos_aperture - pos_rec(:));
        delay_model = 'two-room via aperture';
    end

    toa_geom = round(dist_geom / c * fs);
    delay_samp = toa_geom - toa_meas;

%% Apply the restored delay

    if delay_samp > 0
        srir_delayed = [zeros(delay_samp, size(srir, 2)); srir];
        srir_delayed = srir_delayed(1:size(srir, 1), :);
        fprintf( ...
            ['Restored geometric delay (%s, rec idx %d): measured onset at sample %d, ' ...
             'geometric onset at sample %d, prepended %d samples.\n'], ...
            delay_model, ...
            idx_rec, ...
            toa_meas, ...
            toa_geom, ...
            delay_samp);
    else
        srir_delayed = srir;
        fprintf( ...
            ['Geometric delay restoration skipped (%s, rec idx %d): measured onset at sample %d, ' ...
             'geometric onset at sample %d.\n'], ...
            delay_model, ...
            idx_rec, ...
            toa_meas, ...
                 toa_geom);
    end

%% Check extraction pre-window clearance

    if delay_samp > 0 && toa_geom <= prewindow_samp
        warning('Restored direct sound is still too close to the start for the extraction pre-window.');
    end

end
