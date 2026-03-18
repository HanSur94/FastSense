classdef MarkdownRenderer
%MARKDOWNRENDERER Lightweight Markdown-to-HTML converter.
%
%   html = MarkdownRenderer.render(mdText)
%   html = MarkdownRenderer.render(mdText, themeName)
%
%   Converts a subset of Markdown to a self-contained HTML document.
%   Supported: headings (#-###), **bold**, *italic*, `inline code`,
%   fenced code blocks, [links](url), unordered/ordered lists,
%   horizontal rules (---), tables (pipe-delimited), and paragraph breaks.
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
            inTable = false;
            tableHeaderDone = false;
            paragraphLines = {};

            for i = 1:numel(lines)
                line = lines{i};

                % --- Fenced code blocks ---
                if ~inCodeBlock && numel(line) >= 3 && strcmp(line(1:3), '```')
                    if ~isempty(paragraphLines)
                        bodyParts{end+1} = ['<p>' strjoin(paragraphLines, ' ') '</p>'];
                        paragraphLines = {};
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

                % --- Close open lists/tables if line doesn't continue ---
                isUlLine = ~isempty(regexp(line, '^\s*[-*]\s+', 'once'));
                isOlLine = ~isempty(regexp(line, '^\s*\d+\.\s+', 'once'));
                isTableLine = ~isempty(regexp(line, '^\s*\|', 'once'));

                if inUl && ~isUlLine
                    bodyParts{end+1} = '</ul>';
                    inUl = false;
                end
                if inOl && ~isOlLine
                    bodyParts{end+1} = '</ol>';
                    inOl = false;
                end
                if inTable && ~isTableLine
                    bodyParts{end+1} = '</tbody></table>';
                    inTable = false;
                    tableHeaderDone = false;
                end

                % --- Table rows ---
                if isTableLine
                    if ~isempty(paragraphLines)
                        bodyParts{end+1} = ['<p>' strjoin(paragraphLines, ' ') '</p>'];
                        paragraphLines = {};
                    end
                    % Parse cells from pipe-delimited row
                    cells = MarkdownRenderer.parseTableRow(line);
                    if isempty(cells)
                        continue;
                    end
                    % Skip separator rows (e.g. |---|---|)
                    isSeparator = all(cellfun(@(c) ~isempty(regexp(c, '^\s*[-:]+\s*$', 'once')), cells));
                    if isSeparator
                        continue;
                    end
                    if ~inTable
                        % First row is the header
                        bodyParts{end+1} = '<table><thead><tr>';
                        for ci = 1:numel(cells)
                            bodyParts{end+1} = ['<th>' MarkdownRenderer.inlineFormat(strtrim(cells{ci})) '</th>'];
                        end
                        bodyParts{end+1} = '</tr></thead><tbody>';
                        inTable = true;
                        tableHeaderDone = true;
                    else
                        bodyParts{end+1} = '<tr>';
                        for ci = 1:numel(cells)
                            bodyParts{end+1} = ['<td>' MarkdownRenderer.inlineFormat(strtrim(cells{ci})) '</td>'];
                        end
                        bodyParts{end+1} = '</tr>';
                    end
                    continue;
                end

                % --- Horizontal rule ---
                if ~isempty(regexp(line, '^\s*---+\s*$', 'once'))
                    if ~isempty(paragraphLines)
                        bodyParts{end+1} = ['<p>' strjoin(paragraphLines, ' ') '</p>'];
                        paragraphLines = {};
                    end
                    bodyParts{end+1} = '<hr>';
                    continue;
                end

                % --- Headings ---
                headMatch = regexp(line, '^(#{1,3})\s+(.*)', 'tokens', 'once');
                if ~isempty(headMatch)
                    if ~isempty(paragraphLines)
                        bodyParts{end+1} = ['<p>' strjoin(paragraphLines, ' ') '</p>'];
                        paragraphLines = {};
                    end
                    level = numel(headMatch{1});
                    text = MarkdownRenderer.inlineFormat(strtrim(headMatch{2}));
                    bodyParts{end+1} = sprintf('<h%d>%s</h%d>', level, text, level);
                    continue;
                end

                % --- Unordered list ---
                if isUlLine
                    if ~isempty(paragraphLines)
                        bodyParts{end+1} = ['<p>' strjoin(paragraphLines, ' ') '</p>'];
                        paragraphLines = {};
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
                    if ~isempty(paragraphLines)
                        bodyParts{end+1} = ['<p>' strjoin(paragraphLines, ' ') '</p>'];
                        paragraphLines = {};
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
                    if ~isempty(paragraphLines)
                        bodyParts{end+1} = ['<p>' strjoin(paragraphLines, ' ') '</p>'];
                        paragraphLines = {};
                    end
                    continue;
                end

                % --- Regular text ---
                paragraphLines{end+1} = MarkdownRenderer.inlineFormat(trimmed);
            end

            % Close any open elements
            if ~isempty(paragraphLines)
                bodyParts{end+1} = ['<p>' strjoin(paragraphLines, ' ') '</p>'];
                paragraphLines = {};
            end
            if inTable
                bodyParts{end+1} = '</tbody></table>';
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
            text = MarkdownRenderer.escapeHtml(text);
            % Links: [text](url)
            text = regexprep(text, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>');
            % Bold: **text**
            text = regexprep(text, '\*\*([^*]+)\*\*', '<strong>$1</strong>');
            % Italic: *text*
            text = regexprep(text, '\*([^*]+)\*', '<em>$1</em>');
            % Inline code: `text`
            text = regexprep(text, '`([^`]+)`', '<code>$1</code>');
        end

        function cells = parseTableRow(line)
            % Strip leading/trailing pipes and split by |
            line = strtrim(line);
            if numel(line) >= 1 && line(1) == '|'
                line = line(2:end);
            end
            if numel(line) >= 1 && line(end) == '|'
                line = line(1:end-1);
            end
            cells = strsplit(line, '|');
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
                    tableBorder = '#3a3a5c';
                    tableHeadBg = '#2d2d44';
                    tableStripeBg = '#22223a';
                case {'light', 'scientific'}
                    bg = '#ffffff';
                    fg = '#2d2d2d';
                    codeBg = '#f4f4f4';
                    linkColor = '#0066cc';
                    hrColor = '#ddd';
                    tableBorder = '#ddd';
                    tableHeadBg = '#f4f4f4';
                    tableStripeBg = '#fafafa';
                otherwise
                    bg = '#ffffff';
                    fg = '#2d2d2d';
                    codeBg = '#f4f4f4';
                    linkColor = '#0066cc';
                    hrColor = '#ddd';
                    tableBorder = '#ddd';
                    tableHeadBg = '#f4f4f4';
                    tableStripeBg = '#fafafa';
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
                'p { margin: 0.8em 0; }\n' ...
                'table { border-collapse: collapse; width: 100%%; margin: 1em 0; }\n' ...
                'th, td { border: 1px solid %s; padding: 8px 12px; text-align: left; }\n' ...
                'th { background: %s; font-weight: 600; }\n' ...
                'tr:nth-child(even) td { background: %s; }' ...
            ], fg, bg, hrColor, codeBg, codeBg, linkColor, hrColor, ...
                tableBorder, tableHeadBg, tableStripeBg);
        end
    end
end
