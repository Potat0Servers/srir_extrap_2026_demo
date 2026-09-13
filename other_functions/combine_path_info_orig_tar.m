function path_info = combine_path_info_orig_tar(path_desc_orig, path_desc_tar)
%COMBINE_PATH_INFO_ORIG_TAR Match and pair two single-position path lists.
%
% Inputs are expected to use the same descriptor shape as ism_calculate:
%   toa_samp, dist, doa_deg, path_id, reflection_order
%
% Output is the paired path_info shape consumed by the resynthesis functions:
%   toa.orig_samp / toa.tar_samp
%   dist.orig / dist.tar
%   doa_orig_deg / doa_tar_deg

%% Normalise and match path descriptors

orig = validate_descriptor(path_desc_orig);
tar = validate_descriptor(path_desc_tar);

[common_path_id, idx_orig, idx_tar] = intersect( ...
    orig.path_id, ...
    tar.path_id, ...
    'stable');

if numel(common_path_id) < numel(orig.path_id) || ...
        numel(common_path_id) < numel(tar.path_id)
    warning( ...
        'combine_path_info_orig_tar:DroppedUnmatchedPaths', ...
        ['Original and target descriptors contain different path IDs. ' ...
         'Keeping %d common paths out of %d original and %d target paths.'], ...
        numel(common_path_id), ...
        numel(orig.path_id), ...
        numel(tar.path_id));
end

if ~isequal(orig.reflection_order(idx_orig), tar.reflection_order(idx_tar))
    error( ...
        'combine_path_info_orig_tar:ReflectionOrderMismatch', ...
        'Reflection orders must agree after matching path IDs.');
end

%% Assemble paired path information

path_info.toa.orig_samp = orig.toa_samp(idx_orig);
path_info.toa.tar_samp = tar.toa_samp(idx_tar);

path_info.dist.orig = orig.dist(idx_orig);
path_info.dist.tar = tar.dist(idx_tar);

path_info.path_id = common_path_id;
path_info.reflection_order = orig.reflection_order(idx_orig);

path_info.doa_orig_deg = orig.doa_deg(:, idx_orig);
path_info.doa_tar_deg = tar.doa_deg(:, idx_tar);

end

%% Local helpers

function desc = validate_descriptor(desc)
%VALIDATE_DESCRIPTOR Put every per-path field into a consistent shape.

desc.toa_samp = row_vector(desc.toa_samp);
desc.dist = row_vector(desc.dist);
desc.path_id = row_vector(desc.path_id);
desc.reflection_order = row_vector(desc.reflection_order);

end

function x = row_vector(x)
%ROW_VECTOR Reshape one per-path field as a row vector.

x = reshape(x, 1, []);
end
