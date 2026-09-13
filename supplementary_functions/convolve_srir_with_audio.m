clearvars;
clc;

%% User settings

% orig and target indices (matches the "x-y" folder name in SRIR outputs)
idx_orig = 75;
idx_tar = 25;

% Audio source to auralise (edit this path to choose a different file)
audio_source_file = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'audio sources', 'DryGuitar_mono.wav');

% Peak-normalise the output to avoid clipping?
normalise_output = true;

%% Paths

script_dir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(script_dir, 'addpaths.m'));

srir_folder = fullfile(script_dir, 'SRIR outputs', sprintf('%d-%d', idx_orig, idx_tar));
sr_names = {'original', 'baseline', 'proposed', 'target'};

%% Load binaural decoder

binaural_decoder = load_binaural_decoder();

%% Load and prepare dry source

[audio, audio_fs] = audioread(audio_source_file);
if size(audio, 2) > 1
    audio = mean(audio, 2); % downmix stereo to mono
end
audio = resample(audio, 48000, audio_fs);

[~, audio_base, ~] = fileparts(audio_source_file);

%% Auralise each SRIR

for k = 1:numel(sr_names)
    sofa = SOFAload(fullfile(srir_folder, [sr_names{k} '.sofa']));
    srir = double(squeeze(sofa.Data.IR(1,:,:))).'; % [samples x channels]
    fs = double(sofa.Data.SamplingRate(1));

    brir = render_binaural(srir, binaural_decoder); % [samples x 2]

    out = zeros(size(audio,1) + size(brir,1) - 1, 2);
    for ear = 1:2
        out(:,ear) = conv(audio, brir(:,ear));
    end

    if normalise_output
        out = out / max(abs(out(:))) * 0.95;
    end

    out_file = fullfile(script_dir, sprintf('%d-%d_%s_%s.wav', idx_orig, idx_tar, sr_names{k}, audio_base));
    audiowrite(out_file, out, fs);
    fprintf('Wrote %s\n', out_file);
end


%% Local functions

function binaural_decoder = load_binaural_decoder()
    load_ambisonic_configuration;
    binaural_decoder = SH_ambisonic_binaural_decoder;
end

function brir = render_binaural(srir, binaural_decoder)
    n_output_samples = size(srir,1) + size(binaural_decoder,2) - 1;
    brir = zeros(n_output_samples, 2);

    for channel_idx = 1:size(srir,2)
        for ear_idx = 1:2
            decoder_ir = squeeze(binaural_decoder(channel_idx,:,ear_idx));
            brir(:,ear_idx) = brir(:,ear_idx) + ...
                conv(srir(:,channel_idx), decoder_ir(:));
        end
    end
end
