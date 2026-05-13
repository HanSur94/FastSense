function [user, host] = userIdentity()
%USERIDENTITY Resolve OS username and hostname, cross-platform.
%   [user, host] = userIdentity() returns the OS username and hostname,
%   working on MATLAB R2020b+ and GNU Octave 7+ (including --disable-java
%   builds). Pure MATLAB, no MEX, no toolboxes.
%
%   Fallback chain (first non-empty wins):
%     USERNAME:
%       1. Windows: getenv('USERNAME')
%       2. POSIX:   getenv('USER'), getenv('LOGNAME')
%       3. Both:    system('whoami')
%       4. Default: ''  (empty — caller decides whether to throw)
%     HOSTNAME:
%       1. Windows: getenv('COMPUTERNAME')
%       2. POSIX:   getenv('HOSTNAME')   % NOTE: often unset in non-login shells
%       3. Both:    system('hostname')   % SECONDARY fallback — fixes Pitfall D
%       4. Both:    usejava('jvm') guarded java.net.InetAddress (TERTIARY)
%       5. Default: ''  (empty — caller decides whether to throw)
%
%   Note: this function returns '' on failure rather than throwing.
%   ClusterIdentity.resolve('Strict', true) is the wrapper that converts
%   an empty user or host into Concurrency:identityResolutionFailed.
%
%   See also ClusterIdentity.

    % --- USERNAME ---
    if ispc
        user = getenv('USERNAME');
    else
        user = getenv('USER');
        if isempty(user)
            user = getenv('LOGNAME');
        end
    end
    if isempty(user)
        try
            [s, out] = system('whoami');
            if s == 0
                user = strtrim(out);
            end
        catch
            user = '';
        end
    end

    % --- HOSTNAME ---
    if ispc
        host = getenv('COMPUTERNAME');
    else
        host = getenv('HOSTNAME');
    end
    if isempty(host)
        try
            [s, out] = system('hostname');
            if s == 0
                host = strtrim(out);
                % Windows sometimes appends CR-LF; strtrim handles LF, strip residual CR:
                host = regexprep(host, '\r', '');
            end
        catch
            host = '';
        end
    end
    if isempty(host) && usejava('jvm')
        try
            host = char(java.net.InetAddress.getLocalHost().getHostName());
        catch
            host = '';
        end
    end
end
