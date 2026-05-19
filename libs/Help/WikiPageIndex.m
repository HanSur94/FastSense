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
            files = struct([]);  % implementation in Task 1.2
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
            toc = struct('group', {}, 'entries', {});  % implementation in Task 1.2
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
            mdText = '';           % implementation in Task 1.2
            resolvedPath = '';
            found = false;
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
            hits = struct([]);  % implementation in Task 1.2
        end

        function collisions = collidesWithGenerator(wikiDir, reservedFilenames)
            %COLLIDESWITHGENERATOR Detect hand-written pages that share a
            %   filename with scripts/generate_wiki.py PAGE_MAP entries.
            %
            %   collisions = WikiPageIndex.collidesWithGenerator(wikiDir, names)
            %   returns a cell array of filenames in `names` that:
            %     1. Exist as files in wikiDir, AND
            %     2. Are NOT marked auto-generated (first non-empty line
            %        does NOT start with '<!-- AUTO-GENERATED').
            %
            %   Per CONTEXT.md D-05: a collision means a hand-written
            %   page will be silently overwritten on the next generator
            %   run. Auto-generated files in the slot are not flagged —
            %   the generator owns them. Missing files are not flagged.
            collisions = {};  % implementation in Task 1.2
        end
    end

    methods (Static, Access = private)
        function title = extractH1_(mdText, defaultName)
            %EXTRACTH1_ Extract first H1 heading from markdown body.
            %   title = WikiPageIndex.extractH1_(mdText, defaultName)
            %   returns the captured text of the first '^# heading' line.
            %   Falls back to defaultName when no H1 is present.
            title = defaultName;  % implementation in Task 1.2
        end

        function tf = isAutoGenerated_(mdText)
            %ISAUTOGENERATED_ Detect AUTO-GENERATED marker in first line.
            %   tf = WikiPageIndex.isAutoGenerated_(mdText) returns true
            %   iff the first non-empty line starts with the literal
            %   '<!-- AUTO-GENERATED' (D-03 informational marker).
            tf = false;  % implementation in Task 1.2
        end
    end
end
