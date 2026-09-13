% [this script is written by codex] 

function srir_delayed = restore_geometric_delay(srir, fs, pos_src, pos_rec) 
% Restore propagation delay removed by onset alignment in the transition dataset.
% 恢复 transition 数据集在 onset alignment 过程中移除的几何传播延迟。 
% 具体做法是：先在测量 IR 的 omni/ACN0 通道中检测当前直达声样本点，
% 再用 source 和 listener 的三维坐标距离计算理论直达声到达样本点，
% 两者之差就是需要补回到 IR 前面的静音样本数

    c = 343; % 声速
    window_dur_ms = 3; % 外推函数中到达声提取窗口长度，单位 ms。
    prewindow_samp = round(fs*((window_dur_ms/1000)/4)); % 计算窗口前置样本数，用于后续安全检查。
    
    ir = abs(lowpass(highpass(srir(:,1),700,fs),5000,fs)); % 对 omni 通道做 700-5000 Hz 带通并取绝对值，突出直达声峰值。
    absir = ir ./ max(ir); % 归一化幅度，方便用固定阈值找峰。
    [~,lcs] = findpeaks(absir,"MinPeakDistance",50,MinPeakHeight=0.05); % 查找候选直达声峰值位置。

    if isempty(lcs) % 如果没有找到任何峰值。
        warning('Could not detect direct sound onset; leaving SRIR delay unchanged.'); 
        % 如果没有检测到可靠的直达声峰值，就不要强行移动 IR；
        % 保持原始 SRIR 不变可以避免把错误的峰值当作直达声并引入更大的时间错位。
        srir_delayed = srir; 
        return 
    end 
    
    toa_meas = lcs(1); % 取第一个峰值作为测量 IR 中的直达声到达样本。
    toa_geom = round(norm(pos_src(:)-pos_rec(:)) / c * fs); % 根据 source-listener 距离计算理论直达声样本。
    delay_samp = toa_geom - toa_meas; % 计算需要补回的前置静音样本数。
    
    if delay_samp > 0 % 如果测量直达声比几何直达声更早，说明需要在前面补零。
        srir_delayed = [zeros(delay_samp,size(srir,2)); srir]; % 在所有通道前面补 delay_samp 个零样本。
        srir_delayed = srir_delayed(1:size(srir,1),:); % 截回原始长度，避免改变后续数组尺寸。
        fprintf('Restored geometric delay: measured DS at sample %d, geometric DS at sample %d, prepended %d samples.\n', ... 
            toa_meas, toa_geom, delay_samp); 
    else % 如果不需要补零。
        srir_delayed = srir; % 保持原始 SRIR 不变。
        fprintf('Geometric delay restoration skipped: measured DS at sample %d, geometric DS at sample %d.\n', ... 
            toa_meas, toa_geom); % 打印测量直达声和几何直达声位置。
    end 
    
    % Keep enough samples before the direct sound for the extrapolator's window. 
    % 确保恢复后的直达声前面仍有足够的样本，供外推函数截取 pre-window。 
    % 当前外推函数会在直达声之前取一小段窗口用于 DoA 估计和到达声提取；
    % 如果补偿后直达声仍然太靠近开头，后续仍可能出现窗口越界或估计不稳定。
    if delay_samp > 0 && toa_geom <= prewindow_samp % 如果补偿后直达声仍然太靠近开头。
        warning('Restored direct sound is still too close to the start for the extraction pre-window.'); 
    end

end
