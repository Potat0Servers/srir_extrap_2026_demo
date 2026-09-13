function [met, doa_noqe] = mclachlan2024_metrics(m)
%MCLACHLAN2021_METRICS - extract localization metrics
%   Usage: metric = mclachlan2021_metrics(doa) 
%
%   Input parameters:
%     m                 : matrix of localisation data
%
%   Output parameters:
%     metric            : metrics for evaluation of localisation
%                         performance
%
%   `mclachlan2024_metrics(...)` returns psychoacoustic performance 
%   parameters for experimental response patterns. 
%
%   The metrics struct contains the following fields:
%   
%     met.reversal_fb      Percentage of front-back reversals, omitting
%                       small errors occurring within 10 degrees of the
%                       plane dividing the hemifields
%
%     met.reversal_ud      Percentage of up-down reversals, omitting
%                       small errors occurring within 10 degrees of the
%                       plane dividing the hemifields
%
%     met.rmsL             Lateral root mean squared error
%
%     met.rmsP             Polar root mean squared error, omitting reversals
%                       and restricted to directions within 35 degrees of
%                       the vertical midline
%
%     doa_nofb          localisation data without FBCs 
%
%   
%   See also: demo_mclachlan2021 mclachlan2021
%
%   References: reijniers2014 schonstein2008comparison

%   #StatusDoc: Perfect
%   #StatusCode: Perfect
%   #Verification: Unknown
%   #Requirements: M-Signal M-Image
%   #Author: Glen McLachlan (2024)

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

% compute localisation metrics from Tab. 2
u=unique(m(:,17));
for s=1:length(u)
    idx=m(:,17)==u(s);
    met.rmsL(s) = localizationerror(m(idx,:),'rmsL');
    met.rmsP(s) = localizationerror(m(idx,:),'rmsPmedian_nofb');
    met.querr(s) = localizationerror(m(idx,:),'querrMiddlebrooks');
    met.FBC(s) = localizationerror(m(idx,:),'rFBC');
    met.UDC(s) = localizationerror(m(idx,:),'rUDC');
    
    % elevation gain for Fig. 6
    met.gain(s)=m(idx,2)\m(idx,4);
end 

% percentage of front-back confusions according to Carlile et al. (1999)
idx_fb = find(sign(m(:,9))~=sign(m(:,12)) & abs(m(:,9))>0.01);      % & (abs(m(:,8))<75 | (m(:,8)>105 & m(:,8)<255)));
idx_ud = find(sign(m(:,11))~=sign(m(:,14)) & abs(m(:,11))>0.01);
idx_qe = find((abs(mynpi2pi(m(:,8)-m(:,6))))>90 & abs(m(:,5))<90);
idx_fbud = unique([idx_fb;idx_ud]);
idx_nofbud = setxor(1:size(m,1),idx_fbud);
idx_noqe=setxor(1:size(m,1),idx_qe);

doa_noqe.est=m(idx_noqe,12:14); doa_noqe.real=m(idx_noqe,9:11); %remove fbc

[uniq,~,ic1] = unique(m(:,9:11),'rows');
[GC]= diff(find([true,diff(sort(ic1)')~=0,true])); 
bias_perdir=zeros(size(uniq,1),3);
for i=idx_noqe' % compute bias vectors per direction
    bias_perdir(ic1(i),:)=bias_perdir(ic1(i),:)+m(i,12:14);
end
met.bias_perdir=bias_perdir./sqrt(sum(bias_perdir.^2,2));
met.bias_perdir(isnan(met.bias_perdir))=0;
[bias_sph(:,1), bias_sph(:,2)] = cart2horpolar(met.bias_perdir(:,1),met.bias_perdir(:,2),met.bias_perdir(:,3)); %bias_sph=SOFAconvertCoordinates(met.bias_perdir,'cartesian','horizontal-polar');
bias_sph=bias_sph/180*pi;
bias_sph(:,1)=bias_sph(:,1)-pi;
met.bias_norm=sqrt(sum(met.bias_perdir.^2,2));

%% REVERSALS 
fbc_perdir=zeros(length(uniq),1);
udc_perdir=zeros(length(uniq),1);
qe_perdir=zeros(length(uniq),1);

for i=idx_fb' % compute percentage of fb confusions per direction
    fbc_perdir(ic1(i))=fbc_perdir(ic1(i))+1;
end

for i=idx_ud' % compute percentage of fb confusions per direction
    udc_perdir(ic1(i))=udc_perdir(ic1(i))+1;
end

for i=idx_qe'
    qe_perdir(ic1(i))=qe_perdir(ic1(i))+1;
end
met.fbc_perdir=fbc_perdir./GC'*100;
met.udc_perdir=udc_perdir./GC'*100;
met.qe_perdir=qe_perdir./GC'*100;
met.qe_mean=mean(met.qe_perdir(abs(uniq(:,1))>0.01));
met.qe_f=(mean(met.qe_perdir(uniq(:,1)>0.01))/2)/met.qe_mean*100;
met.qe_b=(mean(met.qe_perdir(uniq(:,1)<-0.01))/2)/met.qe_mean*100;

met.fbc_mean=mean(met.fbc_perdir(abs(uniq(:,1))>0.01));
met.ofwhich_fb=(mean(met.fbc_perdir(uniq(:,1)>0.01))/2)/met.fbc_mean*100;
met.udc_mean=mean(met.udc_perdir(abs(uniq(:,3))>0.01));
idx_nolr=find(m(:,10)~=1&m(:,10)~=-1);
omit=intersect(idx_noqe,idx_nolr);
lgc_omit=false(size(m,1),1);
lgc_omit(omit)=true;
met.revid=lgc_omit;

%% Kent distributions

for j=1:length(uniq) % per true source direction
didx= find(ismember(doa_noqe.real,uniq(j,:),'rows')); %indices with source direction j
n = length(didx);
d=doa_noqe.est;

%% compute Kent parameters
% find rotation matrix G that rotates bias to north pole
p0=met.bias_perdir(j,:);
p1=[0,0,1];
% calculate cross and dot products
C = cross(p0, p1) ; 
D = dot(p0, p1) ;
NP0 = norm(p0) ; % used for scaling
if ~all(C==0) % check for colinearity    
    Z = [0 -C(3) C(2); C(3) 0 -C(1); -C(2) C(1) 0] ; 
    G = (eye(3) + Z + Z^2 * (1-D)/(norm(C)^2)) / NP0^2 ; % rotation matrix
else
    G = sign(D) * (norm(p1) / NP0) ; % orientation and scaling
end

ud = (G * d(didx,:)')';

cov_d=cov(ud(:,1:2));
[evec,eval] = eig(cov_d);
eigM=blkdiag(flip(evec),1);

% rd is a rotated version of responses which follow the PCA axes
rd = (eigM * ud')';

% if j==28
%     j
% end

% figure;
% hold on
% quiver3(0, 0, 0, evec(1,2),evec(2,2), 0,'b', 'LineWidth', 2);
% quiver3(0, 0, 0, evec(1,1),evec(2,1), 0,'r', 'LineWidth', 2);
% scatter3(rd(:,1), rd(:,2), rd(:,3), 5, 'filled','k');
% scatter3(ud(:,1), ud(:,2), ud(:,3), 5, 'filled','r');
% daz=30;
% AZgrid=repmat((-90:90),length(-180:daz:180),1)'*pi/180;
% ELgrid=repmat((-180:daz:180)',1,length(-90:90))'*pi/180;
% [xgrid1,zgrid1,ygrid1]=sph2cart(AZgrid,ELgrid,1);
% [xgrid2,zgrid2,ygrid2]=sph2cart(ELgrid,AZgrid,1);
% plot3(xgrid1,ygrid1,zgrid1,'Color',[.7 .7 .7]);
% hold on
% plot3(xgrid2,ygrid2,zgrid2,'Color',[.7 .7 .7]);

% calculate mean and std dev
uv = mean(rd,1);
sigv = std(rd,[],1);

% now figure out ellipse size for std deviation
ellz(:,j) = sigv(1:2) / 1;

% compute the points of the ellipse and rotate into original coordinates
PP=40;
for i=1:PP-1
   psi=i/PP*2*pi;
   x = ellz(1,j) * sin(psi);
   y = ellz(2,j) * cos(psi);
   z = abs(sqrt(1 - x*x - y*y));
   xyz = (inv(G) * inv(eigM) *[x;y;z])';	% convert to orig coords
   ell(j,i,:) = xyz;
end
ell(j,PP,:)=ell(j,1,:); % copy first to last to complete circle

tmp= m(idx_noqe,:);
met.SD(1,j)=std(mynpi2pi(tmp(didx,7)-tmp(didx,5)));
met.SD(2,j)=std(mynpi2pi(tmp(didx,8)-tmp(didx,6)));
end

met.kentdist=ell;
met.axes=ellz;
met.dirs=uniq;

% polar RMS excluding quadrant errors and 10 degrees around interaural axis
% m_rmsP = m;
% m_rmsP([idx_fb; idx_ud],:) = [];
% idx = abs(m_rmsP(:,5))<=35; % ignore 10 degrees around interaural axis
% m_rmsP = m_rmsP(idx,:);
% 
% metric.rmsP=sqrt(sum((mynpi2pi(m_rmsP(:,8)-m_rmsP(:,6))).^2)/size(m_rmsP,1));

end

function out_deg=mynpi2pi(ang_deg)
ang=ang_deg/180*pi;
out_rad=sign(ang).*((abs(ang)/pi)-2*ceil(((abs(ang)/pi)-1)/2))*pi;
out_deg=out_rad*180/pi;
end

% [dirs1,id1]=sortrows(met_emp.dirs);
% 
% tbl=table(round(m_s(:,5)),round(m_s(:,6)),met_emp.laterr,met_emp.polerr,'VariableNames',["theta","phi","laterr","polerr"]);
% 
% for i=1:length(m_s)
%     met_emp.polerr(i);
%     met_emp.laterr(i);
% end
% 
% figure; scatter(ulat,laterr_perdir)
% figure; scatter(upol,polerr_perdir)
