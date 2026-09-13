function [srir_new, arr_info] = apply_coupledRoom_arrival_reposition(srir_orig, paths_s2a, paths_a2r, fs, window_param)
%APPLY_COUPLEDROOM_ARRIVAL_REPOSITION 挖出、移动、缩放并叠加 coupled-room arrivals。
%
% 输入：
%   srir_orig    : 原始 SRIR，尺寸为 [num_samples, num_channels]。
%   paths_s2a    : source -> aperture 的路径结构体。
%   paths_a2r    : aperture -> receiver 的传播结构体。
%   fs           : 采样率。
%   window_param : 窗口和淡入淡出参数，可选。
%
% 输出：
%   srir_new : 重定位后的 SRIR。
%   arr_info : 每条 arrival 的原始/目标 ToA、总距离和 gain，便于检查。

if nargin < 5
    window_param = struct();
end

window_param = set_default_window_param(window_param);

[num_samples, num_channels] = size(srir_orig);

%% window parameters

arr_info.window_samp = max(1, round(window_param.window_ms / 1000 * fs));
arr_info.pre_samp = max(0, round(window_param.pre_ms / 1000 * fs));

%% calculate basic arrival information

arr_info.toa.orig_samp = paths_s2a.toa_samp + paths_a2r.toa.orig_samp;
arr_info.toa.tar_samp = paths_s2a.toa_samp + paths_a2r.toa.tar_samp;

arr_info.dist.orig = paths_s2a.dist + paths_a2r.dist.orig;
arr_info.dist.tar = paths_s2a.dist + paths_a2r.dist.tar;

arr_info.gain = arr_info.dist.orig ./ arr_info.dist.tar;
arr_info.is_direct = paths_s2a.is_direct;
arr_info.is_o1 = paths_s2a.is_o1;

arr_info.num_paths = numel(paths_s2a.toa_samp);

%% make arrival window

arrival_window = make_arrival_window( ...
    arr_info.window_samp, ...
    num_channels, ...
    min(window_param.fade_in_samp, arr_info.window_samp), ...
    min(window_param.fade_out_samp, arr_info.window_samp));

%% initialize matrices and status flags

srir_residual = srir_orig;
srir_repositioned = zeros(size(srir_orig));

arr_info.was_extracted = false(1, arr_info.num_paths);
arr_info.was_added = false(1, arr_info.num_paths);

%% arrival repositioning loop

for i = 1:arr_info.num_paths
    [extract_idx, extract_win_idx] = clipped_indices( ...
        arr_info.toa.orig_samp(i) - arr_info.pre_samp, ...
        arr_info.window_samp, ...
        num_samples);

    if isempty(extract_idx)
        continue
    end

    window_part = arrival_window(extract_win_idx, :);
    arrival = srir_orig(extract_idx, :) .* window_part;

    srir_residual(extract_idx, :) = srir_residual(extract_idx, :) .* (1 - window_part);
    arr_info.was_extracted(i) = true;

    [target_idx, arrival_idx] = clipped_indices( ...
        arr_info.toa.tar_samp(i) - arr_info.pre_samp, ...
        size(arrival, 1), ...
        num_samples);

    if isempty(target_idx)
        continue
    end

    % 第一版遇到多个 target window 重叠时直接线性叠加。
    srir_repositioned(target_idx, :) = srir_repositioned(target_idx, :) + ...
        arrival(arrival_idx, :) * arr_info.gain(i);

    arr_info.was_added(i) = true;
end

srir_new = srir_residual + srir_repositioned;

end

function window_param = set_default_window_param(window_param)
% 设置窗口参数默认值。

if ~isfield(window_param, 'window_ms') || isempty(window_param.window_ms)
    window_param.window_ms = 3;
end

if ~isfield(window_param, 'pre_ms') || isempty(window_param.pre_ms)
    window_param.pre_ms = window_param.window_ms / 4;
end

if ~isfield(window_param, 'fade_in_samp') || isempty(window_param.fade_in_samp)
    window_param.fade_in_samp = 5;
end

if ~isfield(window_param, 'fade_out_samp') || isempty(window_param.fade_out_samp)
    window_param.fade_out_samp = 10;
end

end

function window = make_arrival_window(window_samp, num_channels, fade_in_samp, fade_out_samp)
% 生成带淡入淡出的 arrival 窗口。

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
% 把可能越界的窗口裁剪到合法索引范围。

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
