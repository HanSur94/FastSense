"""Tests for scripts/generate_wiki.py page mapping logic.

Run from repo root:
    python3 -m pytest scripts/test_generate_wiki.py
or:
    python3 scripts/test_generate_wiki.py
"""

import sys
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import generate_wiki  # noqa: E402


class DetectAffectedPagesTests(unittest.TestCase):
    def _filenames(self, pages):
        return {p["filename"] for p in pages}

    def test_empty_changed_files_returns_empty(self):
        self.assertEqual(generate_wiki.detect_affected_pages([]), [])

    def test_libs_change_maps_to_owning_pages(self):
        pages = generate_wiki.detect_affected_pages(["libs/Dashboard/DashboardEngine.m"])
        names = self._filenames(pages)
        self.assertIn("Dashboard-Engine-Guide.md", names)
        self.assertIn("Home.md", names)
        self.assertIn("Architecture.md", names)
        self.assertNotIn("WebBridge-Guide.md", names)

    def test_examples_change_triggers_examples_index(self):
        pages = generate_wiki.detect_affected_pages(["examples/example_basic.m"])
        self.assertIn("Examples.md", self._filenames(pages))

    def test_unrelated_change_returns_empty(self):
        pages = generate_wiki.detect_affected_pages(["README.md"])
        self.assertEqual(pages, [])

    def test_generator_change_triggers_full_regen(self):
        """Regression: a change to generate_wiki.py must regenerate every eligible page.

        Previously this returned [] because the script path matched neither
        libs/<dir>/ nor examples/, causing the workflow to exit silently and
        send zero requests to the LLM provider.
        """
        pages = generate_wiki.detect_affected_pages(["scripts/generate_wiki.py"])
        names = self._filenames(pages)

        self.assertEqual(names, self._filenames(generate_wiki._all_eligible_pages()))
        for excluded in generate_wiki.EXCLUDED_PAGES:
            self.assertNotIn(excluded, names)
        for prefix in generate_wiki.EXCLUDED_PREFIXES:
            self.assertFalse(any(n.startswith(prefix) for n in names))

    def test_generator_change_via_absolute_path(self):
        abs_path = str(generate_wiki.PROJECT_ROOT / "scripts" / "generate_wiki.py")
        pages = generate_wiki.detect_affected_pages([abs_path])
        self.assertEqual(
            self._filenames(pages),
            self._filenames(generate_wiki._all_eligible_pages()),
        )

    def test_excluded_pages_are_never_emitted(self):
        # Touch every lib + examples to force every mapping rule to fire.
        changed = [
            "libs/FastSense/FastSense.m",
            "libs/Dashboard/DashboardEngine.m",
            "libs/SensorThreshold/Sensor.m",
            "libs/EventDetection/EventDetector.m",
            "libs/WebBridge/WebBridge.m",
            "examples/example_basic.m",
        ]
        names = self._filenames(generate_wiki.detect_affected_pages(changed))
        self.assertTrue(generate_wiki.EXCLUDED_PAGES.isdisjoint(names))


if __name__ == "__main__":
    unittest.main()
