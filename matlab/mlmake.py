"""Run a Matlab file in the session matlabserver keeps warm, for :make.

:make runs 'makeprg' through the shell, so it needs a program to run; it
cannot speak to the socket itself. This is that program. It connects to the
session, asks it to run the file, prints whatever Matlab printed, and exits
non-zero if the file raised, so :make reports a failure.

Errors arrive already shaped as "file:line: message" by matlab/server.m, which
is what compiler/matlab.vim teaches Vim's errorformat to read, so they land in
the quickfix list without any parsing here.

    python mlmake.py <file.m> [port]

The port defaults to $MATLABSERVER_PORT, then 51763. Starting the session is
Vim's job, not this script's: a Matlab left running by a subprocess would
outlive Vim with nothing owning it. plugin/matlabserver.vim starts one before
:make runs.
"""

import os
import socket
import sys

SENTINEL = "--MATLABSERVER-DONE--"


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("mlmake: no file given\n")
        return 2
    path = os.path.abspath(argv[1])
    if not os.path.exists(path):
        sys.stderr.write("mlmake: no such file: %s\n" % path)
        return 2
    port = int(argv[2]) if len(argv) > 2 else int(os.environ.get("MATLABSERVER_PORT") or 51763)

    try:
        sock = socket.create_connection(("127.0.0.1", port), timeout=5)
    except OSError as exc:
        sys.stderr.write(
            "mlmake: no Matlab session on port %d (%s); run :MatlabStart\n" % (port, exc)
        )
        return 2

    # The connect timeout must not become a read timeout: the script being run
    # may take as long as it likes.
    sock.settimeout(None)
    stream = sock.makefile("rw", encoding="utf-8", newline="\n")

    folder = os.path.dirname(path).replace("'", "''")
    name = os.path.splitext(os.path.basename(path))[0]
    stream.write("cd('%s'); %s\n" % (folder, name))
    stream.flush()

    status = 0
    try:
        for line in stream:
            line = line.rstrip("\r\n")
            if line.startswith(SENTINEL):
                tail = line[len(SENTINEL):].strip()
                status = int(tail) if tail.isdigit() else 0
                break
            print(line)
        else:
            sys.stderr.write("mlmake: the Matlab session closed the connection\n")
            return 2
    finally:
        stream.close()
        sock.close()

    return 1 if status else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
