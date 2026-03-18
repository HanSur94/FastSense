# LLM-Powered Wiki Generation — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a CI workflow that uses Claude to auto-generate non-API wiki pages from source code, submitting changes as PRs for human review.

**Architecture:** A Python script (`generate_wiki.py`) maps source file changes to wiki pages, assembles context from MATLAB sources and examples, calls the Anthropic API to generate/update markdown, and writes results to `wiki/`. GitHub Actions creates a PR for review. A separate sync workflow pushes merged wiki content to the wiki git repo.

**Tech Stack:** Python 3.12, `anthropic` SDK, GitHub Actions, GitHub CLI (`gh`)

**Spec:** `docs/superpowers/specs/2026-03-18-llm-wiki-generation-design.md`

---

## Chunk 1: Wiki Migration & Sync Workflow

**Important:** Tasks 1–3 must be committed together (or in order 3 → 2 → 1) to avoid a broken state where the old `generate-docs.yml` clones the wiki repo on top of a tracked `wiki/` directory.

### Task 1: Track wiki/ in the main repo

**Files:**
- Modify: `wiki/` (add to git tracking)
- Modify: `.gitignore` (if wiki/ is listed, remove it)

- [ ] **Step 1: Check if wiki/ is in .gitignore**

Run: `grep -n "wiki" .gitignore` (if .gitignore exists)
Expected: Possibly no match. If it matches, remove the line.

- [ ] **Step 2: Add wiki/ to git tracking**

```bash
git add wiki/
```

- [ ] **Step 3: Commit the migration**

```bash
git commit -m "docs: track wiki/ content in main repo for PR-based review"
```

### Task 2: Create sync-wiki.yml

**Files:**
- Create: `.github/workflows/sync-wiki.yml`

- [ ] **Step 1: Write the sync workflow**

```yaml
name: Sync Wiki

on:
  push:
    branches: [main]
    paths:
      - 'wiki/**'

permissions:
  contents: write

jobs:
  sync:
    name: Sync wiki to GitHub Wiki repo
    runs-on: ubuntu-latest
    steps:
      - name: Checkout main repo
        uses: actions/checkout@v4

      - name: Clone wiki repo
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/HanSur94/FastSense.wiki.git" wiki-remote

      - name: Copy wiki content
        run: |
          cp wiki/*.md wiki-remote/

      - name: Push to wiki repo
        run: |
          cd wiki-remote
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          if git diff --cached --quiet; then
            echo "No wiki changes to sync"
          else
            git commit -m "docs: sync wiki from main repo"
            git push
            echo "Wiki synced successfully"
          fi
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/sync-wiki.yml
git commit -m "ci: add sync-wiki workflow to push wiki/ to wiki repo on merge"
```

### Task 3: Update generate-docs.yml to write to main repo

**Files:**
- Modify: `.github/workflows/generate-docs.yml`

The current workflow clones the wiki repo and pushes directly. Update it to write API docs to `wiki/` in the main repo and commit to `main` instead. The new `sync-wiki.yml` handles pushing to the wiki repo.

- [ ] **Step 1: Rewrite generate-docs.yml**

```yaml
name: Generate API Docs

on:
  push:
    branches: [main]
    paths:
      - 'libs/**/*.m'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  generate:
    name: Generate API Documentation
    runs-on: ubuntu-latest
    steps:
      - name: Checkout main repo
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Generate API docs
        run: python3 scripts/generate_api_docs.py

      - name: Commit updated wiki
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add wiki/
          if git diff --cached --quiet; then
            echo "No documentation changes"
          else
            git commit -m "docs: auto-update API reference from source code"
            git push
            echo "Wiki API docs updated in main repo"
          fi
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/generate-docs.yml
git commit -m "ci: update generate-docs to write to main repo wiki/ instead of pushing to wiki repo directly"
```

### Task 3b: Update wiki-links.yml to use main repo wiki/

**Files:**
- Modify: `.github/workflows/wiki-links.yml`

After migration, `wiki/` in the main repo is the source of truth. Update the link checker to read from there instead of cloning the remote wiki repo.

- [ ] **Step 1: Rewrite wiki-links.yml**

```yaml
name: Wiki Link Check

on:
  push:
    branches: [main]
    paths:
      - 'wiki/**'
  schedule:
    - cron: '0 6 * * 1'
  workflow_dispatch:

jobs:
  check-links:
    name: Check Wiki Links
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check markdown links
        uses: lycheeverse/lychee-action@v2
        with:
          args: >-
            --no-progress
            --exclude-loopback
            --exclude 'github.com/HanSur94/FastSense/wiki'
            --suggest
            wiki/*.md
          fail: true
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/wiki-links.yml
git commit -m "ci: update wiki-links to check main repo wiki/ instead of cloning remote"
```

---

## Chunk 2: Core Generation Script — Page Mapping & Context Assembly

### Task 4: Create generate_wiki.py with page mapping and CLI

**Files:**
- Create: `scripts/generate_wiki.py`

This task creates the script skeleton with the page mapping config, CLI argument parsing, change detection logic, and context assembly — everything except the actual LLM call (Task 6).

- [ ] **Step 1: Write the script with page mapping, CLI, and context assembly**

```python
#!/usr/bin/env python3
"""Generate wiki pages from MATLAB source code using Claude.

Maps source file changes to wiki pages, assembles context from MATLAB
sources and examples, calls the Anthropic API to generate/update markdown.

Usage:
    python3 scripts/generate_wiki.py --changed-files libs/FastSense/FastSense.m libs/Dashboard/DashboardEngine.m
    python3 scripts/generate_wiki.py --all
"""

import argparse
import difflib
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Project root detection
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
LIBS_DIR = PROJECT_ROOT / "libs"
WIKI_DIR = PROJECT_ROOT / "wiki"
EXAMPLES_DIR = PROJECT_ROOT / "examples"

AUTO_GENERATED_NOTICE = (
    "<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py"
    " — do not edit manually -->\n"
)

# ---------------------------------------------------------------------------
# Page mapping: source dirs -> wiki pages
# ---------------------------------------------------------------------------

# Each entry: (wiki_filename, page_type, source_dirs, example_patterns)
# page_type: "overview" | "architecture" | "guide" | "usecase" | "examples"
# source_dirs: list of lib subdirectory names whose .m files form the context
# example_patterns: list of glob patterns matching relevant example files

PAGE_MAP = [
    {
        "filename": "Home.md",
        "page_type": "overview",
        "source_dirs": ["FastSense", "Dashboard", "SensorThreshold", "EventDetection", "WebBridge"],
        "example_patterns": ["example_basic.m", "example_dashboard.m", "example_sensor_threshold.m"],
    },
    {
        "filename": "Architecture.md",
        "page_type": "architecture",
        "source_dirs": ["FastSense", "Dashboard", "SensorThreshold", "EventDetection"],
        "example_patterns": [],
    },
    {
        "filename": "Getting-Started.md",
        "page_type": "guide",
        "source_dirs": ["FastSense"],
        "example_patterns": ["example_basic.m", "example_multi.m", "example_datetime.m", "example_themes.m"],
    },
    {
        "filename": "Performance.md",
        "page_type": "guide",
        "source_dirs": ["FastSense"],
        "example_patterns": ["example_100M.m", "example_stress_test.m", "example_lttb_vs_minmax.m"],
    },
    {
        "filename": "MEX-Acceleration.md",
        "page_type": "guide",
        "source_dirs": ["FastSense"],
        "example_patterns": [],
    },
    {
        "filename": "Dashboard-Engine-Guide.md",
        "page_type": "guide",
        "source_dirs": ["Dashboard"],
        "example_patterns": [
            "example_dashboard.m", "example_dashboard_engine.m",
            "example_dashboard_9tile.m", "example_dashboard_all_widgets.m",
            "example_dashboard_live.m",
        ],
    },
    {
        "filename": "Event-Detection-Guide.md",
        "page_type": "guide",
        "source_dirs": ["EventDetection"],
        "example_patterns": [
            "example_event_detection_live.m", "example_event_viewer_from_file.m",
            "example_live_pipeline.m",
        ],
    },
    {
        "filename": "Use-Case:-Multi-Sensor-Shared-Threshold.md",
        "page_type": "usecase",
        "source_dirs": ["SensorThreshold"],
        "example_patterns": [
            "example_sensor_threshold.m", "example_sensor_multi_state.m",
            "example_sensor_registry.m", "example_multi_sensor_linked.m",
        ],
    },
    {
        "filename": "WebBridge-Guide.md",
        "page_type": "guide",
        "source_dirs": ["WebBridge"],
        "example_patterns": [],
    },
    {
        "filename": "Live-Mode-Guide.md",
        "page_type": "guide",
        "source_dirs": ["FastSense"],
        "example_patterns": ["example_dashboard_live.m", "example_live_pipeline.m"],
    },
    {
        "filename": "Datetime-Guide.md",
        "page_type": "guide",
        "source_dirs": ["FastSense"],
        "example_patterns": ["example_datetime.m", "example_sensor_detail_datetime.m"],
    },
    {
        "filename": "Examples.md",
        "page_type": "examples",
        "source_dirs": [],
        "example_patterns": ["example_*.m"],
    },
]

# Aggregate pages regenerate when any lib changes
AGGREGATE_PAGES = {"Home.md", "Architecture.md"}

# Pages excluded from generation (owned by other tools or manually maintained)
EXCLUDED_PAGES = {"_Sidebar.md", "Installation.md"}
EXCLUDED_PREFIXES = ("API-Reference:-",)


# ---------------------------------------------------------------------------
# Change detection
# ---------------------------------------------------------------------------

def detect_affected_pages(changed_files: list[str]) -> list[dict]:
    """Map changed source files to wiki pages that need regeneration."""
    if not changed_files:
        return []

    # Determine which source dirs were touched
    touched_dirs: set[str] = set()
    touched_examples = False

    for f in changed_files:
        p = Path(f)
        parts = p.parts
        if len(parts) >= 2 and parts[0] == "libs":
            touched_dirs.add(parts[1])
        if len(parts) >= 1 and parts[0] == "examples":
            touched_examples = True

    affected = []
    for page in PAGE_MAP:
        # Safety: skip excluded pages
        fn = page["filename"]
        if fn in EXCLUDED_PAGES or any(fn.startswith(p) for p in EXCLUDED_PREFIXES):
            continue

        # Aggregate pages: any lib change triggers regen
        if page["filename"] in AGGREGATE_PAGES and touched_dirs:
            affected.append(page)
            continue

        # Check if any of this page's source dirs were touched
        page_dirs = set(page.get("source_dirs", []))
        if page_dirs & touched_dirs:
            affected.append(page)
            continue

        # Examples page: any example change triggers regen
        if page["page_type"] == "examples" and touched_examples:
            affected.append(page)
            continue

        # Guide pages that use examples: regen if examples touched
        if touched_examples and page.get("example_patterns"):
            affected.append(page)
            continue

    # Deduplicate (a page could match multiple rules)
    seen = set()
    unique = []
    for page in affected:
        if page["filename"] not in seen:
            seen.add(page["filename"])
            unique.append(page)

    return unique


# ---------------------------------------------------------------------------
# Context assembly
# ---------------------------------------------------------------------------

def _import_parser():
    """Import parse_classdef from generate_api_docs.py (once)."""
    sys.path.insert(0, str(SCRIPT_DIR))
    from generate_api_docs import parse_classdef
    return parse_classdef

_parse_classdef = None

def extract_public_surface(filepath: Path) -> str:
    """Extract public API surface from a MATLAB .m file.

    Returns a trimmed version with classdef, public properties,
    and method signatures + help text (no implementation bodies).

    Reuses parsing approach from generate_api_docs.py.
    """
    global _parse_classdef
    if _parse_classdef is None:
        _parse_classdef = _import_parser()

    cls = _parse_classdef(filepath)
    if cls is None:
        # Not a classdef — return the raw file (likely a function file)
        return filepath.read_text(encoding="utf-8", errors="replace")

    lines = []
    lines.append(f"classdef {cls.name}" + (f" < {cls.parent}" if cls.parent else ""))
    if cls.help_text:
        for hl in cls.help_text.split("\n"):
            lines.append(f"    % {hl}")
    lines.append("")

    if cls.properties:
        lines.append("    properties (Public)")
        for prop in cls.properties:
            comment = f"  % {prop.comment}" if prop.comment else ""
            default = f" = {prop.default}" if prop.default else ""
            lines.append(f"        {prop.name}{default}{comment}")
        lines.append("    end")
        lines.append("")

    all_methods = cls.methods + cls.static_methods
    if all_methods:
        lines.append("    methods (Public)")
        for m in all_methods:
            prefix = "[static] " if m.is_static else ""
            lines.append(f"        function {prefix}{m.signature}")
            if m.help_text:
                for hl in m.help_text.split("\n"):
                    lines.append(f"            % {hl}")
            lines.append("        end")
            lines.append("")
        lines.append("    end")

    lines.append("end")
    return "\n".join(lines)


def assemble_context(page: dict) -> dict:
    """Assemble context payload for a wiki page.

    Returns a dict with:
        - source_context: str (trimmed .m files)
        - example_context: str (full example scripts)
        - current_page: str (existing wiki page content, or "")
        - sidebar: str (_Sidebar.md content)
        - page_type: str
        - filename: str
    """
    # 1. Source files — trimmed to public API surface
    source_parts = []
    for dir_name in page.get("source_dirs", []):
        lib_dir = LIBS_DIR / dir_name
        if not lib_dir.is_dir():
            continue
        for mfile in sorted(lib_dir.glob("*.m")):
            try:
                surface = extract_public_surface(mfile)
                source_parts.append(f"--- {mfile.relative_to(PROJECT_ROOT)} ---\n{surface}")
            except Exception as e:
                print(f"  Warning: Failed to parse {mfile}: {e}", file=sys.stderr)

    # 2. Example scripts — full content
    example_parts = []
    for pattern in page.get("example_patterns", []):
        for efile in sorted(EXAMPLES_DIR.glob(pattern)):
            content = efile.read_text(encoding="utf-8", errors="replace")
            example_parts.append(f"--- {efile.relative_to(PROJECT_ROOT)} ---\n{content}")

    # 3. Current wiki page
    wiki_path = WIKI_DIR / page["filename"]
    current_page = ""
    if wiki_path.exists():
        current_page = wiki_path.read_text(encoding="utf-8", errors="replace")

    # 4. Sidebar
    sidebar_path = WIKI_DIR / "_Sidebar.md"
    sidebar = ""
    if sidebar_path.exists():
        sidebar = sidebar_path.read_text(encoding="utf-8", errors="replace")

    # Token budget enforcement: drop examples if context is too large
    TOKEN_BUDGET = 50_000
    source_text = "\n\n".join(source_parts)
    example_text = "\n\n".join(example_parts)
    est_tokens = (len(source_text) + len(example_text) + len(current_page) + len(sidebar)) // 4

    if est_tokens > TOKEN_BUDGET and example_parts:
        print(f"  Context exceeds budget (~{est_tokens:,} tokens), trimming examples...")
        # Drop examples from the end (least specific) until under budget
        while example_parts and est_tokens > TOKEN_BUDGET:
            dropped = example_parts.pop()
            example_text = "\n\n".join(example_parts)
            est_tokens = (len(source_text) + len(example_text) + len(current_page) + len(sidebar)) // 4

    return {
        "source_context": source_text,
        "example_context": example_text,
        "current_page": current_page,
        "sidebar": sidebar,
        "page_type": page["page_type"],
        "filename": page["filename"],
    }


# ---------------------------------------------------------------------------
# Quality controls
# ---------------------------------------------------------------------------

def compute_similarity(old: str, new: str) -> float:
    """Compute similarity ratio between two strings using SequenceMatcher."""
    if not old and not new:
        return 1.0
    return difflib.SequenceMatcher(None, old, new).ratio()


def validate_wiki_links(content: str, existing_pages: set[str]) -> list[str]:
    """Check that all [[wiki-links]] reference existing pages.

    Returns list of warning messages for broken links.
    """
    warnings = []
    # Match [[Display Text|Page Name]] or [[Page Name]]
    for match in re.finditer(r"\[\[([^\]]+)\]\]", content):
        link_text = match.group(1)
        # If it has a pipe, the page name is after the pipe
        if "|" in link_text:
            page_name = link_text.split("|", 1)[1].strip()
        else:
            page_name = link_text.strip()

        # Convert to filename: spaces -> hyphens, add .md
        page_file = page_name.replace(" ", "-") + ".md"

        if page_file not in existing_pages:
            warnings.append(f"Broken wiki link: [[{link_text}]] -> {page_file}")

    return warnings


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(description="Generate wiki pages using Claude")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--changed-files",
        nargs="+",
        help="List of changed source files to determine which pages to regenerate",
    )
    group.add_argument(
        "--all",
        action="store_true",
        help="Regenerate all wiki pages (full refresh)",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    print("FastPlot Wiki Generator")
    print(f"Project root: {PROJECT_ROOT}")
    print()

    WIKI_DIR.mkdir(parents=True, exist_ok=True)

    # Determine pages to regenerate
    if args.all:
        pages = PAGE_MAP
        print(f"Full refresh: regenerating all {len(pages)} pages")
    else:
        pages = detect_affected_pages(args.changed_files)
        if not pages:
            print("No wiki pages affected by the changed files.")
            return
        print(f"Changed files affect {len(pages)} wiki page(s):")
        for p in pages:
            print(f"  - {p['filename']}")

    print()

    # Collect existing wiki page names for link validation
    existing_pages = {f.name for f in WIKI_DIR.glob("*.md")}
    # Add new pages that will be created
    for p in PAGE_MAP:
        existing_pages.add(p["filename"])

    results = []  # (filename, status, warnings)
    for page in pages:
        print(f"[{page['filename']}]")
        ctx = assemble_context(page)

        # Check context size
        total_chars = len(ctx["source_context"]) + len(ctx["example_context"])
        est_tokens = total_chars // 4  # rough estimate
        print(f"  Context: ~{est_tokens:,} tokens (source + examples)")

        # Call LLM to generate page
        try:
            new_content = generate_page_with_llm(ctx)
        except Exception as e:
            print(f"  ERROR: {e}", file=sys.stderr)
            results.append((page["filename"], "failed", [str(e)]))
            continue

        # Quality checks
        warnings = []
        similarity = compute_similarity(ctx["current_page"], new_content)

        if similarity > 0.95:
            print(f"  Skipped: content unchanged (similarity {similarity:.1%})")
            results.append((page["filename"], "skipped", []))
            continue

        if similarity < 0.2:
            msg = f"Large diff warning: similarity {similarity:.1%} — review carefully"
            warnings.append(msg)
            print(f"  WARNING: {msg}")

        # Link validation
        link_warnings = validate_wiki_links(new_content, existing_pages)
        warnings.extend(link_warnings)
        for w in link_warnings:
            print(f"  WARNING: {w}")

        # Write the page
        wiki_path = WIKI_DIR / page["filename"]
        wiki_path.write_text(new_content, encoding="utf-8")
        print(f"  Written: {wiki_path.relative_to(PROJECT_ROOT)}")
        results.append((page["filename"], "updated", warnings))

    # Summary
    print()
    print("--- Summary ---")
    updated = [r for r in results if r[1] == "updated"]
    skipped = [r for r in results if r[1] == "skipped"]
    failed = [r for r in results if r[1] == "failed"]
    print(f"Updated: {len(updated)}, Skipped: {len(skipped)}, Failed: {len(failed)}")

    # Write results to a file for the workflow to read
    summary_path = PROJECT_ROOT / "wiki-gen-summary.md"
    summary_lines = ["## Wiki Auto-Update\n"]
    if updated:
        summary_lines.append("**Pages regenerated:**")
        for fname, _, warns in updated:
            summary_lines.append(f"- {fname}")
            for w in warns:
                summary_lines.append(f"  - ⚠️ {w}")
        summary_lines.append("")
    if failed:
        summary_lines.append("**Failed pages (kept existing content):**")
        for fname, _, errs in failed:
            summary_lines.append(f"- {fname}: {errs[0] if errs else 'unknown error'}")
        summary_lines.append("")
    summary_lines.append("⚠️ Review carefully — LLM-generated content may contain inaccuracies.")
    summary_path.write_text("\n".join(summary_lines), encoding="utf-8")

    # Exit with error if all pages failed
    if failed and not updated:
        print("All pages failed — no PR will be created.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

Note: `generate_page_with_llm()` is defined in Task 6. For now the script can be tested with a stub.

- [ ] **Step 2: Verify the script parses arguments and detects affected pages**

Run: `cd /Users/hannessuhr/FastPlot && python3 scripts/generate_wiki.py --changed-files libs/Dashboard/DashboardEngine.m 2>&1 | head -20`

Expected: Lists Dashboard-Engine-Guide.md and Home.md as affected pages, then errors on missing `generate_page_with_llm`.

- [ ] **Step 3: Commit**

```bash
git add scripts/generate_wiki.py
git commit -m "feat: add generate_wiki.py with page mapping and context assembly"
```

---

## Chunk 3: LLM Integration — Prompts & Generation

### Task 5: Add prompt templates

This adds the system prompts for each page type directly in `generate_wiki.py`. Each page type gets a tailored prompt that guides Claude to produce the right style of documentation.

**Files:**
- Modify: `scripts/generate_wiki.py` (add prompt constants after the PAGE_MAP section)

- [ ] **Step 1: Add the prompt templates to generate_wiki.py**

Insert after the `EXCLUDED_PREFIXES` line. The prompts are defined as a dict mapping page_type to system prompt string:

```python
# ---------------------------------------------------------------------------
# Prompt templates
# ---------------------------------------------------------------------------

SHARED_INSTRUCTIONS = """
CRITICAL RULES:
- Do NOT invent features, classes, methods, or parameters that do not exist in the provided source code.
- Only document what you can verify from the source files provided.
- Use MATLAB syntax highlighting in code blocks (```matlab).
- Use [[Page Name]] wiki link syntax for cross-references (see the sidebar for valid page names).
- Start the page with the auto-generated notice exactly as shown.
- Write in a technical, concise style. No marketing language.
- Every code example must be runnable if copy-pasted (given proper setup).

AUTO-GENERATED NOTICE (must be the first line):
<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->
"""

PROMPTS = {
    "overview": SHARED_INSTRUCTIONS + """
PAGE TYPE: Project Overview (Home page)

Generate the main wiki home page for the FastPlot MATLAB library.
- Start with a one-line description, then key metrics table (pull exact numbers from source/benchmarks).
- Summarize each library component (FastSense, Dashboard, SensorThreshold, EventDetection, WebBridge).
- Include a Quick Start section with a minimal runnable code example from the examples provided.
- End with links to the Getting Started guide and API reference pages.
- Keep the overall structure similar to the existing page if one is provided.
""",

    "architecture": SHARED_INSTRUCTIONS + """
PAGE TYPE: Architecture Overview

Generate a technical architecture page for the FastPlot library.
- Explain the high-level design: render pipeline, zoom/pan callbacks, data flow.
- Describe the class hierarchy and how components interact.
- Document the downsampling strategy (MinMax vs LTTB, pyramid cache).
- Explain MEX acceleration and the fallback mechanism.
- Use text-based diagrams or bullet-point flows (no image references).
- Keep the overall structure similar to the existing page if one is provided.
""",

    "guide": SHARED_INSTRUCTIONS + """
PAGE TYPE: Feature Guide

Generate a tutorial-style guide for the specified feature.
- Start with a brief overview of what the feature does and when to use it.
- Walk through usage step by step with code examples from the provided example scripts.
- Document key classes, their properties, and methods (reference the API pages, don't duplicate them).
- Include common patterns, tips, and gotchas.
- Keep the overall structure similar to the existing page if one is provided.
""",

    "usecase": SHARED_INSTRUCTIONS + """
PAGE TYPE: Use Case Walkthrough

Generate a problem → solution walkthrough.
- Start with the problem statement: what scenario does this solve?
- Walk through the solution step by step with complete, runnable code.
- Draw code examples from the provided example scripts.
- Explain the key decisions and trade-offs.
- Keep the overall structure similar to the existing page if one is provided.
""",

    "examples": SHARED_INSTRUCTIONS + """
PAGE TYPE: Examples Index

Generate an index page listing all example scripts.
- Group examples by category (basic, dashboard, sensors, events, etc.).
- For each example, include: filename, one-line description (from the file's first comment line).
- Use a table or bulleted list format.
- Link to relevant guide pages where applicable.
""",
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/generate_wiki.py
git commit -m "feat: add prompt templates for each wiki page type"
```

### Task 6: Add Claude API integration

**Files:**
- Modify: `scripts/generate_wiki.py` (add `generate_page_with_llm` function)

- [ ] **Step 1: Add the LLM generation function**

Insert after the prompt templates section, before the quality controls section:

```python
# ---------------------------------------------------------------------------
# LLM generation
# ---------------------------------------------------------------------------

def generate_page_with_llm(ctx: dict) -> str:
    """Call Claude to generate a wiki page.

    Args:
        ctx: Context dict from assemble_context() with keys:
            source_context, example_context, current_page, sidebar,
            page_type, filename

    Returns:
        Generated markdown content as a string.
    """
    import anthropic

    client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY from env

    system_prompt = PROMPTS.get(ctx["page_type"], PROMPTS["guide"])

    # Build user message with all context
    user_parts = []
    user_parts.append(f"Generate the wiki page: {ctx['filename']}\n")

    if ctx["current_page"]:
        user_parts.append("=== CURRENT PAGE CONTENT (use as structural template) ===")
        user_parts.append(ctx["current_page"])
        user_parts.append("=== END CURRENT PAGE ===\n")

    if ctx["sidebar"]:
        user_parts.append("=== WIKI SIDEBAR (for link references) ===")
        user_parts.append(ctx["sidebar"])
        user_parts.append("=== END SIDEBAR ===\n")

    if ctx["source_context"]:
        user_parts.append("=== SOURCE CODE (public API surface) ===")
        user_parts.append(ctx["source_context"])
        user_parts.append("=== END SOURCE CODE ===\n")

    if ctx["example_context"]:
        user_parts.append("=== EXAMPLE SCRIPTS ===")
        user_parts.append(ctx["example_context"])
        user_parts.append("=== END EXAMPLES ===\n")

    user_parts.append(
        "Generate the complete wiki page now. Output ONLY the markdown content, "
        "starting with the auto-generated notice comment."
    )

    user_message = "\n".join(user_parts)

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=system_prompt,
        messages=[{"role": "user", "content": user_message}],
    )

    # Extract text content
    content = response.content[0].text

    # Strip any markdown code fence wrapper (Claude sometimes wraps output)
    if content.startswith("```markdown"):
        content = content[len("```markdown"):].strip()
    elif content.startswith("```"):
        content = content[3:].strip()
    if content.endswith("```"):
        content = content[:-3].strip()

    # Ensure trailing newline
    if not content.endswith("\n"):
        content += "\n"

    return content
```

- [ ] **Step 2: Test locally with a single page (requires ANTHROPIC_API_KEY)**

Run: `cd /Users/hannessuhr/FastPlot && ANTHROPIC_API_KEY=<key> python3 scripts/generate_wiki.py --changed-files examples/example_basic.m 2>&1 | head -30`

Expected: Shows context assembly, calls Claude, writes Examples.md and Getting-Started.md to wiki/.

- [ ] **Step 3: Commit**

```bash
git add scripts/generate_wiki.py
git commit -m "feat: add Claude API integration for wiki page generation"
```

---

## Chunk 4: GitHub Actions Workflow

### Task 7: Create generate-wiki.yml

**Files:**
- Create: `.github/workflows/generate-wiki.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: Generate Wiki Pages

on:
  push:
    branches: [main]
    paths:
      - 'libs/**'
      - 'examples/**'
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  generate:
    name: Generate Wiki Pages with LLM
    runs-on: ubuntu-latest
    if: github.actor != 'github-actions[bot]'
    steps:
      - name: Checkout main repo
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: pip install anthropic

      - name: Detect changed files
        id: changes
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            echo "mode=all" >> "$GITHUB_OUTPUT"
          else
            BEFORE="${{ github.event.before }}"
            if [ -z "$BEFORE" ] || [ "$BEFORE" = "0000000000000000000000000000000000000000" ]; then
              echo "mode=all" >> "$GITHUB_OUTPUT"
            else
              CHANGED=$(git diff "$BEFORE" "${{ github.sha }}" --name-only -- libs/ examples/ || echo "")
              if [ -z "$CHANGED" ]; then
                echo "mode=none" >> "$GITHUB_OUTPUT"
              else
                echo "mode=diff" >> "$GITHUB_OUTPUT"
                echo "$CHANGED" > changed_files.txt
                echo "Changed files:"
                cat changed_files.txt
              fi
            fi
          fi

      - name: Generate wiki pages
        if: steps.changes.outputs.mode != 'none'
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          if [ "${{ steps.changes.outputs.mode }}" = "all" ]; then
            python3 scripts/generate_wiki.py --all
          else
            mapfile -t CHANGED < changed_files.txt
            python3 scripts/generate_wiki.py --changed-files "${CHANGED[@]}"
          fi

      - name: Create pull request
        if: steps.changes.outputs.mode != 'none'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Check if wiki/ has changes
          if git diff --quiet wiki/; then
            echo "No wiki changes to commit"
            exit 0
          fi

          SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)
          BRANCH="wiki-update/${SHORT_SHA}"

          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          git checkout -b "$BRANCH"
          git add wiki/
          git commit -m "docs: update wiki pages [auto-generated]"
          git push origin "$BRANCH"

          # Read the summary file for the PR body
          if [ -f wiki-gen-summary.md ]; then
            PR_BODY=$(cat wiki-gen-summary.md)
          else
            PR_BODY="Wiki pages auto-updated by LLM."
          fi

          PR_BODY="${PR_BODY}

Triggered by: commit ${{ github.sha }}"

          gh pr create \
            --title "docs: update wiki pages [auto-generated]" \
            --body "$PR_BODY" \
            --base main \
            --head "$BRANCH"
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/generate-wiki.yml
git commit -m "ci: add generate-wiki workflow with LLM-powered page generation and PR creation"
```

### Task 8: Final integration verification

- [ ] **Step 1: Verify all files exist and are consistent**

Run:
```bash
ls -la scripts/generate_wiki.py .github/workflows/generate-wiki.yml .github/workflows/sync-wiki.yml
```
Expected: All three files exist.

- [ ] **Step 2: Dry-run the script with --all to check for import/syntax errors**

Run: `cd /Users/hannessuhr/FastPlot && python3 -c "import scripts.generate_wiki" 2>&1 || python3 scripts/generate_wiki.py --all 2>&1 | head -5`

Expected: Script starts, shows "Full refresh: regenerating all N pages", then fails on missing ANTHROPIC_API_KEY (expected in local dev).

- [ ] **Step 3: Commit all remaining changes**

```bash
git add -A
git commit -m "feat: complete LLM-powered wiki generation pipeline"
```
