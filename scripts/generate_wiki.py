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

TOKEN_BUDGET = 50_000

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
        if p.is_absolute():
            try:
                p = p.relative_to(PROJECT_ROOT)
            except ValueError:
                continue  # file outside project root, skip
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
    """Assemble context payload for a wiki page."""
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
    source_text = "\n\n".join(source_parts)
    example_text = "\n\n".join(example_parts)
    est_tokens = (len(source_text) + len(example_text) + len(current_page) + len(sidebar)) // 4

    if est_tokens > TOKEN_BUDGET and example_parts:
        print(f"  Context exceeds budget (~{est_tokens:,} tokens), trimming examples...")
        while example_parts and est_tokens > TOKEN_BUDGET:
            example_parts.pop()
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
# LLM generation (placeholder — implemented in Task 6)
# ---------------------------------------------------------------------------

def generate_page_with_llm(ctx: dict) -> str:
    """Call Claude to generate a wiki page. Placeholder for Task 6."""
    raise NotImplementedError("LLM generation not yet implemented — see Task 6")


# ---------------------------------------------------------------------------
# Quality controls
# ---------------------------------------------------------------------------

def compute_similarity(old: str, new: str) -> float:
    """Compute similarity ratio between two strings using SequenceMatcher."""
    if not old and not new:
        return 1.0
    return difflib.SequenceMatcher(None, old, new).ratio()


def validate_wiki_links(content: str, existing_pages: set[str]) -> list[str]:
    """Check that all [[wiki-links]] reference existing pages."""
    warnings = []
    for match in re.finditer(r"\[\[([^\]]+)\]\]", content):
        link_text = match.group(1)
        if "|" in link_text:
            page_name = link_text.split("|", 1)[1].strip()
        else:
            page_name = link_text.strip()

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
        pages = [
            p for p in PAGE_MAP
            if p["filename"] not in EXCLUDED_PAGES
            and not any(p["filename"].startswith(pfx) for pfx in EXCLUDED_PREFIXES)
        ]
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
    for p in PAGE_MAP:
        existing_pages.add(p["filename"])

    results = []
    for page in pages:
        print(f"[{page['filename']}]")
        ctx = assemble_context(page)

        total_chars = len(ctx["source_context"]) + len(ctx["example_context"])
        est_tokens = total_chars // 4
        print(f"  Context: ~{est_tokens:,} tokens (source + examples)")

        try:
            new_content = generate_page_with_llm(ctx)
        except Exception as e:
            print(f"  ERROR: {e}", file=sys.stderr)
            results.append((page["filename"], "failed", [str(e)]))
            continue

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

        link_warnings = validate_wiki_links(new_content, existing_pages)
        warnings.extend(link_warnings)
        for w in link_warnings:
            print(f"  WARNING: {w}")

        # Ensure auto-generated notice is present (safety net — LLM should include it)
        if not new_content.startswith("<!-- AUTO-GENERATED"):
            new_content = AUTO_GENERATED_NOTICE + "\n" + new_content

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

    # Write results for workflow to read
    summary_path = PROJECT_ROOT / "wiki-gen-summary.md"
    summary_lines = ["## Wiki Auto-Update"]
    if updated:
        summary_lines.append("**Pages regenerated:**")
        for fname, _, warns in updated:
            summary_lines.append(f"- {fname}")
            for w in warns:
                summary_lines.append(f"  - {w}")
        summary_lines.append("")
    if failed:
        summary_lines.append("**Failed pages (kept existing content):**")
        for fname, _, errs in failed:
            summary_lines.append(f"- {fname}: {errs[0] if errs else 'unknown error'}")
        summary_lines.append("")
    summary_lines.append("Review carefully — LLM-generated content may contain inaccuracies.")
    summary_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

    if failed and not updated:
        print("All pages failed — no PR will be created.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
