function path_info = calc_path_info_single_room(path_sameroom)
%CALC_PATH_INFO_SINGLE_ROOM Match the original and target paths in one room.
%
% Input:
%   path_sameroom.orig  ISM paths for the original source-receiver geometry.
%   path_sameroom.tar   ISM paths for the target source-receiver geometry.
%
% Output:
%   path_info  Original/target timing, distance, gain, and path metadata.

%% Match original and target paths

num_paths_orig = numel(path_sameroom.orig.path_id);
num_paths_tar = numel(path_sameroom.tar.path_id);

if num_paths_orig ~= num_paths_tar
    error( ...
        'calc_path_info_single_room:PathCountMismatch', ...
        ['Original and target ISM results must contain the same number ' ...
         'of paths.']);
end

[~, tar_idx] = ismember( ...
    path_sameroom.orig.path_id, ...
    path_sameroom.tar.path_id);

if ~isequal( ...
        path_sameroom.orig.reflection_order, ...
        path_sameroom.tar.reflection_order(tar_idx))
    error( ...
        'calc_path_info_single_room:ReflectionOrderMismatch', ...
        ['Original and target reflection orders must agree after ' ...
         'matching path IDs.']);
end

%% Assemble timing, distance, and gain data

path_info.toa.orig_samp = path_sameroom.orig.toa_samp;
path_info.toa.tar_samp = path_sameroom.tar.toa_samp(tar_idx);

path_info.dist.orig = path_sameroom.orig.dist;
path_info.dist.tar = path_sameroom.tar.dist(tar_idx);
path_info.gain = path_info.dist.orig ./ path_info.dist.tar;

%% Copy path metadata and directions

path_info.path_id = path_sameroom.orig.path_id;
path_info.reflection_order = path_sameroom.orig.reflection_order;
path_info.doa_orig_deg = path_sameroom.orig.doa_deg;
path_info.doa_tar_deg = path_sameroom.tar.doa_deg(:, tar_idx);

end
