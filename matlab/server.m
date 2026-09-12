function server(port, idleSeconds)
%SERVER  Serve Vim over a socket, so Vim need not restart Matlab.
%
%   Matlab takes several seconds to start, which is too slow to pay for every
%   script you run. This keeps one session alive and listens on a loopback
%   socket; Vim connects to it and gets answers in milliseconds. The work is
%   in vimserver.m, next to this file; this is the entry point Vim names.
%
%   Started by :MatlabStart. By hand:
%
%       matlab -nodesktop -nosplash -noDisplayDesktop -wait ^
%              -logfile server.log -r "server(51763, 1800)"
%
%   and not -batch, which is what it used to be. A debugger stop needs an
%   interactive prompt to return to: under -batch a dbquit ends the process,
%   since it abandons the one statement -batch was given. With -r that
%   statement returns at once, the prompt sits idle, and a timer does the
%   listening. On Windows -nodesktop alone opens a command window that takes
%   the focus as it appears; -noDisplayDesktop keeps it from existing, at the
%   price that fprintf with arguments cannot write to stdout (vimserver.m
%   uses disp(sprintf(...)) for its few log lines, and what you run is
%   captured by evalc). Nothing reaches stdout in any case, hence -logfile.
%
%   idleSeconds is how long to sit with nothing to do before shutting down,
%   so a forgotten session does not hold hundreds of megabytes for the rest
%   of the day. The clock does not run while a command is being evaluated or
%   while the debugger is stopped, so a long computation is never cut short.
%   The timeout lives here rather than in Vim on purpose: it still fires if
%   Vim is killed outright.
%
%   The protocol is described at the top of vimserver.m. Only loopback
%   connections are accepted: this evaluates whatever it is sent.

if nargin < 2 || isempty(idleSeconds)
    idleSeconds = 1800;
end
vimserver.start(port, idleSeconds);
end
