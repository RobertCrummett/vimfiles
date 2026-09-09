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
    if isKey(seen, lower(name))
        fid = fopen(target, 'a', 'n', 'UTF-8');
        fprintf(fid, '\n%s\n', repmat('-', 1, 70));
    else
        fid = fopen(target, 'w', 'n', 'UTF-8');
        seen(lower(name)) = true;
    end
    if fid < 0
        continue
    end
    fprintf(fid, '%s', s);
    fclose(fid);
    written = written + 1;
    if mod(k, 250) == 0
        fprintf('  %d/%d (%.0f s)\n', k, numel(names), toc(t));
    end
end

fid = fopen(fullfile(outDir, '.stamp'), 'w', 'n', 'UTF-8');
fprintf(fid, 'matlabroot %s\nversion %s\nnames %d\nbuilt %s\n', ...
    matlabroot, version, written, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fclose(fid);

fprintf('build_index: wrote %d files to %s in %.0f s\n', written, outDir, toc(t));
end
