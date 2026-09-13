function save_srir_sofa(template_sofa, srir, src_pos, rec_pos, file_path)
%SAVE_SRIR_SOFA Write one samples-by-channels SRIR to a SOFA file.
%   It copies the template metadata and replaces the IR plus the source and
%   receiver positions.

    obj = template_sofa;

    % srir is [samples x channels]; Data.IR expects [M x R x N] = [1 x channels x samples]
    obj.Data.IR = reshape(srir.', 1, size(srir, 2), size(srir, 1));

    obj.SourcePosition = src_pos(:).';
    obj.ListenerPosition = rec_pos(:).';

    obj = SOFAsave(file_path, obj);
end
