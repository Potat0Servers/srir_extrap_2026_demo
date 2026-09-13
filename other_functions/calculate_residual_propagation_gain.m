function residual_gain = calculate_residual_propagation_gain( ...
    path_info, ...
    path_a2r_orig, ...
    path_a2r_tar, ...
    residual_propagation_gain_param)
%CALCULATE_RESIDUAL_PROPAGATION_GAIN Pick the gain used for the residual SRIR.

%% Select the residual propagation model

model = string(residual_propagation_gain_param.model);

switch model
    case "fixed_distance"
        fixed_distance_m = residual_propagation_gain_param.fixed_distance_m;
        residual_gain = (fixed_distance_m + path_a2r_orig.dist) / (fixed_distance_m + path_a2r_tar.dist);

    case "full_path"
        direct_path_idx = path_info.path_id == 0;
        residual_gain = path_info.dist.orig(direct_path_idx) ./ path_info.dist.tar(direct_path_idx);
end

fprintf('Residual gain model: %s, gain: %.4f (%.2f dB)\n', model, residual_gain, 20*log10(residual_gain));

end
