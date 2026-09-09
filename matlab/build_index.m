function build_index(outDir)
%BUILD_INDEX  Write Matlab's help text to one file per function name.
%
%   Vim's matlabdoc plugin reads these files directly, so looking a function
%   up costs a file read instead of the five seconds Matlab needs to start.
%   Run it from Vim with :MatlabDocIndex, or by hand:
%
%       matlab -batch "build_index('index')"
%
%   The names come from matlabroot/help/matlab/helpfuncbycat.xml, which lists
%   every documented function. Operators (+, .*, ==) and multi-word entries
%   ("App Designer") are skipped: they are not words you can put the cursor
%   on. Files are named after the lowercased function, because Windows
%   filenames are case insensitive; the six names that collide that way
%   (Combine/combine, Feval/feval, ...) share a file and both entries are
%   written into it.

if nargin < 1
    outDir = 'index';
end
if ~isfolder(outDir)
    mkdir(outDir);
end

warning('off', 'all');

xmlFile = fullfile(matlabroot, 'help', 'matlab', 'helpfuncbycat.xml');
txt = fileread(xmlFile);
tok = regexp(txt, '<name>(.*?)</name>', 'tokens');
names = unique(cellfun(@(c) c{1}, tok, 'UniformOutput', false));
names = names(~cellfun(@isempty, regexp(names, '^[A-Za-z]\w*$', 'once')));

fprintf('build_index: %d names from %s\n', numel(names), xmlFile);
t = tic;
written = 0;
seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for k = 1:numel(names)
    name = names{k};
    try
        s = help(name);
    catch
        continue
    end
    if isempty(strtrim(s))
        continue
    end
    target = fullfile(outDir, [lower(name) '.txt']);
    % A name whose file is already there is one of the pairs that differ only
    % in case, so this entry is appended after a rule rather than replacing
    % the first. The handle is checked before anything is written to it:
    % fprintf on a failed fopen raises, which would end the build.
    %
    % Nothing here may be named after a documented function: a variable
    % shadows one, and help() then answers "x is a variable of type ..."
    % instead of the help text, quietly ruining that one entry.
    collides = isKey(seen, lower(name));
    if collides
        fid = fopen(target, 'a', 'n', 'UTF-8');
    else
        fid = fopen(target, 'w', 'n', 'UTF-8');
    end
    if fid < 0
        continue
    end
    if collides
        fprintf(fid, '\n%s\n', repmat('-', 1, 70));
    else
        seen(lower(name)) = true;
    end
    fprintf(fid, '%s', s);
    fclose(fid);
    written = written + 1;
    if mod(k, 250) == 0
        fprintf('  %d/%d (%.0f s)\n', k, numel(names), toc(t));
    end
end

% datetime rather than datestr(now): datestr is the one MathWorks marks not
% recommended, and warnings are off here, so the day it goes it would raise
% instead - after the whole index had been written, leaving it with no stamp
% and :MatlabDocStatus reporting no index at all.
fid = fopen(fullfile(outDir, '.stamp'), 'w', 'n', 'UTF-8');
fprintf(fid, 'matlabroot %s\nversion %s\nnames %d\nbuilt %s\n', ...
    matlabroot, version, written, ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fclose(fid);

fprintf('build_index: wrote %d files to %s in %.0f s\n', written, outDir, toc(t));
end
