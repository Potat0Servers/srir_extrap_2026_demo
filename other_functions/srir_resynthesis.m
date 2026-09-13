function [srir_new, path_info] = srir_resynthesis(srir_orig, path_info, window_param)
%SRIR_RESYNTHESIS Extract, transform, and mix windows.
%
% Inputs:
%   srir_orig   Original SRIR, sized [num_samples, num_channels].
%   path_info   Arrival timing, gains, and path diagnostics.
%   window_param Window length, pre-arrival offset, and fade parameters.
%
% Outputs:
%   srir_new    Resynthesized SRIR.
%   path_info   Input information with extraction/addition status appended.


[num_samples, num_channels] = size(srir_orig);
num_paths = numel(path_info.path_id);

%% Calculate source and target window positions

source_start_samp = path_info.toa.orig_samp - window_param.pre_samp;
target_start_samp = path_info.toa.tar_samp - window_param.pre_samp;

%% Make the arrival window

arrival_window = make_arrival_window( ...
    window_param.window_samp, ...
    num_channels, ...
    min(window_param.fade_in_samp, window_param.window_samp), ...
    min(window_param.fade_out_samp, window_param.window_samp));

%% Initialize output components and status flags

srir_residual = srir_orig;
srir_repositioned = zeros(size(srir_orig));

path_info.was_extracted = false(1, num_paths);
path_info.was_added = false(1, num_paths);

%% Extract, scale, reposition, and accumulate each arrival

for i = 1:num_paths
    [extract_idx, extract_win_idx] = clipped_indices( ...
        source_start_samp(i), ...
        window_param.window_samp, ...
        num_samples);

    if isempty(extract_idx)
        continue
    end

    window_part = arrival_window(extract_win_idx, :);
    arrival = srir_orig(extract_idx, :) .* window_part;

    srir_residual(extract_idx, :) = ...
        srir_residual(extract_idx, :) .* (1 - window_part);
    path_info.was_extracted(i) = true;

    [target_idx, arrival_idx] = clipped_indices( ...
        target_start_samp(i), ...
        size(arrival, 1), ...
        num_samples);

    if isempty(target_idx)
        continue
    end

    srir_repositioned(target_idx, :) = ...
        srir_repositioned(target_idx, :) + ...
        arrival(arrival_idx, :) * path_info.gain(i);

    path_info.was_added(i) = true;
end

srir_new = srir_residual + srir_repositioned;

end

function window = make_arrival_window(window_samp, num_channels, fade_in_samp, fade_out_samp)
%MAKE_ARRIVAL_WINDOW Generate a multichannel window with linear fades.

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
%CLIPPED_INDICES Clip a possibly out-of-bounds window to valid indices.

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
