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
%
%   One client at a time. Matlab is single threaded and a second caller
%   could not be served while the first one's command runs, so the accept
%   loop finishes with one connection before taking the next. A client that
%   gives up waiting closes its socket; the reply then goes nowhere, and the
%   next connection starts clean.

if nargin < 2 || isempty(idleSeconds)
    idleSeconds = 1800;
end

SENTINEL = '--MATLABSERVER-DONE--';
timeoutMs = round(idleSeconds * 1000);

% Matlab decorates warnings and errors with clickable <a href="matlab:...">
% links meant for its own desktop. Turn them off where we can.
try
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
        catch err
            if isSocketTimeout(err)
                % Same again: a client that connected and then went quiet.
                fprintf('server: idle for %g s; shutting down\n', idleSeconds);
                sock.close();
                return
            end
            % Any other failure is the client going away: Vim gave up on a
            % slow command and closed its socket, or exited. That is not a
            % reason to stop; take the next connection.
            break
        end
        if isempty(line)
            break                      % client hung up
        end
        cmd = strtrim(char(line));
        if strcmp(cmd, 'quit')
            sendLine(out, sprintf('%s 0', SENTINEL));
            sock.close();
            return
        end
        status = 0;
        caught = [];
        % The command runs in the base workspace, not in this function's:
        % here it would share a workspace with the plumbing, and a script
        % opening with "clear all" (or assigning to out, srv, cmd ...) took
        % the whole session down. Under -batch the base workspace starts
        % empty, so "clear all" there clears only what the user made.
        %
        % The try/catch sits inside the evalc so that what the command
        % printed before it raised is kept and shown ahead of the error;
        % an error thrown through evalc would discard that output.
        txt = evalc('try, evalin(''base'', cmd), catch caught, end');
        if ~isempty(caught)
            % Reported as "file:line: message", the shape compiler/matlab.vim
            % gives Vim's errorformat, so :make drops the error straight into
            % the quickfix list and :clist and :cnext can walk it.
            %
            % The report would name evalin, evalc and this file in the stack,
            % which is our plumbing and not the caller's problem, so those
            % frames go.
            here = [mfilename('fullpath') '.m'];
            frames = caught.stack;
            if ~isempty(frames)
                keep = arrayfun(@(f) ~isempty(f.file) && ~strcmp(f.file, here), frames);
                frames = frames(keep);
            end
            % One line only: errorformat's %m stops at the end of the line,
            % and \s covers the newlines a multi-line message carries. A
            % parse error's message already opens with "Error: ", which the
            % line below adds again.
            msg = strtrim(regexprep(caught.message, '\s+', ' '));
            % Parse errors carry an opentoline hotlink around the position
            % even with hotlinks off; drop the markup before reading it.
            msg = regexprep(msg, '</?a[^>]*>', '');
            msg = regexprep(msg, '^Error:\s*', '');
            % A parse error has no stack; its position is in the message,
            % as "File: name.m Line: 2 Column: 5". The name is relative to
            % the directory the command cd'd into, so resolve it here where
            % that directory is current.
            pos = regexp(msg, '^File: (\S+) Line: (\d+) Column: (\d+) (.*)$', 'tokens', 'once');
            if isempty(frames) && ~isempty(pos)
                f = which(pos{1});
                if isempty(f)
                    f = pos{1};
                end
                lines = {sprintf('%s:%s:%s: %s', f, pos{2}, pos{3}, pos{4})};
            elseif isempty(frames)
                lines = {sprintf('Error: %s', msg)};
            else
                lines = {sprintf('%s:%d: %s', frames(1).file, frames(1).line, msg)};
                for k = 2:numel(frames)
                    lines{end+1} = sprintf('%s:%d: called from %s', ...
                        frames(k).file, frames(k).line, frames(k).name); %#ok<AGROW>
                end
            end
            if ~isempty(txt) && txt(end) ~= newline
                txt = [txt newline];
            end
            txt = [txt strjoin(lines, newline)];
            status = 1;
        end
        txt = regexprep(txt, '\r\n?', '\n');
        % Strip anything hotlinks left behind, plus the backspaces Matlab
        % pads warning text with for terminal rendering.
        % help() called from a captured command also wraps the function
        % name in <strong>, which -batch on the command line does not.
        txt = regexprep(txt, '</?(a|strong|b)(\s[^>]*)?>', '');
        txt = strrep(txt, char(8), '');
        % CollapseDelimiters is on by default and would fold the blank lines
        % out of the output.
        for piece = strsplit(txt, '\n', 'CollapseDelimiters', false)
            sendLine(out, piece{1});
        end
        sendLine(out, sprintf('%s %d', SENTINEL, status));
    end
    sock.close();
end
end

function tf = isSocketTimeout(err)
%ISSOCKETTIMEOUT  True when a caught error is Java's SocketTimeoutException.
tf = isa(err, 'matlab.exception.JavaException') && ...
    isa(err.ExceptionObject, 'java.net.SocketTimeoutException');
end

function sendLine(out, text)
%SENDLINE  Write one line ending in a bare newline.
%   PrintWriter.println ends a line with the platform separator, and on
%   Windows the trailing carriage return rides along into Vim's quickfix
%   entries and channel replies.
out.print(java.lang.String([text char(10)]));
out.flush();
end
