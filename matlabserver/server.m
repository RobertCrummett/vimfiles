function server(port, idleSeconds)
%SERVER  Evaluate commands sent over a socket, so Vim need not restart Matlab.
%
%   Matlab takes several seconds to start, which is too slow to pay for every
%   script you run. This keeps one session alive and listens on a loopback
%   socket; Vim connects to it and gets answers in milliseconds.
%
%   Started by :MatlabStart. By hand:
%
%       matlab -batch "server(51763, 1800)"
%
%   idleSeconds is how long to sit with nothing to do before shutting down,
%   so a forgotten session does not hold hundreds of megabytes for the rest
%   of the day. The clock covers waiting for a client and waiting for a
%   command from one; it does not run while a command is being evaluated, so
%   a long computation is never cut short. The timeout lives here rather than
%   in Vim on purpose: it still fires if Vim is killed outright.
%
%   The socket comes from Java rather than tcpserver, which needs the
%   Instrument Control Toolbox; Matlab always ships a JVM.
%
%   Protocol, line based and UTF-8. The client sends one command per line.
%   The server replies with the command's output, then a line
%
%       <SENTINEL> <status>
%
%   where status is 0 when the command ran and 1 when it raised. Only
%   loopback connections are accepted: this evaluates whatever it is sent.

if nargin < 2 || isempty(idleSeconds)
    idleSeconds = 1800;
end

SENTINEL = '--MATLABSERVER-DONE--';
timeoutMs = round(idleSeconds * 1000);

% Matlab decorates warnings and errors with clickable <a href="matlab:...">
% links meant for its own desktop. Turn them off where we can.
try %#ok<TRYNC>
    feature('hotlinks', 0);
end

% Warning backtraces would name this file, which is our plumbing and tells
% the caller nothing about their own code.
warning('off', 'backtrace');

srv = java.net.ServerSocket(port, 4, java.net.InetAddress.getByName('127.0.0.1'));
cleanup = onCleanup(@() srv.close()); %#ok<NASGU>
srv.setSoTimeout(timeoutMs);
fprintf('server: listening on 127.0.0.1:%d, idle timeout %g s\n', ...
    srv.getLocalPort(), idleSeconds);

while true
    try
        sock = srv.accept();
    catch
        % accept only fails here by timing out: nobody connected in time.
        fprintf('server: no client for %g s; shutting down\n', idleSeconds);
        return
    end
    if ~sock.getInetAddress().isLoopbackAddress()
        sock.close();
        continue
    end
    sock.setSoTimeout(timeoutMs);
    in  = java.io.BufferedReader(java.io.InputStreamReader(sock.getInputStream(), 'UTF-8'));
    out = java.io.PrintWriter(java.io.OutputStreamWriter(sock.getOutputStream(), 'UTF-8'), true);
    while true
        try
            line = in.readLine();
        catch
            % Same again: a client that connected and then went quiet.
            fprintf('server: idle for %g s; shutting down\n', idleSeconds);
            sock.close();
            return
        end
        if isempty(line)
            break                      % client hung up
        end
        cmd = strtrim(char(line));
        if strcmp(cmd, 'quit')
            out.println(java.lang.String(sprintf('%s 0', SENTINEL)));
            sock.close();
            return
        end
        status = 0;
        try
            txt = evalc(cmd);
        catch err
            % err.getReport would name evalc and this file in the stack, which
            % is our plumbing and not the caller's problem. Report the message
            % and only the frames from their own code.
            lines = {sprintf('Error: %s', err.message)};
            here = mfilename('fullpath');
            for k = 1:numel(err.stack)
                f = err.stack(k);
                if strcmp(f.file, [here '.m']) || isempty(f.file)
                    continue
                end
                lines{end+1} = sprintf('  in %s (%s) at line %d', ...
                    f.name, f.file, f.line); %#ok<AGROW>
            end
            txt = strjoin(lines, newline);
            status = 1;
        end
        txt = regexprep(txt, '\r\n?', '\n');
        % Strip anything hotlinks left behind, plus the backspaces Matlab
        % pads warning text with for terminal rendering.
        txt = regexprep(txt, '</?a[^>]*>', '');
        txt = strrep(txt, char(8), '');
        for piece = strsplit(txt, '\n')
            out.println(java.lang.String(piece{1}));
        end
        out.println(java.lang.String(sprintf('%s %d', SENTINEL, status)));
    end
    sock.close();
end
end
