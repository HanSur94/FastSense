# Dashboard Info Page Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Info button to the dashboard toolbar that renders a linked Markdown file in MATLAB's browser.

**Architecture:** New `MarkdownRenderer` static class converts `.md` to HTML. `DashboardEngine` gains an `InfoFile` property and `showInfo()` method. `DashboardToolbar` conditionally shows an Info button. Serialization round-trips the `infoFile` field.

**Tech Stack:** MATLAB/Octave, `uicontrol`, `web()`, `regexprep`

**Spec:** `docs/superpowers/specs/2026-03-18-dashboard-info-page-design.md`

---

## Chunk 1: MarkdownRenderer

### Task 1: MarkdownRenderer — tests and implementation

**Files:**
- Create: `libs/Dashboard/MarkdownRenderer.m`
- Create: `tests/suite/TestMarkdownRenderer.m`

- [ ] **Step 1: Write test file for MarkdownRenderer**

```matlab
classdef TestMarkdownRenderer < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testHeadings(testCase)
            html = MarkdownRenderer.render('# Heading 1');
            testCase.verifyTrue(contains(html, '<h1>Heading 1</h1>'));

            html = MarkdownRenderer.render('## Heading 2');
            testCase.verifyTrue(contains(html, '<h2>Heading 2</h2>'));

            html = MarkdownRenderer.render('### Heading 3');
            testCase.verifyTrue(contains(html, '<h3>Heading 3</h3>'));
        end

        function testBoldAndItalic(testCase)
            html = MarkdownRenderer.render('This is **bold** text');
            testCase.verifyTrue(contains(html, '<strong>bold</strong>'));

            html = MarkdownRenderer.render('This is *italic* text');
            testCase.verifyTrue(contains(html, '<em>italic</em>'));
        end

        function testInlineCode(testCase)
            html = MarkdownRenderer.render('Use `foo()` here');
            testCase.verifyTrue(contains(html, '<code>foo()</code>'));
        end

        function testLinks(testCase)
            html = MarkdownRenderer.render('[Click](http://example.com)');
            testCase.verifyTrue(contains(html, '<a href="http://example.com">Click</a>'));
        end

        function testUnorderedList(testCase)
            md = sprintf('- Item 1\n- Item 2\n- Item 3');
            html = MarkdownRenderer.render(md);
            testCase.verifyTrue(contains(html, '<ul>'));
            testCase.verifyTrue(contains(html, '<li>Item 1</li>'));
            testCase.verifyTrue(contains(html, '<li>Item 2</li>'));
            testCase.verifyTrue(contains(html, '<li>Item 3</li>'));
            testCase.verifyTrue(contains(html, '</ul>'));
        end

        function testUnorderedListAsterisk(testCase)
            md = sprintf('* Item A\n* Item B');
            html = MarkdownRenderer.render(md);
            testCase.verifyTrue(contains(html, '<ul>'));
            testCase.verifyTrue(contains(html, '<li>Item A</li>'));
        end

        function testOrderedList(testCase)
            md = sprintf('1. First\n2. Second\n3. Third');
            html = MarkdownRenderer.render(md);
            testCase.verifyTrue(contains(html, '<ol>'));
            testCase.verifyTrue(contains(html, '<li>First</li>'));
            testCase.verifyTrue(contains(html, '</ol>'));
        end

        function testCodeBlock(testCase)
            md = sprintf('```\nx = 1:10;\nplot(x);\n```');
            html = MarkdownRenderer.render(md);
            testCase.verifyTrue(contains(html, '<pre><code>'));
            testCase.verifyTrue(contains(html, 'x = 1:10;'));
            testCase.verifyTrue(contains(html, '</code></pre>'));
        end

        function testCodeBlockEscapesHtml(testCase)
            md = sprintf('```\nfprintf(''<b>%%s</b>'', x);\n```');
            html = MarkdownRenderer.render(md);
            testCase.verifyTrue(contains(html, '&lt;b&gt;'));
            testCase.verifyTrue(contains(html, '&lt;/b&gt;'));
        end

        function testHorizontalRule(testCase)
            html = MarkdownRenderer.render('---');
            testCase.verifyTrue(contains(html, '<hr>'));
        end

        function testParagraphs(testCase)
            md = sprintf('First paragraph.\n\nSecond paragraph.');
            html = MarkdownRenderer.render(md);
            testCase.verifyTrue(contains(html, '<p>First paragraph.</p>'));
            testCase.verifyTrue(contains(html, '<p>Second paragraph.</p>'));
        end

        function testUnknownThemeDefaultsToLight(testCase)
            htmlUnknown = MarkdownRenderer.render('# Test', 'nonexistent_theme');
            htmlLight = MarkdownRenderer.render('# Test', 'light');
            testCase.verifyEqual(htmlUnknown, htmlLight);
        end

        function testDarkTheme(testCase)
            htmlLight = MarkdownRenderer.render('# Test', 'light');
            htmlDark = MarkdownRenderer.render('# Test', 'dark');
            % Dark theme should have different background color
            testCase.verifyTrue(~strcmp(htmlLight, htmlDark));
        end

        function testFullHtmlDocument(testCase)
            html = MarkdownRenderer.render('# Hello');
            testCase.verifyTrue(strncmp(html, '<!DOCTYPE html>', 15));
            testCase.verifyTrue(contains(html, '</html>'));
        end
    end
end
```

Write this to `tests/suite/TestMarkdownRenderer.m`.

- [ ] **Step 2: Write MarkdownRenderer implementation**

```matlab
classdef MarkdownRenderer
%MARKDOWNRENDERER Lightweight Markdown-to-HTML converter.
%
%   html = MarkdownRenderer.render(mdText)
%   html = MarkdownRenderer.render(mdText, themeName)
%
%   Converts a subset of Markdown to a self-contained HTML document.
%   Supported: headings (#-###), **bold**, *italic*, `inline code`,
%   fenced code blocks, [links](url), unordered/ordered lists,
%   horizontal rules (---), and paragraph breaks.
%
%   The optional themeName ('light', 'dark', etc.) controls the CSS
%   color scheme. Unrecognized themes default to 'light'.

    methods (Static)
        function html = render(mdText, themeName)
            if nargin < 2 || isempty(themeName)
                themeName = 'light';
            end

            % regexp split preserves empty tokens (Octave-compatible)
            lines = regexp(mdText, '\n', 'split');
            bodyParts = {};
            inCodeBlock = false;
            codeLines = {};
            inUl = false;
            inOl = false;
            inParagraph = false;

            for i = 1:numel(lines)
                line = lines{i};

                % --- Fenced code blocks ---
                if ~inCodeBlock && numel(line) >= 3 && strcmp(line(1:3), '```')
                    if inParagraph
                        bodyParts{end+1} = '</p>';
                        inParagraph = false;
                    end
                    inCodeBlock = true;
                    codeLines = {};
                    continue;
                end
                if inCodeBlock
                    if numel(line) >= 3 && strcmp(line(1:3), '```')
                        inCodeBlock = false;
                        bodyParts{end+1} = ['<pre><code>' ...
                            MarkdownRenderer.escapeHtml(strjoin(codeLines, char(10))) ...
                            '</code></pre>'];
                        codeLines = {};
                    else
                        codeLines{end+1} = line;
                    end
                    continue;
                end

                % --- Close open lists if line doesn't continue them ---
                isUlLine = ~isempty(regexp(line, '^\s*[-*]\s+', 'once'));
                isOlLine = ~isempty(regexp(line, '^\s*\d+\.\s+', 'once'));

                if inUl && ~isUlLine
                    bodyParts{end+1} = '</ul>';
                    inUl = false;
                end
                if inOl && ~isOlLine
                    bodyParts{end+1} = '</ol>';
                    inOl = false;
                end

                % --- Horizontal rule ---
                if ~isempty(regexp(line, '^\s*---+\s*$', 'once'))
                    if inParagraph
                        bodyParts{end+1} = '</p>';
                        inParagraph = false;
                    end
                    bodyParts{end+1} = '<hr>';
                    continue;
                end

                % --- Headings ---
                headMatch = regexp(line, '^(#{1,3})\s+(.*)', 'tokens', 'once');
                if ~isempty(headMatch)
                    if inParagraph
                        bodyParts{end+1} = '</p>';
                        inParagraph = false;
                    end
                    level = numel(headMatch{1});
                    text = MarkdownRenderer.inlineFormat(strtrim(headMatch{2}));
                    bodyParts{end+1} = sprintf('<h%d>%s</h%d>', level, text, level);
                    continue;
                end

                % --- Unordered list ---
                if isUlLine
                    if inParagraph
                        bodyParts{end+1} = '</p>';
                        inParagraph = false;
                    end
                    if ~inUl
                        bodyParts{end+1} = '<ul>';
                        inUl = true;
                    end
                    item = regexprep(line, '^\s*[-*]\s+', '');
                    bodyParts{end+1} = ['<li>' MarkdownRenderer.inlineFormat(item) '</li>'];
                    continue;
                end

                % --- Ordered list ---
                if isOlLine
                    if inParagraph
                        bodyParts{end+1} = '</p>';
                        inParagraph = false;
                    end
                    if ~inOl
                        bodyParts{end+1} = '<ol>';
                        inOl = true;
                    end
                    item = regexprep(line, '^\s*\d+\.\s+', '');
                    bodyParts{end+1} = ['<li>' MarkdownRenderer.inlineFormat(item) '</li>'];
                    continue;
                end

                % --- Blank line = close current paragraph ---
                trimmed = strtrim(line);
                if isempty(trimmed)
                    if inParagraph
                        bodyParts{end+1} = '</p>';
                        inParagraph = false;
                    end
                    continue;
                end

                % --- Regular text ---
                if ~inParagraph
                    bodyParts{end+1} = '<p>';
                    inParagraph = true;
                end
                bodyParts{end+1} = MarkdownRenderer.inlineFormat(trimmed);
            end

            % Close any open elements
            if inParagraph
                bodyParts{end+1} = '</p>';
            end
            if inUl
                bodyParts{end+1} = '</ul>';
            end
            if inOl
                bodyParts{end+1} = '</ol>';
            end

            bodyHtml = strjoin(bodyParts, char(10));

            css = MarkdownRenderer.getCSS(themeName);
            html = ['<!DOCTYPE html>' char(10) ...
                '<html><head><meta charset="utf-8">' char(10) ...
                '<style>' char(10) css char(10) '</style>' char(10) ...
                '</head><body>' char(10) ...
                bodyHtml char(10) ...
                '</body></html>'];
        end
    end

    methods (Static, Access = private)
        function text = inlineFormat(text)
            % Links: [text](url)
            text = regexprep(text, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>');
            % Bold: **text**
            text = regexprep(text, '\*\*([^*]+)\*\*', '<strong>$1</strong>');
            % Italic: *text*
            text = regexprep(text, '\*([^*]+)\*', '<em>$1</em>');
            % Inline code: `text`
            text = regexprep(text, '`([^`]+)`', '<code>$1</code>');
        end

        function text = escapeHtml(text)
            text = strrep(text, '&', '&amp;');
            text = strrep(text, '<', '&lt;');
            text = strrep(text, '>', '&gt;');
        end

        function css = getCSS(themeName)
            switch themeName
                case {'dark', 'industrial', 'ocean'}
                    bg = '#1a1a2e';
                    fg = '#d4d4d4';
                    codeBg = '#2d2d44';
                    linkColor = '#5ca8e6';
                    hrColor = '#3a3a5c';
                case {'light', 'scientific'}
                    bg = '#ffffff';
                    fg = '#2d2d2d';
                    codeBg = '#f4f4f4';
                    linkColor = '#0066cc';
                    hrColor = '#ddd';
                otherwise
                    bg = '#ffffff';
                    fg = '#2d2d2d';
                    codeBg = '#f4f4f4';
                    linkColor = '#0066cc';
                    hrColor = '#ddd';
            end
            css = sprintf([ ...
                'body { font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; ' ...
                'max-width: 800px; margin: 40px auto; padding: 0 20px; ' ...
                'line-height: 1.6; color: %s; background: %s; }\n' ...
                'h1, h2, h3 { margin-top: 1.5em; margin-bottom: 0.5em; }\n' ...
                'h1 { font-size: 1.8em; border-bottom: 1px solid %s; padding-bottom: 0.3em; }\n' ...
                'h2 { font-size: 1.4em; }\n' ...
                'h3 { font-size: 1.1em; }\n' ...
                'code { background: %s; padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }\n' ...
                'pre { background: %s; padding: 16px; border-radius: 6px; overflow-x: auto; }\n' ...
                'pre code { padding: 0; background: transparent; }\n' ...
                'a { color: %s; }\n' ...
                'hr { border: none; border-top: 1px solid %s; margin: 2em 0; }\n' ...
                'ul, ol { padding-left: 2em; }\n' ...
                'li { margin: 0.3em 0; }\n' ...
                'p { margin: 0.8em 0; }' ...
            ], fg, bg, hrColor, codeBg, codeBg, linkColor, hrColor);
        end
    end
end
```

Write this to `libs/Dashboard/MarkdownRenderer.m`.

- [ ] **Step 3: Run tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestMarkdownRenderer.m'); disp(results); assert(all([results.Passed]))"`

Expected: All 14 tests pass.

- [ ] **Step 4: Commit**

```bash
git add libs/Dashboard/MarkdownRenderer.m tests/suite/TestMarkdownRenderer.m
git commit -m "feat(dashboard): add MarkdownRenderer for info page"
```

---

## Chunk 2: DashboardEngine InfoFile property and showInfo

### Task 2: Add InfoFile property, InfoTempFile, showInfo(), and update delete()

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m`
- Create: `tests/suite/TestDashboardInfo.m`

- [ ] **Step 1: Write test file for InfoFile property and showInfo**

```matlab
classdef TestDashboardInfo < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Test)
        function testInfoFileDefaultEmpty(testCase)
            d = DashboardEngine('Test');
            testCase.verifyEqual(d.InfoFile, '');
        end

        function testInfoFileAtConstruction(testCase)
            d = DashboardEngine('Test', 'InfoFile', 'info.md');
            testCase.verifyEqual(d.InfoFile, 'info.md');
        end

        function testInfoFileSetAfterConstruction(testCase)
            d = DashboardEngine('Test');
            d.InfoFile = 'docs/readme.md';
            testCase.verifyEqual(d.InfoFile, 'docs/readme.md');
        end

        function testShowInfoMissingFileWarns(testCase)
            d = DashboardEngine('Test');
            d.InfoFile = 'nonexistent_file_xyz.md';
            % showInfo should warn, not error
            testCase.verifyWarning(@() d.showInfo(), ...
                'DashboardEngine:infoFileNotFound');
        end

        function testShowInfoReadsFile(testCase)
            mdPath = fullfile(testCase.TempDir, 'info.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Test Info\n\nHello world.');
            fclose(fid);

            d = DashboardEngine('Test');
            d.InfoFile = mdPath;
            d.showInfo();
            testCase.addTeardown(@() d.cleanupInfoTempFile());
            testCase.verifyTrue(~isempty(d.InfoTempFile));
            testCase.verifyTrue(exist(d.InfoTempFile, 'file') == 2);
        end

        function testRelativePathResolvesAgainstFilePath(testCase)
            % Create a subdirectory with an md file
            subDir = fullfile(testCase.TempDir, 'sub');
            mkdir(subDir);
            mdPath = fullfile(subDir, 'info.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Info');
            fclose(fid);

            d = DashboardEngine('Test');
            d.InfoFile = 'info.md';
            % Simulate having been loaded from sub/dashboard.json
            % FilePath is SetAccess=private, so we save+load to set it
            dashPath = fullfile(subDir, 'dash.json');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], 'Content', 'x');
            d.save(dashPath);

            d2 = DashboardEngine.load(dashPath);
            d2.InfoFile = 'info.md';
            % Should resolve info.md relative to sub/
            d2.showInfo();
            testCase.addTeardown(@() d2.cleanupInfoTempFile());
            testCase.verifyTrue(exist(d2.InfoTempFile, 'file') == 2);
        end

        function testRelativePathUnsavedResolvesAgainstPwd(testCase)
            mdPath = fullfile(pwd, 'test_info_unsaved_xyz.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Unsaved test');
            fclose(fid);
            testCase.addTeardown(@() delete(mdPath));

            d = DashboardEngine('Test');
            d.InfoFile = 'test_info_unsaved_xyz.md';
            % FilePath is empty (unsaved), should resolve against pwd
            d.showInfo();
            testCase.addTeardown(@() d.cleanupInfoTempFile());
            testCase.verifyTrue(exist(d.InfoTempFile, 'file') == 2);
        end
    end
end
```

Write this to `tests/suite/TestDashboardInfo.m`.

- [ ] **Step 2: Add InfoFile property and InfoTempFile to DashboardEngine**

In `libs/Dashboard/DashboardEngine.m`, add `InfoFile` to the public properties block (line 22-26):

```matlab
    properties (Access = public)
        Name         = ''
        Theme        = 'light'
        LiveInterval = 5
        InfoFile     = ''
    end
```

Add `InfoTempFile` to the `properties (SetAccess = private)` block (after line 36, `FilePath`):

```matlab
        FilePath       = ''
        InfoTempFile   = ''
```

- [ ] **Step 3: Add showInfo() and cleanupInfoTempFile() methods to DashboardEngine**

Add to the `methods (Access = public)` block, after `exportScript()` (after line 165):

```matlab
        function showInfo(obj)
        %SHOWINFO Display the linked Markdown info file in a browser.
            if isempty(obj.InfoFile)
                return;
            end

            % Resolve file path — pure string check (Octave-compatible)
            isAbsPath = (numel(obj.InfoFile) > 0 && obj.InfoFile(1) == '/') || ...
                (numel(obj.InfoFile) > 1 && obj.InfoFile(2) == ':');
            if isAbsPath
                mdPath = obj.InfoFile;
            else
                if ~isempty(obj.FilePath)
                    baseDir = fileparts(obj.FilePath);
                else
                    baseDir = pwd;
                end
                mdPath = fullfile(baseDir, obj.InfoFile);
            end

            % Check file exists
            if ~exist(mdPath, 'file')
                warning('DashboardEngine:infoFileNotFound', ...
                    'Info file not found: %s', mdPath);
                return;
            end

            % Read file with safe fclose on both paths
            fid = fopen(mdPath, 'r');
            if fid == -1
                warning('DashboardEngine:infoReadError', ...
                    'Cannot open info file: %s', mdPath);
                return;
            end
            try
                mdText = fread(fid, '*char')';
                fclose(fid);
            catch ME
                fclose(fid);
                warning('DashboardEngine:infoReadError', ...
                    'Failed to read info file: %s', ME.message);
                return;
            end

            % Convert to HTML
            html = MarkdownRenderer.render(mdText, obj.Theme);

            % Write temp file (reuse path)
            if isempty(obj.InfoTempFile)
                obj.InfoTempFile = [tempname '.html'];
            end
            fid = fopen(obj.InfoTempFile, 'w');
            fwrite(fid, html);
            fclose(fid);

            % Display
            if exist('OCTAVE_VERSION', 'builtin')
                if ismac
                    system(['open "' obj.InfoTempFile '"']);
                elseif ispc
                    system(['cmd /c start "" "' obj.InfoTempFile '"']);
                else
                    system(['xdg-open "' obj.InfoTempFile '"']);
                end
            else
                web(obj.InfoTempFile, '-new');
            end
        end

        function cleanupInfoTempFile(obj)
        %CLEANUPINFOTEMPFILE Delete the temporary HTML file if it exists.
            if ~isempty(obj.InfoTempFile) && exist(obj.InfoTempFile, 'file')
                delete(obj.InfoTempFile);
                obj.InfoTempFile = '';
            end
        end
```

- [ ] **Step 4: Update delete() to clean up temp file**

Replace the existing `delete` method (lines 296-298) with:

```matlab
        function delete(obj)
            obj.stopLive();
            obj.cleanupInfoTempFile();
        end
```

- [ ] **Step 5: Run tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboardInfo.m'); disp(results); assert(all([results.Passed]))"`

Expected: All 7 tests pass.

Also verify existing tests still pass:
Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboardEngine.m'); disp(results); assert(all([results.Passed]))"`

Expected: All existing tests pass unchanged.

- [ ] **Step 6: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m tests/suite/TestDashboardInfo.m
git commit -m "feat(dashboard): add InfoFile property and showInfo method"
```

---

## Chunk 3: Serialization

### Task 3: Update DashboardSerializer for infoFile

**Files:**
- Modify: `libs/Dashboard/DashboardSerializer.m`
- Modify: `libs/Dashboard/DashboardEngine.m`
- Extend: `tests/suite/TestDashboardInfo.m`

- [ ] **Step 1: Add serialization tests to TestDashboardInfo.m**

Append these test methods to the `methods (Test)` block in `tests/suite/TestDashboardInfo.m`:

```matlab
        function testSerializationRoundTrip(testCase)
            d = DashboardEngine('Info Test', 'InfoFile', 'docs/info.md');
            d.addWidget('text', 'Title', 'Note', 'Position', [1 1 4 2], ...
                'Content', 'Hello');

            filepath = fullfile(testCase.TempDir, 'info_dash.json');
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.InfoFile, 'docs/info.md');
        end

        function testSerializationWithoutInfoFile(testCase)
            d = DashboardEngine('No Info');
            d.addWidget('text', 'Title', 'Note', 'Position', [1 1 4 2], ...
                'Content', 'Hello');

            filepath = fullfile(testCase.TempDir, 'no_info_dash.json');
            d.save(filepath);

            content = fileread(filepath);
            testCase.verifyFalse(contains(content, 'infoFile'));
        end

        function testWidgetsToConfigBackwardCompat(testCase)
            w = TextWidget('Title', 'T', 'Position', [1 1 4 2], 'Content', 'x');
            config = DashboardSerializer.widgetsToConfig('Test', 'light', 5, {w});
            testCase.verifyEqual(config.name, 'Test');
            testCase.verifyFalse(isfield(config, 'infoFile'));
        end

        function testExportScriptWithInfoFile(testCase)
            d = DashboardEngine('Export Info', 'InfoFile', 'notes.md');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');

            filepath = fullfile(testCase.TempDir, 'export_info.m');
            d.exportScript(filepath);

            content = fileread(filepath);
            testCase.verifyTrue(contains(content, 'InfoFile'));
            testCase.verifyTrue(contains(content, 'notes.md'));
        end

        function testExportScriptWithoutInfoFile(testCase)
            d = DashboardEngine('Export No Info');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');

            filepath = fullfile(testCase.TempDir, 'export_no_info.m');
            d.exportScript(filepath);

            content = fileread(filepath);
            testCase.verifyFalse(contains(content, 'InfoFile'));
        end
```

- [ ] **Step 2: Update widgetsToConfig with optional 5th argument**

In `libs/Dashboard/DashboardSerializer.m`, replace `widgetsToConfig` (lines 51-61):

```matlab
        function config = widgetsToConfig(name, theme, liveInterval, widgets, infoFile)
            %WIDGETSTOCONFIG Build a config struct from widget objects.
            if nargin < 5
                infoFile = '';
            end
            config.name = name;
            config.theme = theme;
            config.liveInterval = liveInterval;
            if ~isempty(infoFile)
                config.infoFile = infoFile;
            end
            config.grid = struct('columns', 24);
            config.widgets = cell(1, numel(widgets));
            for i = 1:numel(widgets)
                config.widgets{i} = widgets{i}.toStruct();
            end
        end
```

- [ ] **Step 3: Update exportScript to emit InfoFile line**

In `libs/Dashboard/DashboardSerializer.m`, in the `exportScript` method, add after line 120 (the `lines{end+1} = '';` blank line after `d.LiveInterval`):

```matlab
            if isfield(config, 'infoFile') && ~isempty(config.infoFile)
                lines{end+1} = sprintf('d.InfoFile = ''%s'';', config.infoFile);
                lines{end+1} = '';
            end
```

- [ ] **Step 4: Update DashboardEngine.save() to pass InfoFile**

In `libs/Dashboard/DashboardEngine.m`, modify `save()` (lines 154-159):

```matlab
        function save(obj, filepath)
            config = DashboardSerializer.widgetsToConfig( ...
                obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets, obj.InfoFile);
            DashboardSerializer.save(config, filepath);
            obj.FilePath = filepath;
        end
```

- [ ] **Step 5: Update DashboardEngine.exportScript() to pass InfoFile**

In `libs/Dashboard/DashboardEngine.m`, modify `exportScript()` (lines 161-165):

```matlab
        function exportScript(obj, filepath)
            config = DashboardSerializer.widgetsToConfig( ...
                obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets, obj.InfoFile);
            DashboardSerializer.exportScript(config, filepath);
        end
```

- [ ] **Step 6: Update DashboardEngine.load() to read infoFile**

In `libs/Dashboard/DashboardEngine.m`, in the `load` static method, after line 499 (`obj.FilePath = filepath;`), add:

```matlab
            if isfield(config, 'infoFile')
                obj.InfoFile = config.infoFile;
            end
```

- [ ] **Step 7: Run tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboardInfo.m'); disp(results); assert(all([results.Passed]))"`

Expected: All 12 tests pass (7 from Task 2 + 5 new).

Also verify existing serializer tests still pass:
Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboardSerializer.m'); disp(results); assert(all([results.Passed]))"`

Expected: All existing tests pass unchanged.

- [ ] **Step 8: Commit**

```bash
git add libs/Dashboard/DashboardSerializer.m libs/Dashboard/DashboardEngine.m tests/suite/TestDashboardInfo.m
git commit -m "feat(dashboard): serialize InfoFile in JSON and export script"
```

---

## Chunk 4: Toolbar Info Button

### Task 4: Add conditional Info button to DashboardToolbar

**Files:**
- Modify: `libs/Dashboard/DashboardToolbar.m`
- Extend: `tests/suite/TestDashboardInfo.m`

- [ ] **Step 1: Add toolbar button tests to TestDashboardInfo.m**

Append these test methods to `tests/suite/TestDashboardInfo.m`:

```matlab
        function testToolbarInfoButtonPresent(testCase)
            d = DashboardEngine('Toolbar Test', 'InfoFile', 'dummy.md');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            testCase.verifyNotEmpty(d.Toolbar.hInfoBtn);
            testCase.verifyTrue(ishandle(d.Toolbar.hInfoBtn));
        end

        function testToolbarInfoButtonAbsent(testCase)
            d = DashboardEngine('Toolbar No Info');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            testCase.verifyTrue(isempty(d.Toolbar.hInfoBtn));
        end
```

- [ ] **Step 2: Add hInfoBtn property to DashboardToolbar**

In `libs/Dashboard/DashboardToolbar.m`, add `hInfoBtn` to the `properties (SetAccess = private)` block (after line 19, `hLastUpdate`):

```matlab
        hInfoBtn     = []
```

- [ ] **Step 3: Add conditional Info button creation in constructor**

In `libs/Dashboard/DashboardToolbar.m`, after `btnY = 0.15;` (after line 48), add:

```matlab
            % Conditional Info button (only when InfoFile is set)
            if ~isempty(engine.InfoFile)
                % Shorten title to make room
                set(obj.hTitleText, 'Position', [0.01 0.1 0.27 0.8]);

                obj.hInfoBtn = uicontrol('Parent', obj.hPanel, ...
                    'Style', 'pushbutton', ...
                    'Units', 'normalized', ...
                    'Position', [0.29 btnY 0.05 btnH], ...
                    'String', 'Info', ...
                    'Callback', @(~,~) obj.onInfo());
            end
```

- [ ] **Step 4: Add onInfo callback method**

In `libs/Dashboard/DashboardToolbar.m`, add a new method after `onEdit()` (after line 156):

```matlab
        function onInfo(obj)
            obj.Engine.showInfo();
        end
```

- [ ] **Step 5: Run tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboardInfo.m'); disp(results); assert(all([results.Passed]))"`

Expected: All 14 tests pass (12 from previous + 2 new toolbar tests).

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboardEngine.m'); disp(results); assert(all([results.Passed]))"`

Expected: All existing tests pass unchanged.

- [ ] **Step 6: Commit**

```bash
git add libs/Dashboard/DashboardToolbar.m tests/suite/TestDashboardInfo.m
git commit -m "feat(dashboard): add conditional Info button to toolbar"
```

---

## Chunk 5: Final verification

### Task 5: Run full test suite and verify

**Files:** None (verification only)

- [ ] **Step 1: Run the full dashboard test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite'); disp(results); disp(table(results)); fprintf('Passed: %d, Failed: %d\n', sum([results.Passed]), sum([results.Failed]))"`

Expected: All tests pass, including all existing tests unchanged.

- [ ] **Step 2: Run MarkdownRenderer tests specifically**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestMarkdownRenderer.m'); disp(results); assert(all([results.Passed]))"`

Expected: All 14 tests pass.

- [ ] **Step 3: Run TestDashboardInfo tests specifically**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboardInfo.m'); disp(results); assert(all([results.Passed]))"`

Expected: All 14 tests pass.
