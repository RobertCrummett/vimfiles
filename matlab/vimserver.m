classdef vimserver < handle
%VIMSERVER  The Matlab half of plugin/matlabserver.vim and plugin/matlabdebug.vim.
%
%   One object per session, created by server.m and reachable afterwards as
%   vimserver.instance(). It owns the loopback socket Vim connects to, a
%   timer that polls that socket, and the queue of requests waiting to run.
%
%   How a request runs, and why it is not run by the timer that read it
%   ---------------------------------------------------------------------
%   The session sits at an ordinary Matlab prompt with nothing to do. The
%   timer fires there, reads what Vim sent, and queues each request; then it
%   asks the prompt to run vimserver.instance().next(), which pops one
%   request and evaluates it. Going through the prompt matters for the
%   debugger. When the evaluated code hits a breakpoint, Matlab stops at a
%   K>> prompt with next() suspended underneath; the timer keeps firing at
%   that prompt, keeps reading the socket, and can hand the prompt further
%   requests, which run in the workspace of the stopped frame. Had the timer
%   evaluated the code itself, the stop would have happened inside its
%   callback, later ticks would have been dropped, and nothing could have
%   read the socket again.
%
%   The prompt is asked through MLExecuteServices.consoleEval, which queues
%   a line as though it had been typed. That is also how the debugger
%   commands (dbstep, dbcont, dbquit ...) reach it: they are only accepted at
%   the prompt, not from inside a callback.
%
%   THIS IS A WORKAROUND, NOT A SUPPORTED INTERFACE. consoleEval lives in
%   com.mathworks.mlservices, an undocumented Java package that MathWorks has
%   said the com.mathworks packages will eventually lose. Every other call in
%   this file is documented, or (IsDebugMode, getWorkspaceDisplay) is what
%   MathWorks' own Visual Studio Code debug adapter uses. Verified on R2026a;
%   when a release breaks it, look for the replacement in that adapter
%   (github.com/mathworks/MATLAB-language-server, src/debug) before anything
%   else. See :help matlabdebug-workaround.
%
%   Protocol, line based and UTF-8. A request from Vim is one line:
%
%       <id> <kind> <text>
%
%   <id> is Vim's tag for the request and comes back on the reply. Kinds:
%
%       eval <code>       Evaluate <code> at the prompt: in the base
%                         workspace, or while stopped in the debugger, in
%                         the selected frame. The reply is its output.
%       dbg <command>     dbstep, dbstep in, dbstep out, dbcont, dbquit,
%                         dbup, dbdown. The reply only acknowledges; what
%                         happens next arrives as an event.
%       stack             The frames Matlab is stopped in, innermost first.
%       vars              The variables of the selected frame.
%       break <file>\t<line>[\t<condition>]
%       clear <file>\t<line>, or clear <file>, or clear
%                         Set or remove a breakpoint; both reply with the
%                         breakpoints now in <file>, one "line\tcondition"
%                         per line, as Matlab placed them (a breakpoint on
%                         a comment moves to the next line that runs).
%       quit              End the session.
%
%   A reply is
%
%       --MATLABSERVER-BEGIN-- <id>
%       ...the output...
%       --MATLABSERVER-DONE-- <id> <status>
%
%   status 0 when it ran, 1 when it raised, 2 when a dbquit threw it away.
%   The BEGIN line is there because replies interleave: a request that is
%   stopped in the debugger answers only after every request served at the
%   K>> prompt meanwhile. Events are unsolicited and describe a stop:
%
%       --MATLABSERVER-FRAME-- <line>\t<name>\t<file>     one per frame
%       --MATLABSERVER-EVENT-- stopped <selected frame> <id>
%
%   where the selected frame is 1 for the innermost and <id> names the
%   request whose code is stopped, or - if none is.
%
%   Only loopback connections are accepted: this evaluates what it is sent.

properties (SetAccess = private)
    port
    idleSeconds
    here            % this file, whose frames are plumbing and never shown
    server          % java.nio.channels.ServerSocketChannel, non-blocking
    client = []     % java.nio.channels.SocketChannel of the client, if any
    pending = uint8([])  % bytes read from it that do not yet end a line
    buf             % java.nio.ByteBuffer the reads land in
    tmr             % the polling timer
    queue = {}      % requests read but not yet run: structs id, kind, text
    inflight = {}   % ids of requests next() is running, innermost last
    busy = false    % the prompt has been given something not yet finished
    stopped = false % the debugger prompt was seen on the last look
    frame = 1       % selected frame while stopped, 1 innermost
    lastdbg = ''    % the debugger command most recently sent to the prompt
    expect = ''     % what mark() follows: 'dbg' a debugger command, 'next' a request
    lastsig = ''    % the stack as last reported, to tell a nested stop
    sending = false % inside send(); a poll() that fires meanwhile must wait
    quitting = false % told to leave; exit goes out once the prompt is idle
    alone           % tic of when the client went away, [] while one is here
    quiet           % tic of the last activity, for the idle timeout
end

properties (Constant)
    SENTINEL = '--MATLABSERVER-DONE--'
    EVENT = '--MATLABSERVER-EVENT--'
    FRAME = '--MATLABSERVER-FRAME--'
    BEGIN = '--MATLABSERVER-BEGIN--'
    PERIOD = 0.02   % seconds between looks at the socket
    DBG = {'dbstep', 'dbstep in', 'dbstep out', 'dbcont', 'dbquit', 'dbquit all', 'dbup', 'dbdown'}
end

methods (Static)
    function obj = instance(newobj)
    %INSTANCE  The session's object. Locked so that a script's clear all
    %   does not forget it; the timer holds it as well.
        persistent inst
        mlock
        if nargin
            inst = newobj;
        end
        obj = inst;
    end

    function start(port, idleSeconds)
    %START  Open the socket, start polling, and return to the prompt.
        S = vimserver(port, idleSeconds);
        vimserver.instance(S);
        % disp of a sprintf, not fprintf: started with -noDisplayDesktop,
        % which is what keeps the command window from ever appearing,
        % fprintf with arguments fails with "Error writing to output
        % stream" (disp and sprintf are fine). Every line this file
        % writes to the log goes this way.
        disp(sprintf('server: listening on 127.0.0.1:%d, idle timeout %g s', ...
            port, idleSeconds));
    end

    function tf = debugging()
    %DEBUGGING  Whether Matlab is stopped at a K>> prompt. Undocumented,
    %   but it is what MathWorks' own debug adapter asks. It is true only
    %   when the prompt itself is a debug prompt: false while user code is
    %   sitting in pause() or drawnow, which is when a timer also fires.
        tf = logical(system_dependent('IsDebugMode'));
    end

    function prompt(cmd)
    %PROMPT  Queue a line to run at the prompt as if typed. The workaround.
        com.mathworks.mlservices.MLExecuteServices.consoleEval(cmd);
    end
end

methods
    function S = vimserver(port, idleSeconds)
        S.port = port;
        S.idleSeconds = idleSeconds;
        S.here = [mfilename('fullpath') '.m'];
        % Matlab decorates warnings and errors with clickable
        % <a href="matlab:...">
        % links meant for its own desktop. Turn them off where we can.
        try
            feature('hotlinks', 0);
        end
        % Warning backtraces would name this file, which is our plumbing
        % and tells the caller nothing about their own code.
        warning('off', 'backtrace');
        % Without the desktop, the first breakpoint stop still spends ten
        % seconds bringing up the JavaScript editor to show the line.
        % Vim shows the line.
        try
            com.mathworks.services.Prefs.setBooleanPref('EditorGraphicalDebugging', false);
        end
        % The class must stay reachable after a script cd's away from
        % this directory, since every request comes through its methods.
        addpath(fileparts(S.here));

        % nio rather than ServerSocket so that accept() can be asked
        % without blocking: a timer callback that blocked would hold the
        % whole session.
        S.server = java.nio.channels.ServerSocketChannel.open();
        S.server.configureBlocking(false);
        S.server.socket().bind(java.net.InetSocketAddress( ...
            java.net.InetAddress.getByName('127.0.0.1'), port), 4);
        S.buf = java.nio.ByteBuffer.allocate(65536);
        S.quiet = tic;
        S.tmr = timer('Name', 'matlabserver', 'Tag', 'matlabserver', ...
            'ExecutionMode', 'fixedSpacing', 'Period', vimserver.PERIOD, ...
            'BusyMode', 'drop', 'TimerFcn', @(~, ~) S.poll(), ...
            'ErrorFcn', @(t, ev) S.timerError(t, ev));
        start(S.tmr);
    end

    function timerError(S, t, ev)
    %TIMERERROR  An error in poll() stops a periodic timer, and a stopped
    %   timer is a session that answers nothing. Say what happened and
    %   start it again.
        try
            msg = ev.Data.message;
        catch
            msg = 'unknown';
        end
        disp(sprintf('server: timer error: %s', msg));
        S.sending = false;
        if strcmp(t.Running, 'off') && ~isempty(S.server)
            start(t);
        end
    end

    function delete(S)
        try
            stop(S.tmr);
            delete(S.tmr);
        end
        S.hangup();
        try
            S.server.close();
        end
    end

    % ---------------------------------------------------------- the timer

    function poll(S)
    %POLL  One look at the world: new client, new lines, a stop to report,
    %   something to hand the prompt, or nothing for too long.
        if S.sending
            % A send() that is waiting on a slow client called pause(),
            % which is where timers run. Its line must not be interleaved.
            return
        end
        if S.quitting
            % exit is refused at a K>> prompt, and a line queued behind
            % the dbquit that leaves it is thrown away with everything
            % else the abort discards. So the exit waits here for the
            % idle prompt.
            if ~vimserver.debugging()
                stop(S.tmr);
                vimserver.prompt('exit');
            end
            return
        end
        S.acceptClient();
        S.readLines();
        S.noticeStop();
        S.dispatch();
        % Idle with a client: nothing running, nothing stopped, nothing
        % waiting. Without one: however things stand, since a Vim that was
        % killed while the debugger was stopped leaves this session
        % stopped, and it must still go away by itself.
        if isempty(S.client)
            idle = ~isempty(S.alone) && toc(S.alone) > S.idleSeconds;
        else
            idle = ~S.busy && ~S.stopped && isempty(S.inflight) && isempty(S.queue) ...
                && toc(S.quiet) > S.idleSeconds;
        end
        if idle
            disp(sprintf('server: idle for %g s; shutting down', S.idleSeconds));
            S.finish();
        end
    end

    function acceptClient(S)
        c = S.server.accept();
        if isempty(c)
            return
        end
        if ~c.socket().getInetAddress().isLoopbackAddress()
            c.close();
            return
        end
        % One client at a time: a new connection is Vim reconnecting, so
        % whatever was still open is finished with.
        S.hangup();
        % Non-blocking, and read through the channel itself. The stream
        % view of a channel socket is no use for polling: on the JDK 8
        % Matlab ships, its available() and ready() answer 0 with a line
        % waiting, so the old BufferedReader would never have seen it.
        c.configureBlocking(false);
        S.client = c;
        S.pending = uint8([]);
        S.alone = [];
        S.quiet = tic;
        if S.stopped
            % A Vim that reconnects (restarted, say) is told where things
            % stand; nothing else would tell it the session is stopped.
            S.reportStop();
        end
    end

    function hangup(S)
        if ~isempty(S.client)
            try
                S.client.close();
            end
        end
        S.client = [];
        S.pending = uint8([]);
        S.alone = tic;
    end

    function readLines(S)
    %READLINES  Take what has arrived and queue every complete line. Bytes
    %   after the last newline wait for the rest of their line, so a
    %   multibyte character split across two reads is decoded whole.
        if isempty(S.client)
            return
        end
        try
            for k = 1:64
                S.buf.clear();
                n = S.client.read(S.buf);
                if n < 0
                    S.hangup();                 % the client hung up
                    return
                elseif n == 0
                    break
                end
                bytes = S.buf.array();
                S.pending = [S.pending, typecast(reshape(bytes(1:n), 1, []), 'uint8')];
            end
        catch
            S.hangup();
            return
        end
        while true
            nl = find(S.pending == 10, 1);
            if isempty(nl)
                return
            end
            line = native2unicode(S.pending(1:nl-1), 'UTF-8');
            S.pending = S.pending(nl+1:end);
            S.enqueue(line);
        end
    end

    function enqueue(S, line)
        S.quiet = tic;
        line = strtrim(line);
        if isempty(line)
            return
        end
        tok = regexp(line, '^(\S+)\s+(\S+)\s?(.*)$', 'tokens', 'once');
        if isempty(tok)
            S.begin('?');
            S.send('a request is "<id> <kind> <text>"');
            S.done('?', 1);
            return
        end
        req = struct('id', tok{1}, 'kind', tok{2}, 'text', tok{3});
        % A debugger command typed as :Matlab dbstep takes the debugger
        % route: evaluated inside next() it would step with next()
        % suspended underneath, and a dbquit would abort next() itself.
        if strcmp(req.kind, 'eval') && any(strcmp(strtrim(req.text), vimserver.DBG))
            req.kind = 'dbg';
        end
        S.queue{end+1} = req;
    end

    function noticeStop(S)
    %NOTICESTOP  A breakpoint reached while the prompt was running a
    %   request shows up here, as a debug prompt that was not there on the
    %   last look. Every later stop, after a dbstep or dbcont, or a
    %   breakpoint reached by a request evaluated at the K>> prompt, is
    %   reported by mark() instead, which the prompt runs the moment it is
    %   back. The timer cannot tell those apart from a request that merely
    %   yields part way (getWorkspaceDisplay does), which puts transient
    %   frames on the stack under a K>> that is still the same one.
        dm = vimserver.debugging();
        if dm && ~S.stopped
            S.stopped = true;
            S.frame = 1;
            S.busy = false;
            if ~S.skipStop()
                S.reportStop();
            end
        elseif ~dm && S.stopped && ~S.busy
            % Left the debugger by some route other than a command of
            % ours, with nothing of ours pending: dbquit typed into the
            % hidden window, say. Every request in flight is gone with
            % it. Reported as a stop with no frames and frame 0, so Vim
            % can let go too. (A dbquit inside evaluated code unwinds
            % next() with busy set; the mark() queued behind that next()
            % handles it.)
            S.stopped = false;
            S.frame = 1;
            S.lastsig = '';
            S.busy = false;
            for k = numel(S.inflight):-1:1
                S.begin(S.inflight{k});
                S.send('the run was abandoned');
                S.done(S.inflight{k}, 2);
            end
            S.inflight = {};
            S.send(sprintf('%s stopped 0 -', vimserver.EVENT));
        end
    end

    function dispatch(S)
        if isempty(S.queue) || isempty(S.client)
            return
        end
        % A quit is honoured whatever else is going on, so that a session
        % wedged somewhere unforeseen can still be told to leave.
        for k = 1:numel(S.queue)
            if strcmp(S.queue{k}.kind, 'quit')
                S.begin(S.queue{k}.id);
                S.done(S.queue{k}.id, 0);
                S.finish();
                return
            end
        end
        if S.busy
            return
        end
        req = S.queue{1};
        switch req.kind
            case 'dbg'
                S.queue(1) = [];
                S.debugCommand(req);
            otherwise
                % Everything else runs at the prompt, one request per
                % turn; next() pops it. mark() follows for the same reason
                % as after a debugger command: should the request stop at
                % a breakpoint of its own, next() is suspended and mark()
                % runs at the new prompt, where it sees a stack that is
                % not the one last reported.
                S.expect = 'next';
                S.busy = true;
                vimserver.prompt('vimserver.instance().next();');
                vimserver.prompt('vimserver.instance().mark();');
        end
    end

    function debugCommand(S, req)
        cmd = strtrim(req.text);
        S.begin(req.id);
        if ~any(strcmp(cmd, vimserver.DBG))
            S.send(sprintf('not a debugger command: %s', cmd));
            S.done(req.id, 1);
            return
        end
        if ~vimserver.debugging()
            S.send('not stopped in the debugger');
            S.done(req.id, 1);
            return
        end
        depth = numel(S.frames());
        if strcmp(cmd, 'dbup') && S.frame >= depth
            S.send('already at the outermost frame');
            S.done(req.id, 1);
            return
        elseif strcmp(cmd, 'dbdown') && S.frame <= 1
            S.send('already at the innermost frame');
            S.done(req.id, 1);
            return
        end
        S.lastdbg = cmd;
        S.expect = 'dbg';
        S.busy = true;
        % One line per call: text after "dbstep;" on the same line is
        % dropped, and a second line queued behind a dbstep or dbcont runs
        % only when the prompt is next reached. That second fact is what
        % mark() relies on: it runs at the next stop, or, if the code ran
        % to the end, at the idle prompt after it.
        vimserver.prompt(cmd);
        vimserver.prompt('vimserver.instance().mark();');
        S.done(req.id, 0);
    end

    function finish(S)
        S.hangup();
        try
            S.server.close();       % free the port at once
        end
        S.quitting = true;
        if vimserver.debugging()
            vimserver.prompt('dbquit all');
        end
        % The timer sends the exit from the idle prompt; see poll().
    end

    % ------------------------------------------------ run at the prompt

    function next(S)
    %NEXT  Pop one request and run it. Called at the prompt, so that
    %   "caller" below is the prompt's workspace: base, or the selected
    %   debug frame.
        if isempty(S.queue)
            S.busy = false;
            return
        end
        req = S.queue{1};
        S.queue(1) = [];
        S.inflight{end+1} = req.id;
        status = 0;
        txt = '';
        % Whatever raises in here must still answer and must still clear
        % busy: an unanswered request is a wedged session, since nothing
        % is dispatched while busy holds. A dbquit does not come through
        % here, it unwinds next() entirely; mark() covers that.
        try
        switch req.kind
            case 'eval'
                % The try/catch sits inside the evalc so that what the
                % command printed before it raised is kept and shown ahead
                % of the error; an error thrown through evalc would discard
                % that output. cmd and caught live in this method's
                % workspace; the code itself runs in the caller's, so
                % nothing here is visible to it or cleared by it.
                cmd = req.text; %#ok<NASGU>
                caught = [];
                txt = evalc('try, evalin(''caller'', cmd), catch caught, end');
                if ~isempty(caught)
                    txt = S.appendError(txt, caught);
                    status = 1;
                end
            case 'stack'
                txt = '';
                for f = S.frames()
                    txt = [txt sprintf('%d\t%s\t%s\n', f.line, f.name, f.file)]; %#ok<AGROW>
                end
            case 'vars'
                % Asked from here and not from a helper: evalin('caller')
                % reaches the prompt's workspace only from the method the
                % prompt called.
                try
                    w = evalin('caller', 'matlab.internal.datatoolsservices.getWorkspaceDisplay(''caller'')');
                catch
                    w = evalin('caller', 'whos');
                end
                txt = vimserver.formatVariables(w);
            case 'break'
                [txt, status] = S.breakpoint(req.text, true);
            case 'clear'
                [txt, status] = S.breakpoint(req.text, false);
            otherwise
                txt = sprintf('unknown request kind: %s', req.kind);
                status = 1;
        end
        catch failed
            txt = sprintf('%s\nserver: %s', txt, regexprep(failed.message, '\s+', ' '));
            status = 1;
        end
        S.inflight(end) = [];
        % Only now, with the answer in hand: had the BEGIN gone out before
        % the evaluation, a stop inside it would have put every reply
        % served at the K>> prompt between this request's BEGIN and its
        % output.
        S.begin(req.id);
        S.sendText(txt);
        S.done(req.id, status);
        % busy stays set: the mark() queued behind this call clears it.
        % Cleared here, a timer tick between the two could take a run
        % that just ended for one that left the debugger on its own.
        S.quiet = tic;
    end

    function mark(S)
    %MARK  Runs at the first prompt after a debugger command. A debug
    %   prompt means the code stopped again: report where. A plain prompt
    %   means it ran to the end, in which case next() has already replied,
    %   or was thrown away by dbquit, in which case it has not.
        S.busy = false;
        try
            S.markInner();
        catch failed
            disp(sprintf('server: mark failed: %s', failed.message));
            S.busy = false;
        end
        S.quiet = tic;
    end

    function markInner(S)
        if vimserver.debugging()
            if strcmp(S.expect, 'next')
                % After a request: a stop is news when nothing was known
                % to be stopped (the request itself hit a breakpoint, and
                % mark() got here before the timer looked), or when the
                % stack is not the one last reported (a breakpoint hit by
                % a request evaluated at a K>> prompt). The same stack
                % with the session already reported stopped means the
                % request ran and ended at the prompt it was given.
                if ~S.stopped || ~strcmp(S.signature(), S.lastsig)
                    S.stopped = true;
                    S.frame = 1;
                    if ~S.skipStop()
                        S.reportStop();
                    end
                end
                return
            end
            S.stopped = true;
            switch S.lastdbg
                case 'dbup'
                    S.frame = S.frame + 1;
                case 'dbdown'
                    S.frame = S.frame - 1;
                otherwise
                    S.frame = 1;
            end
            if S.skipStop()
                return
            end
            S.reportStop();
        else
            S.stopped = false;
            S.frame = 1;
            S.lastsig = '';
            for k = numel(S.inflight):-1:1
                S.begin(S.inflight{k});
                S.send('the run was abandoned');
                S.done(S.inflight{k}, 2);
            end
            S.inflight = {};
        end
    end

    % -------------------------------------------------------- the reply

    function send(S, text)
    %SEND  One line, ending in a bare newline, not the platform separator:
    %   on Windows a carriage return rode along into Vim's quickfix entries.
        if isempty(S.client)
            return
        end
        bytes = unicode2native([text char(10)], 'UTF-8');
        jb = java.nio.ByteBuffer.wrap(typecast(bytes, 'int8'));
        S.sending = true;
        try
            % A non-blocking write may take only part of the line when the
            % client is slow to read; try again for a while before
            % deciding it has gone.
            stalled = 0;
            while jb.hasRemaining()
                if S.client.write(jb) == 0
                    stalled = stalled + 1;
                    if stalled > 400
                        error('vimserver:stalled', 'client not reading');
                    end
                    pause(0.005);
                end
            end
        catch
            S.hangup();
        end
        S.sending = false;
    end

    function sendText(S, txt)
        txt = regexprep(txt, '\r\n?', '\n');
        % Strip anything hotlinks left behind, plus the backspaces Matlab
        % pads warning text with for terminal rendering. help() called
        % from a captured command also wraps the function name in <strong>.
        txt = regexprep(txt, '</?(a|strong|b)(\s[^>]*)?>', '');
        txt = strrep(txt, char(8), '');
        if isempty(txt)
            return
        end
        % CollapseDelimiters is on by default and would fold the blank
        % lines out of the output.
        for piece = strsplit(txt, '\n', 'CollapseDelimiters', false)
            S.send(piece{1});
        end
    end

    function begin(S, id)
        S.send(sprintf('%s %s', vimserver.BEGIN, id));
    end

    function done(S, id, status)
        S.send(sprintf('%s %s %d', vimserver.SENTINEL, id, status));
    end

    function sig = signature(S)
    %SIGNATURE  The stack as one string, to compare two looks at it.
        f = S.frames();
        sig = strjoin(arrayfun(@(x) sprintf('%s:%d', x.file, x.line), f, 'UniformOutput', false), '|');
    end

    function tf = skipStop(S)
    %SKIPSTOP  A stop that is not the user's to see, stepped past rather
    %   than reported: true when a command went to the prompt for it.
    %
    %   Stepping off the last line of a script leaves Matlab stopped at
    %   "End of script", where the script's frame reports a negative line
    %   number; one more step lands in the caller. Stepping off the last
    %   line of the outermost user frame lands in next(), this file, the
    %   plumbing that ran it; there is nothing left to see, and the run is
    %   let finish.
        tf = false;
        f = S.frames();
        if isempty(f)
            cmd = 'dbcont';
        elseif f(1).line <= 0
            cmd = 'dbstep';
        else
            return
        end
        S.lastdbg = cmd;
        S.expect = 'dbg';
        S.busy = true;
        vimserver.prompt(cmd);
        vimserver.prompt('vimserver.instance().mark();');
        tf = true;
    end

    function reportStop(S)
        S.lastsig = S.signature();
        for f = S.frames()
            S.send(sprintf('%s %d\t%s\t%s', vimserver.FRAME, f.line, f.name, f.file));
        end
        id = '-';
        if ~isempty(S.inflight)
            id = S.inflight{end};
        end
        S.send(sprintf('%s stopped %d %s', vimserver.EVENT, S.frame, id));
    end

    function txt = appendError(S, txt, caught)
    %APPENDERROR  Report an error as "file:line: message", the shape
    %   compiler/matlab.vim gives Vim's errorformat, so :make drops it
    %   straight into the quickfix list.
        frames = caught.stack;
        if ~isempty(frames)
            % evalin, evalc and this file would be in the stack: plumbing.
            keep = arrayfun(@(f) ~isempty(f.file) && ~strcmpi(f.file, S.here), frames);
            frames = frames(keep);
        end
        % One line only: errorformat's %m stops at the end of the line,
        % and \s covers the newlines a multi-line message carries. A parse
        % error's message already opens with "Error: ", which the line
        % below adds again.
        msg = strtrim(regexprep(caught.message, '\s+', ' '));
        % Parse errors carry an opentoline hotlink around the position
        % even with hotlinks off; drop the markup before reading it.
        msg = regexprep(msg, '</?a[^>]*>', '');
        msg = regexprep(msg, '^Error:\s*', '');
        % A parse error has no stack; its position is in the message, as
        % "File: name.m Line: 2 Column: 5". The name is relative to the
        % directory the command cd'd into, so resolve it here where that
        % directory is current.
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
    end

    % ------------------------------------------------------ the debugger

    function f = frames(S)
    %FRAMES  The user's frames, innermost first: the stack minus the timer
    %   and this file. Works from the timer (where the stopped code sits
    %   below timercb) and from the prompt (where it sits below next()).
        st = dbstack('-completenames');
        k = find(strcmp({st.name}, 'timercb'), 1, 'last');
        if ~isempty(k)
            st = st(k+1:end);
        end
        keep = arrayfun(@(s) ~isempty(s.file) && ~strcmpi(s.file, S.here), st);
        f = st(keep);
        if isempty(f)
            f = struct('file', {}, 'name', {}, 'line', {});
        end
        f = reshape(f, 1, []);
    end

    function [txt, status] = breakpoint(S, text, set)
    %BREAKPOINT  Set or clear one, then list the file's breakpoints as
    %   Matlab has them, since it moves a breakpoint on a comment or a
    %   blank line to the next line that runs.
        status = 0;
        parts = strsplit(text, sprintf('\t'));
        file = strtrim(parts{1});
        line = '';
        if numel(parts) > 1
            line = strtrim(parts{2});
        end
        try
            if set
                if numel(parts) > 2 && ~isempty(strtrim(parts{3}))
                    dbstop('in', file, 'at', line, 'if', strtrim(parts{3}));
                else
                    dbstop('in', file, 'at', line);
                end
            elseif isempty(file)
                dbclear('all');
            elseif isempty(line)
                dbclear('in', file);
            else
                dbclear('in', file, 'at', line);
            end
        catch e
            txt = regexprep(e.message, '\s+', ' ');
            status = 1;
            return
        end
        txt = S.listBreakpoints(file);
    end

    function txt = listBreakpoints(~, file)
        lines = {};
        if ~isempty(file)
            st = dbstatus('-completenames');
            % Vim may spell the path with forward slashes; Matlab reports
            % it with backslashes.
            for s = reshape(st, 1, [])
                if ~strcmpi(strrep(s.file, '\', '/'), strrep(file, '\', '/'))
                    continue
                end
                for k = 1:numel(s.line)
                    cond = '';
                    if numel(s.expression) >= k
                        cond = s.expression{k};
                    end
                    lines{end+1} = sprintf('%d\t%s', s.line(k), cond); %#ok<AGROW>
                end
            end
        end
        txt = strjoin(lines, newline);
    end
end

methods (Static)
    function txt = formatVariables(w)
    %FORMATVARIABLES  One "name\tsize\tclass\tvalue" per variable, from
    %   what the desktop's workspace browser shows (Name, Size, Class,
    %   Value) or, failing that, from whos (name, size, class).
        lines = {};
        for k = 1:numel(w)
            if isfield(w, 'Name')
                v = regexprep(char(string(w(k).Value)), '\s+', ' ');
                % The size comes with a multiplication sign; x reads the
                % same and survives any font.
                sz = strrep(char(string(w(k).Size)), char(215), 'x');
                lines{end+1} = sprintf('%s\t%s\t%s\t%s', w(k).Name, sz, w(k).Class, strtrim(v)); %#ok<AGROW>
            else
                sz = strjoin(arrayfun(@num2str, w(k).size, 'UniformOutput', false), 'x');
                lines{end+1} = sprintf('%s\t%s\t%s\t', w(k).name, sz, w(k).class); %#ok<AGROW>
            end
        end
        txt = strjoin(lines, newline);
    end
end
end
