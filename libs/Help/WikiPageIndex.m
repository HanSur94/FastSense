classdef WikiPageIndex
%WIKIPAGEINDEX Pure-logic directory index and search for wiki/*.md pages.
%
%   Static helper for the Wiki Browser (Phase 1034). Owns NO UI handles —
%   every method is a stateless function so it can be unit-tested headless
%   and runs unchanged on GNU Octave.
%
%   Phase 1034 splits the Wiki Browser into a pure-logic layer (this class)
%   and a UI layer (WikiBrowser, Plan 04). All directory enumeration, H1
%   title extraction, TOC grouping, page resolution with Home.md fallback,
%   full-text substring search, and the generator-collision guard live
%   here. The UI layer calls these statics; the tests in
%   tests/test_wiki_page_index.m exercise them headless.
%
%   Methods (Static):
%     listPages(wikiDir)                      — struct array of pages
%     buildToc(wikiDir)                       — grouped struct array for sidebar
%     readPage(wikiDir, pageName)             — load page body with Home.md fallback
%     search(wikiDir, query)                  — full-text substring search, ranked
%     collidesWithGenerator(wikiDir, names)   — guard vs scripts/generate_wiki.py PAGE_MAP
%
%   Conventions:
%     - Pure char arrays throughout (no `string` class) for Octave parity.
%     - regexp(... 'split') is used in place of strsplit for the
%       MarkdownRenderer-proven Octave-compatible line splitter idiom.
%     - Error IDs follow the namespace 'WikiPageIndex:invalidWikiDir',
%       'WikiPageIndex:pageReadError'.
%
%   Example:
%     files = WikiPageIndex.listPages('wiki');
%     toc   = WikiPageIndex.buildToc('wiki');
%     [md, path, found] = WikiPageIndex.readPage('wiki', 'Home');
%     hits  = WikiPageIndex.search('wiki', 'FastPlot');
%     dup   = WikiPageIndex.collidesWithGenerator('wiki', {'Home.md'});
%
%   See also MarkdownRenderer, WikiBrowser (Phase 1034 Plan 04).

    methods (Static)
        function files = listPages(wikiDir)
            %LISTPAGES Enumerate wiki/*.md files into a struct array.
            %   files = WikiPageIndex.listPages(wikiDir) returns a struct
            %   array with one entry per .md file in wikiDir. Each entry
            %   has fields:
            %     .filename  char — e.g. 'Home.md'
            %     .pageName  char — filename with .md stripped
            %     .title     char — H1 line if present, else pageName
            %     .path      char — full absolute path
            %     .group     char — 'API Reference' / 'Sidebar' / 'Pages'
            %
            %   Returns an empty 0x0 struct when wikiDir contains no .md
            %   files. Throws 'WikiPageIndex:invalidWikiDir' if wikiDir
            %   does not exist.

            if nargin < 1 || isempty(wikiDir) || ~ischar(wikiDir)
                error('WikiPageIndex:invalidWikiDir', ...
                    'wikiDir must be a non-empty char path to the wiki directory.');
            end
            if ~exist(wikiDir, 'dir')
                error('WikiPageIndex:invalidWikiDir', ...
                    'wiki directory not found: %s', wikiDir);
            end

            listing = dir(fullfile(wikiDir, '*.md'));
            % Initialise empty struct with the canonical field order so
            % that downstream concat (e.g. buildToc partitioning) never
            % triggers "different fields" errors on Octave.
            files = repmat(struct( ...
                'filename', '', ...
                'pageName', '', ...
                'title',    '', ...
                'path',     '', ...
                'group',    ''), 0, 0);
            for k = 1:numel(listing)
                entry = listing(k);
                if entry.isdir
                    continue;
                end
                filename = entry.name;
                pageName = regexprep(filename, '\.md$', '');
                fullPath = fullfile(wikiDir, filename);

                if strcmpi(filename, '_Sidebar.md')
                    grp = 'Sidebar';
                elseif numel(filename) >= numel('API-Reference:-') && ...
                        strncmp(filename, 'API-Reference:-', numel('API-Reference:-'))
                    grp = 'API Reference';
                else
                    grp = 'Pages';
                end

                mdText = '';
                try
                    mdText = fileread(fullPath);
                catch
                    % fileread can fail on permission issues — title
                    % falls back to pageName silently below.
                end
                title = WikiPageIndex.extractH1_(mdText, pageName);

                files(end+1) = struct( ...
                    'filename', filename, ...
                    'pageName', pageName, ...
                    'title',    title, ...
                    'path',     fullPath, ...
                    'group',    grp); %#ok<AGROW>
            end
        end

        function toc = buildToc(wikiDir)
            %BUILDTOC Build a grouped Table-of-Contents for the sidebar.
            %   toc = WikiPageIndex.buildToc(wikiDir) returns a 1x2 struct
            %   array with fields:
            %     .group    char         — 'Pages' or 'API Reference'
            %     .entries  struct array — same shape as listPages output
            %
            %   Ordering: 'Pages' first, then 'API Reference'. Within each
            %   group: alphabetical by .pageName (case-insensitive).
            %   '_Sidebar.md' is filtered out.

            files = WikiPageIndex.listPages(wikiDir);

            % Filter out the Sidebar group — it's a TOC config artefact,
            % not a navigable page.
            keepMask = false(1, numel(files));
            for k = 1:numel(files)
                keepMask(k) = ~strcmp(files(k).group, 'Sidebar');
            end
            files = files(keepMask);

            % Partition into the two ordered groups.
            pagesMask = false(1, numel(files));
            apiMask   = false(1, numel(files));
            for k = 1:numel(files)
                switch files(k).group
                    case 'Pages'
                        pagesMask(k) = true;
                    case 'API Reference'
                        apiMask(k) = true;
                end
            end
            pagesEntries = WikiPageIndex.sortByPageName_(files(pagesMask));
            apiEntries   = WikiPageIndex.sortByPageName_(files(apiMask));

            % Construct the 1x2 grouped struct array with deterministic
            % field order. Using cell-form struct() so the empty groups
            % carry the same fields as populated ones.
            toc = struct( ...
                'group',   {'Pages', 'API Reference'}, ...
                'entries', {pagesEntries, apiEntries});
        end

        function [mdText, resolvedPath, found] = readPage(wikiDir, pageName)
            %READPAGE Read a wiki page body with Home.md fallback.
            %   [mdText, resolvedPath, found] = WikiPageIndex.readPage(...)
            %   loads a .md file from wikiDir. pageName may include or
            %   omit the .md suffix. If the requested page is missing,
            %   silently falls back to Home.md; if Home.md is also
            %   missing, returns mdText='', resolvedPath='', found=false.
            %   Never throws — file-read errors are caught and reported
            %   as found=false so callers can render a "page not found"
            %   notice instead of a crash.

            mdText = '';
            resolvedPath = '';
            found = false;

            if nargin < 2 || isempty(pageName) || ~ischar(pageName)
                % Empty page name immediately tries Home.md fallback.
                [mdText, resolvedPath, found] = WikiPageIndex.readHome_(wikiDir);
                return;
            end

            % Tolerate both 'Home' and 'Home.md' input forms.
            baseName = regexprep(pageName, '\.md$', '');
            candidate = fullfile(wikiDir, [baseName '.md']);

            if exist(candidate, 'file') == 2
                try
                    mdText = fileread(candidate);
                    resolvedPath = candidate;
                    found = true;
                    return;
                catch
                    % Fall through to Home fallback on read error.
                    mdText = '';
                    resolvedPath = '';
                    found = false;
                end
            end

            % Page missing or unreadable — try Home.md.
            [mdText, resolvedPath, found] = WikiPageIndex.readHome_(wikiDir);
        end

        function hits = search(wikiDir, query)
            %SEARCH Full-text substring search across wiki/*.md.
            %   hits = WikiPageIndex.search(wikiDir, query) returns a
            %   struct array sorted by score DESC. Empty/whitespace
            %   query returns an empty struct.
            %
            %   Scoring: title match weighted 10x, body match 1x.
            %   Each is a count of case-insensitive substring matches.
            %
            %   Fields per hit:
            %     .pageName, .title, .filename, .path  (from listPages)
            %     .score    double — 10*titleMatches + bodyMatches
            %     .excerpt  char   — first matching body line, <=120 chars

            hits = struct( ...
                'pageName', {}, ...
                'title',    {}, ...
                'filename', {}, ...
                'path',     {}, ...
                'score',    {}, ...
                'excerpt',  {});

            if nargin < 2 || isempty(query) || ~ischar(query)
                return;
            end
            q = strtrim(query);
            if isempty(q)
                return;
            end

            qLower = lower(q);
            files = WikiPageIndex.listPages(wikiDir);

            % Skip the Sidebar entry; it is not a navigable page so it
            % shouldn't pollute the result list.
            keepMask = false(1, numel(files));
            for k = 1:numel(files)
                keepMask(k) = ~strcmp(files(k).group, 'Sidebar');
            end
            files = files(keepMask);

            for k = 1:numel(files)
                f = files(k);
                titleMatches = WikiPageIndex.countSubstring_(lower(f.title), qLower);

                mdText = '';
                try
                    mdText = fileread(f.path);
                catch
                    % Skip unreadable files.
                    continue;
                end

                lines = regexp(mdText, '\n', 'split');
                bodyMatches = 0;
                excerpt = '';
                for li = 1:numel(lines)
                    line = lines{li};
                    n = WikiPageIndex.countSubstring_(lower(line), qLower);
                    if n > 0
                        bodyMatches = bodyMatches + n;
                        if isempty(excerpt)
                            excerpt = WikiPageIndex.trimExcerpt_(line, 120);
                        end
                    end
                end

                score = 10 * titleMatches + bodyMatches;
                if score <= 0
                    continue;
                end

                hits(end+1) = struct( ...
                    'pageName', f.pageName, ...
                    'title',    f.title, ...
                    'filename', f.filename, ...
                    'path',     f.path, ...
                    'score',    score, ...
                    'excerpt',  excerpt); %#ok<AGROW>
            end

            if isempty(hits)
                return;
            end

            % Sort by score DESC, tie-break alphabetical (case-insensitive)
            % by .pageName ASC so the test fixture is deterministic.
            % Stable sort: first by pageName ASC, then by score DESC
            % (later key dominates the stable secondary sort).
            pageNamesLower = lower({hits.pageName});
            [~, idx1] = sort(pageNamesLower);
            hits = hits(idx1);
            [~, idx2] = sort([hits.score], 'descend');
            hits = hits(idx2);
        end

        function collisions = collidesWithGenerator(wikiDir, reservedFilenames)
            %COLLIDESWITHGENERATOR Detect hand-written pages that share a
            %   filename with scripts/generate_wiki.py PAGE_MAP entries.
            %
            %   collisions = WikiPageIndex.collidesWithGenerator(wikiDir, names)
            %   returns a cell array of filenames in `names` that:
            %     1. Exist as files in wikiDir, AND
            %     2. ARE marked auto-generated (first non-empty line
            %        starts with '<!-- AUTO-GENERATED').
            %
            %   Per CONTEXT.md D-05: the generator already owns this
            %   slot and will silently overwrite anything placed at the
            %   same filename. A hand-written file at the same path
            %   would be lost on the next generator run. Auto-generated
            %   slots flagged here are reservations — Plan 02's
            %   hand-written content must adopt distinct filenames.
            %   Missing files are not flagged.

            collisions = {};
            if nargin < 2 || isempty(reservedFilenames)
                return;
            end
            if ~iscell(reservedFilenames)
                error('WikiPageIndex:invalidReservedFilenames', ...
                    'reservedFilenames must be a cell array of char.');
            end

            for k = 1:numel(reservedFilenames)
                name = reservedFilenames{k};
                if ~ischar(name) || isempty(name)
                    continue;
                end
                fullPath = fullfile(wikiDir, name);
                if exist(fullPath, 'file') ~= 2
                    continue;
                end
                try
                    mdText = fileread(fullPath);
                catch
                    continue;
                end
                if WikiPageIndex.isAutoGenerated_(mdText)
                    collisions{end+1} = name; %#ok<AGROW>
                end
            end
        end
    end

    methods (Static, Access = private)
        function title = extractH1_(mdText, defaultName)
            %EXTRACTH1_ Extract first H1 heading from markdown body.
            %   title = WikiPageIndex.extractH1_(mdText, defaultName)
            %   returns the captured text of the first '^# heading' line.
            %   Falls back to defaultName when no H1 is present.
            title = defaultName;
            if isempty(mdText) || ~ischar(mdText)
                return;
            end
            % Constrain the H1 capture to a single line — use [^\n]+ rather
            % than '.+' because Octave's regexp engine treats '.' as
            % "match newline too" even with 'lineanchors', which would
            % capture the whole file into the title.
            tok = regexp(mdText, '^#\s+([^\n]+)', 'tokens', 'lineanchors', 'once');
            if isempty(tok)
                return;
            end
            raw = tok{1};
            % Strip trailing whitespace and any trailing '#' chars (some
            % markdown flavors allow '# Title #').
            raw = regexprep(raw, '\s+#+\s*$', '');
            raw = strtrim(raw);
            if isempty(raw)
                return;
            end
            title = raw;
        end

        function tf = isAutoGenerated_(mdText)
            %ISAUTOGENERATED_ Detect AUTO-GENERATED marker in first line.
            %   tf = WikiPageIndex.isAutoGenerated_(mdText) returns true
            %   iff the first non-empty line starts with the literal
            %   '<!-- AUTO-GENERATED' (D-03 informational marker).
            tf = false;
            if isempty(mdText) || ~ischar(mdText)
                return;
            end
            lines = regexp(mdText, '\n', 'split');
            for li = 1:numel(lines)
                line = strtrim(lines{li});
                if isempty(line)
                    continue;
                end
                marker = '<!-- AUTO-GENERATED';
                if numel(line) >= numel(marker) && ...
                        strncmp(line, marker, numel(marker))
                    tf = true;
                end
                return;
            end
        end

        function [mdText, resolvedPath, found] = readHome_(wikiDir)
            %READHOME_ Internal Home.md fallback for readPage.
            mdText = '';
            resolvedPath = '';
            found = false;
            homePath = fullfile(wikiDir, 'Home.md');
            if exist(homePath, 'file') ~= 2
                return;
            end
            try
                mdText = fileread(homePath);
                resolvedPath = homePath;
                found = true;
            catch
                mdText = '';
                resolvedPath = '';
                found = false;
            end
        end

        function sorted = sortByPageName_(entries)
            %SORTBYPAGENAME_ Stable case-insensitive sort by .pageName.
            if isempty(entries)
                sorted = entries;
                return;
            end
            names = lower({entries.pageName});
            [~, idx] = sort(names);
            sorted = entries(idx);
        end

        function n = countSubstring_(haystack, needle)
            %COUNTSUBSTRING_ Count non-overlapping occurrences of needle.
            %   Both inputs assumed lowercase char. Empty needle returns 0.
            n = 0;
            if isempty(needle) || isempty(haystack)
                return;
            end
            positions = strfind(haystack, needle);
            n = numel(positions);
        end

        function out = trimExcerpt_(line, maxLen)
            %TRIMEXCERPT_ Trim a body line to <=maxLen chars with ellipsis.
            %   ASCII '...' chosen over the Unicode HORIZONTAL ELLIPSIS
            %   (U+2026, char(8230)) because Octave clips that codepoint
            %   to a single byte and emits a range-conversion warning —
            %   ASCII keeps the excerpt readable on both runtimes.
            line = strtrim(line);
            if numel(line) <= maxLen
                out = line;
                return;
            end
            out = [line(1:maxLen) '...'];
        end
    end
end
