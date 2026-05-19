function test_wiki_page_index()
%TEST_WIKI_PAGE_INDEX Function-based tests for WikiPageIndex pure-logic helpers.
%   Runs on MATLAB and Octave (no UI dependencies). Verifies directory
%   listing, H1 title extraction, TOC grouping, page resolution with
%   Home.md fallback, full-text search, and the generator-collision
%   guard.
%
%   Each sub-test is an independent local function that returns 1 on
%   success and asserts on failure (so a failing sub-test is loud and
%   immediate). All sub-tests run against the live repo wiki/ directory
%   so the assertions exercise real content shapes that the Wiki Browser
%   UI (Plan 04) will encounter.
%
%   See also WikiPageIndex, test_companion_filter_tags.

    % --- Path setup ---
    here = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    addpath(repoRoot);
    install();
    % Add Help/ explicitly in case install() in an older worktree predates
    % the libs/Help addpath line (Plan 1034-03 added it).
    helpDir = fullfile(repoRoot, 'libs', 'Help');
    if exist(helpDir, 'dir')
        addpath(helpDir);
    end

    wikiDir = fullfile(repoRoot, 'wiki');
    assert(isfolder(wikiDir), 'wiki/ not found at %s', wikiDir);

    nPassed = 0;
    nPassed = nPassed + t1_list_pages_has_minimum(wikiDir);
    nPassed = nPassed + t2_api_reference_group_assignment(wikiDir);
    nPassed = nPassed + t3_home_h1_extraction(wikiDir);
    nPassed = nPassed + t4_buildtoc_excludes_sidebar(wikiDir);
    nPassed = nPassed + t5_buildtoc_group_order(wikiDir);
    nPassed = nPassed + t6_buildtoc_alphabetical_within_group(wikiDir);
    nPassed = nPassed + t7_readpage_home_basic(wikiDir);
    nPassed = nPassed + t8_readpage_md_extension_tolerated(wikiDir);
    nPassed = nPassed + t9_readpage_fallback_to_home(wikiDir);
    nPassed = nPassed + t10_search_empty_returns_empty(wikiDir);
    nPassed = nPassed + t11_search_fastplot_title_match(wikiDir);
    nPassed = nPassed + t12_collides_with_generator_flags_home(wikiDir);
    nPassed = nPassed + t13_search_missing_term_returns_empty(wikiDir);
    nPassed = nPassed + t14_collides_with_generator_empty_input(wikiDir);

    fprintf('    All %d tests passed.\n', nPassed);
end

% ===================== Sub-tests =====================

function n = t1_list_pages_has_minimum(wikiDir)
%T1_LIST_PAGES_HAS_MINIMUM listPages enumerates >= 20 entries against the
%   repo wiki/, covering the 22-page baseline plus the 4 hand-written
%   pages added in Plan 1034-02.
    files = WikiPageIndex.listPages(wikiDir);
    assert(numel(files) >= 20, 'expected >=20 wiki pages, got %d', numel(files));
    % Every entry must have all five canonical fields.
    requiredFields = {'filename', 'pageName', 'title', 'path', 'group'};
    for i = 1:numel(files)
        for j = 1:numel(requiredFields)
            assert(isfield(files(i), requiredFields{j}), ...
                'entry %d missing field %s', i, requiredFields{j});
            assert(ischar(files(i).(requiredFields{j})), ...
                'entry %d field %s must be char', i, requiredFields{j});
        end
    end
    n = 1;
end

function n = t2_api_reference_group_assignment(wikiDir)
%T2_API_REFERENCE_GROUP_ASSIGNMENT Filenames starting with
%   'API-Reference:-' are placed in the 'API Reference' group.
    files = WikiPageIndex.listPages(wikiDir);
    nApi = 0;
    nMisgrouped = 0;
    for i = 1:numel(files)
        startsWithApi = strncmp(files(i).filename, 'API-Reference:-', numel('API-Reference:-'));
        if startsWithApi
            nApi = nApi + 1;
            if ~strcmp(files(i).group, 'API Reference')
                nMisgrouped = nMisgrouped + 1;
            end
        end
    end
    assert(nApi > 0, 'expected at least one API-Reference page in wiki/');
    assert(nMisgrouped == 0, ...
        '%d API-Reference pages were not placed in the API Reference group', ...
        nMisgrouped);
    n = 1;
end

function n = t3_home_h1_extraction(wikiDir)
%T3_HOME_H1_EXTRACTION Home.md's H1 ('# FastPlot') is captured as the
%   .title. Important regression: Octave's regexp engine treats '.' as
%   match-newline even with 'lineanchors', so a naive '.+' capture would
%   slurp the whole file. WikiPageIndex.extractH1_ uses [^\n]+ instead.
    files = WikiPageIndex.listPages(wikiDir);
    foundHome = false;
    for i = 1:numel(files)
        if strcmp(files(i).filename, 'Home.md')
            assert(strcmp(files(i).title, 'FastPlot'), ...
                'expected Home.md title=FastPlot, got |%s|', files(i).title);
            foundHome = true;
        end
    end
    assert(foundHome, 'Home.md not present in listPages output');
    n = 1;
end

function n = t4_buildtoc_excludes_sidebar(wikiDir)
%T4_BUILDTOC_EXCLUDES_SIDEBAR _Sidebar.md is filtered out of buildToc
%   because it is a TOC config artefact (Docsify-style), not a navigable
%   page.
    toc = WikiPageIndex.buildToc(wikiDir);
    for i = 1:numel(toc)
        for j = 1:numel(toc(i).entries)
            assert(~strcmp(toc(i).entries(j).filename, '_Sidebar.md'), ...
                '_Sidebar.md was leaked into TOC group %s', toc(i).group);
        end
    end
    n = 1;
end

function n = t5_buildtoc_group_order(wikiDir)
%T5_BUILDTOC_GROUP_ORDER buildToc returns exactly two groups in fixed
%   order: 'Pages' first, 'API Reference' second.
    toc = WikiPageIndex.buildToc(wikiDir);
    assert(numel(toc) == 2, 'expected 2 TOC groups, got %d', numel(toc));
    assert(strcmp(toc(1).group, 'Pages'), ...
        'expected group 1 = Pages, got |%s|', toc(1).group);
    assert(strcmp(toc(2).group, 'API Reference'), ...
        'expected group 2 = API Reference, got |%s|', toc(2).group);
    n = 1;
end

function n = t6_buildtoc_alphabetical_within_group(wikiDir)
%T6_BUILDTOC_ALPHABETICAL_WITHIN_GROUP Entries within each group are
%   sorted alphabetically by pageName (case-insensitive).
    toc = WikiPageIndex.buildToc(wikiDir);
    for i = 1:numel(toc)
        names = cell(1, numel(toc(i).entries));
        for j = 1:numel(toc(i).entries)
            names{j} = lower(toc(i).entries(j).pageName);
        end
        sortedNames = sort(names);
        assert(isequal(names, sortedNames), ...
            'group %s entries are not sorted alphabetically', toc(i).group);
    end
    n = 1;
end

function n = t7_readpage_home_basic(wikiDir)
%T7_READPAGE_HOME_BASIC readPage('Home') returns non-empty text,
%   found=true, and a path ending in Home.md.
    [mdText, resolvedPath, found] = WikiPageIndex.readPage(wikiDir, 'Home');
    assert(found, 'expected found=true for Home');
    assert(~isempty(mdText), 'expected non-empty mdText for Home');
    assert(endsWith_(resolvedPath, 'Home.md'), ...
        'expected resolvedPath to end with Home.md, got |%s|', resolvedPath);
    n = 1;
end

function n = t8_readpage_md_extension_tolerated(wikiDir)
%T8_READPAGE_MD_EXTENSION_TOLERATED readPage('Home.md') resolves
%   identically to readPage('Home').
    [md1, path1, f1] = WikiPageIndex.readPage(wikiDir, 'Home');
    [md2, path2, f2] = WikiPageIndex.readPage(wikiDir, 'Home.md');
    assert(f1 && f2, 'both forms must report found=true');
    assert(strcmp(path1, path2), ...
        'paths differ: |%s| vs |%s|', path1, path2);
    assert(strcmp(md1, md2), ...
        'text contents differ between Home and Home.md inputs');
    n = 1;
end

function n = t9_readpage_fallback_to_home(wikiDir)
%T9_READPAGE_FALLBACK_TO_HOME readPage on a missing page falls back to
%   Home.md silently when Home.md exists; found=true and resolvedPath
%   ends with Home.md so the caller can detect a "page not found,
%   showing Home" condition by comparing requested vs resolved.
    [mdText, resolvedPath, found] = WikiPageIndex.readPage(wikiDir, 'No-Such-Page-XYZ-12345');
    assert(found, 'expected found=true via Home fallback');
    assert(~isempty(mdText), 'expected non-empty mdText from Home fallback');
    assert(endsWith_(resolvedPath, 'Home.md'), ...
        'expected fallback path to end with Home.md, got |%s|', resolvedPath);
    n = 1;
end

function n = t10_search_empty_returns_empty(wikiDir)
%T10_SEARCH_EMPTY_RETURNS_EMPTY search with empty/whitespace query is a
%   no-op (returns an empty struct rather than every page).
    hits1 = WikiPageIndex.search(wikiDir, '');
    hits2 = WikiPageIndex.search(wikiDir, '   ');
    assert(isempty(hits1), 'search('''') should return empty');
    assert(isempty(hits2), 'search(whitespace) should return empty');
    n = 1;
end

function n = t11_search_fastplot_title_match(wikiDir)
%T11_SEARCH_FASTPLOT_TITLE_MATCH search('FastPlot') returns at least one
%   hit, and the top hit's score is >= 10 (title match weight). Home.md
%   has H1 'FastPlot' so Home should be the top result.
    hits = WikiPageIndex.search(wikiDir, 'FastPlot');
    assert(~isempty(hits), 'expected at least one hit for FastPlot');
    assert(hits(1).score >= 10, ...
        'expected top hit score >= 10 (title weight), got %g', hits(1).score);
    % Sanity: the top hit's excerpt is non-empty
    assert(~isempty(hits(1).excerpt), 'expected non-empty excerpt');
    n = 1;
end

function n = t12_collides_with_generator_flags_home(wikiDir)
%T12_COLLIDES_WITH_GENERATOR_FLAGS_HOME Home.md begins with the
%   '<!-- AUTO-GENERATED' marker (generator owns the slot), so it must
%   appear in the collision list. Tag-Status-Table.md is hand-written
%   without the marker (added in Plan 1034-02) so it must NOT appear.
    coll = WikiPageIndex.collidesWithGenerator(wikiDir, ...
        {'Home.md', 'Tag-Status-Table.md'});
    assert(iscell(coll), 'expected cell array, got %s', class(coll));
    assert(any(strcmp(coll, 'Home.md')), ...
        'Home.md (auto-generated) should be in collision list, got %s', ...
        strjoin(coll, ', '));
    assert(~any(strcmp(coll, 'Tag-Status-Table.md')), ...
        'Tag-Status-Table.md (hand-written) should NOT be in collision list');
    n = 1;
end

function n = t13_search_missing_term_returns_empty(wikiDir)
%T13_SEARCH_MISSING_TERM_RETURNS_EMPTY A query that appears nowhere in
%   the wiki returns an empty struct (not all pages with score=0).
    hits = WikiPageIndex.search(wikiDir, 'absolutely_xyzzy_not_present_anywhere');
    assert(isempty(hits), 'expected empty hits for unmatched query, got %d', numel(hits));
    n = 1;
end

function n = t14_collides_with_generator_empty_input(wikiDir)
%T14_COLLIDES_WITH_GENERATOR_EMPTY_INPUT An empty reserved-names list
%   returns an empty cell array (no collisions possible).
    coll = WikiPageIndex.collidesWithGenerator(wikiDir, {});
    assert(iscell(coll) && isempty(coll), ...
        'expected empty cell, got class=%s numel=%d', class(coll), numel(coll));
    n = 1;
end

% ===================== Helpers =====================

function tf = endsWith_(str, suffix)
%ENDSWITH_ Octave-compatible alternative to built-in endsWith.
%   Returns true iff str ends with suffix (char-arrays both).
    nStr = numel(str);
    nSuf = numel(suffix);
    if nSuf > nStr
        tf = false;
        return;
    end
    tf = strcmp(str(nStr - nSuf + 1:end), suffix);
end
