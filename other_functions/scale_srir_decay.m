function srir_out = scale_srir_decay( ...
    srir_in, ...
    fs, ...
    t60_orig, ...
    t60_target, ...
    scale_start_ms, ...
    scale_end_ms)
%SCALE_SRIR_DECAY Transform the decay within a selected SRIR interval.
%   Empty start and end values select the first and last input samples.
%   The selected interval starts at time zero for the decay envelope.

if t60_orig == t60_target
    srir_out = srir_in;
    return
end

if isempty(scale_start_ms)
    scale_start_sample = 1;
else
    scale_start_sample = round(scale_start_ms * 1e-3 * fs) + 1;
end

if isempty(scale_end_ms)
    scale_end_sample = size(srir_in,1);
else
    scale_end_sample = round(scale_end_ms * 1e-3 * fs) + 1;
end

scale_indices = scale_start_sample:scale_end_sample;
time_vector = (0:numel(scale_indices)-1)' / fs;
decay_envelope = 10.^(-3 * time_vector * (1 / t60_target - 1 / t60_orig));
srir_out = srir_in;
srir_out(scale_indices,:) = srir_in(scale_indices,:) .* decay_envelope;

end
