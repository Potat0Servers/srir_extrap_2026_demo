function [srir_new, was_added] = srir_resynthesize_from_arrivals( ...
    arrival_set, srir_residual, target_toa_samp, pre_samp)
%SRIR_RESYNTHESIZE_FROM_ARRIVALS Place arrivals at target times and mix the residual.

%% Reposition early reflections

num_samples = size(srir_residual, 1);
num_paths = numel(arrival_set.audio);
target_start_samp = reshape(target_toa_samp, 1, []) - pre_samp;
srir_repositioned = zeros(size(srir_residual));
was_added = false(1, num_paths);

for i = arrival_set.reflection_idx
    if isempty(arrival_set.audio{i})
        continue
    end

    [srir_repositioned, was_added(i)] = add_arrival( ...
        srir_repositioned, ...
        arrival_set.audio{i}, ...
        target_start_samp(i), ...
        num_samples);
end

%% Reposition direct sound

i = arrival_set.direct_idx;
if ~isempty(arrival_set.audio{i})
    if arrival_set.direct_end_samp >= 1
        direct_end_samp = min(num_samples, arrival_set.direct_end_samp);
        srir_repositioned(1:direct_end_samp,:) = 0;
    end

    [srir_repositioned, was_added(i)] = add_arrival( ...
        srir_repositioned, ...
        arrival_set.audio{i}, ...
        target_start_samp(i), ...
        num_samples);
end

%% Mix repositioned arrivals and residual

srir_new = srir_residual + srir_repositioned;

end

%% Arrival-addition helper

function [srir_out, was_added] = add_arrival(srir_in, arrival, target_start_samp, num_samples)
%ADD_ARRIVAL Add the valid part of one arrival at its target start sample.

[target_idx, arrival_idx] = clipped_indices(target_start_samp, size(arrival,1), num_samples);

if isempty(target_idx)
    srir_out = srir_in;
    was_added = false;
    return
end

srir_out = srir_in;
srir_out(target_idx,:) = srir_out(target_idx,:) + arrival(arrival_idx,:);
was_added = true;
end

%% Clipped-index helper

function [valid_idx, local_idx] = clipped_indices(start_raw, len, max_len)
%CLIPPED_INDICES Match a clipped signal range to its local sample indices.

end_raw = start_raw + len - 1;
valid_start = max(1, start_raw);
valid_end = min(max_len, end_raw);

if valid_start > valid_end
    valid_idx = [];
    local_idx = [];
    return
end

valid_idx = valid_start:valid_end;
local_start = valid_start - start_raw + 1;
local_end = local_start + numel(valid_idx) - 1;
local_idx = local_start:local_end;
end
