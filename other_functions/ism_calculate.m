function paths = ism_calculate(coord_rec, coord_src, ord_ism, dim_room, fs, c, flag_plot)
%ISM_CALCULATE Build direct and image-source paths in a rectangular room.
%   It returns path timing, distance, direction, IDs, and reflection orders
%   from a source to a receiver or aperture.
%
% 输入：
%   coord_rec : 接收点坐标 [x y z]。在第一段 coupled-room ISM 中就是 aperture。
%   coord_src : 声源坐标 [x y z]。
%   ord_ism   : ISM 阶数。当前基础版建议先用 1。
%   dim_room  : 源房间尺寸 [Lx Ly Lz]。
%   fs        : 采样率。
%   flag_plot : 是否画出 image source 和路径，用于检查几何。
%
% 输出：
%   paths : 整理后的路径结构体。它把 direct path 和 reflections 合并，
%           删除边界退化假反射，并按到达时间排序。

if nargin < 6 || isempty(c)
    c = 343;
end

if nargin < 7 || isempty(flag_plot)
    flag_plot = false;
end

coord_rec = coord_rec(:).';
coord_src = coord_src(:).';

Lx = dim_room(1);
Ly = dim_room(2);
Lz = dim_room(3);

x = coord_src(1);
y = coord_src(2);
z = coord_src(3);

if flag_plot
    figure;
    hold on;
    grid on;
    axis equal;
    xlabel('x (m)');
    ylabel('y (m)');
    zlabel('z (m)');
    title('ISM paths: source to aperture/receiver');
    draw_room_box(dim_room);
end

%% 生成 image source 坐标

if ord_ism == 1
    % 一阶 ISM：对 6 个墙面分别镜像一次。
    coords_ism = first_order_image_sources(x, y, z, Lx, Ly, Lz);
    reflection_order_ism = ones(1, size(coords_ism, 2));
else
    % 二阶及以上：尽量沿用旧函数的 image source 生成逻辑，便于结果对照。
    [coords_ism, reflection_order_ism] = higher_order_image_sources( ...
        x, ...
        y, ...
        z, ...
        Lx, ...
        Ly, ...
        Lz, ...
        ord_ism);
end

%% 计算反射路径距离、ToA 和 DoA

num_reflections = size(coords_ism, 2);
dist_ism = zeros(1, num_reflections);
toa_ism = zeros(1, num_reflections);
doa_ism = zeros(2, num_reflections);

for i = 1:num_reflections
    coord_img = coords_ism(:, i).';

    dist_ism(i) = norm(coord_img - coord_rec);
    toa_ism(i) = round((fs / c) * dist_ism(i));
    doa_ism(:, i) = vector_to_azel_deg(coord_img - coord_rec);

    if flag_plot
        plot3(coord_img(1), coord_img(2), coord_img(3), 'g*');
        plot3( ...
            [coord_img(1) coord_rec(1)], ...
            [coord_img(2) coord_rec(2)], ...
            [coord_img(3) coord_rec(3)], ...
            'Color', ...
            [0.8 0.8 0.8]);
    end
end

%% 计算直达路径距离、ToA 和 DoA

dist_ds = norm(coord_src - coord_rec);
toa_ds = round((fs / c) * dist_ds);
doa_ds = vector_to_azel_deg(coord_src - coord_rec);

%% 合并 direct path 和 reflection paths

paths.dist = [dist_ds, dist_ism];
paths.toa_samp = [toa_ds, toa_ism];
paths.doa_deg = [doa_ds, doa_ism];
paths.path_id = 0:num_reflections;
paths.reflection_order = [0, reflection_order_ism];

%% 删除边界退化假反射，再按到达时间排序

paths = remove_degenerate_boundary_reflections(paths);

[paths.toa_samp, sort_idx] = sort(paths.toa_samp);
paths.dist = paths.dist(sort_idx);
paths.doa_deg = paths.doa_deg(:, sort_idx);
paths.path_id = paths.path_id(sort_idx);
paths.reflection_order = paths.reflection_order(sort_idx);

paths.time_sec = paths.toa_samp / fs;
paths.time_ms = paths.time_sec * 1000;

if flag_plot
    plot3( ...
        coord_src(1), ...
        coord_src(2), ...
        coord_src(3), ...
        '^', ...
        'LineWidth', ...
        2, ...
        'MarkerEdgeColor', ...
        [0.4660 0.6740 0.1880]);
    plot3( ...
        coord_rec(1), ...
        coord_rec(2), ...
        coord_rec(3), ...
        'o', ...
        'LineWidth', ...
        2, ...
        'MarkerEdgeColor', ...
        [0.8500 0.3250 0.0980]);
    view(0, 90);
end

end

function paths = remove_degenerate_boundary_reflections(paths)
%REMOVE_DEGENERATE_BOUNDARY_REFLECTIONS Drop boundary paths that copy the direct path.

idx_direct = find(paths.path_id == 0, 1);

if isempty(idx_direct)
    return
end

direct_toa = paths.toa_samp(idx_direct);
direct_dist = paths.dist(idx_direct);

same_toa = paths.toa_samp == direct_toa;
same_dist = abs(paths.dist - direct_dist) < 1e-9;

fake_o1 = paths.path_id ~= 0 & ...
    paths.reflection_order <= 1 & ...
    same_toa & same_dist;

paths = filter_paths(paths, ~fake_o1);

end

function paths = filter_paths(paths, keep_idx)
%FILTER_PATHS Keep the same selected paths in every per-path field.

paths.dist = paths.dist(keep_idx);
paths.toa_samp = paths.toa_samp(keep_idx);
paths.doa_deg = paths.doa_deg(:, keep_idx);
paths.path_id = paths.path_id(keep_idx);
paths.reflection_order = paths.reflection_order(keep_idx);

end

function [coords_ism, coords_ism_o1] = first_order_image_sources(x, y, z, Lx, Ly, Lz)
%FIRST_ORDER_IMAGE_SOURCES Generate the six first-order image sources.

xyz_src = [ ...
     x -y -z; ...
    -x  y -z; ...
    -x -y  z; ...
     x -y -z; ...
    -x  y -z; ...
    -x -y  z].';

xyz_room = [ ...
    0    0    0; ...
    0    0    0; ...
    0    0    0; ...
    2*Lx 0    0; ...
    0    2*Ly 0; ...
    0    0    2*Lz].';

coords_ism = xyz_room - xyz_src;
coords_ism_o1 = coords_ism;

end

function [coords_ism, reflection_order] = higher_order_image_sources( ...
    x, y, z, Lx, Ly, Lz, ord_ism)
%HIGHER_ORDER_IMAGE_SOURCES Generate higher-order sources with the legacy layout.

xyz_src = [ ...
    -x -y -z; ...
    -x -y  z; ...
    -x  y -z; ...
    -x  y  z; ...
     x -y -z; ...
     x -y  z; ...
     x  y -z; ...
     x  y  z].';

n_vect = -(ord_ism - 1):(ord_ism - 1);
l_vect = -(ord_ism - 1):(ord_ism - 1);
m_vect = -(ord_ism - 1):(ord_ism - 1);

coords_ism = [];
reflection_order = [];
xyz_diff_lim = [min(n_vect)*2*Lx; min(l_vect)*2*Ly; min(m_vect)*2*Lz];

for n = n_vect
    for l = l_vect
        for m = m_vect
            xyz_diff = [n*2*Lx; l*2*Ly; m*2*Lz];
            coords_here = xyz_diff - xyz_src;
            order_x = [abs(2*n), abs(2*n), abs(2*n), abs(2*n), ...
                       abs(2*n - 1), abs(2*n - 1), abs(2*n - 1), abs(2*n - 1)];
            order_y = [abs(2*l), abs(2*l), abs(2*l - 1), abs(2*l - 1), ...
                       abs(2*l), abs(2*l), abs(2*l - 1), abs(2*l - 1)];
            order_z = [abs(2*m), abs(2*m - 1), abs(2*m), abs(2*m - 1), ...
                       abs(2*m), abs(2*m - 1), abs(2*m), abs(2*m - 1)];
            order_here = order_x + order_y + order_z;

            delete_idx = [];
            for i = 1:size(coords_here, 2)
                coord_img = coords_here(:, i);
                if any(coord_img < xyz_diff_lim)
                    delete_idx(end + 1) = i; %#ok<AGROW>
                end
            end

            coords_here(:, delete_idx) = [];
            order_here(delete_idx) = [];
            coords_ism = [coords_ism, coords_here]; %#ok<AGROW>
            reflection_order = [reflection_order, order_here]; %#ok<AGROW>
        end
    end
end

end

function azel_deg = vector_to_azel_deg(vec)
%VECTOR_TO_AZEL_DEG Convert a receiver-to-source vector to azimuth and elevation.

hyp = sqrt(vec(1)^2 + vec(2)^2);
azimuth = atan2(vec(2), vec(1));
elevation = atan(vec(3) / (hyp + eps));

azel_deg = [azimuth; elevation] * 180 / pi;

end

function flags = flag_matching_columns(main_matrix, other_matrix)
%FLAG_MATCHING_COLUMNS Flag columns that also appear in the other matrix.

num_cols = size(main_matrix, 2);
flags = false(num_cols, 1);

for i = 1:num_cols
    flags(i) = ismember(main_matrix(:, i).', other_matrix.', 'rows');
end

end

function draw_room_box(dim_room)
%DRAW_ROOM_BOX Draw a simple room wireframe for geometry checks.

Lx = dim_room(1);
Ly = dim_room(2);
Lz = dim_room(3);

corners = [ ...
    0  0  0; ...
    Lx 0  0; ...
    Lx Ly 0; ...
    0  Ly 0; ...
    0  0  Lz; ...
    Lx 0  Lz; ...
    Lx Ly Lz; ...
    0  Ly Lz];

edges = [ ...
    1 2; 2 3; 3 4; 4 1; ...
    5 6; 6 7; 7 8; 8 5; ...
    1 5; 2 6; 3 7; 4 8];

for i = 1:size(edges, 1)
    p1 = corners(edges(i, 1), :);
    p2 = corners(edges(i, 2), :);
    plot3([p1(1) p2(1)], [p1(2) p2(2)], [p1(3) p2(3)], 'k-');
end

end
