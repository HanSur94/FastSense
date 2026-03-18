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
            testCase.verifyTrue(~strcmp(htmlLight, htmlDark));
        end

        function testFullHtmlDocument(testCase)
            html = MarkdownRenderer.render('# Hello');
            testCase.verifyTrue(strncmp(html, '<!DOCTYPE html>', 15));
            testCase.verifyTrue(contains(html, '</html>'));
        end
    end
end
