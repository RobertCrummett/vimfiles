" A server started from Vim should not outlive it. When Vim exits normally
" it terminates its jobs, and on Windows that reaches the whole process tree
" through the job object. When Vim is killed or crashes nothing does, and a
" llama-server holding the GPU or a Matlab session holding the port and
" several hundred megabytes stays behind. So the command is run under a
" small watchdog that waits for either Vim or the server to end and then
" kills the other. Used by autoload/llm.vim and autoload/matlabserver.vim.

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
function! watchdog#wrap(cmd) abort
  let l:pid = getpid()
  if has('win32')
    " taskkill /T rather than Stop-Process: Matlab's matlab.exe is a
    " launcher whose real work is a child MATLAB.exe, and killing the
    " launcher alone leaves that child running.
    let l:script = '$p = Start-Process -PassThru -NoNewWindow -FilePath ' . s:psq(a:cmd[0])
      \ . ' -ArgumentList @(' . join(map(a:cmd[1:], 's:psarg(v:val)'), ',') . ');'
      \ . ' while (-not $p.HasExited -and (Get-Process -Id ' . l:pid . ' -ErrorAction SilentlyContinue)) { Start-Sleep -Milliseconds 500 };'
      \ . ' if (-not $p.HasExited) { taskkill /T /F /PID $p.Id | Out-Null };'
      \ . ' $p.WaitForExit(); exit $p.ExitCode'
    return ['powershell', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', l:script]
  endif
  let l:script = '"$0" "$@" & c=$!; trap "kill $c 2>/dev/null" EXIT TERM INT;'
    \ . ' while kill -0 ' . l:pid . ' 2>/dev/null && kill -0 $c 2>/dev/null; do sleep 1; done;'
    \ . ' wait $c'
  return ['sh', '-c', l:script] + a:cmd
endfunction
