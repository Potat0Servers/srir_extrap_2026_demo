# test_extrapolate_srir_180526_Baseline 调用树

## 总览

- 总层数: 6 层
- 内容最多的一层: 第 3 层，约 32 个节点

test_extrapolate_srir_180526_Baseline.m
├─ addpaths.m
├─ load_ambisonic_configuration.m
│  	├─ load_hrirs_lebedev.m
│  	├─ generate_binaural_Ambisonic_decoder.m
│  	│  	├─ ambiDecoder.m
│  	│ 	 │  	├─ getRSH.m
│ 	 │  	│  	└─ getMaxREchannelweights.m
│  	│  	└─ ambisonic_crossover.m
│	  ├─ ambisonic_time_alignment.m
│  	│ 	 ├─ ambisonic_crossover.m
│  	│ 	 └─ remove_ITD_HRIRs  [local function]
│ 	 └─ ambisonic_diffuse_field_equalisation.m
│ 	   	 ├─ tdesign2azi_ele  [local function]
│   	  	└─ generate_binaural_Ambisonic_decoder.m
├─ SOFAload.m
│ 	 ├─ SOFAarghelper.m
│  	├─ SOFAcheckFilename.m
│  	├─ NETCDFload.m
│  	├─ SOFAgetConventions.m
│	  │  	└─ SOFAdefinitions.m
│ 	 └─ SOFAupdateDimensions.m
├─ SOFAplotGeometry.m
│ 	 ├─ SOFAarghelper.m
│ 	 ├─ SOFAexpand.m
│ 	 ├─ SOFAconvertCoordinates.m
│  	└─ sph2SH.m
├─ extrapolate_srir_180526.m
│ 	 ├─ SOFAload.m
│ 	 ├─ find_direct_sound  [local function]
│	  ├─ ism_calculate  [local function]
│ 	 │  	└─ flagMatchingRows  [local function]
│  	├─ doa_pwd  [local function]
│ 	 │ 	 ├─ grid2dirs.m
│ 	 │  	└─ sphPWDmap.m
│	  ├─ srir_arrival_remove  [local function]
│ 	 │ 	 └─ beamform_extract_remove  [local function]
│ 	 │	   	  ├─ getRealSH_N3D  [local function]
│	  │    		 └─ expandWeights_ACN  [local function]
│ 	 ├─ rotateHOA_N3D.m
│  	├─ azel2vec  [local function]
│  	└─ ir2lowpass  [local function]
│  	  	 └─ errorFunction  [nested function]
├─ render_binaural  [local function in main file]
├─ mckenzie2025.m
├─ freqplot_smooth.m
├─ plot_doa_horiz  [local function in main file]
│ 	 ├─ grid2dirs.m
│  	├─ ambisonic_crossover.m
│ 	 └─ sphPWDmap.m
├─ get_pwd  [local function in main file]
│	  ├─ grid2dirs.m
│	  ├─ ambisonic_crossover.m
│  	└─ sphPWDmap.m
├─ heatmap_plot_hammer.m
└─ plot_doa_horiz_time  [local function in main file]
  	 ├─ grid2dirs.m
   	├─ ambisonic_crossover.m
   	└─ sphPWDmap.m



## 调用树

### `test_extrapolate_srir_180526_Baseline.m`

| 项目 | 内容 |
|---|---|
| 功能 | 主实验脚本；加载工具箱和数据，执行 SRIR 外推，并进行时域、频域、双耳色彩、DoA 可视化评估。 |
| 输入 | 6DoF SRIR SOFA 文件、扬声器直达声指向性 SOFA 文件、脚本内设置参数。 |
| 输出 | `srir_new`、`brir_*`、PBC/DoA 指标、若干图形窗口/可选导出 PDF、音频播放。 |

#### `addpaths.m`

| 项目 | 内容 |
|---|---|
| 功能 | 将项目依赖工具箱和数据目录递归加入 MATLAB path。 |
| 输入 | 无显式输入；使用当前文件所在目录作为根目录。 |
| 输出 | 无返回值；副作用是修改 MATLAB path。 |

#### `load_ambisonic_configuration.m`

| 项目 | 内容 |
|---|---|
| 功能 | 配置并生成双耳 Ambisonic 解码器。 |
| 输入 | 脚本内 `ambisonic_order`、`dualband_flag`、预处理开关等参数。 |
| 输出 | `SH_ambisonic_binaural_decoder`、`SH_ambisonic_binaural_decoder_NPP`、`VL_hrirs`、`loudspeaker_directions`、`Fs` 等工作区变量。 |

##### `load_hrirs_lebedev.m`

| 项目 | 内容 |
|---|---|
| 功能 | 按 Ambisonic 阶数加载 Lebedev 虚拟扬声器方向和对应 HRIR。 |
| 输入 | `ambisonic_order`。 |
| 输出 | `loudspeaker_directions`、`VL_hrirs`、`Fs`。 |

##### `generate_binaural_Ambisonic_decoder.m`

| 项目 | 内容 |
|---|---|
| 功能 | 将虚拟扬声器 HRIR 编码为 SH/Ambisonic 双耳解码器，可选 dual-band 解码。 |
| 输入 | `ambisonic_order`、`VL_hrirs`、`loudspeaker_directions`、`dualband_flag`。 |
| 输出 | `SH_ambisonic_binaural_decoder`。 |

###### `ambiDecoder.m`

| 项目 | 内容 |
|---|---|
| 功能 | 生成 Ambisonic 解码矩阵。 |
| 输入 | `ls_dirs`、`method`、`decoderWeight`、`order`。 |
| 输出 | `D`、`order`。 |

###### `getRSH.m`

| 项目 | 内容 |
|---|---|
| 功能 | 计算实球谐函数矩阵。 |
| 输入 | 阶数、方向列表。 |
| 输出 | 球谐基矩阵。 |

###### `getMaxREchannelweights.m`

| 项目 | 内容 |
|---|---|
| 功能 | 获取 Max-rE 每阶/每通道权重。 |
| 输入 | Ambisonic 阶数。 |
| 输出 | `maxReWeights`。 |

###### `ambisonic_crossover.m`

| 项目 | 内容 |
|---|---|
| 功能 | 设计 Ambisonic dual-band 交叉滤波器。 |
| 输入 | `ambisonic_order_or_fc`、`Fs`。 |
| 输出 | `filtLo`、`filtHi`、`fcHz`。 |

##### `ambisonic_time_alignment.m`

| 项目 | 内容 |
|---|---|
| 功能 | 对虚拟扬声器 HRIR 做 Ambisonic 时间对齐。 |
| 输入 | `VL_hrirs`、`Fs`、`ambisonic_order`。 |
| 输出 | `VL_hrirs_TA`。 |

###### `ambisonic_crossover.m`

| 项目 | 内容 |
|---|---|
| 功能 | 设计低/高频分频滤波器。 |
| 输入 | 阶数或分频频率、采样率。 |
| 输出 | `filtLo`、`filtHi`、`fcHz`。 |

###### `remove_ITD_HRIRs` local function

| 项目 | 内容 |
|---|---|
| 功能 | 去除 HRIR 中左右耳 ITD 差异。 |
| 输入 | `VL_hrirs`。 |
| 输出 | `VL_hrirs_ITD_removed`。 |

##### `ambisonic_diffuse_field_equalisation.m`

| 项目 | 内容 |
|---|---|
| 功能 | 对双耳 Ambisonic 解码器/HRIR 做 diffuse-field 均衡。 |
| 输入 | `ambisonic_order`、`SH_ambisonic_binaural_decoder`、`VL_hrirs`、`Fs`、`dfe_plot_flag`。 |
| 输出 | `SH_ambisonic_binaural_decoder_DFE`、`VL_hrirs_DFE`、`df_avg_L`、`df_avg_R`。 |

###### `tdesign2azi_ele` local function

| 项目 | 内容 |
|---|---|
| 功能 | 生成 t-design 方向的方位角/仰角。 |
| 输入 | `noOfPoints`。 |
| 输出 | `azi`、`ele`。 |

###### `generate_binaural_Ambisonic_decoder.m`

| 项目 | 内容 |
|---|---|
| 功能 | 用均衡后的 HRIR 重新生成双耳 Ambisonic 解码器。 |
| 输入 | `ambisonic_order`、`VL_hrirs`、`loudspeaker_directions`、`dualband_flag`。 |
| 输出 | `SH_ambisonic_binaural_decoder`。 |

#### `SOFAload.m`

| 项目 | 内容 |
|---|---|
| 功能 | 读取 SOFA 文件并整理元数据/维度。 |
| 输入 | 文件名 `fn` 和可选参数。 |
| 输出 | `Obj`，SOFA 数据结构。 |

##### `SOFAarghelper.m`

| 项目 | 内容 |
|---|---|
| 功能 | 解析 SOFA 工具箱参数。 |
| 输入 | 参数定义和用户参数。 |
| 输出 | 解析后的参数/标志。 |

##### `SOFAcheckFilename.m`

| 项目 | 内容 |
|---|---|
| 功能 | 检查或规范化 SOFA 文件名。 |
| 输入 | 文件名。 |
| 输出 | 规范化文件名/检查结果。 |

##### `NETCDFload.m`

| 项目 | 内容 |
|---|---|
| 功能 | 从 NetCDF 文件读取 SOFA 底层数据。 |
| 输入 | SOFA/NetCDF 文件路径。 |
| 输出 | NetCDF 内容结构。 |

##### `SOFAgetConventions.m`

| 项目 | 内容 |
|---|---|
| 功能 | 读取 SOFA convention 定义。 |
| 输入 | convention 名称/版本等。 |
| 输出 | convention 定义结构。 |

###### `SOFAdefinitions.m`

| 项目 | 内容 |
|---|---|
| 功能 | 返回 SOFA 变量、属性、维度定义。 |
| 输入 | convention/查询参数。 |
| 输出 | 定义结构或字段。 |

##### `SOFAupdateDimensions.m`

| 项目 | 内容 |
|---|---|
| 功能 | 根据 SOFA 数据更新维度字段。 |
| 输入 | SOFA 对象。 |
| 输出 | 更新后的 SOFA 对象。 |

#### `SOFAplotGeometry.m`

| 项目 | 内容 |
|---|---|
| 功能 | 绘制 SOFA 文件中的源/接收者几何位置。 |
| 输入 | `Obj0` 和可选绘图参数。 |
| 输出 | 无显式返回；生成图形。 |

##### `SOFAarghelper.m`

| 项目 | 内容 |
|---|---|
| 功能 | 解析绘图参数。 |
| 输入 | 参数定义和 `varargin`。 |
| 输出 | 解析后的参数。 |

##### `SOFAexpand.m`

| 项目 | 内容 |
|---|---|
| 功能 | 展开压缩 SOFA 数据维度。 |
| 输入 | SOFA 对象。 |
| 输出 | 展开后的 SOFA 对象。 |

##### `SOFAconvertCoordinates.m`

| 项目 | 内容 |
|---|---|
| 功能 | 在 SOFA 支持的坐标格式之间转换。 |
| 输入 | 坐标值、源格式、目标格式。 |
| 输出 | 转换后的坐标。 |

##### `sph2SH.m`

| 项目 | 内容 |
|---|---|
| 功能 | 将球坐标转换为球谐相关表示。 |
| 输入 | 球坐标/阶数等参数。 |
| 输出 | 球谐表示。 |

#### `extrapolate_srir_180526.m`

| 项目 | 内容 |
|---|---|
| 功能 | 核心 SRIR 外推；用 image source model、波束提取、旋转、增益/延迟和源指向性修正生成目标位置 SRIR。 |
| 输入 | `srir_orig`、`fs`、`ord_ism`、`src_rec`、`dim_room`、`flag`。 |
| 输出 | `srir_new`。 |

##### `SOFAload.m`

| 项目 | 内容 |
|---|---|
| 功能 | 加载扬声器指向性 SOFA 文件。 |
| 输入 | `LS_directivity_Calibrated_GENELEC_8331A.sofa`。 |
| 输出 | `sofa_ls_directivity`。 |

##### `find_direct_sound` local function

| 项目 | 内容 |
|---|---|
| 功能 | 检测直接声第一个显著峰。 |
| 输入 | `ir`。 |
| 输出 | `locD`、`ValD`、`pks`、`lcs`。 |

##### `ism_calculate` local function

| 项目 | 内容 |
|---|---|
| 功能 | 计算 image source 距离、到达时间和到达方向。 |
| 输入 | `coord_rec`、`coord_src`、`ord_ism`、`dim_room`、`fs`、`flag_plot`。 |
| 输出 | `dist_ism`、`toa_ism`、`doa_ism`、`dist_DS_ism`、`toa_DS_ism`、`doa_DS_ism`、`flag_o1_ism`。 |

###### `flagMatchingRows` local function

| 项目 | 内容 |
|---|---|
| 功能 | 标记主矩阵中哪些列也出现在另一个矩阵里。 |
| 输入 | `mainMatrix`、`otherMatrix`。 |
| 输出 | `flags`。 |

##### `doa_pwd` local function

| 项目 | 内容 |
|---|---|
| 功能 | 用 PWD 波束图估计 SRIR 的 DoA。 |
| 输入 | `srir`、`fs`。 |
| 输出 | `doa_est`、`normalised_doa_est_P_dB`、`P_pwd`、`doa_est_P`。 |

###### `grid2dirs.m`

| 项目 | 内容 |
|---|---|
| 功能 | 生成规则球面方向网格。 |
| 输入 | `aziRes`、`polarRes`、`POLAR_OR_ELEV`、`ZEROED_OR_CENTERED`。 |
| 输出 | `dirs`。 |

###### `sphPWDmap.m`

| 项目 | 内容 |
|---|---|
| 功能 | 在方向网格上计算 PWD 功率图并找峰。 |
| 输入 | `sphCOV`、`grid_dirs`、`nSrc`、`kappa`。 |
| 输出 | `P_pwd`、`est_dirs`、`est_dirs_P`。 |

##### `srir_arrival_remove` local function

| 项目 | 内容 |
|---|---|
| 功能 | 从 SRIR 中窗口提取/移除某个到达声，可选波束提取。 |
| 输入 | `srir_in`、`srir_unalt`、`fs`、`time_arrival_samp`、`arrival_dur_ms`、`flag_beamform_extract`、`extract_az_deg`、`extract_el_deg`、`flag_DS`。 |
| 输出 | `srir_arrival`、`srir_arrival_removed`。 |

###### `beamform_extract_remove` local function

| 项目 | 内容 |
|---|---|
| 功能 | 向指定方向波束形成，输出波束成分和残差。 |
| 输入 | `in`、`azDeg`、`elDeg`。 |
| 输出 | `out_beam`、`out_resid`。 |

###### `getRealSH_N3D` local function

| 项目 | 内容 |
|---|---|
| 功能 | 计算 N3D 归一化实球谐 steering vector。 |
| 输入 | `N`、`az`、`el`。 |
| 输出 | `Y`。 |

###### `expandWeights_ACN` local function

| 项目 | 内容 |
|---|---|
| 功能 | 将每阶权重展开为 ACN 通道权重。 |
| 输入 | `w_order`。 |
| 输出 | `wvec`。 |

##### `rotateHOA_N3D.m`

| 项目 | 内容 |
|---|---|
| 功能 | 按 yaw/pitch/roll 旋转 N3D HOA 信号。 |
| 输入 | `hoasig`、`yaw`、`pitch`、`roll`。 |
| 输出 | `hoasig_rot`。 |

##### `azel2vec` local function

| 项目 | 内容 |
|---|---|
| 功能 | 将方位角/仰角转换为三维单位向量。 |
| 输入 | `az`、`el`。 |
| 输出 | `v`。 |

##### `ir2lowpass` local function

| 项目 | 内容 |
|---|---|
| 功能 | 用测得 IR 拟合高架/低通感知的 `shelvingFilter`。 |
| 输入 | `ir`、`fs`、`boostFlag`、`plotFlag`。 |
| 输出 | `shelf`。 |

###### `errorFunction` nested function

| 项目 | 内容 |
|---|---|
| 功能 | 优化 shelving filter 参数时的频响误差函数。 |
| 输入 | `params`、`mag_measured`、`f`、`fs`、`minfftBin`、`maxfftBin`。 |
| 输出 | `err`。 |

#### `render_binaural` local function in main file

| 项目 | 内容 |
|---|---|
| 功能 | 用 SH 双耳解码器把 Ambisonic SRIR 渲染成双耳 BRIR。 |
| 输入 | `input`、`binaural_decoder`。 |
| 输出 | `out_SH`。 |

#### `mckenzie2025.m`

| 项目 | 内容 |
|---|---|
| 功能 | 预测参考/测试双耳信号之间的 binaural colouration。 |
| 输入 | `reference`、`test`、`settings`。 |
| 输出 | `pbc2`、`pbc2_raw`、`C`、`f`。 |

#### `freqplot_smooth.m`

| 项目 | 内容 |
|---|---|
| 功能 | 绘制音频信号单边频谱，并可做 octave smoothing。 |
| 输入 | `x`、`Fs`、`NoctSmoothing`、`graphFormatting`、`lineWidth`。 |
| 输出 | 无显式返回；生成频谱曲线。 |

#### `plot_doa_horiz` local function in main file

| 项目 | 内容 |
|---|---|
| 功能 | 对多个 SRIR 估计水平 DoA 并画散点图。 |
| 输入 | `srir`、`fs`。 |
| 输出 | `doa_est`、`normalized_doa_est_P_dB`、`P_pwd`。 |

##### `grid2dirs.m`

| 项目 | 内容 |
|---|---|
| 功能 | 生成水平/球面搜索方向网格。 |
| 输入 | 方位/仰角分辨率和模式参数。 |
| 输出 | `grid_dirs`。 |

##### `ambisonic_crossover.m`

| 项目 | 内容 |
|---|---|
| 功能 | 构造高通/低通滤波器。 |
| 输入 | `highPassFilterFreq`、`fs`。 |
| 输出 | `filtHi` 等滤波器。 |

##### `sphPWDmap.m`

| 项目 | 内容 |
|---|---|
| 功能 | 计算方向功率图和峰值 DoA。 |
| 输入 | `sphCOV`、`grid_dirs`、`nSrc`、`kappa`。 |
| 输出 | `P_pwd`、`est_dirs_pwd`、`est_dirs_P`。 |

#### `get_pwd` local function in main file

| 项目 | 内容 |
|---|---|
| 功能 | 对单个 SRIR 计算 3D PWD 功率图和 DoA 估计。 |
| 输入 | `srir`、`fs`。 |
| 输出 | `P_pwd`、`doa_est`、`doa_est_P`、`grid_dirs`。 |

##### `grid2dirs.m`

| 项目 | 内容 |
|---|---|
| 功能 | 生成 3D 球面方向网格。 |
| 输入 | `degreeResolution` 等参数。 |
| 输出 | `grid_dirs`。 |

##### `ambisonic_crossover.m`

| 项目 | 内容 |
|---|---|
| 功能 | 生成高通滤波器。 |
| 输入 | `highPassFilterFreq`、`fs`。 |
| 输出 | `filtHi` 等滤波器。 |

##### `sphPWDmap.m`

| 项目 | 内容 |
|---|---|
| 功能 | 计算 PWD 功率图和方向峰值。 |
| 输入 | `sphCOV`、`grid_dirs`、`nSrc`、`kappa`。 |
| 输出 | `P_pwd`、`est_dirs_pwd`、`est_dirs_P`。 |

#### `heatmap_plot_hammer.m`

| 项目 | 内容 |
|---|---|
| 功能 | 将球面方向数据插值后用 Aitoff/Hammer 类投影画热力图。 |
| 输入 | `az`、`el`、`z`。 |
| 输出 | 无显式返回；生成投影热力图。 |

#### `plot_doa_horiz_time` local function in main file

| 项目 | 内容 |
|---|---|
| 功能 | 用滑动窗计算水平 DoA 随时间变化，并画空间-时间图。 |
| 输入 | `srir`、`fs`。 |
| 输出 | `P_pwd`。 |

##### `grid2dirs.m`

| 项目 | 内容 |
|---|---|
| 功能 | 生成水平方向网格。 |
| 输入 | `res_deg_azi`、`res_deg_ele`、模式参数。 |
| 输出 | `grid_dirs`。 |

##### `ambisonic_crossover.m`

| 项目 | 内容 |
|---|---|
| 功能 | 生成高通滤波器。 |
| 输入 | `highPassFilterFreq`、`fs`。 |
| 输出 | `filtHi` 等滤波器。 |

##### `sphPWDmap.m`

| 项目 | 内容 |
|---|---|
| 功能 | 对每个时间窗计算 PWD 方向功率图。 |
| 输入 | `sphCOV`、`grid_dirs`、`nSrc`、`kappa`。 |
| 输出 | `P_pwd`。 |

