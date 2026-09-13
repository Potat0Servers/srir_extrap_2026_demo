function [srir_residual_scaled, scale_info] = scale_srir_residual( ...
    srir_residual, direct_toa_samp, residual_scale_param, fs)
%SCALE_SRIR_RESIDUAL Apply one gain envelope to the SRIR residual.
%
% Supported modes:
%   "off"          Leave the residual unchanged.
%   "full"         Scale the complete residual by a constant gain.
%   "after_cutoff" Keep unity gain until a direct-sound-relative cutoff,
%                   crossfade linearly to the requested gain, then keep
%                   that gain for the remainder of the residual.
%
% The same envelope is applied to every HOA channel so their relative
% spatial encoding is preserved.

%% Scaling setup and metadata

num_samples = size(srir_residual, 1);
mode = string(residual_scale_param.mode);
gain_value = residual_scale_param.gain;
validate_computed_gain(gain_value);

scale_info.mode = mode;
scale_info.gain = gain_value;
if gain_value == 0
    scale_info.gain_db = -Inf;
else
    scale_info.gain_db = 20 * log10(gain_value);
end
scale_info.direct_toa_samp = round(direct_toa_samp);
scale_info.start_samp = NaN;
scale_info.fade_end_samp = NaN;
scale_info.start_time_sec = NaN;
scale_info.fade_end_time_sec = NaN;
scale_info.was_applied = false;

gain_envelope = ones(num_samples, 1);

%% Build the gain envelope

switch mode
    case "off"
        % Unity envelope: explicit no-op for disabled room combinations.

    case "full"
        gain_envelope(:) = gain_value;
        scale_info.start_samp = 1;
        scale_info.fade_end_samp = 1;
        scale_info.start_time_sec = 0;
        scale_info.fade_end_time_sec = 0;
        scale_info.was_applied = gain_value ~= 1;

    case "after_cutoff"
        cutoff_offset_samp = round(residual_scale_param.start * fs);
        fade_samp = round(residual_scale_param.fade * fs);
        start_samp = round(direct_toa_samp) + cutoff_offset_samp;

        scale_info.start_samp = start_samp;
        scale_info.start_time_sec = (start_samp - 1) / fs;

        if start_samp <= num_samples
            start_samp = max(1, start_samp);

            if fade_samp <= 0
                gain_envelope(start_samp:end) = gain_value;
                fade_end_samp = start_samp;
            else
                fade_end_samp = min( ...
                    num_samples, ...
                    start_samp + fade_samp - 1);

                % Linear-amplitude crossfade: the cutoff sample starts at
                % unity, and the final fade sample reaches the target gain.
                gain_envelope(start_samp:fade_end_samp) = linspace( ...
                    1, ...
                    gain_value, ...
                    fade_end_samp - start_samp + 1).';

                if fade_end_samp < num_samples
                    gain_envelope(fade_end_samp + 1:end) = gain_value;
                end
            end

            scale_info.fade_end_samp = fade_end_samp;
            scale_info.fade_end_time_sec = (fade_end_samp - 1) / fs;
            scale_info.was_applied = gain_value ~= 1;
        end
end

%% Apply residual scaling

srir_residual_scaled = srir_residual .* gain_envelope;

end

%% Computed-gain validation

function validate_computed_gain(gain_value)
%VALIDATE_COMPUTED_GAIN Check that a calculated gain is one finite scalar.

if ~isscalar(gain_value) || ~isfinite(gain_value)
    error( ...
        'scale_srir_residual:NonFiniteGain', ...
        'The calculated residual gain must be a finite scalar.');
end
end
