function residual_gain = calculate_direct_path_residual_gain(path_info)
%CALCULATE_DIRECT_PATH_RESIDUAL_GAIN Select direct-path gain for a residual.
%
% The deterministic arrivals may each have a different propagation gain,
% whereas scale_srir_residual requires one scalar.  For a Room-1-to-
% Room-2 or Room-2-to-Room-1 transition, use the matched direct path's
% complete original-to-target distance ratio as the representative gain.

%% Select the direct-path gain

direct_path_idx = path_info.path_id == 0;
residual_gain = path_info.gain(direct_path_idx);

end
