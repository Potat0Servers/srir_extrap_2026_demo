function met = exp_mclachlan2024(varargin)


%% ------ Check input options ---------------------------------------------
definput.import = {'amt_cache'};
definput.keyvals.MarkerSize = 6;
definput.keyvals.FontSize = 12;

definput.flags.type = {'missingflag','tab2','fig1','fig2','fig3','fig4','fig5','fig6','fig7','trackerstats','demoKent','snap'};
definput.flags.plot = {'plot', 'no_plot'};
definput.flags.redo = {'no_redo_fast','redo_fast', 'redo'};
definput.flags.plot_type = {'interp','scatter'};

[flags,kv]  = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
  flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
             sprintf('%s or %s',definput.flags.type{end-1},...
             definput.flags.type{end})];
  error('%s: You must specify one of the following flags: %s.', ...
      upper(mfilename),flagnames);
end
       
% initialise variables
subjects = {'NH214','NH257','NH919','NH963','NH1144','NH1146','NH1147','NH1150'};
ms_emp=[];
md_emp=[];
m17s=[];
m17d=[];
doa_mod.s.est=[];
doa_mod.s.real=[];
doa_mod.d.est=[];
doa_mod.d.real=[];

% load experimental data
expdat_s = data_mclachlan2024('static'); %experimental data static
expdat_d = data_mclachlan2024('dynamic'); %experimental data dynamic

% omit outliers and drop results of headphone condition
ed_all=0;
for s=1:length(subjects)
    [tmp,es] = omitTrials(expdat_s(s),1);
    ms_emp=[ms_emp; tmp.m_exp(:,:,2)];
    expdat_s(s).T=tmp.T;

    [tmp,ed] = omitTrials(expdat_d(s),2);
    md_emp=[md_emp; tmp.m_exp(:,:,2)];
    ed_all=ed_all+length(ed);
    expdat_d(s).T=tmp.T;
end

met.emp.s = mclachlan2024_metrics(ms_emp);
met.emp.d = mclachlan2024_metrics(md_emp);

if flags.do_tab2 % 
    % RUN MODEL
    if flags.do_redo
    for sub=1:length(subjects)
        template{sub} = mclachlan2023_featureextraction(expdat_s(sub).HRTF,'group_2024_stat','source_ir',0); % generate template
        template{sub}.id=str2num(expdat_s(sub).id(3:end));

        doa_s = mclachlan2023(template{sub}, 'group_2024_stat'); %run model static
        doa_d = mclachlan2023(template{sub}, 'group_2024_act','track_data',expdat_d(s).T); %run model active

        %reformat
        doa_mod.s.est=[doa_mod.s.est; doa_s.est];
        doa_mod.s.real=[doa_mod.s.real; doa_s.real];
        doa_mod.d.est=[doa_mod.d.est; doa_d.est];
        doa_mod.d.real=[doa_mod.d.real; doa_d.real];

        %concatenate subject list
        m17s=[m17s;repmat(template{sub}.id,length(doa_s.real),1)];
        m17d=[m17d;repmat(template{sub}.id,length(doa_d.real),1)];
    end
    ms_mod=formatData(doa_mod.s,m17s,500);
    md_mod=formatData(doa_mod.d,m17d,0);
    save('model_fig1.mat','ms_mod','md_mod')
    save('template.mat','template')
    tab2=load('model_fig1'); 
    else
        tab2=load('model_fig1'); 
        %tab2=amt_cache('get','model_fig1',flags.cachemode); 
    end

    met.mod.s=mclachlan2024_metrics(tab2.ms_mod);
    met.mod.d=mclachlan2024_metrics(tab2.md_mod);

    % FORMAT TABLE
    Condition=["B-Static";"B-Dynamic";"M-Static";"M-Dynamic"];
    [Ys_emp,Ms_emp]=std([met.emp.s.rmsL;met.emp.s.rmsP;met.emp.s.querr;met.emp.s.FBC;met.emp.s.UDC],[],2);
    [Yd_emp,Md_emp]=std([met.emp.d.rmsL;met.emp.d.rmsP;met.emp.d.querr;met.emp.d.FBC;met.emp.d.UDC],[],2);
    [Ys_mod,Ms_mod]=std([met.mod.s.rmsL;met.mod.s.rmsP;met.mod.s.querr;met.mod.s.FBC;met.mod.s.UDC],[],2);
    [Yd_mod,Md_mod]=std([met.mod.d.rmsL;met.mod.d.rmsP;met.mod.d.querr;met.mod.d.FBC;met.mod.d.UDC],[],2);

    s_emp=reshape([Ms_emp,Ys_emp]',1,[]);
    d_emp=reshape([Md_emp,Yd_emp]',1,[]);
    s_mod=reshape([Ms_mod,Ys_mod]',1,[]);
    d_mod=reshape([Md_mod,Yd_mod]',1,[]);
    err=[s_emp;d_emp;s_mod;d_mod];

    tab2 = table(Condition,err(:,1),err(:,2),err(:,3),err(:,4),err(:,5),err(:,6),err(:,7),err(:,8),err(:,9),err(:,10));
    tab2.Properties.VariableNames(2:end)={'mean LRMSE','std LRMSE','mean PRMSE','std PRMSE','mean QE','std QE','mean FBC','std FBC','mean UDC','std UDC'}

end

if flags.do_demoKent
    met = met.emp.s;

    idx=(round(ms_emp(:,5))==30 & round(ms_emp(:,6))==30);
    est=ms_emp(idx,12:14);

    dirs=met.dirs;
    %% Kent plot
    figure
    hold on;
    colormap([1 1 1]);
    set(gca,'Visible','off');
    
    % draw a sphere
    daz=30;
    AZgrid=repmat((-90:90),length(-180:daz:180),1)'*pi/180; 
    ELgrid=repmat((-180:daz:180)',1,length(-90:90))'*pi/180; 
    [xgrid1,zgrid1,ygrid1]=sph2cart(AZgrid,ELgrid,1);
    [xgrid2,zgrid2,ygrid2]=sph2cart(ELgrid,AZgrid,1);
    [X,Y,Z] = sphere;
    surf(X*0.95,Y*0.95,Z*0.95,'FaceColor','white','EdgeColor','none');
    plot3(xgrid1,ygrid1,zgrid1,'Color',[.7 .7 .7]);
    hold on
    plot3(xgrid2,ygrid2,zgrid2,'Color',[.7 .7 .7]);
    view(90,0);
    
    scatter3(dirs(28,1),dirs(28,2),dirs(28,3),30,'xk'); 		% plot target locations
    %plot bias
    q1=quiver3(dirs(28,1),dirs(28,2),dirs(28,3),met.bias_perdir(28,1)-dirs(28,1),met.bias_perdir(28,2)-dirs(28,2),met.bias_perdir(28,3)-dirs(28,3),'off','Color','k');
    q1.MaxHeadSize = 0.05;
    q1.LineWidth = 1.5;
    scatter3(est(:,1),est(:,2),est(:,3),28,'.k');
    % plot kent distributions
    p=fill3(met.kentdist(28,:,1),met.kentdist(28,:,2),met.kentdist(28,:,3),'k');
    p.FaceAlpha = 0.1;
    
    axis equal
    daspect([1 1 1]);
    pbaspect([1 1 1]);
end

if flags.do_fig1 % Kent distributions         

    if flags.do_redo %model computation
        exp_mclachlan2024('tab2','redo')
    else
        %fig1=amt_cache('get','model_fig1',flags.cachemode); 
        fig1=load('model_fig1'); 
    end

    met.mod.s = mclachlan2024_metrics(fig1.ms_mod);
    met.mod.d = mclachlan2024_metrics(fig1.md_mod);

    % plots
    fig = figure('Position', get(0, 'Screensize'));
    tiledlayout(1,4,'TileSpacing','tight','Padding','compact');
    nexttile(1);
    plot_mclachlan2024('fig1',met.emp.s,met.emp.s.dirs); % empirical static
    xPlane = [-1.2,1.2,1.2,-1.2]; yPlane = [0 0 0 0]; zPlane = [-1.2,-1.2,1.2,1.2];
    patch(xPlane, yPlane, zPlane, 'w');
    view(0,0)
    nexttile(3);
    plot_mclachlan2024('fig1',met.emp.d,met.emp.d.dirs); % empirical dynamic
    patch(xPlane, yPlane, zPlane, 'w');
    view(0,0)
    nexttile(2);
    plot_mclachlan2024('fig1',met.mod.s,met.mod.s.dirs); % model static
    patch(xPlane, yPlane, zPlane, 'w');
    view(0,0)
    nexttile(4);
    plot_mclachlan2024('fig1',met.mod.d,met.mod.d.dirs); % model dynamic
    patch(xPlane, yPlane, zPlane, 'w');
    view(0,0)
end

if flags.do_fig2  % FBC plots        

    if flags.do_redo %model computation
        for sub=1:length(subjects)
            template{sub} = mclachlan2023_featureextraction(expdat_s(sub).HRTF,'group_2024_stat','source_ir',0); % generate template
            template{sub}.id=str2num(expdat_s(sub).id(3:end));

           doa_s = mclachlan2023(template{sub}, 'group_2024_stat'); %run model static
           doa_d1 = mclachlan2023(template{sub}, 'group_2024_left'); %run model rotation left
           doa_d2 = mclachlan2023(template{sub}, 'group_2024_right'); %run model rotation right
           
           ndirs=size(doa_s.est,1);
           nexp=size(doa_s.est,2);

           %reformat
           doa_mod.s.est=[doa_mod.s.est; reshape(doa_s.est,ndirs*nexp,3)];
           doa_mod.s.real=[doa_mod.s.real; repmat(doa_s.real,nexp,1)];
           doa_mod.d.est=[doa_mod.d.est; reshape(doa_d1.est,ndirs*nexp,3);reshape(doa_d2.est,ndirs*nexp,3)];
           doa_mod.d.real=[doa_mod.d.real; repmat(doa_d1.real,nexp,1); repmat(doa_d2.real,nexp,1)];
    
            %concatenate subject list
            m17s=[m17s;repmat(template{sub}.id,ndirs*nexp,1)];
            m17d=[m17d;repmat(template{sub}.id,ndirs*nexp*2,1)];
        end
        ms_mod=formatData(doa_mod.s,m17s,100);
        md_mod=formatData(doa_mod.d,m17d,100);
    else
        %fig2=amt_cache('get','model_fig1',flags.cachemode); %same data as fig 1
        fig2=load('model_fig1'); 
    end

    met.mod.s = mclachlan2024_metrics(fig2.ms_mod);
    met.mod.d = mclachlan2024_metrics(fig2.md_mod);

    % plots
    fig = figure('Position', get(0, 'Screensize'));
    tiledlayout(1,4,'TileSpacing','tight','Padding','compact');
    nexttile(1);
    plot_mclachlan2024('fig2',met.emp.s,met.emp.s.dirs); % empirical static
    nexttile(3);
    plot_mclachlan2024('fig2',met.emp.d,met.emp.d.dirs); % empirical dynamic
    nexttile(2);
    plot_mclachlan2024('fig2',met.mod.s,met.mod.s.dirs); % model static
    nexttile(4);
    plot_mclachlan2024('fig2',met.mod.d,met.mod.d.dirs); % model dynamic
end

if flags.do_fig3 %time steps
    dt=[0.01,0.02,0.05,0.1,0.2,0.5];
    if flags.do_redo %model computation
        for i=1:length(dt)
            doa_mod.s.est=[];
            doa_mod.s.real=[];
            doa_mod.d.est=[];
            doa_mod.d.real=[];
            m17s=[];
            m17d=[];

            for sub=1:8
                template{sub} = mclachlan2023_featureextraction(expdat_s(sub).HRTF,'group_2024_stat','source_ir',0); % generate template
                template{sub}.id=str2double(expdat_s(sub).id(3:end));                 
                doa_s = parfor_mclachlan2024(template{sub}, 'group_2024_stat','dt',dt(i)); %run model static
                doa_d = parfor_mclachlan2024(template{sub}, 'group_2024_act','track_data',expdat_d(s).T,'dt',dt(i)); %run model active
        
                %reformat
                doa_mod.s.est=[doa_mod.s.est; doa_s.est];
                doa_mod.s.real=[doa_mod.s.real; doa_s.real];
                doa_mod.d.est=[doa_mod.d.est; doa_d.est];
                doa_mod.d.real=[doa_mod.d.real; doa_d.real];
                
                %concatenate subject list
                m17s=[m17s;repmat(template{sub}.id,length(doa_s.real),1)];
                m17d=[m17d;repmat(template{sub}.id,length(doa_d.real),1)];
            end
            ms_mod{i}=formatData(doa_mod.s,m17s,500);
            md_mod{i}=formatData(doa_mod.d,m17d,0);
        end
        save('model_fig3b','ms_mod','md_mod');
    else % no redo
        fig3=load('model_fig3');
        %fig3=amt_cache('get','model_fig3',flags.cachemode);
    end

    for d=1:length(dt)    
        tmp_s=mclachlan2024_metrics(fig3.ms_mod{d});
        tmp_d=mclachlan2024_metrics(fig3.md_mod{d});
        met.mod.s.rmsL(d,:)=tmp_s.rmsL;
        met.mod.s.rmsP(d,:)=tmp_s.rmsP;
        met.mod.s.querr(d,:)=tmp_s.querr;
        met.mod.d.rmsL(d,:)=tmp_d.rmsL;
        met.mod.d.rmsP(d,:)=tmp_d.rmsP;
        met.mod.d.querr(d,:)=tmp_d.querr;
    end

    plot_mclachlan2024('fig3',met)

end

if flags.do_fig4 %itd plot
    itd=[0.3,0.6,1.2,1.8,2.4,3.0];
    if flags.do_redo %model computation
        for i=1:length(itd)
            doa_mod.s.est=[];
            doa_mod.s.real=[];
            doa_mod.d.est=[];
            doa_mod.d.real=[];
            m17s=[];
            m17d=[];
            for sub=1:8
               template{sub} = mclachlan2023_featureextraction(expdat_s(sub).HRTF,'group_2024_stat','source_ir',0); % generate template
               template{sub}.id=str2num(expdat_s(sub).id(3:end));    

                doa_s = parfor_mclachlan2024(template{sub}, 'group_2024_stat','sig_itd0',itd(i)); %run model static
                doa_d = parfor_mclachlan2024(template{sub}, 'group_2024_act','track_data',expdat_d(s).T,'sig_itd0',itd(i)); %run model active
        
                %reformat
                doa_mod.s.est=[doa_mod.s.est; doa_s.est];
                doa_mod.s.real=[doa_mod.s.real; doa_s.real];
                doa_mod.d.est=[doa_mod.d.est; doa_d.est];
                doa_mod.d.real=[doa_mod.d.real; doa_d.real];
                
                %concatenate subject list
                m17s=[m17s;repmat(template{sub}.id,length(doa_s.real),1)];
                m17d=[m17d;repmat(template{sub}.id,length(doa_d.real),1)];
            end
            ms_mod{i}=formatData(doa_mod.s,m17s,500);
            md_mod{i}=formatData(doa_mod.d,m17d,0);
        end
        save('model_fig4','ms_mod','md_mod');
        fig4.ms_mod=ms_mod;
        fig4.md_mod=md_mod;
    else % no redo
        fig4=load('model_fig4');
        %fig4=amt_cache('get','model_fig4',flags.cachemode);
    end

    for i=1:length(itd)    
        tmp_s=mclachlan2024_metrics(fig4.ms_mod{i});
        tmp_d=mclachlan2024_metrics(fig4.md_mod{i});
        met.mod.s.rmsL(i,:)=tmp_s.rmsL;
        met.mod.s.rmsP(i,:)=tmp_s.rmsP;
        met.mod.s.querr(i,:)=tmp_s.querr;
        met.mod.d.rmsL(i,:)=tmp_d.rmsL;
        met.mod.d.rmsP(i,:)=tmp_d.rmsP;
        met.mod.d.querr(i,:)=tmp_d.querr;
    end

    plot_mclachlan2024('fig4',met)
end

if flags.do_fig5 %motor plot
    sigH=[0.0001,2,4,8];
    sigu=[8];
    if flags.do_redo %model computation
        for i=1:length(sigu)
        for j=1:length(sigH)
            doa_mod.s.est=[];
            doa_mod.s.real=[];
            doa_mod.d.est=[];
            doa_mod.d.real=[];
            m17s=[];
            m17d=[];
            for sub=1:8
                template{sub} = mclachlan2023_featureextraction(expdat_s(sub).HRTF,'group_2024_stat','source_ir',0); % generate template
                template{sub}.id=str2double(expdat_s(sub).id(3:end));                 
                doa_s = parfor_mclachlan2024(template{sub}, 'group_2024_stat','sig_u',sigu(i),'sig_H',sigH(j)); %run model static
                doa_d = parfor_mclachlan2024(template{sub}, 'group_2024_act','track_data',expdat_d(s).T,'sig_u',sigu(i),'sig_H',sigH(j)); %run model active
        
                %reformat
                doa_mod.s.est=[doa_mod.s.est; doa_s.est];
                doa_mod.s.real=[doa_mod.s.real; doa_s.real];
                doa_mod.d.est=[doa_mod.d.est; doa_d.est];
                doa_mod.d.real=[doa_mod.d.real; doa_d.real];
                
                %concatenate subject list
                m17s=[m17s;repmat(template{sub}.id,length(doa_s.real),1)];
                m17d=[m17d;repmat(template{sub}.id,length(doa_d.real),1)];
            end
            ms_mod{i,j}=formatData(doa_mod.s,m17s,100);
            md_mod{i,j}=formatData(doa_mod.d,m17d,100);
        end
        end
        save('model_fig5b','ms_mod','md_mod');
        fig5.ms_mod=ms_mod;
        fig5.md_mod=md_mod;
    else % no redo
        fig5=load('model_fig5');
        %fig5=amt_cache('get','model_fig5',flags.cachemode);
    end

    %plot figure
    for i=1:length(sigH)
        for j=1:2
            tmp_s=mclachlan2024_metrics(fig5.ms_mod{j,i});
            tmp_d=mclachlan2024_metrics(fig5.md_mod{j,i});
            met.mod.s.rmsL((i-1)*2+j,:)=tmp_s.rmsL;
            met.mod.s.rmsP((i-1)*2+j,:)=tmp_s.rmsP;
            met.mod.s.querr((i-1)*2+j,:)=tmp_s.querr;
            met.mod.d.rmsL((i-1)*2+j,:)=tmp_d.rmsL;
            met.mod.d.rmsP((i-1)*2+j,:)=tmp_d.rmsP;
            met.mod.d.querr((i-1)*2+j,:)=tmp_d.querr;
        end
    end

    plot_mclachlan2024('fig5',met)

end

if flags.do_fig6 %prior plot
    pr=[10,20,30,40,50,60];
    if flags.do_redo %model computation
        for i=1:length(pr)
            doa_mod.s.est=[];
            doa_mod.s.real=[];
            doa_mod.d.est=[];
            doa_mod.d.real=[];
            m17s=[];
            m17d=[];
            for sub=1:8
                template{sub} = mclachlan2023_featureextraction(expdat_s(sub).HRTF,'group_2024_stat','source_ir',0); % generate template
                template{sub}.id=str2double(expdat_s(sub).id(3:end));

                doa_s = mclachlan2023(template{sub}, 'group_2024_stat','sig_p',pr(i)); %run model static
                doa_d = mclachlan2023(template{sub}, 'group_2024_act','track_data',expdat_d(s).T,'sig_p',pr(i)); %run model active
        
                %reformat
                doa_mod.s.est=[doa_mod.s.est; doa_s.est];
                doa_mod.s.real=[doa_mod.s.real; doa_s.real];
                doa_mod.d.est=[doa_mod.d.est; doa_d.est];
                doa_mod.d.real=[doa_mod.d.real; doa_d.real];
                
                %concatenate subject list
                m17s=[m17s;repmat(template{sub}.id,length(doa_s.real),1)];
                m17d=[m17d;repmat(template{sub}.id,length(doa_d.real),1)];
            end
            ms_mod{i}=formatData(doa_mod.s,m17s,100);
            md_mod{i}=formatData(doa_mod.d,m17d,100);
        end
        save('model_fig6','ms_mod','md_mod');
        fig6.ms_mod=ms_mod;
        fig6.md_mod=md_mod;
    else % no redo
        fig6=load("model_fig6.mat");
        %fig6=amt_cache('get','model_fig6',flags.cachemode);
    end

    for i=1:length(pr)    
        tmp_s=mclachlan2024_metrics(fig6.ms_mod{i});
        tmp_d=mclachlan2024_metrics(fig6.md_mod{i});
        met.mod.s.gain(i,:)=tmp_s.gain;
        met.mod.s.querr(i,:)=tmp_s.querr;
        met.mod.d.gain(i,:)=tmp_d.gain;
        met.mod.d.querr(i,:)=tmp_d.querr;
        
    end

    plot_mclachlan2024('fig6',met)
end

if flags.do_fig7 %prior shape
    shape={'gaussian','laplace'};
    if flags.do_redo %model computation
        for i=1:length(shape)
            doa_mod.s.est=[];
            doa_mod.s.real=[];
            doa_mod.d.est=[];
            doa_mod.d.real=[];
            m17s=[];
            m17d=[];
            for sub=1:8
                template{sub} = mclachlan2023_featureextraction(expdat_s(sub).HRTF,'group_2024_stat','source_ir',0); % generate template
                template{sub}.id=str2double(expdat_s(sub).id(3:end));                 
                doa_s = parfor_mclachlan2024(template{sub}, 'group_2024_stat','priorshape',shape{i},'sig_p',29.6); %run model static
                doa_d = parfor_mclachlan2024(template{sub}, 'group_2024_act','track_data',expdat_d(s).T,'priorshape',shape{i},'sig_p',29.6); %run model active
        
                %reformat
                doa_mod.s.est=[doa_mod.s.est; doa_s.est];
                doa_mod.s.real=[doa_mod.s.real; doa_s.real];
                doa_mod.d.est=[doa_mod.d.est; doa_d.est];
                doa_mod.d.real=[doa_mod.d.real; doa_d.real];
                
                %concatenate subject list
                m17s=[m17s;repmat(template{sub}.id,length(doa_s.real),1)];
                m17d=[m17d;repmat(template{sub}.id,length(doa_d.real),1)];
            end
        ms_mod{i}=formatData(doa_mod.s,m17s,100);
        md_mod{i}=formatData(doa_mod.d,m17d,100);
        end
        save('model_fig7','ms_mod','md_mod');
    else % no redo
        fig7=load('model_fig7');
        %fig7=amt_cache('get','model_fig7',flags.cachemode);
    end

    for i=1:length(shape)    
        met.mod.s{i}=mclachlan2024_metrics(fig7.ms_mod{i});
        met.mod.d{i}=mclachlan2024_metrics(fig7.md_mod{i});
    end

    dirs=met.mod.s{1}.dirs;
    
    fig = figure;
    tiledlayout(2,3,'TileSpacing','tight','Padding','compact');
    nexttile(1);
    plot_mclachlan2024('fig1',met.emp.d,met.emp.d.dirs); % 
    view(90,90)
    nexttile(2);
    plot_mclachlan2024('fig1',met.mod.s{1},met.mod.s{1}.dirs); %gaussian prior
    view(90,90)
    nexttile(3);
    plot_mclachlan2024('fig1',met.mod.s{2},met.mod.s{2}.dirs); %laplacian prior
    view(90,90)
    nexttile(4);
    plot_mclachlan2024('fig2',met.emp.s,met.emp.s.dirs); % 
    view(90,90)
    nexttile(5);
    plot_mclachlan2024('fig2',met.mod.s{1},met.mod.s{1}.dirs); %gaussian prior
    view(90,90)
    nexttile(6);
    plot_mclachlan2024('fig2',met.mod.s{2},met.mod.s{2}.dirs); %laplacian prior
    view(90,90)

end

if flags.do_trackerstats

    figure;
    subplot(3,1,1)
    subtitle('yaw')
    subplot(3,1,2)
    subtitle('pitch')
    subplot(3,1,3)
    subtitle('roll')
    for sub=1:length(subjects)
        trackerdat = expdat_d(sub).T;
        for i=1:length(trackerdat)
            tmp=trackerdat{i};
            l=find( abs(tmp(:,1)-tmp(1,1)) > 0.5, 1 )/10; 
            if l>0
                latency(sub,i)= l;
            else
                latency(sub,i)=nan;
            end
            dur(sub,i)=(length(tmp));
            if ~isnan(tmp)
                
               x=(1:length(tmp(:,1)))*10;
                subplot(3,1,1)
                plot(x,tmp(:,1)); hold on
                subplot(3,1,2)
                plot(x,tmp(:,2)); hold on
                subplot(3,1,3)
                plot(x,tmp(:,3)); hold on
                roll(sub,i)=max(abs(tmp(:,3)))-min(abs(tmp(:,3)));
            else
                roll(sub,i)=nan;
            end
            acc(sub,i)=2*tmp(end,1)/dur(sub,i)^2;
            
        end
        
    end
    meanroll=nanmean(roll,'all')
    stdroll = nanstd(roll,[],'all')
    meanlatency = nanmean(latency,'all')
    stdlatency = nanstd(latency,[],'all')
    meandur = nanmean(dur,'all')
    stddur = nanstd(dur,[],'all')
end

end






function [data_out,e] = omitTrials(data_in,mov)

data_out=data_in;
e=[];

for i=1:size(data_in.T)
    v=data_in.T{i};
    if mov==1
        if (any(abs(v)>2)) % minimum allowed rotation size and maximum allowed deviation
            e = [e, i];
            data_out.T{i} = [];
        end
    elseif mov==2
        if  abs(max(v(:,1))-min(v(:,1)))>13 || abs(v(end,1))<7 || max(abs(v(:,2)))>6; % minimum allowed rotation size
            e = [e, i];
            data_out.T{i} = nan;
        else
            for j=1:length(v(:,1))
                if abs(v(j,3)-median(v(:,3)))>2.5
                    v(j,3)=median(v(:,3));
                end
            end
            v=smoothdata(v,'sgolay','SmoothingFactor',0.1);
            data_out.T{i}=v;
        end
    end
end
data_out.m_exp(e,:,:)=[];
end

function m=formatData(doa,subject,dur)
    % real doa, in spherical and lat-pol coordinates
    sph_real = SOFAconvertCoordinates(doa.real, 'cartesian', 'spherical');
    [lat_real,pol_real]=sph2horpolar(sph_real(:,1),sph_real(:,2));
    num_dirs = size(doa.real,1);
    doa.est = squeeze(doa.est);
    
    if size(doa.est, 3) ~= 1 % remove third dimension relative to repetition of experiments
        num_exp = size(doa.est, 2);
        doa_est = [];
    
        for i = 1:size(doa.est, 1)
            est = squeeze(doa.est(i,:,:));
            doa_est = [doa_est; est];
        end
    else
        if(size(doa.est, 1) == num_dirs)
            num_exp = 1;
        else
            num_exp = size(doa.est, 1);
        end
        doa_est = doa.est;
    end
    
    % mean estimated doa over all experiments, in spherical and lat-pol coordinates
        sph_est = SOFAconvertCoordinates(doa_est, 'cartesian', 'spherical');
        [lat_est,pol_est] = sph2horpolar(sph_est(:,1),sph_est(:,2));
        
        % matrix of all doas
        m = zeros(size(sph_real, 1)*num_exp, 14);
        m(:, 1:2) = repelem(sph_real(:, [1 2]), num_exp, 1);     % spherical real
        m(:, 3:4) = sph_est(:, [1 2]);                          % spherical estimate
        m(:, 5:6) = repelem([lat_real,pol_real], num_exp, 1);    % lat-pol real
        m(:, 7:8) = [lat_est,pol_est];                          % lat-pol estimate
        m(:, 9:11) = repelem(doa.real(:,1:3),num_exp, 1);        % cartesian real
        m(:, 12:14) = doa_est(:,1:3);                           % cartesian estimate
        
        % ensure real values, as sph2horpolar can return complex numbers 
        % due to numerical approximations
        m = real(m);
        m(:,15)=dur;
        m(:,17)=subject;
end
