function paths = calc_path_info_coupled_room(paths_s2a, path_a2r, fs)
%CALC_PATH_INFO_COUPLED_ROOM Join both parts of each coupled-room path.
%   It returns the same path layout as ism_calculate for one receiver reached
%   through the aperture.
%
% Inputs:
%   paths_s2a  Source-to-aperture paths from ism_calculate.
%   path_a2r   Single aperture-to-receiver propagation descriptor with
%              fields dist, toa_samp and receiver-side doa_deg.
%   fs         Sampling rate. Optional if path_a2r already has time fields.
%
% Output:
%   paths      Single-position path descriptor, matching ism_calculate:
%              dist, toa_samp, doa_deg, path_id, reflection_order,
%              time_sec, time_ms.

%% Optional sampling-rate setup

if nargin < 3 || isempty(fs)
    fs = [];
end

%% Assemble coupled-room path descriptor

paths.dist = reshape(paths_s2a.dist, 1, []) + path_a2r.dist;
paths.toa_samp = reshape(paths_s2a.toa_samp, 1, []) + path_a2r.toa_samp;
paths.path_id = reshape(paths_s2a.path_id, 1, []);
paths.reflection_order = reshape(paths_s2a.reflection_order, 1, []);

num_paths = numel(paths.path_id);
paths.doa_deg = repmat(path_a2r.doa_deg, 1, num_paths);

%% Derive time fields

if ~isempty(fs)
    paths.time_sec = paths.toa_samp / fs;
    paths.time_ms = paths.time_sec * 1000;
elseif isfield(path_a2r, 'time_sec')
    paths.time_sec = paths.toa_samp * (path_a2r.time_sec / path_a2r.toa_samp);
    paths.time_ms = paths.time_sec * 1000;
end

end
