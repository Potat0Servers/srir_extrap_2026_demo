# Baseline Reuse Guide for New SRIR Extrapolation Algorithms

本文档面向已经理解 `test_extrapolate_srir_180526_Baseline.m` 和相关论文方法、并希望基于现有代码模块实现新算法的开发者。它不是运行教程，而是一份工程复用指南：哪些模块值得复用，输入输出契约是什么，哪些位置适合替换，哪些地方容易踩坑。

目标脚本:

```text
test_extrapolate_srir_180526_Baseline.m
```

核心算法函数:

```text
extrapolate_srir_180526.m
```

## 1. 复用目标

如果要基于 baseline 实现一个新 SRIR extrapolation 算法，建议把现有代码理解为一组可复用能力，而不是一个必须沿用的完整 pipeline。

最值得复用的是:

- SOFA 数据读取和场景选择逻辑
- Ambisonic binaural decoder 配置逻辑
- image source 几何计算
- 直接声和早期反射的 ToA/DoA 相关工具
- SRIR arrival windowing / removal / beamforming 工具
- HOA 旋转工具
- 双耳渲染和评估可视化工具

最适合替换的是:

- arrival selection 策略
- arrival extraction 策略
- arrival transform 模型
- residual / reconstruction 策略
- source directivity 修正模型
- 评估指标组合方式

## 2. 模块地图

### A. 数据与配置层

| 模块 | 位置 | 作用 |
|---|---|---|
| `addpaths.m` | 根目录 | 添加项目依赖路径 |
| `load_ambisonic_configuration.m` | `binaural-ambisonic-preprocessing-main/test_scripts/` | 生成双耳 Ambisonic decoder |
| `SOFAload.m` | `SOFAtoolbox/SOFAtoolbox/` | 加载 SOFA 数据 |
| 主脚本的 source/receiver 选择段 | `test_extrapolate_srir_180526_Baseline.m` | 从 SOFA 数据中取出原始和目标 SRIR |

### B. 几何与 ISM 层

| 模块 | 位置 | 作用 |
|---|---|---|
| `ism_calculate` | `extrapolate_srir_180526.m` local function | 计算 image source 的距离、ToA、DoA |
| `flagMatchingRows` | `extrapolate_srir_180526.m` local function | 标记 first-order image sources |
| `azel2vec` | `extrapolate_srir_180526.m` local function | 方位角/仰角转三维单位向量 |

### C. Arrival 检测与提取层

| 模块 | 位置 | 作用 |
|---|---|---|
| `find_direct_sound` | `extrapolate_srir_180526.m` local function | 检测直接声峰值 |
| `srir_arrival_remove` | `extrapolate_srir_180526.m` local function | 窗口提取并移除某个 arrival |
| `beamform_extract_remove` | `extrapolate_srir_180526.m` local function | 指定方向 beamforming，分离 beam 和 residual |
| `doa_pwd` | `extrapolate_srir_180526.m` local function | 用 PWD 估计 DoA |
| `grid2dirs.m` | `Spherical-Harmonic-Transform/` | 生成球面方向网格 |
| `sphPWDmap.m` | `Spherical-Array-Processing-master/` | 计算 PWD power map 和方向峰值 |

### D. HOA / 空间变换层

| 模块 | 位置 | 作用 |
|---|---|---|
| `rotateHOA_N3D.m` | `Higher-Order-Ambisonics-master/` | 旋转 HOA/N3D 信号 |
| `getRealSH_N3D` | `extrapolate_srir_180526.m` local function | 生成 N3D real SH steering vector |
| `expandWeights_ACN` | `extrapolate_srir_180526.m` local function | 每阶权重展开到 ACN 通道 |

### E. Source Directivity 层

| 模块 | 位置 | 作用 |
|---|---|---|
| directivity SOFA loading | `extrapolate_srir_180526.m` | 加载 Genelec 8331A directivity SOFA |
| `ir2lowpass` | `extrapolate_srir_180526.m` local function | 用 measured IR 拟合 shelving filter |
| `errorFunction` | `ir2lowpass` nested function | shelving filter 参数优化目标函数 |

### F. SRIR 合成层

| 模块 | 位置 | 作用 |
|---|---|---|
| ER loop | `extrapolate_srir_180526.m` | 逐个 early reflection 提取、旋转、修正、加回 |
| DS block | `extrapolate_srir_180526.m` | 单独处理 direct sound |
| residual handling | `extrapolate_srir_180526.m` | 保留或清零残差中的部分区间 |

### G. 评估与可视化层

| 模块 | 位置 | 作用 |
|---|---|---|
| `render_binaural` | `test_extrapolate_srir_180526_Baseline.m` local function | SH SRIR 渲染为双耳 BRIR |
| `mckenzie2025.m` | `amtoolbox-code-mckenzie2025/models/` | binaural colouration 指标 |
| `freqplot_smooth.m` | 根目录 | 平滑频响图 |
| `plot_doa_horiz` | 主脚本 local function | 水平 DoA 散点图 |
| `get_pwd` | 主脚本 local function | 3D PWD power map |
| `heatmap_plot_hammer.m` | 根目录 | 球面方向热力图 |
| `plot_doa_horiz_time` | 主脚本 local function | 水平 DoA time plot |

## 3. 推荐复用清单

| 模块 | 建议 | 原因 |
|---|---|---|
| `SOFAload` + 主脚本数据选择逻辑 | 强烈建议复用 | 数据索引和 SOFA 字段访问已经验证过 |
| `load_ambisonic_configuration` | 可复用但要小心 | 是 script，会清变量、关图窗、依赖相对路径 |
| `ism_calculate` | 强烈建议复用 | 几何、ToA、DoA 计算相对独立 |
| `find_direct_sound` | 建议复用或改造 | 简单有效，但阈值和 peak distance 固定 |
| `doa_pwd` | 建议复用 | 封装了 PWD DoA 估计 |
| `srir_arrival_remove` | 可复用但要小心 | arrival windowing 很有用，但索引边界和 beamforming 耦合强 |
| `beamform_extract_remove` | 可复用但要验证 | 简洁可用，但 steering vector 和权重假设较强 |
| `rotateHOA_N3D` | 强烈建议复用 | 已有成熟 HOA 旋转实现 |
| `ir2lowpass` | 可选复用 | 只在 source directivity 修正中必要 |
| `render_binaural` | 评估阶段建议复用 | 适合把 SH SRIR 转成 BRIR 做 perceptual evaluation |
| 主脚本绘图段 | 建议参考或封装后复用 | 直接复制会带来大量 workspace 变量耦合 |

## 4. 数据结构和单位约定

### SRIR / BRIR

| 变量 | 形状 | 单位/含义 |
|---|---|---|
| `srir_orig` | `[numSamples x numSHChannels]` | 原始位置 SH SRIR |
| `srir_tar` | `[numSamples x numSHChannels]` | 目标位置 measured SH SRIR，用于 evaluation |
| `srir_new` | `[numSamples x numSHChannels]` | 外推生成的目标位置 SH SRIR |
| `brir_orig` | `[numSamples x 2]` | 原始位置双耳 BRIR |
| `brir_new` | `[numSamples x 2]` | 外推结果双耳 BRIR |
| `brir_tar` | `[numSamples x 2]` | 目标位置双耳 BRIR |

SH 通道数通常满足:

```matlab
numSHChannels = (order + 1)^2
order = sqrt(numSHChannels) - 1
```

### `src_rec`

| 字段 | 形状 | 含义 |
|---|---|---|
| `pos_src_orig` | `1x3` | 原始 source 坐标 `[x y z]`, meter |
| `pos_rec_orig` | `1x3` | 原始 receiver 坐标 `[x y z]`, meter |
| `pos_src_tar` | `1x3` | 目标 source 坐标 `[x y z]`, meter |
| `pos_rec_tar` | `1x3` | 目标 receiver 坐标 `[x y z]`, meter |
| `view_src_orig` | `1x3` | 原始 source view vector |

### 几何和 DoA

| 变量 | 形状 | 单位 |
|---|---|---|
| `dist_ism` | `1xN` | meter |
| `toa_ism` | `1xN` | sample index |
| `doa_ism` | `2xN` | degree, `[azimuth; elevation]` |
| `grid_dirs` | `Kx2` | radian, usually `[azimuth elevation]` |
| `doa_est` | `nSrc x 2` or `nSrc x 2 x N` | degree |

注意: baseline 内部同时使用 degree 和 radian。

- `ism_calculate` 输出 DoA 是 degree。
- `rotateHOA_N3D` 输入 yaw/pitch/roll 是 degree。
- `grid2dirs` 输出方向是 radian。
- `sphPWDmap` 输入 `grid_dirs` 是 radian，输出 `est_dirs` 也是 radian，调用处通常再转 degree。

## 5. 核心模块契约

### `ism_calculate`

```matlab
[dist_ism, toa_ism, doa_ism, dist_DS_ism, toa_DS_ism, doa_DS_ism, flag_o1_ism] = ...
    ism_calculate(coord_rec, coord_src, ord_ism, dim_room, fs, flag_plot)
```

| 项 | 内容 |
|---|---|
| 功能 | 根据房间、源/接收点、ISM 阶数计算 image source arrival 几何信息。 |
| 输入 | `coord_rec`, `coord_src`: receiver/source 坐标；`ord_ism`: ISM 阶数；`dim_room`: 房间尺寸；`fs`: 采样率；`flag_plot`: 是否画图。 |
| 输出 | image source 的距离、ToA、DoA；direct sound 的距离、ToA、DoA；first-order image source 标记。 |
| 单位 | 距离 meter；ToA samples；DoA degree。 |
| 隐含假设 | 声速固定为 `343 m/s`；房间为长方体；坐标为 `[x y z]`。 |
| 复用建议 | 建议拆成独立 `ism_calculate.m`，作为新算法的几何层。 |

重要细节:

- direct sound 是单独输出的，不在 `dist_ism/toa_ism/doa_ism` 中按同等方式处理。
- 当 `ord_ism > 1` 时，主函数后续会移除最短路径，以避免和 direct sound 重复；这一步不在 `ism_calculate` 内，而在 `extrapolate_srir_180526` 主体里。
- 如果你的新算法需要保留所有 image sources，注意不要照搬 baseline 的 `idx = idx(2:end)`。

### `find_direct_sound`

```matlab
[locD, ValD, pks, lcs] = find_direct_sound(ir)
```

| 项 | 内容 |
|---|---|
| 功能 | 在单通道 IR 中寻找第一个显著 peak，作为 measured direct sound。 |
| 输入 | `ir`: 一维 IR，通常先经过 bandpass 或 high/low pass。 |
| 输出 | `locD`: peak sample index；`ValD`: peak value；`pks/lcs`: 全部 peaks 和 locations。 |
| 隐含参数 | `MinPeakDistance = 50`，`MinPeakHeight = 0.05`。 |
| 风险 | 如果直接声较弱或前面有噪声峰，可能误检。 |
| 复用建议 | 可以复用，但建议把阈值参数化。 |

### `doa_pwd`

```matlab
[doa_est, normalised_doa_est_P_dB, P_pwd, doa_est_P] = doa_pwd(srir, fs)
```

| 项 | 内容 |
|---|---|
| 功能 | 对一个 SRIR 片段做 PWD DoA 估计。 |
| 输入 | `srir`: `[samples x SH channels]`；`fs`: 采样率。 |
| 输出 | DoA 估计、估计方向功率、PWD power map。 |
| 内部依赖 | `grid2dirs`、`sphPWDmap`、highpass/lowpass。 |
| 隐含参数 | `res_deg_azi = 1`，`res_deg_ele = 1`，`nSrc = 1`，`highPassFilterFreq = 700`，`kappa = 20`。 |
| 复用建议 | 适合作为 direct sound 或 isolated arrival 的 DoA estimator。 |

### `srir_arrival_remove`

```matlab
[srir_arrival, srir_arrival_removed] = srir_arrival_remove( ...
    srir_in, srir_unalt, fs, time_arrival_samp, arrival_dur_ms, ...
    flag_beamform_extract, extract_az_deg, extract_el_deg, flag_DS)
```

| 项 | 内容 |
|---|---|
| 功能 | 从输入 SRIR 中窗口提取一个 arrival，并从 residual 中移除它。可选 beamforming。 |
| 输入 | 当前 residual `srir_in`、未改动原始 `srir_unalt`、arrival 起点、窗口长度、beamforming 参数。 |
| 输出 | `srir_arrival`: 被提取的 arrival；`srir_arrival_removed`: 移除该 arrival 后的 residual。 |
| 单位 | `time_arrival_samp` 是 sample index；`arrival_dur_ms` 是 ms。 |
| 隐含参数 | fade in/out samples 为 `[5 10]`。 |
| 风险 | 没有显式边界保护；arrival 太靠近开头或结尾时可能索引越界。 |
| 复用建议 | 新算法如果仍需 arrival-level 操作，这是关键模块；建议先加边界保护再复用。 |

direct sound 和 early reflection 的差异:

- `flag_DS == 1`: 不使用 beamformed arrival 本身，只使用 beam-removed residual。
- `flag_DS == 0`: 使用 beamformed arrival，同时把 residual 加回 overall residual。

### `beamform_extract_remove`

```matlab
[out_beam, out_resid] = beamform_extract_remove(in, azDeg, elDeg)
```

| 项 | 内容 |
|---|---|
| 功能 | 对 SH/HOA 信号向指定方向做 beamforming，并返回 beam 成分和 residual。 |
| 输入 | `in`: `[samples x SH channels]`；`azDeg/elDeg`: 目标方向 degree。 |
| 输出 | `out_beam`: 指向性提取成分；`out_resid`: `in - out_beam`。 |
| 内部依赖 | `getRealSH_N3D`、`expandWeights_ACN`。 |
| 隐含假设 | 输入是 ACN/N3D 风格的 SH 信号；权重默认为每阶全 1。 |
| 复用建议 | 可作为 baseline beam extractor；新算法如果对 spatial selectivity 敏感，应验证 beam pattern。 |

### `rotateHOA_N3D`

```matlab
hoasig_rot = rotateHOA_N3D(hoasig, yaw, pitch, roll)
```

| 项 | 内容 |
|---|---|
| 功能 | 旋转 N3D HOA 信号。 |
| 输入 | `hoasig`: HOA signal；`yaw/pitch/roll`: degree。 |
| 输出 | `hoasig_rot`。 |
| 复用建议 | 空间旋转建议直接复用，不建议重写。 |

### `ir2lowpass`

```matlab
shelf = ir2lowpass(ir, fs, boostFlag, plotFlag)
```

| 项 | 内容 |
|---|---|
| 功能 | 从 directivity IR 拟合一个 shelving filter。 |
| 输入 | `ir`: measured IR；`fs`: 采样率；`boostFlag`: boost/cut 方向；`plotFlag`: 是否画拟合图。 |
| 输出 | `shelf`: MATLAB `shelvingFilter` 对象。 |
| 内部依赖 | `fmincon`、`freqz`、`shelvingFilter`。 |
| 复用建议 | 只在新算法仍考虑 source directivity 时复用；否则可完全跳过。 |

### `render_binaural`

```matlab
out_SH = render_binaural(input, binaural_decoder)
```

| 项 | 内容 |
|---|---|
| 功能 | 将 SH SRIR 与双耳 Ambisonic decoder 卷积，得到 stereo BRIR。 |
| 输入 | `input`: `[samples x SH channels]`；`binaural_decoder`: `[SH channels x decoderLength x 2]`。 |
| 输出 | `out_SH`: `[samples + decoderLength - 1 x 2]`。 |
| 复用建议 | 适合评估和试听阶段复用。 |

## 6. Baseline Pipeline 的可替换接入点

Baseline 的核心 pipeline 可抽象为:

```text
srir_orig + fs + src_rec + dim_room + flags
        |
        v
1. 计算 original / target ISM arrival geometry
        |
        v
2. 用 measured direct sound 对齐 ISM timing 和 DoA
        |
        v
3. 对每个 early reflection 提取 arrival
        |
        v
4. 根据 original -> target geometry 做旋转、延迟、增益变换
        |
        v
5. 可选 source directivity 修正
        |
        v
6. overlap/add 到 residual 中
        |
        v
7. 单独处理 direct sound
        |
        v
srir_new
```

推荐接入点:

| 接入点 | 可以替换什么 | 建议保留什么 |
|---|---|---|
| Arrival geometry | 替换 ISM、混合 measured/estimated geometry、加入学习式 arrival proposal | `src_rec` 数据结构、`dim_room`、`fs` 单位约定 |
| Arrival selection | 替换排序、筛选、权重策略 | `ism_calculate` 输出格式 |
| Direct sound alignment | 替换 DS ToA/DoA 对齐策略 | `find_direct_sound` 和 `doa_pwd` 可作为 baseline estimator |
| Arrival extraction | 替换 window size、fade、beamforming 方法 | `srir_arrival_remove` 可作为初版 |
| Spatial transform | 替换 rotation/gain/delay 模型 | `rotateHOA_N3D` |
| Source directivity | 替换 Genelec-specific correction | directivity SOFA loading 可选保留 |
| Reconstruction | 替换 residual 清零、overlap/add、masking 策略 | `srir_arrival_removed` 的 residual 思路 |
| Evaluation | 保持和 baseline 一致，便于比较 | `render_binaural`、`mckenzie2025`、DoA plots |

## 7. Local Functions 拆分建议

当前很多有价值的 helper 都是 local function，不能直接从新 `.m` 文件调用。建议为了新算法开发，把它们逐步拆成独立文件。

### 优先拆分

| 优先级 | 函数 | 建议文件名 | 理由 |
|---|---|---|---|
| 1 | `ism_calculate` | `CODEX_ism_calculate.m` 或 `ism_calculate.m` | 新算法几何层最可能复用 |
| 2 | `find_direct_sound` | `CODEX_find_direct_sound.m` | DS alignment 常用 |
| 3 | `doa_pwd` | `CODEX_doa_pwd.m` | arrival DoA estimation 常用 |
| 4 | `srir_arrival_remove` | `CODEX_srir_arrival_remove.m` | arrival-level processing 核心 |
| 5 | `beamform_extract_remove` | `CODEX_beamform_extract_remove.m` | beamforming extraction 核心 |
| 6 | `getRealSH_N3D` | `CODEX_getRealSH_N3D.m` | `beamform_extract_remove` 依赖 |
| 7 | `expandWeights_ACN` | `CODEX_expandWeights_ACN.m` | `beamform_extract_remove` 依赖 |
| 8 | `azel2vec` | `CODEX_azel2vec.m` | directivity/geometry 小工具 |
| 9 | `ir2lowpass` | `CODEX_ir2lowpass.m` | source directivity 可选模块 |
| 10 | `render_binaural` | `CODEX_render_binaural.m` | evaluation 阶段通用 |

### 拆分时建议同时做的改造

- 给 `srir_arrival_remove` 增加边界保护。
- 把 `find_direct_sound` 的 peak 参数改成输入参数或 config。
- 把 `doa_pwd` 的 grid resolution、filter frequency、`nSrc`、`kappa` 参数化。
- 把 `beamform_extract_remove` 的 per-order weights 参数化。
- 统一所有 DoA 输入输出单位，至少在函数名或注释中明确 degree/radian。

## 8. 推荐的新算法工程骨架

建议不要直接在 `test_extrapolate_srir_180526_Baseline.m` 上改。更稳的方式是新建一个 main script 或 function，保留 baseline 文件作为 reference。

推荐结构:

```text
CODEX_new_algorithm_main.m
├─ setup paths / config
├─ load SOFA dataset
├─ select original and target scene
├─ build src_rec
├─ apply optional room geometry correction
├─ compute reusable geometry
├─ extract reusable arrivals
├─ run your new transform / reconstruction model
├─ render binaural outputs
└─ evaluate and plot
```

伪代码:

```matlab
addpaths

cfg = struct();
cfg.ord_ism = 2;
cfg.idx_LS_src_orig = 1;
cfg.idx_LS_rec_orig = 1;
cfg.idx_LS_src_tar = 1;
cfg.idx_LS_rec_tar = 5;

load_ambisonic_configuration;

sofa1 = SOFAload('6DoF_SRIRs_eigenmike_SH_50percent_absorbers_enabled.sofa');
fs = sofa1.Data.SamplingRate;

[srir_orig, srir_tar, src_rec] = CODEX_select_srir_pair(sofa1, cfg);
src_rec = CODEX_apply_room_geometry_correction(src_rec, cfg);

geom_orig = CODEX_ism_calculate(src_rec.pos_rec_orig, src_rec.pos_src_orig, cfg.ord_ism, cfg.dim_room, fs, false);
geom_tar  = CODEX_ism_calculate(src_rec.pos_rec_tar,  src_rec.pos_src_tar,  cfg.ord_ism, cfg.dim_room, fs, false);

arrivals = CODEX_extract_arrivals(srir_orig, geom_orig, cfg);

srir_new = CODEX_my_new_reconstruction(arrivals, geom_orig, geom_tar, src_rec, cfg);

brir_new = CODEX_render_binaural(srir_new, SH_ambisonic_binaural_decoder);
metrics = CODEX_evaluate_srir(srir_new, srir_tar, brir_new, cfg);
```

这里的 `CODEX_my_new_reconstruction` 才是你的新算法核心。其他模块尽量保持薄封装，便于和 baseline 对比。

## 9. 常见坑位

### `load_ambisonic_configuration` 是 script

它不是 function，并且开头有:

```matlab
clear variables; close all; clc;
```

这对模块化开发不友好。直接调用会清掉已有变量。建议:

- 开发早期可以继续用它。
- 稳定后改造成 `CODEX_load_ambisonic_configuration(cfg)` function。
- 或者在 main script 的最前面调用，避免清掉后续变量。

### Local functions 不能跨文件直接调用

`extrapolate_srir_180526.m` 里的 local functions 只能被同文件内部调用。新算法如果要复用它们，需要:

- 拆成独立 `.m` 文件；
- 或者临时复制到新算法文件末尾；
- 或者继续通过 `extrapolate_srir_180526` 整体调用，但这会限制你替换内部逻辑。

### `srir_arrival_remove` 没有边界保护

这类索引可能越界:

```matlab
time_arrival_samp + 1 : time_arrival_samp + arrival_dur_ms/1000*fs
```

如果新算法改变 ToA、窗口长度或处理更早/更晚的 arrival，建议先加:

- start sample clamp
- end sample clamp
- window length adjustment
- warning 或 skip policy

### Degree 和 radian 混用

尤其注意:

- `doa_ism`: degree
- `doa_rot`: degree
- `rotateHOA_N3D`: degree
- `grid_dirs`: radian
- `sphPWDmap`: radian
- `rad2deg`/`deg2rad` 转换散落在调用处

建议新算法内部统一约定，比如所有 public helper 输出 degree，只有调用 `sphPWDmap` 前转换为 radian。

### `ord_ism > 1` 时 direct sound duplicate handling

baseline 中:

```matlab
if ord_ism > 1
    idx = idx(2:end);
end
```

这是为了移除疑似重复 direct sound 的最短 image source。新算法如果要学习或显式建模所有路径，必须重新考虑这一步。

### Source directivity 部分强绑定数据集

direct sound directivity 用了:

```matlab
LS_directivity_Calibrated_GENELEC_8331A.sofa
```

并且有固定索引逻辑:

```matlab
3241 + round(abs(rec_view_orig(1)))
```

这对 Genelec 8331A directivity 数据集是特化的。换数据集或换 loudspeaker 时，不应直接复用这段。

### `room_geometry_correction` 在主脚本里

房间几何修正发生在主脚本，而不是 `extrapolate_srir_180526` 内。新算法如果绕过主脚本直接调用核心函数，需要自己决定是否应用同样修正。

### Evaluation 代码和算法代码混在一个脚本

主脚本后半部分大量绘图和评估依赖 workspace 变量。建议新算法中拆成:

- `CODEX_evaluate_time_domain`
- `CODEX_evaluate_binaural_colouration`
- `CODEX_plot_frequency_response`
- `CODEX_plot_doa`

这样算法核心更干净。

## 10. 建议开发顺序

### Step 1: 保持 baseline 可运行

先确认原始 `test_extrapolate_srir_180526_Baseline.m` 可以跑通，并记录 baseline 指标:

- RMS
- PBC orig -> tar
- PBC new -> tar
- DoA metrics
- 主要图形结果

### Step 2: 新建独立 main script

不要直接改 baseline。新建:

```text
CODEX_new_algorithm_main.m
```

先复现 baseline 的数据加载、场景选择和 evaluation。

### Step 3: 拆出 helper functions

优先拆:

```text
CODEX_ism_calculate.m
CODEX_find_direct_sound.m
CODEX_doa_pwd.m
CODEX_srir_arrival_remove.m
CODEX_beamform_extract_remove.m
```

拆完后先跑一次 baseline-equivalent 流程，确认输出没有明显变化。

### Step 4: 替换新算法核心

只替换一个接入点开始，比如:

- 只改 arrival selection
- 或只改 transform model
- 或只改 reconstruction

每次只改一个模块，保留 baseline evaluation。

### Step 5: 建立对照实验

建议输出结构固定为:

```text
original
baseline extrapolated
new algorithm extrapolated
target
```

这样时域、频域、PBC、DoA 都能横向比较。

## 11. 函数索引表

| 函数/脚本 | 所在位置 | 是否 local | 建议用途 | 风险等级 |
|---|---|---:|---|---|
| `addpaths` | 根目录 | 否 | 环境初始化 | 低 |
| `load_ambisonic_configuration` | `binaural-ambisonic-preprocessing-main/test_scripts/` | 否，script | decoder 初始化 | 中 |
| `SOFAload` | `SOFAtoolbox/SOFAtoolbox/` | 否 | SOFA 数据加载 | 低 |
| `extrapolate_srir_180526` | 根目录 | 否 | baseline reference / 可整体调用 | 中 |
| `ism_calculate` | `extrapolate_srir_180526.m` | 是 | geometry helper | 中 |
| `find_direct_sound` | `extrapolate_srir_180526.m` | 是 | DS detection | 中 |
| `doa_pwd` | `extrapolate_srir_180526.m` | 是 | DoA estimation | 中 |
| `srir_arrival_remove` | `extrapolate_srir_180526.m` | 是 | arrival extraction/removal | 高 |
| `beamform_extract_remove` | `extrapolate_srir_180526.m` | 是 | beamforming extraction | 中 |
| `rotateHOA_N3D` | `Higher-Order-Ambisonics-master/` | 否 | HOA rotation | 低 |
| `ir2lowpass` | `extrapolate_srir_180526.m` | 是 | source directivity filter fitting | 中 |
| `render_binaural` | `test_extrapolate_srir_180526_Baseline.m` | 是 | binaural rendering | 低 |
| `mckenzie2025` | `amtoolbox-code-mckenzie2025/models/` | 否 | perceptual colouration metric | 低 |
| `freqplot_smooth` | 根目录 | 否 | frequency plot | 低 |
| `plot_doa_horiz` | `test_extrapolate_srir_180526_Baseline.m` | 是 | horizontal DoA plot | 中 |
| `get_pwd` | `test_extrapolate_srir_180526_Baseline.m` | 是 | 3D PWD map | 中 |
| `plot_doa_horiz_time` | `test_extrapolate_srir_180526_Baseline.m` | 是 | spatial-time DoA plot | 中 |

## 12. 变量索引表

| 变量 | 来源 | 形状/类型 | 用途 |
|---|---|---|---|
| `sofa1` | `SOFAload` | struct | 6DoF SRIR 数据 |
| `fs` | `sofa1.Data.SamplingRate` | scalar | 采样率 |
| `dim_room` | 主脚本设置 | `1x3` | 房间尺寸 |
| `ord_imgsrc` | 主脚本设置 | scalar | image source 阶数 |
| `flag` | 主脚本设置 | struct | directivity/beamforming 开关 |
| `src_rec` | 主脚本构造 | struct | source/receiver 坐标和 view |
| `srir_orig` | SOFA IR | matrix | 原始 SRIR |
| `srir_tar` | SOFA IR | matrix | 目标 SRIR |
| `srir_new` | `extrapolate_srir_180526` | matrix | 生成 SRIR |
| `dist_ism_*` | `ism_calculate` | vector | arrival 距离 |
| `toa_ism_*` | `ism_calculate` | vector | arrival 到达样本 |
| `doa_ism_*` | `ism_calculate` | `2xN` | arrival DoA |
| `SH_ambisonic_binaural_decoder` | `load_ambisonic_configuration` | 3D array | 双耳渲染 decoder |
| `brir_*` | `render_binaural` | `[samples x 2]` | 双耳 BRIR |
| `pbc2_*` | `mckenzie2025` | scalar/vector | binaural colouration 指标 |

## 13. 推荐的文档和代码边界

建议后续把新算法相关内容分成三层:

```text
文档层:
CODEX_new_algorithm_design.md
CODEX_test_extrapolate_srir_180526_Baseline_reuse_guide.md

实验入口层:
CODEX_new_algorithm_main.m
CODEX_run_baseline_comparison.m

可复用函数层:
CODEX_ism_calculate.m
CODEX_srir_arrival_remove.m
CODEX_beamform_extract_remove.m
CODEX_render_binaural.m
...
```

这样 baseline 仍然保持原貌，新算法也不会被主脚本的绘图、workspace 变量和 local functions 绑住。

