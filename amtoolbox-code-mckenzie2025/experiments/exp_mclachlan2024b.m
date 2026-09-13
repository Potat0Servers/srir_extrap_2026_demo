function exp_mclachlan2024b(varargin)

definput.flags.fig = {'missingflag','fig4','fig5','fig6a','fig6b','fig7','fig8','fig9','fig10'};
definput.flags.condition = {'NT','PG','F'};

definput.import = {'amt_cache'};
definput.keyvals.MarkerSize = 6;
definput.keyvals.FontSize = 12;

[flags,kv]  = ltfatarghelper({},definput,varargin);

minangle= tand(10/2);
rot_t=[]; vectordata_all=[];

hor_dirs=[2,4,6,10,12,32];
ver_dirs= [15,23,27];
ext_dirs=[20,21,23,25,27,28,30,41]; %upwards (negative pitch)
flx_dirs=[14,15,37,22,26]; %downwards (positive pitch)
diagext_dirs=[20,28,30,41,21,25];
diagflx_dirs=[22,26,14,37];
all_dirs=[hor_dirs,ver_dirs,ext_dirs,flx_dirs];

maxrot=NaN(17,95,3);
maxrotT=NaN(17,95,3);
maxtrans=NaN(17,95,3);
maxvel=NaN(17,95,3);

fig=figure;

for subject=1:17
subject

if flags.do_NT
    load(['Data/Raw/T_subject_' num2str(subject) '_cond_2.mat'])
elseif flags.do_PG
    load(['Data/Raw/T_subject_' num2str(subject) '_cond_0.mat'])
elseif flags.do_F
    load(['Data/Raw/T_subject_' num2str(subject) '_cond_3.mat'])
end

idx = cellfun(@(x)ismember(x(1,13),all_dirs),T,'UniformOutput',false); %cells to omit
idx=cell2mat(idx);
T=T(idx); %drop lsp_0 and straight ahead trials

T=postProcTrackerData(T,subject,flags.condition,false); %cell array 
r=[];
re=[];
ext=[]; flx=[];

 for i=1:length(T)
    Ti=T{i};
    if any(~isnan(Ti),'all')
        yaw=Ti(100:end,1);pitch=Ti(100:end,2);roll=Ti(100:end,3); %rotation in head coords
        speakerpos=Ti(100:end,13);

        rx=Ti(100:end,7); ry=Ti(100:end,8); rz=Ti(100:end,9); %rotation vector
        idx=sqrt(rx.^2+ry.^2+rz.^2)>minangle;
        r=[r;rx(idx),ry(idx),rz(idx),speakerpos(idx)]; %omitting small angles
        rot_t=[rot_t;yaw,pitch,roll,speakerpos,(1:length(yaw))'];   %all rotational data

        re=[re;Ti(:,7),Ti(:,8),Ti(:,9)];

        vel=[];
        %velocity
        vel(1,:)=diff(yaw)/0.01;
        vel(2,:)=diff(pitch)/0.01;
        vel(3,:)=diff(roll)/0.01;
        vel=smoothdata(vel,2,'sgolay');
        
        % maximum translations
        [~,id]=max(abs(Ti(:,10:12)));
        maxtrans(subject,i,1)=Ti(id(1),10);
        maxtrans(subject,i,2)=Ti(id(2),11);
        maxtrans(subject,i,3)=Ti(id(3),12);

        % maximum rotations
        [~,id]=max(abs(Ti(100:end,1:3)));
        maxrot(subject,i,1)=yaw(id(1));
        maxrot(subject,i,2)=pitch(id(2));
        maxrot(subject,i,3)=roll(id(3));
        
        %maxrotT(subject,i,2)=max(yawT); maxrotT(subject,i,4)=max(pitchT); maxrotT(subject,i,6)=max(rollT);
        %maxrotT(subject,i,1)=min(yawT); maxrotT(subject,i,3)=min(pitchT); maxrotT(subject,i,5)=min(rollT);
%         maxvel(subject,i,2)=max(vel(1,:)); maxvel(subject,i,4)=max(vel(2,:)); maxvel(subject,i,6)=max(vel(3,:));
%         maxvel(subject,i,1)=min(vel(1,:)); maxvel(subject,i,3)=min(vel(2,:)); maxvel(subject,i,5)=min(vel(3,:));

%         set(0,'CurrentFigure',fig2) %Twisted planes
%         subplot(3,6,subject)
%         plot3(ax,az,ay,'Color','k','LineWidth',0.5); hold on;
    end
 end



%% Fitted twisted surface
plane(subject,:) = lsqcurvefit(@surfaceFit, zeros(10,1), [r(:,2),r(:,3),zeros(length(r),1)],r(:,1));
F=surfaceFit(plane(subject,:),[r(:,2),r(:,3),zeros(length(r),1)]);

SStot = sum((r(:,1)-mean(r(:,1))).^2);        % Total Sum-Of-Squares
SSres = sum((r(:,1)-F).^2);                   % Residual Sum-Of-Squares
Rsq(subject,1) = 1-SSres/SStot;               % R^2

%thickness(1,subject)=std(2*atand(residual));

for i=1:6
    tmp=lsqcurvefit(@surfaceFit, zeros(10,1), [r(:,2),r(:,3),i*ones(length(r),1)],r(:,1));
    F=surfaceFit(tmp,[r(:,2),r(:,3),zeros(length(r),1)]);
    
    SStot = sum((r(:,1)-mean(r(:,1))).^2);        % Total Sum-Of-Squares
    SSres = sum((r(:,1)-F).^2);                   % Residual Sum-Of-Squares
    Rsq(subject,i+1) = 1-SSres/SStot;             % R^2
end

ext=r(:,2)<0; %extension indices

y=r(:,1); % dependent variable
    
%% Simplex optimisation for k-gimbal model
k(1,subject) = fminsearch(@(k) minSimp(k, y, r(:,2), r(:,3)), 1);               %k value per subject
k(2,subject) = fminsearch(@(k) minSimp(k, y(ext), r(ext,2), r(ext,3)), 1);      %k value per subject-extension
k(3,subject) = fminsearch(@(k) minSimp(k, y(~ext), r(~ext,2), r(~ext,3)), 1);   %k value per subject-flexion

%% Linear regression for y*z product
G(1,subject)=(r(:,3).*r(:,2))\y;                                                %gimbal score per subject
G(2,subject)=(r(ext,3).*r(ext,2))\y(ext);                                       %gimbal score per subject-extension
G(3,subject)=(r(~ext,3).*r(~ext,2))\y(~ext);                                    %gimbal score per subject-flexion

vectordata_all=[vectordata_all;r(:,1:3),ext,subject(ones(length(r),1))];        %all rotational data, excluding small angles

if flags.do_fig7 % plot twisted surfaces
    if flags.do_NT
        subjects=[7,1,9];
    elseif flags.do_PG
        subjects=[7,12,16];
    end
    if ismember(subject,subjects)
        [~,i] = ismember(subject,subjects);
        subplot(1,3,i)
        scatter3(re(:,1),re(:,3),re(:,2),0.5,'k'); hold on;
        plotSurface(plane(subject,:),2);
        fontsize(fig,14,"points")
        view(-37.5,30);
    end
end

if flags.do_fig9 % plot linear regressions
    subjects=[7,12,16];
    if ismember(subject,subjects)
        [~,i] = ismember(subject,subjects);
        subplot(1,3,i)
        
        scatter(r(:,2).*r(:,3),r(:,1),0.5,'k'); hold on;
        L(1)=plot(-0.4:0.01:0.4,G(2,subject)*(-0.4:0.01:0.4),'Color',[0 0.4470 0.7410],'LineWidth',1.5);
        L(2)=plot(-0.4:0.01:0.4,G(3,subject)*(-0.4:0.01:0.4),'Color',[0.8500 0.3250 0.0980],'LineWidth',1.5);
        
        text(-0.15,-0.1,num2str(G(2,subject),'%04.2f'),'color',[0 0.4470 0.7410])
        text(-0.15,-0.15,num2str(G(3,subject),'%04.2f'),'color',[0.8500 0.3250 0.0980])
        if subject==1
            legend(L,'extension','flexion')
        end
        
        ylabel('r_x')
        xlabel('r_yr_z')
        ylim([-0.2,0.2])
        xlim([-0.2, 0.2])
    end
end


end



%% FIGURES

if flags.do_fig4 %PIE CHARTS
    quartiles = squeeze(quantile(maxrot, [0,0.25,0.5,0.75,1], [1, 2]));
    subplot(1,3,1)
    plot_mclachlan2024b(quartiles(:,1),'fig4');
    title('Yaw')
    subplot(1,3,2)
    plot_mclachlan2024b(quartiles(:,2),'fig4');
    title('Pitch')
    subplot(1,3,3)
    ph=plot_mclachlan2024b(quartiles(:,3),'fig4');
    title('Roll')
    %legend(ph(1:3),'Range of minima & maxima','Lower quartile of minima & upper quartile of maxima','Median of minima & maxima','Location','bestoutside')
end

if flags.do_fig5 %TRANSLATION DATA
    set(fig,'Position',[488,342,560,150]);
    subplot(1,2,1)
    set(gca,'FontSize',16);
    r=(maxtrans(:,:,[1])); %x, back-front
    b=(maxtrans(:,:,[2])); %y, left-right
    c=(maxtrans(:,:,[3])); %z, down-up
    scatter(r(:)*100,c(:)*100,5,'k','filled')
    ylim([-10,10])
    xlim([-25,25])
    ylabel('z (down/up) [cm]')
    xlabel('x (back/front) [cm]')
    title('Side view')
    set(gca,'FontSize',10);
    grid on
    subplot(1,2,2)
    scatter(b(:)*100,c(:)*100,5,'k','filled');
    ylim([-10,10])
    xlim([-25,25])
    ylabel('z (down/up) [cm]')
    xlabel('y (right/left) [cm]')
    title('Front view')
    set(gca,'FontSize',10);
    grid on
end

if flags.do_fig6a
    if flags.do_NT
        spdir=28;
    elseif flags.do_PG
        spdir=21;
    end
    idx=rot_t(:,4)==spdir; % select target direction
    scatter(rot_t(idx,5)*10,rot_t(idx,1),1,'MarkerEdgeColor','k','MarkerEdgeAlpha',0.5);
    xlabel('dur [ms]')
    ylabel('yaw [deg]')
    ylim([-10,70])
    xlim([0,2500])
    set(gca,'FontSize',14);
    set(gcf,'Position',[488  538  741  224])
end

if flags.do_fig6b
    if flags.do_NT
        spdir=28;
        [xmarker,ymarker,zmarker]=sph2cart(90/180*pi,60/180*pi,1);
    elseif flags.do_PG
        spdir=21;
        [xmarker,ymarker,zmarker]=sph2cart(45/180*pi,30/180*pi,1);
    end
    [x,y,z]=sphere;
    surf(x,y,z,'FaceColor','white');
    hold on
    idx=rot_t(:,4)==spdir; % select target direction
    rot_t=rot_t(idx,:);
    face=[1,0,0]'; % plot on sphere
    for j=1:length(rot_t) 
    rotM=rotMatrix(rot_t(j,1),rot_t(j,2),rot_t(j,3));
    face(:,j)=rotM*[1,0,0]';
    end
    scatter3(face(1,:),face(2,:),face(3,:),1,'MarkerEdgeColor','k','MarkerEdgeAlpha',0.5); hold on;
    scatter3(1,ymarker,zmarker,200,'MarkerEdgeColor','r','Marker','+','LineWidth',3)
    view([90,0]);
    grid off
    axis off
    set(gcf, 'Position',[488 521 290 241]);
end

if flags.do_fig8 % barplot R^2
    bar(mean(Rsq));
    hold on
    bar(mean(Rsq(:,1)),'FaceColor',[0.9290, 0.6940, 0.1250]);
    ylim([0,1])
    errorbar(mean(Rsq),std(Rsq),'.','Color','k','LineWidth',1)
    yline(mean(Rsq(:,1)),'--','Color','k')
    xticklabels({'R^2','R^2_1','R^2_2','R^2_3','R^2_4','R^2_5','R^2_6'})
end

if flags.do_fig10 % MODEL TESTING

k_all = fminsearch(@(k) minSimp(k, vectordata_all(:,1), vectordata_all(:,2), vectordata_all(:,3)), 1);  %single k value for all

% create vector of values for easy model input
for sub=1:17
    clear k_ind_sign s_ind_sign err
    
    idx=vectordata_all(:,5)==sub;
    y=vectordata_all(idx,1);
    x=vectordata_all(idx,2:3);
    e=logical(vectordata_all(idx,4));

    k_ind = k(1,sub); % individual k values
    k_ind_sign(e) = k(2,sub); % extension
    k_ind_sign(~e) = k(3,sub); % flexion
    s_ind_sign(e) = G(2,sub);
    s_ind_sign(~e) = G(3,sub);

    err(:,1)=y-kgimbal(0.5,x(:,1), x(:,2));          % Zero
    err(:,2)=y-kgimbal(0,x(:,1), x(:,2));            % Fick
    err(:,3)=y-kgimbal(k_all,x(:,1), x(:,2));        % k_all
    err(:,4)=y-kgimbal(k_ind,x(:,1), x(:,2));       % k_individual
    err(:,5)=y-kgimbal(k_ind_sign',x(:,1), x(:,2));  % k_ind_sign
    %err(:,6)=y-x(:,1).*x(:,2).*s_ind_sign';          % s_ind_sign
    err=abs(err);

    thickness(sub,:)=nanstd(2*atand(err));
end

b=boxchart(thickness,'JitterOutliers','on','MarkerStyle','.','BoxFaceColor',[0.8500 0.3250 0.0980],'MarkerColor',[0.8500 0.3250 0.0980]);
xticklabels({'k_0_._5','k_0','k_a_l_l','k_i','k_f_e'})
ylabel('\sigma')
xlabel('Model type')
ylim([0,6])
set(gcf,'Position',[488  342  334  420])
set(gca,'FontSize',14);
end

[rho,pval]=corr(reshape(maxrot(:,:,2),1,[])',reshape(maxtrans(:,:,1),1,[])','rows','complete');
%figure; scatter(reshape(maxrot(:,:,3:4),1,[])',reshape(maxtrans(:,:,1:2),1,[])')

% maxrotabs=squeeze(max(abs(maxrot),[],2));
% maxrotTabs=squeeze(max(abs(maxrotT),[],2));
% maxvelabs=squeeze(max(abs(maxvel),[],2));

end




function x = kgimbal(k,y,z)
  x=  z.*tan(2*k.*atan(y)-atan(y));
end

function F= minSimp(k,x,y,z)
  xmod=kgimbal(k,y,z);
  F=mean(abs(xmod-x));
end


function F=surfaceFit(a,data) %second-order twisted surface (Ceylan et al. 2000)
    order=2;
    ry=data(:,1);
    rz=data(:,2);

    if data(1,3)>0
    a(data(1,3))=0;
    end

    if order==1
        F=(a(1) + a(2)*ry + a(3)*rz);
    elseif order==2
        F=(a(1) + a(2)*ry + a(3)*rz + a(4)*ry.^2 + a(5)*ry.*rz + a(6)*rz.^2);
    end
end

function plotSurface(a,order)
    [ry,rz]=meshgrid(-1:0.1:1,-1:0.1:1);
    if order==1
    rx=(a(1) + a(2)*ry + a(3)*rz);   
    elseif order==2
    rx=(a(1) + a(2)*ry + a(3)*rz + a(4)*ry.^2 + a(5)*ry.*rz + a(6)*rz.^2);
    elseif order==3
    rx=(a(1) + a(2)*ry + a(3)*rz + a(4)*ry.^2 + a(5)*ry.*rz + a(6)*rz.^2+ a(7)*ry.^3 + a(8).*rz.^3 + a(9).*ry.^2.*rz + a(10).*rz.^2.*ry);
    end
    surf(rx,rz,ry,'FaceAlpha',0,'EdgeColor',[.7,.7,.7]);
    xlim([-1,1])
    ylim([-1,1])
    zlim([-1,1])
    xlabel('r_x','Rotation',0)
    ylabel('r_z','Rotation',0)
    zlabel('r_y','Rotation',0)
end

function rotM = rotMatrix(yaw,pitch,roll)
% return rotation matrix for specified azimuth and elevation rotation
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

% function r=errors(data,estimate)
%     I = ~isnan(data) & ~isnan(estimate); 
%     data = data(I); estimate = estimate(I);
%     r=data(:)-estimate(:);
% end






%% GIMBAL SCORE BARPLOT (doesnt work for condition 2 because heads stay close to reference)
% smean=cellfun(@mean,s);
% sstd=cellfun(@std,s);
% k_ext=(l_ext(:,2)+1)/2;
% k_flx=(l_flx(:,2)+1)/2;

% set(0,'CurrentFigure',fig6)
% bar([s_ext;s_flx]');
% hold on
% % Calculating the width for each bar group
% % ngroups = size(smean, 1);
% % nbars = size(smean, 2);
% % groupwidth = min(0.8, nbars/(nbars + 1.5));
% % for i = 1:nbars
% %     x = (1:ngroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
% %     errorbar(x, -smean(:,i),zeros(17:1),-sstd(:,i),'Color','k','LineStyle','none');
% % end
% hold off

% xticks(1:17)
% ylabel('Gimbal score')
% legend('Extension','Flexion')

% plane_mean=[0.000,-0.027,-0.003,-0.130,-1.074,-0.017]; %condition 2
% %plane_mean=[0.000,-0.018,0.013,-0.018,-0.794,-0.007]; %condition 0
% 
% F=surfaceFit(plane_mean,[a(:,2),a(:,3)]);
% residual=a(:,1)-F;
% thickness_mean(1,subject)=std(2*atand(residual));


% function [ax, ay, az] = rotVec(roll, pitch, yaw)
%     %Obtain rotation vector according to Haustein et al. 1989
%     t=deg2rad(roll);
%     h=deg2rad(yaw);
%     v=deg2rad(pitch);
%     ax = t;
%     ay = -v-h.*t;
%     az = -h+v.*t;
% end
% 
% function [roll,pitch,yaw] = rotVecInv(ax,ay,az)
%     %Obtain yaw,pitch,roll components from rotation vector defined by Haustein et al. 1989
%     h=(-az-ax.*ay)./(1+ax.^2);
%     v=(-ay-ax.*az)./(1+ax.^2);
%     t=ax;
%     roll=rad2deg(t);
%     yaw=rad2deg(h);
%     pitch=rad2deg(v);
% end