function [doa, params] = mclachlan2023(template, varargin)
%mclachlan2023 A recursive, dynamic ideal-observer model of human sound localisation
%   Usage: [results,template,target] = mclachlan2023(template,target,'num_exp',20,'sig_S',4.2);
%
%   Input parameters:
%
%     template.fs      : sampling rate (Hz)
%     template.fc      : ERB frequency channels (Hz)
%     template.itd    : itd computed for each hrir (samples)
%     template.H       : Matrix containing absolute values of HRTFS for all grid points
%     template.coords  : Matrix containing cartesian coordinates of all grid points, normed to radius 1m
%
%
%   Output parameters:
%
%     doa               : directions of arrival in spherical coordinates
%
%       .est            : estimated [num_sources, num_repetitions, 3]
%       .real           : actual    [num_sources, 3]
%
%     params            : additional model's data computerd for estimations
%
%       .est_idx        : Indices corresponding to template direction where
%                         the maximum probability density for each source
%                         position is found
%
%     	.est_loglik     : Log-likelihood of each estimated direction
%
%       .post_prob      : Maximum posterior probability
%
%                         density for each target source
%
%       .freq_channels  : number of auditory channels
%
%       .T_template     : Struct with template data elaborated by the model
%
%       .T_target       : Struct with target data elaborated by the model
%
%     	.Tidx           : Helper with indexes to parse
%                         the features from T and X
%
%   MCLACHLAN2023 accepts the following optional parameters:
%
%     'num_exp',num_exp Set the number of localization trials.
%                       Default is num_exp = 500.
%
%     'dt',dt           Time between each acoustic measurement in seconds.
%                       I.e. time step. Default value is dt = 0.005.
%
%     'sig_itd0',sig    Set standard deviation for the noise on the initial
%                       itd. Default value is sig_itd0 = 0.569.
%
%     'sig_itdi',sig    Set standard deviation for the noise on the itd
%                       change per time step. Default value is sig_itdi = 1.
%
%     'sig_I',sig       Set standard deviation for the internal noise.
%                       Default value is sig_I = 3.5.     
%
%     'sig_S',sig       Set standard deviation for the variation on the 
%                       source spectrum. Default value is sig_S = 3.5.
%
%     'stim_dur',dur    Set stimulus duration in seconds. Default value is
%                       stim_dur = 0.1.
%
%     'trackerdata, td  Input tracker data if rot_type was set to 'data'
%
%   Further, cache flags (see amt_cache) can be specified.
%

%   #Author: Glen McLachlan (2023): original implementation
%   #Author: Herbert Peremans (2023): original implementation
%   #Author: Glen McLachlan (2024): integrated in the AMT

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


%% Check input options
definput.import={'amt_cache'};
definput.import={'mclachlan2023'};

[flags,kv]  = ltfatarghelper({}, definput, varargin);

SHorder = kv.SHorder;

template_coords = template.coords;
tempx=template_coords(1,:); tempy=template_coords(2,:); tempz=template_coords(3,:);
if ~isempty(kv.targ_az)
    [target_coords(1,:),target_coords(2,:),target_coords(3,:)]=...
        sph2cart(deg2rad(kv.targ_az),deg2rad(kv.targ_el),ones(length(kv.targ_el),1));
else
    target_coords=template_coords;
end

%% misc parameters
T_int = ceil(kv.stim_dur/kv.dt);          % amount of estimation steps during stimulus
%t_int=(0:kv.dt:(T_int-1)*kv.dt);           % vector of estimation steps during stimulus
trackFs = 100; %head tracker sampling rate in Hz
dt=kv.dt*1000;
num_targets = size(target_coords,2);    % amount of test target directions
num_template = size(template_coords,2); % amount of template directions
num_fc=length(template.fc);
doa_estimations=zeros(kv.num_exp,3); %initialise model estimates

if mod(kv.num_exp,num_targets)>0 && ~strcmp(kv.rot_type,'data')
    warning('Number of experiments is not a multiple of tested target directions.')
end

% noise parameters
sig_itd0=kv.sig_itd0;
sig_itdi=sig_itd0;
sig_I=kv.sig_I;

% precomputed coefficients for SH interpolation (saves computational time)
c_itd=template.coef_itd;
c_H1=template.coef_L;
c_H2=template.coef_R;

%define covar matrix for noise on acoustic information
covS=amt_load('mclachlan2024','covS_ESC_database.mat');
Sig=repmat(covS.covS,[2,2])+(sig_I^2)*eye(num_fc*2);
Sig = blkdiag(sig_itd0^2, Sig);
Sig_gen = (sig_I^2)*eye(num_fc); %covM for generation of monaural noise

%% Head rotation simulation

if strcmp(kv.rot_type,'static')
    u=zeros(T_int,1)+eps;
    u_dir = [0,0,0];
elseif strcmp(kv.rot_type,'yaw')
    acc=(2*kv.rot_size)/kv.stim_dur^2; %acceleration in deg/s^2, for reference
    a=(2*kv.rot_size)/T_int^2; %acceleration in deg/timestep^2
    u=(a*(0:1:T_int).^2)/2;
    u=diff(u); 
    u_dir = [1,0,0];
elseif strcmp(kv.rot_type,'pitch')
    a=kv.rot_size/T_int^2;
    u=a*((0:1:T_int).^2);
    u=diff(u);
    u_dir = [0,1,0];
elseif strcmp(kv.rot_type,'data') % follow human data
    u_all=kv.track_data;
    idx = cellfun(@(C) any(~isnan(C(:))), u_all(:,1));
    u_all=u_all(idx,:);
    kv.num_exp=length(u_all);
    u_dir=1;
end


%% head orientation list for marginalisation
% range of considered initial head orientations
h0range=2*kv.sig_H; %3*sigma covers most of the possible values
minyaw_h=-h0range; maxyaw_h=h0range;
minpitch_h=-h0range; maxpitch_h=h0range;
minroll_h=-h0range; maxroll_h=h0range;

% uniform distribution of intitial head orientations within the allowed range
if kv.sig_H>0.1
    [yaw,pitch] = ndgrid(minyaw_h:kv.sig_H:maxyaw_h,minpitch_h:kv.sig_H:maxpitch_h);
    yaw=reshape(yaw,[],1);
    pitch=reshape(pitch,[],1);
    %roll=reshape(roll,[],1);
    list_dir0_h=cat(2,yaw,pitch,zeros(length(yaw),1)); %assume perfect knowledge of roll to save computational time
else
    list_dir0_h=[0,0,0];
end

%% posterior computation
num_dir0_h = size(list_dir0_h,1); %amount of initial head orientations

tic
for e=1:kv.num_exp

    if strcmp(kv.rot_type,'data') % copy behavioural data
        u=u_all{e,1}; %take current trial rotation data

        Theta_H=zeros(T_int+1,3); %true head orientation
        Theta_H(1,:)=u(1,:); % copy initial head orientation

        idx=size(u,1):-kv.dt*trackFs:1;
        if size(idx) == 1
            idx = [idx,1]; %ensure at least 2 looks at start and end
        end
        u=u(idx,:);
        u=flipud(u);
        u=diff(u);               %cumulative motor commands to reach final orientation
        T_int = size(u,1);           % amount of estimation steps during stimulus
        kv.stim_dur=length(u)*kv.dt;
        target_coord=u_all{e,2};
        [target_coord(1),target_coord(2),target_coord(3)]=sph2cart(deg2rad(target_coord(1)),deg2rad(target_coord(2)),1);
        target_coord=target_coord';
        doa.real(e,:) = target_coord;   % real doa [nexp x 3]
    else % go through all target directions, then repeat
        ee=mod(e,num_targets);
        if ee==0
            ee=33;
        end
        target_coord=target_coords(:,ee);
        doa.real(e,:) = target_coord;
        Theta_H=zeros(T_int+1,3); %true head orientation
        Theta_H(1,:)=[0,0,0]; % assume initial orientation is 0
    end

%   spatial prior
    [tempAZ, tempEL] = cart2sph(tempx,tempy,tempz);
    prior_targdir = mclachlan2023_prior([tempAZ',tempEL'],kv.priorshape,kv.sig_p);

    % initial head orientation information

    y_H=zeros(T_int+1,3); %head orientation observation
    y_H(1,:)=Theta_H(1,:)+chol(kv.sig_H^2)*randn([1,3]);
    mu_H=zeros(T_int+1,3); %head position estimate
    mu_H(1,:)=y_H(1,:);

    % noise on head rotation angle sequence
    sig_head2 = zeros(1,T_int);
    sig_head2(1) = kv.sig_H^2;
    sig_u=zeros(1,T_int)+eps;

    for t=1:T_int+1 % per estimation time step
        tmp_TM = mclachlan2023_rotatedirs(Theta_H(t,1),Theta_H(t,2),Theta_H(t,3)); % head to world coords
        tmp_TM_inv=transpose(tmp_TM);   %world to head coords
        tmp_T = tmp_TM_inv*target_coord; %target directions relative to head

        [AZ,EL]= cart2sph(tmp_T(1,:),tmp_T(2,:),tmp_T(3,:)); %true source direction sequence
        dirs_seqT=[AZ;EL];

        if t<T_int+1
        %noise on sensorimotor information
        delta_H=chol(kv.sig_H^2)*randn([1,3]); %noise on measurement
        sig_u(t)=kv.sig_u; %additive noise
        K(t) = (sig_head2(t) + sig_u(t)^2) / (sig_head2(t) + sig_u(t)^2 + kv.sig_H^2); %Kalman filter
        sig_head2(t+1)=(1-K(t))*(sig_head2(t)+sig_u(t)^2);  

        %delta_u=chol(sig_u(t)^2)*randn([1,3]); % additive noise on motor control
        Theta_H(t+1,:)=Theta_H(t,:)+u(t,:)*u_dir;
        y_H(t+1,:)=Theta_H(t+1,:)+delta_H; %[M,3] noisy measurement of head orientations
        mu_H(t+1,:)=(1-K(t))*(mu_H(t,:)+u(t,:)*u_dir)+K(t)*y_H(t+1,:); % estimate of true head orientation using Kalman filter
        end

        % rotation matrix to rotate to estimated head orientation
        rotM_mu = mclachlan2023_rotatedirs(mu_H(t,1),mu_H(t,2),mu_H(t,3));

        %pre-noise measurements
        Y_N = SH(SHorder, dirs_seqT'); 
        X_itd = Y_N*c_itd';
        X_L = Y_N*c_H1';
        X_R = Y_N*c_H2';
        
        % noise on observations
        delta_L=mvnrnd(zeros(num_fc,1),Sig_gen);
        delta_R=mvnrnd(zeros(num_fc,1),Sig_gen);
        if t==1
            delta_itd=mvnrnd(0,sig_itd0^2);
        else
            delta_itd=mvnrnd(0,sig_itdi^2); 
        end
        
        y_itd=X_itd+delta_itd;
        y_L=X_L-covS.meanS+delta_L; %subtract mean spectrum and add noise
        y_R=X_R-covS.meanS+delta_R;
        y_A = [y_itd,y_L,y_R]; %observed acoustic information

        jointdistr_marg=zeros([num_template, 1]); %initialise posterior probability

        for dirH_idx=1:num_dir0_h % marginalisation over all head orientations    

            rotM_dir0=mclachlan2023_rotatedirs(list_dir0_h(dirH_idx,1),list_dir0_h(dirH_idx,2),list_dir0_h(dirH_idx,3));  %rot matrix to rotate to initial head orientation
    
            %calculate rotation matrix corresponding with current head orientation
            rM = rotM_dir0*rotM_mu; %head to world coords
            [tmp_H(1),tmp_H(2),tmp_H(3)] = eulerAng(rM);
            rM_inv=transpose(rM);   %world to head coords
        
            %transform template directions into head reference system:
            dirsT_tmp = (rM_inv*template_coords)';
            [dirsT_az,dirsT_el] = cart2sph(dirsT_tmp(:,1),dirsT_tmp(:,2),dirsT_tmp(:,3));
    
            %interpolate acoustic cues to current head orientation
            Y_N = SH(SHorder, [dirsT_az dirsT_el]); 
            itd_tmp = Y_N*c_itd';     %ITD in head reference system
            spec_tmp = [transpose(Y_N*c_H1'); transpose(Y_N*c_H2')];

            if t==1
                tmp_A=[itd_tmp,spec_tmp']; %acoustic information, given current head orientation
                likelihood_acoustic=exp(-0.5*pdist2(tmp_A,y_A,'mahalanobis',Sig).^2); % likelihood of current timestep   
            else
                tmp_A=itd_tmp;
                likelihood_acoustic=exp(-0.5*pdist2(tmp_A,y_A(1),'mahalanobis',sig_itdi^2).^2); % likelihood of current timestep
            end

%             figure; plot_reijniers2014(template_coords',likelihood_acoustic,[],target_coord');
    
            % head postition likelihood with independent azimuth and elevation angle
            likelihood_motor=exp(-0.5*pdist2(mu_H(t,:),tmp_H,'mahalanobis',sig_head2(t)*eye(3)).^2);
    
            posterior_motor = likelihood_motor; %Bayes' rule, multiply with prior if it isn't uniform!!

            jointdistr = posterior_motor.*likelihood_acoustic; %joint PDF of acoustic & sensorimotor PDF

            if(isnan(jointdistr))
                warning('uh oh')
            end
    
            %marginal joint PDF for each target direction: [n_temp, n_targ*n_exp]
            jointdistr_marg=jointdistr_marg+jointdistr;

           % figure; plot_reijniers2014(template_coords',jointdistr_marg,[],target_coord');
        end %initial head direction list

        %update posterior
        posterior_targdir=prior_targdir.*jointdistr_marg; 

        posterior_targdir = posterior_targdir./(sum(posterior_targdir,1)); %normalise

        prior_targdir = posterior_targdir; %update prior to posterior from t-1
   %      figure; plot_reijniers2014(template_coords',prior_targdir(:),[],target_coord');
   %      caxis([0,0.03])
    end %time step

    post_prob(:,e) = posterior_targdir;

    %% decision rule
    if strcmp(kv.dec,'MAP')
    % maximum a posteriori (all or nothing)
    [log_lik(:,e), doa_idx(:,e)] = max(posterior_targdir,[],1);
    doa_estimations(e,:) = template_coords(:,doa_idx(:,e))';

    elseif strcmp(kv.dec,'PM')
    % weighted random sampling (Ege et al. 2018)
        idx= randsample(1:length(posterior_targdir),1,true,posterior_targdir);
        doa_estimations(e,:) = template.coords(:,idx)';
        log_lik(e)=posterior_targdir(idx);

%     elseif strcmp(kv.dec,'AS') 
%         % UNFINISHED, requires an estimate of sensory noise in units of degrees...
%         % adaptive sampling (Ege et al. 2018)
%         w=0.9;
%         delta_r=mvnrnd(zeros(num_fc,1),sig_I^2*eye(num_fc),num_targets);
% 
%         [AZ,EL]= cart2sph(template.coords(1,:),template.coords(2,:),template.coords(3,:));
%         [log_lik(:,e),doa_idx(:,e)]=max(posterior_targdir,[],1);
%         doa_estimations(:,e,:) = template_coords(:,doa_idx(:,e))';
%         doa_estimations(:,e,:)=doa_estimations(:,e,:)+w*delta_r; %add noise in range of sensory noise

    elseif strcmp(kv.dec,'mean')
        % expected value
        estAZ = circ_mean(tempAZ',posterior_targdir);
        estEL = circ_mean(tempEL',posterior_targdir);
        [doa_estimations(e,1),doa_estimations(e,2),doa_estimations(e,3)] = sph2cart(estAZ,estEL,1);
    end
%figure; plot_reijniers2014(template_coords',posterior_targdir,[],target_coord');
end %experiment list
toc
post_prob=squeeze(mean(post_prob,3));
%estimated directions of arrival in cart coords per target per trial

%% results
doa.est = doa_estimations;  % estimated doa [nexp x 3]

% user required more than the estimations
if nargout > 1
    params.template_coords = template_coords;   % template coordinates
    params.post_prob = post_prob;               % posterior probabilities [ncoords x nexp]
   % params.est_idx = doa_idx;                   % index of estimated doa [ntargets x nexp]
    params.est_loglik = log_lik;                % likelihood of estimated doa [ntargets x nexp]
    params.freq_channels = template.fc;
    params.Tidx.itd = 1;
    params.Tidx.Hp = params.Tidx.itd + (1:num_fc);
    params.Tidx.Hm = params.Tidx.Hp(end) + (1:num_fc);
else
    clear post_prob doa_idx log_lik
end
end
 
function rotM = mclachlan2023_rotatedirs(yaw,pitch,roll)
    % FOLLOWING FICK CONVENTION in WORLD COORDS, i.e., x > y > z
    rM_x = [ 1, 0, 0;...
                0, cosd(roll), -sind(roll);...
                0, sind(roll), cosd(roll)];
    rM_y = [cosd(pitch), 0, sind(pitch);...
                0, 1, 0;...
                -sind(pitch), 0, cosd(pitch)];
    rM_z = [  cosd(yaw), -sind(yaw), 0;...
                sind(yaw), cosd(yaw), 0;...
                0, 0, 1];
    
    rotM=rM_z*rM_y*rM_x;
end

function [yaw,pitch,roll] = eulerAng(rM) %Fick convention in world coords
        if(rM(3,1)<1)
            if(rM(3,1)>-1)
                pitch=asind(-rM(3,1));
                yaw=atan2d(rM(2,1),rM(1,1));
                roll=atan2d(rM(3,2),rM(3,3));
            else
                pitch=90;
                yaw=-atan2d(-rM(2,3),rM(2,2));
                roll=0;
            end
        else
            pitch=-90;
            yaw=atan2d(-rM(2,3),rM(2,2));
            roll=0;
        end
end

function Y_N = SH(N, dirs)
% calculate spherical harmonics up to order N for directions dirs [azi ele;...] (in radiant)
% 
    N_dirs = size(dirs, 1);
    N_SH = (N+1)^2;
	dirs(:,2) = pi/2 - dirs(:,2); % convert to inclinations

    Y_N = zeros(N_SH, N_dirs);

	  % n = 0
	Lnm = legendre(0, cos(dirs(:,2)'));
	Nnm = sqrt(1./(4*pi)) * ones(1,N_dirs);
	CosSin = zeros(1,N_dirs);
	CosSin(1,:) = ones(1,size(dirs,1));
	Y_N(1, :) = Nnm .* Lnm .* CosSin;
	
	  % n > 0
	idx = 1;
    for n=1:N
        
        m = (0:n)';            

		Lnm = legendre(n, cos(dirs(:,2)'));
		condon = (-1).^[m(end:-1:2);m] * ones(1,N_dirs);
		Lnm = condon .* [Lnm(end:-1:2, :); Lnm];
		
		mag = sqrt( (2*n+1)*factorial(n-m) ./ (4*pi*factorial(n+m)) );
		Nnm = mag * ones(1,N_dirs);
		Nnm = [Nnm(end:-1:2, :); Nnm];
		
		CosSin = zeros(2*n+1,N_dirs);
			% m=0
		CosSin(n+1,:) = ones(1,size(dirs,1));
			% m>0
		CosSin(m(2:end)+n+1,:) = sqrt(2)*cos(m(2:end)*dirs(:,1)');
			% m<0
		CosSin(-m(end:-1:2)+n+1,:) = sqrt(2)*sin(m(end:-1:2)*dirs(:,1)');

		Ynm = Nnm .* Lnm .* CosSin;
        Y_N(idx+1:idx+(2*n+1), :) = Ynm;
        idx = idx + 2*n+1;
    end
    
    Y_N = Y_N.';
    
end