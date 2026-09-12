" A server started from Vim should not outlive it. When Vim exits normally
" it terminates its jobs, and on Windows that reaches the whole process tree
" through the job object. When Vim is killed or crashes nothing does, and a
" llama-server holding the GPU or a Matlab session holding the port and
" several hundred megabytes stays behind. So the command is run under a
" small watchdog that waits for either Vim or the server to end and then
" kills the other. Used by autoload/llm.vim and autoload/matlabserver.vim.
"
" Two extras, both optional and both for the Matlab session:
"
"   hide    On Windows, hide the main window of the started process and of
"           its children once one appears. Matlab without its desktop still
"           opens a command window; minimized it is a taskbar entry, hidden
"           it is nothing.
"   quit    [host, port, line]: before killing the tree, connect to that
"           port and send that line, then give the process five seconds to
"           leave by itself. Killing Matlab outright brings up its crash
"           reporter; asking it to exit does not.

" PowerShell single-quoted literal.
function! s:psq(s) abort
  return "'" . substitute(a:s, "'", "''", 'g') . "'"
endfunction

" One element of Start-Process -ArgumentList. PowerShell joins the list
" with spaces and adds no quoting of its own, so an argument with a space
" in it (a model under "C:\Users\Some Name\...") has to carry its own
" double quotes for the program to see it as one argument.
function! s:psarg(s) abort
  return s:psq(a:s =~# '\s' ? '"' . a:s . '"' : a:s)
endfunction

" The command list to give job_start() so that cmd runs under the
" watchdog. Stdout and stderr of cmd are the job's own, and the job exits
" with cmd's exit status, so callbacks see the server, not the wrapper.
function! watchdog#wrap(cmd, ...) abort
  let l:opts = a:0 ? a:1 : {}
  let l:pid = getpid()
  let l:quit = get(l:opts, 'quit', [])
  if has('win32')
    let l:hide = get(l:opts, 'hide', 0)
    let l:script = '$p = Start-Process -PassThru -NoNewWindow -FilePath ' . s:psq(a:cmd[0])
      \ . ' -ArgumentList @(' . join(map(a:cmd[1:], 's:psarg(v:val)'), ',') . ');'
    if l:hide
      " ShowWindow(handle, 0) is SW_HIDE. Checked every two seconds for
      " the first ten minutes, over the whole process tree: Matlab's
      " matlab.exe is a launcher, its child MATLAB.exe is a broker, and the
      " window belongs to a grandchild MATLAB.exe. Only processes in this
      " tree are touched, so a Matlab desktop you open yourself keeps its
      " window.
      let l:script .= ' Add-Type -Namespace W -Name U -MemberDefinition'
        \ . " '[DllImport(\"user32.dll\")] public static extern bool ShowWindow(IntPtr h, int n);';"
        \ . ' $n = 0;'
    endif
    let l:script .= ' while (-not $p.HasExited -and (Get-Process -Id ' . l:pid . ' -ErrorAction SilentlyContinue)) {'
      \ . ' Start-Sleep -Milliseconds 500;'
    if l:hide
      " Not stopped at the first window found: the launcher can show one
      " before the grandchild that owns the command window exists.
      let l:script .= ' if ($n -lt 1200) { $n++; if ($n % 4 -eq 0) {'
        \ . ' $ids = @($p.Id); $more = @($p.Id);'
        \ . ' while ($more.Count -gt 0) { $more = @(Get-CimInstance Win32_Process -Filter ((''ParentProcessId = '' + ($more -join '' OR ParentProcessId = ''))) | ForEach-Object { $_.ProcessId }); $ids += $more };'
        \ . ' foreach ($id in $ids) { $q = Get-Process -Id $id -ErrorAction SilentlyContinue;'
        \ . ' if ($q -and $q.MainWindowHandle -ne 0) { [W.U]::ShowWindow($q.MainWindowHandle, 0) | Out-Null } } } }'
    endif
    let l:script .= ' };'
      \ . ' if (-not $p.HasExited) {'
    if !empty(l:quit)
      let l:script .= ' try { $c = New-Object Net.Sockets.TcpClient(' . s:psq(l:quit[0]) . ', ' . l:quit[1] . ');'
        \ . ' $s = $c.GetStream(); $b = [Text.Encoding]::UTF8.GetBytes(' . s:psq(l:quit[2]) . ' + [char]10);'
        \ . ' $s.Write($b, 0, $b.Length); $s.Flush(); $c.Close() } catch {};'
        \ . ' $p.WaitForExit(5000) | Out-Null;'
    endif
    " taskkill /T rather than Stop-Process: the launcher alone dying
    " leaves the child MATLAB.exe running.
    let l:script .= ' if (-not $p.HasExited) { taskkill /T /F /PID $p.Id | Out-Null } };'
      \ . ' $p.WaitForExit(); exit $p.ExitCode'
    return ['powershell', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', l:script]
  endif
  let l:script = '"$0" "$@" & c=$!; trap "kill $c 2>/dev/null" EXIT TERM INT;'
    \ . ' while kill -0 ' . l:pid . ' 2>/dev/null && kill -0 $c 2>/dev/null; do sleep 1; done;'
  if !empty(l:quit)
    let l:script .= ' if kill -0 $c 2>/dev/null; then'
      \ . ' (printf ''%s\n'' ' . shellescape(l:quit[2]) . ' > /dev/tcp/' . l:quit[0] . '/' . l:quit[1] . ') 2>/dev/null;'
      \ . ' for i in 1 2 3 4 5; do kill -0 $c 2>/dev/null || break; sleep 1; done; fi;'
  endif
  let l:script .= ' wait $c'
  return ['sh', '-c', l:script] + a:cmd
endfunction
