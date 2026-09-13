function path_a2r = calculate_aperture_to_receiver_propagate( ...
    pos_rec, pos_aperture, fs, c)
%CALCULATE_APERTURE_TO_RECEIVER_PROPAGATE Build the aperture-to-receiver path.
%
% Inputs:
%   pos_rec       Receiver position [x y z].
%   pos_aperture  Aperture position [x y z].
%   fs            Sampling rate.
%   c             Speed of sound in m/s. Optional; defaults to 343.
%
% Output:
%   path_a2r      Single-position propagation descriptor with fields:
%                 dist, toa_samp, doa_deg, time_sec, time_ms.  doa_deg is
%                 the arrival direction at the receiver, i.e. the vector
%                 from the receiver towards the aperture.

%% Coordinate setup

if nargin < 4 || isempty(c)
    c = 343;
end

pos_rec = reshape(pos_rec, 1, []);
pos_aperture = reshape(pos_aperture, 1, []);

%% Calculate the propagation descriptor

path_a2r.dist = norm(pos_rec - pos_aperture);
path_a2r.toa_samp = round((fs / c) * path_a2r.dist);
arrival_vector = pos_aperture - pos_rec;
[azimuth_rad, elevation_rad] = cart2sph( ...
    arrival_vector(1), ...
    arrival_vector(2), ...
    arrival_vector(3));
path_a2r.doa_deg = rad2deg([azimuth_rad; elevation_rad]);
path_a2r.time_sec = path_a2r.toa_samp / fs;
path_a2r.time_ms = path_a2r.time_sec * 1000;

end
