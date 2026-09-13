%% Sandbox for new SRIR algorithms
% Loads the same coupled-room SOFA dataset used by the existing
% coupled-room experiment scripts. Add new experiments below the final
% section so that dataset setup stays separate from algorithm code.


clearvars;
clc;

%% Init

scriptDir = fileparts(mfilename('fullpath'));
run(fullfile(scriptDir, 'addpaths.m'));

%% Load SRIR dataset

sofaFile = fullfile( ...
    scriptDir, ...
    'SOFAfiles', ...
    'roomToHallway_srcRoom_noLOS.sofa');

if ~isfile(sofaFile)
    error('SOFA file not found: %s', sofaFile);
end

fprintf('Loading %s\n', sofaFile);
sofa_orig = SOFAload(sofaFile);

fs = double(sofa_orig.Data.SamplingRate);
fs = fs(1);

num_measurements = size(sofa_orig.Data.IR, 1);
num_channels = size(sofa_orig.Data.IR, 2);
num_samples = size(sofa_orig.Data.IR, 3);

fprintf( ...
    'Loaded %d measurements, %d channels, %d samples at %.0f Hz.\n', ...
    num_measurements, ...
    num_channels, ...
    num_samples, ...
    fs);

%% Parameter Settings

% Extract measurements as samples-by-channels SRIR matrices.
measurement_indices = 30;

% Spherical-harmonic order?
N = 4;

% coordinate change
coord_change = [1 0 0];

%% Main Algorithm

for measurement_idx = measurement_indices

    % r_j stores four directions in polar coordinates, in radians.
    srir = double(squeeze(sofa_orig.Data.IR(measurement_idx, :, :))).';
    [srir_zoom, r_j, r_j_zoom] = zooming(srir, N, coord_change);
    
    % print to check
    fprintf('before zooming:')
    rad2deg(r_j)
    fprintf('after zooming:')
    rad2deg(r_j_zoom)
    
    
    
    
    
    
    %% Evaluation
    
    doa_duration_samples = min(round(fs * 0.3), size(srir_zoom, 1));
    [P_pwd_orig, ~, ~, grid_dirs] = get_pwd( ...
        srir(1:doa_duration_samples, 1:(N+1)^2), ...
        fs);
    [P_pwd_rj, ~, ~, grid_dirs] = get_pwd( ...
        srir_zoom(1:doa_duration_samples, :), ...
        fs);
    
    figure('Name', sprintf('Measurement %d', measurement_idx));
    subplot(1,2,1);
    heatmap_plot_hammer( ...
        rad2deg(grid_dirs(:,1)), ...
        rad2deg(grid_dirs(:,2)), ...
        mag2db(P_pwd_orig));
    colormap(flipud(bone));
    set(gca, 'FontSize', 11);
    k = colorbar;
    xlabel(k, 'Normalised power (dB)');
    title('Before zoom');
    
    subplot(1,2,2);
    heatmap_plot_hammer( ...
        rad2deg(grid_dirs(:,1)), ...
        rad2deg(grid_dirs(:,2)), ...
        mag2db(P_pwd_rj));
    colormap(flipud(bone));
    set(gca, 'FontSize', 11);
    k = colorbar;
    xlabel(k, 'Normalised power (dB)');
    title('After zoom');

end

%% Local functions

function [P_pwd, doa_est, doa_est_P, grid_dirs] = get_pwd(srir_in, fs)

degree_resolution = 2;
order = sqrt(size(srir_in, 2)) - 1;
if order ~= round(order)
    error('The SRIR channel count must be a complete SH set.');
end

n_src = 7;
high_pass_filter_freq = 3000;
kappa = 40;

grid_dirs = grid2dirs( ...
    degree_resolution, ...
    degree_resolution, ...
    0, ...
    0);
[~, filt_hi, ~] = ambisonic_crossover(high_pass_filter_freq, fs);

y_src = filter(filt_hi, 1, srir_in);
steering_vectors = y_src';

% This is equivalent to steering_vectors * eye(T) * steering_vectors',
% without allocating the large T-by-T identity matrix used in the source
% implementation.
spherical_covariance = ...
    steering_vectors * steering_vectors' + ...
    eye((order + 1)^2) / (4*pi);

[P_pwd, doa_est, doa_est_P] = sphPWDmap( ...
    spherical_covariance, ...
    grid_dirs, ...
    n_src, ...
    kappa);

doa_est = rad2deg(doa_est);
negative_flip_limit = -170;
flip_mask = doa_est < negative_flip_limit;
doa_est(flip_mask) = doa_est(flip_mask) + 360;

end
