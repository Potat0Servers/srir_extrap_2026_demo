function [P_pwd, est_dirs,est_dirs_P] = sphPWDmap(sphCOV, grid_dirs, nSrc,kappa)
%SPHPWDMAP Steered-response power map using a plane-wave decomposition beamformer
%   
%   This routine steeres a PWD (regular) beamformer at K grid directions
%   and computes the power output. This power map can be used for DoA
%   estimation.
%
%   Inputs:
%       sphCOV: (order+1)^2x(order+1)^2 covariance/correlation matrix of
%           SH signals
%       grid_dirs:  Kx2 directions of [azi elev] in rads that define a grid
%           for the power map. For easy plotting of the directional maps,
%           use grid2dirs.m to generate the directions
%       nSrc:   (optional) number of peaks to try to find, as potential DoA
%           estimates (Von-Mises peak-finding contributed by Dr. Sakari Tervo)
%
%   Outputs:
%       P_pwd:      Kx1 vector of output powers, evaluated at grid directions
%       est_dirs:   nSrcx2 [azi elev] of estimated directions from
%           peak-finding
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPHPWDMAP.M - 5/10/2016
% Archontis Politis, archontis.politis@aalto.fi
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%% NOTE ------ ADAPTED BY Thomas McKenzie 2020 to add
%%%%%%%%%%%%%% est_dirs_P the power at the estimated directions

nSH = size(sphCOV,1);
order = sqrt(nSH)-1;
% get steering vectors for grid points
nGrid = size(grid_dirs,1);
grid_xyz = unitSph2cart(grid_dirs);
grid_dirs2 = [grid_dirs(:,1) pi/2-grid_dirs(:,2)]; % go from azi-elevation to azi-inclination
Y_grid = getSH(order, grid_dirs2, 'real');

% plane wave decomposition power map
P_pwd = zeros(nGrid,1);
for ng = 1:nGrid
    stVec = 4*pi/(order+1)^2 * Y_grid(ng,:).';
    P_pwd(ng) = stVec' * sphCOV * stVec;
end

% peak finding, if asked
if nargout>=2 && nargin>=3
    if nargin == 3
        kappa = 40;
    end
    
%     kappa  = 20; % Von-Mises concentration factor    % TM | 40 for most | 60 FOR ON AXIS ANECHOIC CHAMBER SOURCE IN CHAMBER DOA PLOT TO FIX THE DOOR REFLECTION AT 425CM 
    P_minus_peak = P_pwd;
    est_dirs = zeros(nSrc, 2);
    est_dirs_P = zeros(nSrc,1);% added the power of the estimated DOAs
    for k = 1:nSrc
        [~, peak_idx] = max(P_minus_peak);
        est_dirs(k,:) = grid_dirs(peak_idx,:);
        est_dirs_P(k) = P_pwd(peak_idx);
        VM_mean = grid_xyz(peak_idx,:); % orientation of VM distribution
        VM_mask = kappa/(2*pi*exp(kappa)-exp(-kappa)) * exp(kappa*grid_xyz*VM_mean'); % VM distribution
        VM_mask = 1./(0.00001+VM_mask); % inverse VM distribution
        P_minus_peak = P_minus_peak.*VM_mask;
    end
end



end
