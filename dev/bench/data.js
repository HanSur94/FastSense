window.BENCHMARK_DATA = {
  "lastUpdate": 1773760373323,
  "repoUrl": "https://github.com/HanSur94/FastPlot",
  "entries": {
    "FastPlot Performance": [
      {
        "commit": {
          "author": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "distinct": true,
          "id": "a0c37058382f86f2c2ae7bd67ac0c659eea783eb",
          "message": "fix: resolve 3 CI failures — segfault, git ownership, example crash\n\n1. Tests segfault: setup.m now skips build_mex when FASTPLOT_SKIP_BUILD\n   is set. Prevents MEX file copy-while-loaded crash in Docker.\n2. Benchmark git error: add safe.directory config for container ownership.\n3. Examples segfault: remove example_themes (6 figures crashes Qt backend\n   in Docker container on close all force).\n\nAlso include mksqlite.mex in artifact upload/cache (was missing).\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-16T22:37:25+01:00",
          "tree_id": "c33a339c3e875d0f73b95e11c9f324d20ebad844",
          "url": "https://github.com/HanSur94/FastPlot/commit/a0c37058382f86f2c2ae7bd67ac0c659eea783eb"
        },
        "date": 1773697297673,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample (1M pts)",
            "value": 2.13,
            "unit": "ms"
          },
          {
            "name": "Binary Search",
            "value": 103.73,
            "unit": "us"
          },
          {
            "name": "Zoom Cycle (1M pts)",
            "value": 28.96,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "distinct": true,
          "id": "1102c04f7ba1ee0b119e44bf640633218494e995",
          "message": "fix: Octave test compatibility — replace contains(), fix Abstract classdef\n\n- Replace contains() with strfind() in 6 Octave test files\n- Remove (Abstract) attribute from DataSource.m (unsupported in Octave)\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-16T22:47:12+01:00",
          "tree_id": "cfcf2dcfadc30cb060b9ea03159ee47a3a7a7022",
          "url": "https://github.com/HanSur94/FastPlot/commit/1102c04f7ba1ee0b119e44bf640633218494e995"
        },
        "date": 1773697799162,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample (1M pts)",
            "value": 2.08,
            "unit": "ms"
          },
          {
            "name": "Binary Search",
            "value": 101.84,
            "unit": "us"
          },
          {
            "name": "Zoom Cycle (1M pts)",
            "value": 27.03,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "distinct": true,
          "id": "8c71c525063ebb6846599b41e5d72f12fdf08de7",
          "message": "fix: DataSource abstract method for Octave, resilient test runner\n\n- Replace methods (Abstract) with runtime error (Octave doesn't\n  support Abstract methods block)\n- Make CI test runner resilient to Octave cleanup crashes: save\n  results to file before potential crash, check results from shell\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-16T22:56:48+01:00",
          "tree_id": "7ae0d9a5230f7d00f865b22bc0b8d4b1a3bc1df8",
          "url": "https://github.com/HanSur94/FastPlot/commit/8c71c525063ebb6846599b41e5d72f12fdf08de7"
        },
        "date": 1773698349419,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample (1M pts)",
            "value": 2.07,
            "unit": "ms"
          },
          {
            "name": "Binary Search",
            "value": 102.37,
            "unit": "us"
          },
          {
            "name": "Zoom Cycle (1M pts)",
            "value": 25.45,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "distinct": true,
          "id": "e3f40e8a1f3f5228c6ae36626b2ce4110739bd01",
          "message": "fix: write test results incrementally to survive Octave cleanup crash\n\nrun_all_tests.m now writes passed/failed counts to a file after each\ntest (when FASTPLOT_RESULTS_FILE is set). The CI shell checks this\nfile even if Octave crashes during handle class garbage collection.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-16T23:06:13+01:00",
          "tree_id": "d80bb396f7bbb697168cc3f700097369dd59add4",
          "url": "https://github.com/HanSur94/FastPlot/commit/e3f40e8a1f3f5228c6ae36626b2ce4110739bd01"
        },
        "date": 1773698910222,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample (1M pts)",
            "value": 3.74,
            "unit": "ms"
          },
          {
            "name": "Binary Search",
            "value": 115.74,
            "unit": "us"
          },
          {
            "name": "Zoom Cycle (1M pts)",
            "value": 20.03,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "sannahrush@googlemail.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "distinct": true,
          "id": "feb96a4a68c4be12d532ff0770e27727618d5799",
          "message": "fix: skip 7 tests with known Octave classdef limitations\n\nThese tests pass on MATLAB but fail on Octave due to:\n- PostSet property listeners (not supported)\n- Abstract class instantiation check differences\n- RandStream (MATLAB-only)\n- Struct field access on empty classdef arrays (members bug)\n- parent_class_name_list internal error\n\nAll 7 are skipped on Octave with a clear message. They continue\nto run normally on MATLAB (weekly CI job).\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-16T23:16:30+01:00",
          "tree_id": "73b6876bb3b471aacff48692c1b1b68c6e8d120a",
          "url": "https://github.com/HanSur94/FastPlot/commit/feb96a4a68c4be12d532ff0770e27727618d5799"
        },
        "date": 1773699533684,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample (1M pts)",
            "value": 2.1,
            "unit": "ms"
          },
          {
            "name": "Binary Search",
            "value": 100.08,
            "unit": "us"
          },
          {
            "name": "Zoom Cycle (1M pts)",
            "value": 25.82,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "name": "HanSur94",
            "username": "HanSur94"
          },
          "committer": {
            "name": "HanSur94",
            "username": "HanSur94"
          },
          "id": "75d7c06d581d20c0704f3806783f39f6a6a11d4b",
          "message": "feat: add LLM-powered wiki documentation generation via Claude API",
          "timestamp": "2026-03-16T22:16:35Z",
          "url": "https://github.com/HanSur94/FastPlot/pull/22/commits/75d7c06d581d20c0704f3806783f39f6a6a11d4b"
        },
        "date": 1773760372373,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample (1M pts)",
            "value": 2.12,
            "unit": "ms"
          },
          {
            "name": "Binary Search",
            "value": 99.95,
            "unit": "us"
          },
          {
            "name": "Zoom Cycle (1M pts)",
            "value": 26.53,
            "unit": "ms"
          }
        ]
      }
    ]
  }
}