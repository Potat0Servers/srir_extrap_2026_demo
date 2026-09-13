function [srir_zoom, r_j, r_j_zoom] = zooming(srir, N, coord_change, plot_directions, preserve_omni_rms)
%ZOOMING Push an SRIR toward a chosen Cartesian direction.
%
% Inputs:
%   srir             SRIR matrix sized [samples, channels].
%   N                Spherical-harmonic order to process.
%   coord_change     Cartesian shift [dx, dy, dz]. Its direction specifies
%                    the zoom direction and its norm specifies the strength.
%                    Examples: [1 0 0] for +X and [0 0.5 0] for mild +Y.
%   plot_directions  Optional direction-plot flag, true by default.
%   preserve_omni_rms  Optional omni RMS preservation flag, true by default.
% Outputs:
%   srir_zoom        Zoomed SRIR, sized [samples, (N+1)^2].
%   r_j              Original sector directions [azimuth, elevation] (rad).
%   r_j_zoom         Shifted sector directions [azimuth, elevation] (rad).

%% Main Algorithm

if nargin < 4
    plot_directions = true;
end
if nargin < 5
    preserve_omni_rms = true;
end

[~, r_j] = getTdesign(2*N);
[x, y, z] = sph2cart(r_j(:, 1), r_j(:, 2), 1);

x = x + coord_change(1);
y = y + coord_change(2);
z = z + coord_change(3);

[r_j_zoom(:, 1), r_j_zoom(:, 2)] = cart2sph(x, y, z);

if plot_directions
    plot_zoom_directions(r_j, r_j_zoom);
end

cn_butterworth = sphButterworth(N, 5, N+1);

[~, sphFB_B] = designSphFilterBank(N, rad2deg(r_j), cn_butterworth', 'EP');

[sphFB_A, ~] = designSphFilterBank(N, rad2deg(r_j_zoom), cn_butterworth', 'EP');

rir_s = srir(:, 1:(N+1)^2) * sphFB_A;

srir_zoom = rir_s * sphFB_B';

if preserve_omni_rms
    srir_zoom = srir_zoom * (rms(srir(:,1)) / rms(srir_zoom(:,1)));
end

end


function plot_zoom_directions(r_j, r_j_zoom)
%PLOT_ZOOM_DIRECTIONS Show sector directions before and after zooming.

direction_sets = {r_j_zoom, r_j};
plot_titles = {"Before zoom: analysis directions", "After zoom: synthesis directions"};
point_colours = [0 0.4470 0.7410; 0.8500 0.3250 0.0980];
[sphere_x, sphere_y, sphere_z] = sphere(40);

figure('Name', 'Zooming sector directions', 'NumberTitle', 'off');

for plot_idx = 1:2
    subplot(1, 2, plot_idx);
    surf( ...
        sphere_x, ...
        sphere_y, ...
        sphere_z, ...
        'FaceColor', ...
        [0.85 0.85 0.85], ...
        'FaceAlpha', ...
        0.15, ...
        'EdgeColor', ...
        [0.75 0.75 0.75]);
    hold on

    directions = direction_sets{plot_idx};
    [point_x, point_y, point_z] = sph2cart( ...
        directions(:,1), ...
        directions(:,2), ...
        ones(size(directions,1), 1));
    scatter3( ...
        point_x, ...
        point_y, ...
        point_z, ...
        40, ...
        point_colours(plot_idx,:), ...
        'filled');

    hold off
    axis equal
    axis([-1.1 1.1 -1.1 1.1 -1.1 1.1]);
    view(35, 25);
    xlabel('X');
    ylabel('Y');
    zlabel('Z');
    title(plot_titles{plot_idx});
    grid on
    box on
end

end
