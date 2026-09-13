function [srir_new, path_info] = srir_resynthesis_withBeamform( ...
    srir_orig, path_info, window_param, flag, residual_scale_param, fs)
%SRIR_RESYNTHESIS_WITHBEAMFORM Rebuild a target SRIR with path beamforming.
%   It extracts, rotates, scales, and repositions each arrival, then mixes the
%   arrivals with the scaled residual.

if nargin < 4 || isempty(flag)
    flag = struct();
end

if ~isfield(flag, 'beamform_extract')
    flag.beamform_extract = true;
end

[num_samples, num_channels] = size(srir_orig);
num_paths = numel(path_info.path_id);

direct_idx = find(path_info.reflection_order == 0);
reflection_idx = find(path_info.reflection_order > 0);
[~, reflection_sort_idx] = sort(mean([ ...
    path_info.dist.orig(reflection_idx); ...
    path_info.dist.tar(reflection_idx)], 1));
reflection_idx = reflection_idx(reflection_sort_idx);

source_start_samp = path_info.toa.orig_samp - window_param.pre_samp;
target_start_samp = path_info.toa.tar_samp - window_param.pre_samp;

arrival_window = make_arrival_window( ...
    window_param.window_samp, ...
    num_channels, ...
    min(window_param.fade_in_samp, window_param.window_samp), ...
    min(window_param.fade_out_samp, window_param.window_samp));

srir_residual = srir_orig;
srir_repositioned = zeros(size(srir_orig));

path_info.was_extracted = false(1, num_paths);
path_info.was_added = false(1, num_paths);

%% Early reflections

for i = reflection_idx
    [arrival, arrival_residual, extract_idx, window_part] = extract_arrival( ...
        srir_orig, ...
        source_start_samp(i), ...
        arrival_window, ...
        num_samples, ...
        flag.beamform_extract, ...
        path_info.doa_orig_deg(:, i), ...
        false);

    if isempty(extract_idx)
        continue
    end

    srir_residual(extract_idx, :) = ...
        srir_residual(extract_idx, :) .* (1 - window_part);

    if flag.beamform_extract
        srir_residual(extract_idx, :) = ...
            srir_residual(extract_idx, :) + arrival_residual;
    end

    path_info.was_extracted(i) = true;

    doa_rotation_deg = wrapped_angle_difference_deg( ...
        path_info.doa_orig_deg(:, i), ...
        path_info.doa_tar_deg(:, i));
    arrival = rotateHOA_N3D( ...
        arrival, ...
        doa_rotation_deg(1), ...
        doa_rotation_deg(2), ...
        0);
    arrival = arrival * path_info.gain(i);

    [srir_repositioned, was_added] = add_arrival( ...
        srir_repositioned, ...
        arrival, ...
        target_start_samp(i), ...
        num_samples);
    path_info.was_added(i) = was_added;
end

%% Direct sound

i = direct_idx;
[arrival, arrival_residual, extract_idx, window_part] = extract_arrival( ...
    srir_orig, ...
    source_start_samp(i), ...
    arrival_window, ...
    num_samples, ...
    flag.beamform_extract, ...
    path_info.doa_orig_deg(:, i), ...
    true);

if ~isempty(extract_idx)
    srir_residual(extract_idx, :) = ...
        srir_residual(extract_idx, :) .* (1 - window_part);

    if flag.beamform_extract
        srir_residual(extract_idx, :) = ...
            srir_residual(extract_idx, :) + arrival_residual;
    end

    path_info.was_extracted(i) = true;

    doa_rotation_deg = wrapped_angle_difference_deg( ...
        path_info.doa_orig_deg(:, i), ...
        path_info.doa_tar_deg(:, i));
    arrival = rotateHOA_N3D( ...
        arrival, ...
        doa_rotation_deg(1), ...
        doa_rotation_deg(2), ...
        0);
    arrival = arrival * path_info.gain(i);

    direct_end_samp = min( ...
        num_samples, ...
        target_start_samp(i) + size(arrival, 1) - 1);

    if direct_end_samp >= 1
        srir_residual(1:direct_end_samp, :) = 0;
        srir_repositioned(1:direct_end_samp, :) = 0;
    end

    [srir_repositioned, was_added] = add_arrival( ...
        srir_repositioned, ...
        arrival, ...
        target_start_samp(i), ...
        num_samples);
    path_info.was_added(i) = was_added;
end

[srir_residual, path_info.residual_scale] = scale_srir_residual( ...
    srir_residual, ...
    path_info.toa.orig_samp(direct_idx), ...
    residual_scale_param, ...
    fs);

% Scale only the residual.  Repositioned direct/early arrivals have already
% received path_info.gain and must not be scaled a second time.
srir_new = srir_residual + srir_repositioned;

end

function [arrival, arrival_residual, extract_idx, window_part] = extract_arrival( ...
    srir_orig, source_start_samp, arrival_window, num_samples, ...
    beamform_extract, doa_orig_deg, is_direct)
%EXTRACT_ARRIVAL Window one arrival and split off its residual contribution.

[extract_idx, window_idx] = clipped_indices( ...
    source_start_samp, ...
    size(arrival_window, 1), ...
    num_samples);

if isempty(extract_idx)
    arrival = [];
    arrival_residual = [];
    window_part = [];
    return
end

window_part = arrival_window(window_idx, :);
arrival = srir_orig(extract_idx, :) .* window_part;
arrival_residual = zeros(size(arrival));

if beamform_extract
    [arrival_beam, arrival_residual] = beamform_extract_remove( ...
        arrival, ...
        doa_orig_deg(1), ...
        doa_orig_deg(2));

    if ~is_direct
        arrival = arrival_beam;
    end
end
end

function [srir_out, was_added] = add_arrival( ...
    srir_in, arrival, target_start_samp, num_samples)
%ADD_ARRIVAL Add the valid part of one arrival at its target start sample.

[target_idx, arrival_idx] = clipped_indices( ...
    target_start_samp, ...
    size(arrival, 1), ...
    num_samples);

if isempty(target_idx)
    srir_out = srir_in;
    was_added = false;
    return
end

srir_out = srir_in;
srir_out(target_idx, :) = ...
    srir_out(target_idx, :) + arrival(arrival_idx, :);
was_added = true;
end

function rotation_deg = wrapped_angle_difference_deg(orig_deg, tar_deg)
%WRAPPED_ANGLE_DIFFERENCE_DEG Return the shortest signed DoA change.

rotation_deg = mod(tar_deg - orig_deg + 180, 360) - 180;
end

function window = make_arrival_window( ...
    window_samp, num_channels, fade_in_samp, fade_out_samp)
%MAKE_ARRIVAL_WINDOW Build one faded window and copy it across all channels.

window_mono = ones(window_samp, 1);

if fade_in_samp > 0
    window_mono(1:fade_in_samp) = linspace(0, 1, fade_in_samp).';
end

if fade_out_samp > 0
    window_mono(end-fade_out_samp+1:end) = linspace(1, 0, fade_out_samp).';
end

window = repmat(window_mono, 1, num_channels);
end

function [valid_idx, local_idx] = clipped_indices(start_raw, len, max_len)
%CLIPPED_INDICES Match a clipped signal range to its local sample indices.

end_raw = start_raw + len - 1;

valid_start = max(1, start_raw);
valid_end = min(max_len, end_raw);

if valid_start > valid_end
    valid_idx = [];
    local_idx = [];
    return
end

valid_idx = valid_start:valid_end;

local_start = valid_start - start_raw + 1;
local_end = local_start + numel(valid_idx) - 1;
local_idx = local_start:local_end;
end

function [out_beam, out_resid] = beamform_extract_remove( ...
    in, azimuth_deg, elevation_deg)
%BEAMFORM_EXTRACT_REMOVE Split a window into one beam and what remains.

num_channels = size(in, 2);
order = round(sqrt(num_channels) - 1);

steering = get_real_sh_n3d( ...
    order, ...
    deg2rad(azimuth_deg), ...
    deg2rad(elevation_deg));
plane_wave = in * steering.';
out_beam = plane_wave * steering;
out_resid = in - out_beam;
end

function Y = get_real_sh_n3d(order, azimuth, elevation)
%GET_REAL_SH_N3D Build one real N3D steering vector.

colatitude = pi/2 - elevation;
Y = zeros(1, (order + 1)^2);

for n = 0:order
    P = legendre(n, cos(colatitude), 'sch');

    for m = -n:n
        idx = n*(n + 1) + m + 1;
        Pnm = P(abs(m) + 1);
        normalization = sqrt( ...
            (2*n + 1)/(4*pi) * ...
            factorial(n - abs(m))/factorial(n + abs(m)));

        if m > 0
            Y(idx) = sqrt(2) * normalization * Pnm * cos(m * azimuth);
        elseif m < 0
            Y(idx) = sqrt(2) * normalization * Pnm * ...
                sin(abs(m) * azimuth);
        else
            Y(idx) = normalization * Pnm;
        end
    end
end

Y = Y / norm(Y);
end
