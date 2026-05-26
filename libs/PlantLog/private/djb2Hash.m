function h = djb2Hash(s)
%DJB2HASH Pure-MATLAB djb2-style hash returning 16-char lowercase hex.
%   h = DJB2HASH(s) accepts a char vector or string scalar `s` and returns
%   a lowercase hex char vector of length 16 representing the uint64 djb2
%   hash of the input bytes. Toolbox-free; deterministic across MATLAB
%   and Octave. No Java, no MEX.
%
%   Algorithm: hash = 5381; for each byte c: hash = (hash * 33) XOR c.
%   Arithmetic is performed in uint64 with wrap-around (modulo 2^64).
%
%   Inputs:
%     s — char vector OR string scalar. Empty input returns the initial
%         seed value 5381 rendered as 16 hex chars: '0000000000001505'.
%
%   Outputs:
%     h — 1x16 char vector, lowercase hex digits (0-9, a-f).
%
%   Example:
%     h = djb2Hash('hello');  % deterministic 16-char hex
%
%   This function is a private helper for PlantLog. Tests reach it
%   indirectly via PlantLogEntry constructor (which calls computeRowHash).
%
%   See also computeRowHash, PlantLogEntry.

    if isstring(s)
        s = char(s);
    end
    if ~ischar(s)
        error('PlantLog:invalidInput', ...
            'djb2Hash expected char or string; got %s.', class(s));
    end

    h_u64 = uint64(5381);
    bytes = uint64(double(s));   % per-character codepoint as uint64
    for k = 1:numel(bytes)
        % MATLAB's uint64 arithmetic SATURATES on overflow (clamps to
        % 2^64 - 1), which would break djb2's required modulo-2^64 wrap.
        % Octave's uint64 wraps natively, but we want identical behavior
        % across runtimes. Double precision can't hold 2^64 exactly
        % (only 53 bits of mantissa), so we split the multiply into two
        % 32-bit halves: compute lo*33 and hi*33 in double precision
        % (each fits in 53 bits), then recombine modulo 2^32 each.
        lo32 = bitand(h_u64, uint64(2^32 - 1));
        hi32 = bitshift(h_u64, -32);
        new_lo = mod(double(lo32) * 33, 2^32);
        new_hi = mod(double(hi32) * 33 + floor(double(lo32) * 33 / 2^32), 2^32);
        h_u64 = bitor(uint64(new_lo), bitshift(uint64(new_hi), 32));
        h_u64 = bitxor(h_u64, bytes(k));
    end

    % Render as 16-char lowercase hex
    h = lower(dec2hex(h_u64, 16));
end
