---
phase: quick
plan: 260405-ovf
type: execute
wave: 1
depends_on: []
files_modified: [README.md]
autonomous: false
requirements: [QUICK]

must_haves:
  truths:
    - "README follows best practices observed in top-starred open-source MATLAB/visualization projects"
    - "README has compelling hero section with clear value proposition"
    - "README structure guides new users from interest to installation to usage in under 60 seconds"
  artifacts:
    - path: "README.md"
      provides: "Improved project README"
      min_lines: 150
  key_links: []
---

<objective>
Research READMEs of highly-starred open-source projects (MATLAB plotting/dashboard/visualization tools) to identify best practices, then rewrite the FastSense README incorporating those patterns.

Purpose: A polished README is the project's front door. Studying what works for successful projects ensures we adopt proven patterns for engagement, clarity, and discoverability.
Output: Improved README.md
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@README.md
@docs/images/
@examples/
</context>

<tasks>

<task type="auto">
  <name>Task 1: Research READMEs of highly-starred open-source projects</name>
  <files>.planning/quick/260405-ovf-update-project-readme-based-on-research-/README-RESEARCH.md</files>
  <action>
Use WebFetch to study the READMEs of 8-12 highly-starred projects across these categories:

**MATLAB plotting/visualization:**
- github.com/altmany/export_fig (MATLAB figure export, ~1.3k stars)
- github.com/plotly/plotly_matlab (Plotly MATLAB, ~300+ stars)
- github.com/raacampbell/shadedErrorBar (shaded error bars, ~300+ stars)
- github.com/kakearney/boundedline-pkg

**Dashboard/monitoring frameworks (any language, for README patterns):**
- github.com/grafana/grafana (dashboarding gold standard)
- github.com/netdata/netdata (real-time monitoring)
- github.com/gethomepage/homepage (dashboard)

**High-performance plotting libraries:**
- github.com/plotly/plotly.js
- github.com/leeoniya/uPlot (already vendored in project)
- github.com/apache/echarts

**Data visualization:**
- github.com/d3/d3
- github.com/vega/vega-lite

For each README, extract and document:
1. **Structure** — section ordering, heading hierarchy, what comes first
2. **Hero section** — how they hook the reader (tagline, badges, hero image/GIF, key stats)
3. **Feature presentation** — how features are listed (icons, tables, bullet groups, screenshots)
4. **Code examples** — placement, length, complexity of first example
5. **Installation** — how many steps, how prominent
6. **Visual assets** — GIFs, screenshots, diagrams, their placement
7. **Social proof** — stars, downloads, contributor counts, testimonials, "used by" sections
8. **Call to action** — what they want readers to do next
9. **Navigation aids** — table of contents, anchor links, section separators
10. **Unique/clever patterns** — anything distinctive that works well

Write findings to README-RESEARCH.md as a structured analysis with a "Key Takeaways" section at the end summarizing the top 8-10 actionable patterns to adopt for FastSense.
  </action>
  <verify>
    <automated>test -f .planning/quick/260405-ovf-update-project-readme-based-on-research-/README-RESEARCH.md && wc -l .planning/quick/260405-ovf-update-project-readme-based-on-research-/README-RESEARCH.md | awk '{if ($1 > 50) print "PASS"; else print "FAIL"}'</automated>
  </verify>
  <done>README-RESEARCH.md exists with structured analysis of 8+ project READMEs and actionable takeaways</done>
</task>

<task type="auto">
  <name>Task 2: Rewrite README.md based on research findings</name>
  <files>README.md</files>
  <action>
Rewrite README.md incorporating the best patterns identified in Task 1. Key improvements to make:

**Structure improvements (based on common patterns from top projects):**
- Keep the existing badge row (Tests, Benchmark, Codecov, License, MATLAB, Octave)
- Improve the one-liner tagline if research suggests a punchier format
- Ensure hero image is prominent (already have docs/images/dashboard.png)
- Add a "Features at a glance" section with compact feature highlights (consider using a feature grid or icon-style bullets if research supports it)
- Add a Table of Contents if research shows top projects use one
- Consider a "Why FastSense?" or "Highlights" section before diving into pillars
- Add a "Contributing" section (even brief) if research shows this is standard
- Consider a "Used by" or "Built with" or "Acknowledgments" section

**Content improvements:**
- The Quick Start is good — keep it, possibly tighten
- The Five Pillars section is comprehensive but long — consider whether research suggests condensing the README and linking to docs for details, or if full feature showcase in README is the norm
- Performance benchmarks in README are a strength — keep and possibly make more visually prominent
- Update widget count from "8 widget types" to actual current count (fastsense, number, status, gauge, table, text, timeline, rawaxes, barchart, heatmap, histogram, scatter, image, multistatus, eventtimeline, group, divider, markdown, iconcard, chipbar, sparkline = 21 types)
- Add mention of newer features: collapsible sections, multi-page navigation, detachable widgets, info tooltips, threshold mini-labels
- Reference the 40+ examples more prominently

**Preserve:**
- All existing badge links
- Citation section
- License section
- Wiki documentation links
- The hero image reference

**Do NOT:**
- Add emojis unless research overwhelmingly shows top MATLAB projects use them
- Remove any existing functional information
- Change the repo URL or badge URLs
- Over-engineer with HTML tables for layout (keep it readable as raw markdown)

Read the research file first, then implement the top patterns that fit FastSense's identity as a serious engineering tool.
  </action>
  <verify>
    <automated>test -f README.md && wc -l README.md | awk '{if ($1 > 150) print "PASS"; else print "FAIL"}'</automated>
  </verify>
  <done>README.md rewritten with research-backed improvements: better structure, updated feature counts, modern best practices, while preserving all existing links and references</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Researched 8-12 top project READMEs and rewrote FastSense README.md based on findings</what-built>
  <how-to-verify>
    1. Review .planning/quick/260405-ovf-update-project-readme-based-on-research-/README-RESEARCH.md for research quality
    2. Open README.md and review the rewrite
    3. Check that all badge links still work
    4. Verify the structure feels right for a MATLAB engineering audience
    5. Confirm no information was lost from the original
    6. Preview on GitHub if desired: the markdown should render well
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues to fix</resume-signal>
</task>

</tasks>

<verification>
- README-RESEARCH.md contains analysis of 8+ projects
- README.md has been rewritten with research-backed patterns
- All original badge URLs preserved
- Widget count and feature list updated to current state
- No broken markdown syntax
</verification>

<success_criteria>
- Research covers 8+ highly-starred projects with structured analysis
- README.md incorporates at least 5 identified best practices
- Feature counts and descriptions reflect current project state (21 widget types, collapsible sections, multi-page, detachable widgets, etc.)
- README renders correctly as markdown
- Human approves the final result
</success_criteria>

<output>
After completion, create `.planning/quick/260405-ovf-update-project-readme-based-on-research-/260405-ovf-SUMMARY.md`
</output>
