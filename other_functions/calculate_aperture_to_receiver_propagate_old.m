function paths_a2r = calculate_aperture_to_receiver_propagate_old(geom, fs)
%CALCULATE_APERTURE_TO_RECEIVER_PROPAGATE_OLD Original orig/tar A2R helper.
%
% This legacy helper is kept for scripts that still expect aperture ->
% original/target receiver quantities in one struct.  New coupled-room
% descriptor code should use calculate_aperture_to_receiver_propagate.

if isfield(geom, 'c') && ~isempty(geom.c)
    c = geom.c;
else
    c = 343;
end

pos_aper = geom.aperture.pos;
pos_rec_orig = geom.rec.orig.pos;
pos_rec_tar = geom.rec.tar.pos;

%% Aperture to original/target receiver distances

paths_a2r.dist.orig = norm(pos_rec_orig - pos_aper);
paths_a2r.dist.tar = norm(pos_rec_tar - pos_aper);

%% Aperture to original/target receiver propagation times

paths_a2r.toa.orig_samp = round((fs / c) * paths_a2r.dist.orig);
paths_a2r.toa.tar_samp = round((fs / c) * paths_a2r.dist.tar);

paths_a2r.time.orig_sec = paths_a2r.toa.orig_samp / fs;
paths_a2r.time.tar_sec = paths_a2r.toa.tar_samp / fs;

paths_a2r.time.orig_ms = paths_a2r.time.orig_sec * 1000;
paths_a2r.time.tar_ms = paths_a2r.time.tar_sec * 1000;

%% Original-to-target aperture propagation delay difference

% Positive means target receiver is farther from the aperture than original.
paths_a2r.delay.orig_to_tar_samp = ...
    paths_a2r.toa.tar_samp - paths_a2r.toa.orig_samp;
paths_a2r.time.delay_orig_to_tar_ms = ...
    paths_a2r.delay.orig_to_tar_samp / fs * 1000;

end
