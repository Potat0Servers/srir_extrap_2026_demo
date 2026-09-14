# Coupled-Room SRIR Extrapolation Demo

A compact MATLAB demo developed for an MSc project in Acoustics and Music Technology at the University of Edinburgh.

The project estimates a fourth-order Higher-Order Ambisonics (HOA) spatial room impulse response (SRIR) at a target receiver position from one measured SRIR and known room geometry. It models propagation through the doorway between two coupled rooms, then compares the result with a single-room baseline and the measured target response.

## Method overview

The processing pipeline:

1. Models direct and early-reflection paths using the image source method (ISM).
2. Represents cross-room propagation as source-to-aperture and aperture-to-receiver segments.
3. Extracts salient arrivals using temporal windows and directional beamforming.
4. Rotates, scales and repositions the extracted HOA arrivals using the predicted direction of arrival (DoA), time of arrival (ToA) and propagation distance.
5. Applies angular zoom and level scaling to the residual sound field.
6. Resynthesises the target-position SRIR and evaluates it against measured data.

## Requirements

- MATLAB
- Signal Processing Toolbox
- Audio Toolbox
- Internet access for the first dataset download

The required research toolboxes are included in the repository and are added to the MATLAB path automatically.

## Quick start

1. Clone the repository:

   ```bash
   git clone https://github.com/Potat0Servers/srir_extrap_2026_demo.git
   ```

2. Open the repository folder in MATLAB.

3. Run:

   ```matlab
   MAIN_BATCH
   ```

On the first run, the selected [Room Transition SRIR dataset](https://zenodo.org/records/7848561) is downloaded automatically to `SOFAfiles/` (approximately 1.1 GB). The demo uses 101 fourth-order HOA measurements with 25 ACN/SN3D channels at 48 kHz. Receiver index 51 lies at the doorway between the meeting room and hallway.

The default configuration evaluates receiver position `30 -> 60` and displays the numerical results and plots.

## Configuration

Edit the settings near the top of `MAIN_BATCH.m`:

- `orig_pos_vec` and `tar_pos_vec`: original and target receiver indices (`1:101`).
- `plot_and_table`: print the evaluation table and create comparison plots.
- `save_csv`: append experiment settings and metrics to a CSV file.
- `save_srir`: export original, baseline, proposed and target responses as SOFA files.
- `run_all`: evaluate all 10,201 original-target combinations. Start with the default single comparison, as a full run is computationally expensive.

## Main files and functions

- `MAIN_BATCH.m` — user-facing entry point for single or batch experiments.
- `MAIN_coupled_room_srir_comparison.m` — loads the data, runs both extrapolation methods, evaluates the results and handles optional exports.
- `other_functions/extrapolate_srir_coupled_room.m` — proposed aperture-aware coupled-room method.
- `other_functions/extrapolate_srir_single_room_baseline.m` — single-room comparison baseline.
- `other_functions/evaluate_srir_set.m` — calculates room, spatial and binaural metrics and generates comparison plots.
- `supplementary_functions/convolve_srir_with_audio.m` — decodes saved HOA SRIRs binaurally and convolves them with a dry audio signal.
- `Results/` — precomputed results for 1,010 receiver-position comparisons.
- `SRIR outputs/75-25/` — example original, baseline, proposed and measured target SOFA files.
- `Figures/` — selected analysis and evaluation figures.

The evaluation includes RMS level, integrated loudness, waveform error, C50, DRR, T60, energy-decay-curve error, PBC-2 binaural colouration and direct-arrival time, together with directional RMS and T60 plots.

## Audio example

Binaural guitar renders for the `75 -> 25` example:

[Original](75-25_original_DryGuitar_mono.wav) · [Single-room baseline](75-25_baseline_DryGuitar_mono.wav) · [Proposed method](75-25_proposed_DryGuitar_mono.wav) · [Measured target](75-25_target_DryGuitar_mono.wav)

## Notes

This repository is a reduced demonstration version of the dissertation code. The measured target SRIR is used only for evaluation and is not used by the extrapolation algorithm.

Third-party toolboxes remain subject to the licences included in their respective folders.
