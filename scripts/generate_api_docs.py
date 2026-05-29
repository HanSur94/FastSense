#!/usr/bin/env python3
"""Generate wiki API reference pages from MATLAB classdef source files.

Parses .m files in libs/ to extract class definitions, properties, and
methods, then writes structured Markdown pages to wiki/.

Usage:
    python3 scripts/generate_api_docs.py
"""

import os
import re
import sys
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional

# ---------------------------------------------------------------------------
# Project root detection
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent

LIBS_DIR = PROJECT_ROOT / "libs"
WIKI_DIR = PROJECT_ROOT / "wiki"

AUTO_GENERATED_NOTICE = (
    "<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py"
    " — do not edit manually -->\n"
)

# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class Property:
    name: str
    default: str
    comment: str


@dataclass
class Method:
    name: str
    signature: str
    help_text: str
    is_static: bool = False
    is_constructor: bool = False


@dataclass
class MatlabClass:
    name: str
    parent: str
    help_text: str
    properties: list = field(default_factory=list)
    methods: list = field(default_factory=list)
    static_methods: list = field(default_factory=list)
    filepath: str = ""


# ---------------------------------------------------------------------------
# MATLAB parser
# ---------------------------------------------------------------------------

def read_file(path: Path) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def parse_classdef(filepath: Path) -> Optional[MatlabClass]:
    """Parse a MATLAB .m file and return a MatlabClass or None if not a classdef."""
    text = read_file(filepath)
    lines = text.split("\n")

    # Find classdef line
    classdef_line = None
    classdef_idx = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("classdef "):
            classdef_line = stripped
            classdef_idx = i
            break

    if classdef_line is None:
        return None

    # Parse class name and parent
    # classdef ClassName < ParentClass
    # classdef ClassName
    # classdef (Sealed) ClassName < ParentClass
    m = re.match(
        r"classdef\s+(?:\([^)]*\)\s+)?(\w+)\s*(?:<\s*(\S+))?", classdef_line
    )
    if not m:
        return None

    class_name = m.group(1)
    parent = m.group(2) or ""

    # Extract class help text (% comments immediately after classdef)
    help_lines = []
    for i in range(classdef_idx + 1, len(lines)):
        stripped = lines[i].strip()
        if stripped.startswith("%"):
            # Remove leading % and optional single space
            content = stripped[1:]
            if content.startswith(" "):
                content = content[1:]
            help_lines.append(content)
        elif stripped == "":
            # Allow blank lines within the help block
            if help_lines:
                help_lines.append("")
        else:
            break

    # Trim trailing blank lines from help text
    while help_lines and help_lines[-1] == "":
        help_lines.pop()

    help_text = "\n".join(help_lines)

    # Parse property and method blocks
    properties = []
    methods = []
    static_methods = []

    i = classdef_idx + 1
    while i < len(lines):
        stripped = lines[i].strip()

        # Detect properties block
        prop_match = re.match(r"properties\s*(\([^)]*\))?\s*$", stripped)
        if prop_match:
            attrs = prop_match.group(1) or ""
            is_public = _is_public_access(attrs)
            i, block_props = _parse_properties_block(lines, i + 1, is_public)
            if is_public:
                properties.extend(block_props)
            continue

        # Detect methods block
        meth_match = re.match(r"methods\s*(\([^)]*\))?\s*$", stripped)
        if meth_match:
            attrs = meth_match.group(1) or ""
            is_private = _is_private_access(attrs)
            is_static = "Static" in attrs
            is_static_private = is_static and is_private
            i, block_methods = _parse_methods_block(
                lines, i + 1, class_name, skip=is_private and not is_static
            )
            if is_static and not is_static_private:
                for m in block_methods:
                    m.is_static = True
                static_methods.extend(block_methods)
            elif not is_private:
                methods.extend(block_methods)
            continue

        i += 1

    return MatlabClass(
        name=class_name,
        parent=parent,
        help_text=help_text,
        properties=properties,
        methods=methods,
        static_methods=static_methods,
        filepath=str(filepath),
    )


def _is_public_access(attrs: str) -> bool:
    """Check if a properties/methods attribute string indicates public access.

    Excludes properties with Access=private, Access=protected,
    SetAccess=private, or SetAccess=protected (internal storage).
    Also excludes Dependent properties (computed, not stored).
    """
    if not attrs:
        return True
    attrs_lower = attrs.lower()
    if re.search(r"\baccess\s*=\s*private\b", attrs_lower):
        return False
    if re.search(r"\baccess\s*=\s*protected\b", attrs_lower):
        return False
    if re.search(r"\bsetaccess\s*=\s*private\b", attrs_lower):
        return False
    if re.search(r"\bsetaccess\s*=\s*protected\b", attrs_lower):
        return False
    if re.search(r"\bdependent\b", attrs_lower):
        return False
    return True


def _is_private_access(attrs: str) -> bool:
    """Check if a methods attribute string indicates private access."""
    if not attrs:
        return False
    attrs_lower = attrs.lower()
    if re.search(r"\baccess\s*=\s*private\b", attrs_lower):
        return True
    if re.search(r"\baccess\s*=\s*protected\b", attrs_lower):
        return True
    return False


def _count_ends(line: str) -> int:
    """Count how many block-closing 'end' keywords appear on a line.

    Returns the net count of 'end' keywords that close blocks (not array
    indexing uses like x(end) or x(1:end-1)).

    Standalone 'end' on its own line -> 1
    Single-line constructs like 'if cond; stmt; end' -> 0 net (the if and end cancel)
    'end' inside parentheses/brackets -> 0 (array indexing)
    """
    stripped = line.strip()
    # Remove comments
    pct = _find_comment_pct(stripped)
    if pct >= 0:
        stripped = stripped[:pct].strip()

    if not stripped:
        return 0

    # Pure 'end' on its own line
    if stripped == "end":
        return 1

    # Check for single-line block constructs: if...end, for...end, etc.
    # These are net-zero: one keyword opens, one end closes
    # Pattern: keyword ... end (where end is at the very end of the line)
    # We need to detect these to avoid double-counting
    if re.match(r"(if|for|while|switch|try|parfor)\b", stripped):
        # Count ends at end of statement (after semicolons)
        # e.g., "if cond; stmt; end" or "for i=1:n; stmt; end"
        # Simple heuristic: if line starts with a block keyword and ends with 'end',
        # it's a single-line construct (net zero depth change)
        if re.search(r"\bend\s*$", stripped):
            return 0  # net zero: keyword + end cancel out

    return 0


def _is_block_end(line: str, block_indent: int) -> bool:
    """Check if this line is a standalone 'end' that closes a block at the given indent level."""
    # Get the indentation of this line
    stripped = line.lstrip()
    indent = len(line) - len(stripped)

    # Remove comment
    code = stripped
    pct = _find_comment_pct(code)
    if pct >= 0:
        code = code[:pct].strip()

    # Must be just 'end' (possibly followed by comment)
    if code != "end":
        return False

    # Must be at or before the expected indentation level
    return indent <= block_indent


def _find_block_end(lines, start, block_indent):
    """Find the line index of the 'end' that closes a block opened at block_indent.

    Uses indentation-aware matching: the closing 'end' must be at the same
    indentation as the opening keyword (properties/methods).
    """
    i = start
    while i < len(lines):
        if _is_block_end(lines[i], block_indent):
            return i
        i += 1
    return len(lines) - 1


def _parse_properties_block(lines, start, is_public):
    """Parse properties between current position and matching 'end'.

    Returns (next_line_index, list_of_Property).
    """
    # Determine the indent of the 'properties' keyword (line before start)
    block_indent = len(lines[start - 1]) - len(lines[start - 1].lstrip())

    props = []
    end_idx = _find_block_end(lines, start, block_indent)

    for i in range(start, end_idx):
        stripped = lines[i].strip()
        if is_public and stripped and not stripped.startswith("%"):
            prop = _parse_property_line(stripped)
            if prop:
                props.append(prop)

    return end_idx + 1, props


def _parse_property_line(line: str) -> Optional[Property]:
    """Parse a property line like: Name = DefaultValue  % Comment"""
    # Skip blank lines and pure comment lines
    if not line or line.startswith("%"):
        return None

    # Pattern: Name = Value % Comment
    # Pattern: Name  % Comment
    # Pattern: Name
    comment = ""
    code_part = line

    # Extract trailing comment
    # Be careful: % inside strings could be tricky, but for property defaults
    # this is rare. We look for % not inside quotes.
    pct_idx = _find_comment_pct(line)
    if pct_idx >= 0:
        comment = line[pct_idx + 1:].strip()
        code_part = line[:pct_idx].strip()

    if not code_part:
        return None

    # Check for assignment
    eq_idx = code_part.find("=")
    if eq_idx >= 0:
        name = code_part[:eq_idx].strip()
        default = code_part[eq_idx + 1:].strip()
    else:
        name = code_part.strip()
        default = ""

    # Validate name is a valid MATLAB identifier
    if not re.match(r"^[A-Za-z]\w*$", name):
        return None

    return Property(name=name, default=default, comment=comment)


def _find_comment_pct(line: str) -> int:
    """Find index of first % that is not inside a string literal."""
    in_single = False
    for i, ch in enumerate(line):
        if ch == "'" and not in_single:
            in_single = True
        elif ch == "'" and in_single:
            in_single = False
        elif ch == "%" and not in_single:
            return i
    return -1


def _parse_methods_block(lines, start, class_name, skip=False):
    """Parse methods between current position and matching 'end'.

    Uses indentation-aware block matching instead of depth counting,
    which avoids issues with single-line if/for/end constructs.

    Returns (next_line_index, list_of_Method).
    """
    # Determine the indent of the 'methods' keyword (line before start)
    block_indent = len(lines[start - 1]) - len(lines[start - 1].lstrip())

    end_idx = _find_block_end(lines, start, block_indent)

    methods = []
    if skip:
        return end_idx + 1, methods

    # Scan for function definitions within this block
    for i in range(start, end_idx):
        stripped = lines[i].strip()
        func_match = re.match(r"function\s+(.+)", stripped)
        if func_match:
            method = _parse_function(lines, i, class_name)
            if method:
                methods.append(method)

    return end_idx + 1, methods


def _parse_function(lines, func_line_idx, class_name):
    """Parse a function signature and its help text."""
    line = lines[func_line_idx].strip()

    # Parse function signature
    # Patterns:
    #   function obj = ClassName(args)
    #   function [out1, out2] = name(args)
    #   function name(args)
    #   function out = name(args)
    func_match = re.match(
        r"function\s+(?:(\[?[^=\]]*\]?)\s*=\s*)?(\w+)\s*(\([^)]*\))?", line
    )
    if not func_match:
        return None

    outputs = func_match.group(1) or ""
    func_name = func_match.group(2)
    args = func_match.group(3) or "()"

    # Skip getter/setter methods (get.Prop / set.Prop)
    if func_name.startswith("get.") or func_name.startswith("set."):
        return None

    # Skip delete method (destructor)
    if func_name == "delete":
        return None

    is_constructor = func_name == class_name

    # Build signature
    if is_constructor:
        signature = f"obj = {class_name}{args}"
    elif outputs:
        outputs_clean = outputs.strip()
        signature = f"{outputs_clean} = {func_name}{args}"
    else:
        signature = f"{func_name}{args}"

    # Extract help text (% comments after the function line)
    help_lines = []
    for j in range(func_line_idx + 1, min(func_line_idx + 50, len(lines))):
        stripped = lines[j].strip()
        if stripped.startswith("%"):
            content = stripped[1:]
            if content.startswith(" "):
                content = content[1:]
            help_lines.append(content)
        elif stripped == "":
            if help_lines:
                help_lines.append("")
        else:
            break

    # Trim trailing blank lines
    while help_lines and help_lines[-1] == "":
        help_lines.pop()

    # Take only the first few meaningful lines (skip detailed argument docs)
    summary_lines = _extract_summary(help_lines)

    return Method(
        name=func_name,
        signature=signature,
        help_text="\n".join(summary_lines),
        is_constructor=is_constructor,
    )


def _extract_summary(help_lines: list) -> list:
    """Extract just the summary from MATLAB help text.

    Stops at 'Input:', 'Output:', 'See also', or after a blank line
    following the first paragraph.
    """
    result = []
    found_content = False
    blank_count = 0

    for line in help_lines:
        # Stop markers
        lower = line.strip().lower()
        if lower.startswith("input:") or lower.startswith("output:"):
            break
        if lower.startswith("see also"):
            break
        if lower.startswith("example"):
            break

        if line.strip() == "":
            if found_content:
                blank_count += 1
                if blank_count >= 1:
                    break
                result.append("")
        else:
            found_content = True
            blank_count = 0
            result.append(line)

    # Trim trailing blanks
    while result and result[-1] == "":
        result.pop()

    return result


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

def format_class_markdown(cls: MatlabClass) -> str:
    """Format a single class as Markdown."""
    parts = []

    # Class heading with short description
    short_desc = _short_description(cls)
    if short_desc:
        parts.append(f"## `{cls.name}` --- {short_desc}\n")
    else:
        parts.append(f"## `{cls.name}`\n")

    # Inheritance
    if cls.parent:
        parts.append(f"> Inherits from: `{cls.parent}`\n")

    # Help text
    help_summary = _class_help_summary(cls.help_text)
    if help_summary:
        parts.append(f"{help_summary}\n")

    # Constructor
    constructor = None
    for m in cls.methods:
        if m.is_constructor:
            constructor = m
            break

    if constructor:
        parts.append("### Constructor\n")
        parts.append(f"```matlab\n{constructor.signature}\n```\n")
        if constructor.help_text:
            parts.append(f"{constructor.help_text}\n")

    # Properties
    if cls.properties:
        parts.append("### Properties\n")
        parts.append("| Property | Default | Description |")
        parts.append("|----------|---------|-------------|")
        for prop in cls.properties:
            default = f"`{prop.default}`" if prop.default else ""
            comment = _escape_md_table(prop.comment)
            parts.append(f"| {prop.name} | {default} | {comment} |")
        parts.append("")

    # Methods (non-constructor)
    public_methods = [m for m in cls.methods if not m.is_constructor]
    if public_methods:
        parts.append("### Methods\n")
        for m in public_methods:
            # Method heading
            parts.append(f"#### `{m.signature}`\n")
            if m.help_text:
                parts.append(f"{m.help_text}\n")

    # Static methods
    if cls.static_methods:
        parts.append("### Static Methods\n")
        for m in cls.static_methods:
            parts.append(f"#### `{cls.name}.{m.signature}`\n")
            if m.help_text:
                parts.append(f"{m.help_text}\n")

    return "\n".join(parts)


def _short_description(cls: MatlabClass) -> str:
    """Extract a one-line description from the help text."""
    if not cls.help_text:
        return ""
    first_line = cls.help_text.split("\n")[0].strip()
    # Remove the class name prefix if present
    # Patterns: "SENSOR Represents...", "NavigatorOverlay  Zoom rectangle..."
    # Try uppercase convention first
    m = re.match(r"[A-Z_]+\s+(.*)", first_line)
    if m:
        desc = m.group(1).strip()
        if desc:
            desc = desc[0].upper() + desc[1:]
        return desc
    # Try mixed-case class name prefix (e.g., "NavigatorOverlay  Description")
    if first_line.startswith(cls.name):
        desc = first_line[len(cls.name):].strip()
        if desc:
            desc = desc[0].upper() + desc[1:]
            return desc
    return first_line


def _class_help_summary(help_text: str) -> str:
    """Extract the summary paragraph from class help text.

    Stops at structured sections like 'Properties:', 'Methods:', 'Example:'.
    """
    if not help_text:
        return ""
    lines = help_text.split("\n")
    result = []
    for line in lines:
        lower = line.strip().lower()
        # Stop at structured sections
        if re.match(r"\w+\s+(properties|methods):", lower):
            break
        if lower.startswith("example"):
            break
        if lower.startswith("see also"):
            break
        if lower.startswith("typical workflow:"):
            break
        if lower.startswith("usage:"):
            break
        if lower.startswith("features:"):
            break
        if lower.startswith("constructor options"):
            break
        result.append(line)

    # Trim trailing blanks
    while result and result[-1].strip() == "":
        result.pop()

    text = "\n".join(result).strip()
    # Remove the first line if it's just the CLASS_NAME description
    # (already captured in the heading)
    text_lines = text.split("\n")
    if text_lines:
        first = text_lines[0].strip()
        if re.match(r"^[A-Z_]+\s+", first):
            text_lines = text_lines[1:]
        elif re.match(r"^[A-Za-z]+\s{2,}", first):
            # Mixed-case class name with double-space separator
            text_lines = text_lines[1:]

    return "\n".join(text_lines).strip()


def _escape_md_table(text: str) -> str:
    """Escape pipe characters and newlines for Markdown tables."""
    return text.replace("|", "\\|").replace("\n", " ")


# ---------------------------------------------------------------------------
# Page definitions
# ---------------------------------------------------------------------------

# Each page: (output filename, page title, library dir, anchors).
#
# `anchors` is an ORDERING HINT, not an allow-list: for a library page, EVERY
# classdef discovered in the directory is documented regardless of whether it
# is listed here (see generate_page). Anchors float the headline classes to the
# top; remaining classes are appended alphabetically. An anchor that no longer
# exists is silently skipped, so this list can never drop or duplicate a real
# class — it only affects ordering. Keep it short (the few most important
# classes). This is what makes the generator immune to class renames.
#
# Exception: the special page with library dir None (Utilities) uses `anchors`
# as an explicit cross-library class selector — only the named classes appear.
#
# Page names track the published wiki and _Sidebar.md (project brand:
# "FastPlot"), which intentionally differs from the underlying class names
# (e.g. the FastSense class is documented on the "FastPlot" page).
PAGES = [
    (
        "API-Reference:-FastPlot.md",
        "API Reference: FastPlot",
        "FastSense",
        ["FastSense", "FastSenseDataStore", "FastSenseGrid", "SensorDetailPlot"],
    ),
    (
        "API-Reference:-Dashboard.md",
        "API Reference: Dashboard",
        "Dashboard",
        [
            "DashboardEngine", "DashboardBuilder", "DashboardWidget",
            "DashboardLayout", "DashboardPage", "DashboardSerializer",
        ],
    ),
    (
        "API-Reference:-Sensors.md",
        "API Reference: Sensors",
        "SensorThreshold",
        [
            "Tag", "SensorTag", "MonitorTag", "CompositeTag", "DerivedTag",
            "StateTag", "TagRegistry",
        ],
    ),
    (
        "API-Reference:-Event-Detection.md",
        "API Reference: Event Detection",
        "EventDetection",
        ["Event", "EventStore", "EventViewer", "LiveEventPipeline"],
    ),
    (
        "API-Reference:-Utilities.md",
        "API Reference: Utilities",
        None,  # special: explicit cross-library class list (anchors IS the selector)
        ["ConsoleProgressBar"],
    ),
]


def collect_classes(lib_dir: Path) -> dict:
    """Parse all .m classdef files in a library directory (non-recursive, skip private/)."""
    classes = {}
    if not lib_dir.is_dir():
        return classes
    for mfile in sorted(lib_dir.glob("*.m")):
        # Skip files in private/ (they are subdirs, glob("*.m") won't catch them)
        print(f"  Parsing {mfile.relative_to(PROJECT_ROOT)} ... ", end="")
        cls = parse_classdef(mfile)
        if cls:
            classes[cls.name] = cls
            print(f"class {cls.name}")
        else:
            print("(not a classdef, skipped)")
    return classes


def generate_page(filename, title, classes_by_name, anchors):
    """Generate a wiki page documenting every class in classes_by_name.

    `anchors` lists headline class names to emit first, in order; every
    remaining class is appended alphabetically. Anchor names absent from
    classes_by_name are skipped — completeness comes from discovery, never
    from the anchor list, so a stale anchor cannot drop a real class.
    """
    parts = [AUTO_GENERATED_NOTICE, f"# {title}\n"]

    written = set()
    for name in anchors:
        if name in classes_by_name:
            parts.append(format_class_markdown(classes_by_name[name]))
            parts.append("---\n")
            written.add(name)

    # Append any discovered classes not already emitted via anchors.
    for name, cls in sorted(classes_by_name.items()):
        if name not in written:
            parts.append(format_class_markdown(cls))
            parts.append("---\n")

    # Remove trailing separator
    if parts and parts[-1] == "---\n":
        parts.pop()

    content = "\n".join(parts) + "\n"

    outpath = WIKI_DIR / filename
    with open(outpath, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"  -> Wrote {outpath.relative_to(PROJECT_ROOT)}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Library directories scanned for classdefs. Order is cosmetic (parse logging).
SCANNED_LIBS = ["FastSense", "Dashboard", "SensorThreshold", "EventDetection", "WebBridge"]

# Scanned for cross-page class lookup but intentionally given no page of their
# own. Suppresses the "undocumented library" warning below.
UNDOCUMENTED_OK = {"WebBridge"}


def prune_stale_api_pages(produced):
    """Delete API-Reference pages this generator owns but no longer produces.

    Safety: only files matching ``API-Reference:-*.md`` that carry THIS
    script's auto-generated banner are eligible. Manually-maintained pages
    (e.g. API-Reference:-Themes.md, which documents a function rather than a
    classdef) carry no banner and are never touched; nor are pages owned by
    generate_wiki.py, which use a different banner. This makes orphans left by
    a page rename self-healing instead of silently shipping stale content.
    """
    banner_marker = "by scripts/generate_api_docs.py"
    for page in sorted(WIKI_DIR.glob("API-Reference:-*.md")):
        if page.name in produced:
            continue
        head = page.read_text(encoding="utf-8", errors="replace")[:300]
        if banner_marker in head:
            page.unlink()
            print(f"  -> Pruned stale auto-generated page: {page.relative_to(PROJECT_ROOT)}")


def warn_undocumented_libs(lib_classes, documented_libs):
    """Warn if a scanned library has classdefs but no page maps to it."""
    for lib_name, parsed in lib_classes.items():
        if parsed and lib_name not in documented_libs and lib_name not in UNDOCUMENTED_OK:
            print(
                f"  WARNING: libs/{lib_name}/ has {len(parsed)} class(es) but no "
                f"API-Reference page maps to it — add an entry to PAGES.",
                file=sys.stderr,
            )


def main():
    print("FastPlot API Doc Generator")
    print(f"Project root: {PROJECT_ROOT}")
    print(f"Libs dir:     {LIBS_DIR}")
    print(f"Wiki dir:     {WIKI_DIR}")
    print()

    if not LIBS_DIR.is_dir():
        print(f"ERROR: libs/ directory not found at {LIBS_DIR}", file=sys.stderr)
        sys.exit(1)

    WIKI_DIR.mkdir(parents=True, exist_ok=True)

    # Collect all classes from all library dirs
    all_classes = {}  # name -> MatlabClass
    lib_classes = {}  # lib_name -> {name: MatlabClass}

    for lib_name in SCANNED_LIBS:
        lib_dir = LIBS_DIR / lib_name
        print(f"[{lib_name}]")
        parsed = collect_classes(lib_dir)
        lib_classes[lib_name] = parsed
        all_classes.update(parsed)
        print()

    # Generate pages
    print("Generating wiki pages:")
    produced = set()
    documented_libs = set()
    for filename, title, lib_name, anchors in PAGES:
        if lib_name is None:
            # Special page: anchors doubles as an explicit cross-library class
            # selector — only the named classes are documented here.
            subset = {
                name: all_classes[name]
                for name in anchors
                if name in all_classes
            }
        else:
            # Library page: document every classdef discovered in the directory.
            subset = lib_classes.get(lib_name, {})
            documented_libs.add(lib_name)

        generate_page(filename, title, subset, anchors)
        produced.add(filename)

    # Remove pages we used to generate but no longer do (e.g. after a rename),
    # then flag any library that has classes but no page mapping (inverse drift).
    prune_stale_api_pages(produced)
    warn_undocumented_libs(lib_classes, documented_libs)

    print()
    print("Done. Generated API reference pages in wiki/.")


if __name__ == "__main__":
    main()
