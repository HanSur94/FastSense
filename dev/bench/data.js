window.BENCHMARK_DATA = {
  "lastUpdate": 1773941969638,
  "repoUrl": "https://github.com/HanSur94/FastSense",
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
    ],
    "FastSense Performance": [
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
          "id": "566c932e4987f9af103aa4a32e0b4d5da4baa5e2",
          "message": "docs: add CI benchmark results and live tracking to README\n\n- Add CI benchmark table (Ubuntu/Octave 8.4) alongside local Apple M4 numbers\n- Add Benchmark badge linking to live charts at GitHub Pages\n- Link to https://hansur94.github.io/FastSense/dev/bench/\n- Fix stale \"FastPlot Performance\" name in benchmark workflow\n- Fix stale FastPlot references in run_ci_benchmark.m\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T18:08:19+01:00",
          "tree_id": "d7db9243fc53ee59b3cfaafff51591ef8c969fb9",
          "url": "https://github.com/HanSur94/FastSense/commit/566c932e4987f9af103aa4a32e0b4d5da4baa5e2"
        },
        "date": 1773854113889,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.078,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.033,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 147.784,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 20.038,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 231.354,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 11.705,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.169,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.235,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.834,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.063,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 154.829,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.456,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 234.242,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.141,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.295,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 2.014,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.707,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.172,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 181.49,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 1.804,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 243.679,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.518,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.132,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.701,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 99.395,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.656,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1559.096,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 79.789,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 241.649,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 4.463,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.438,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.674,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 195.872,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 3.009,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2968.125,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 187.435,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 245.698,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.52,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.496,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.422,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 983.917,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 19.055,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22807.14,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 617.846,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 691.964,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 635.988,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 16.28,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 5.981,
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
          "id": "4440ae921770cb542300023e5f65ab5f189829a7",
          "message": "docs: fix local benchmark hardware specs (M1 Pro, not M4)\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T18:09:29+01:00",
          "tree_id": "b8f67091aa831741268b525955c5bc07e5e42a6a",
          "url": "https://github.com/HanSur94/FastSense/commit/4440ae921770cb542300023e5f65ab5f189829a7"
        },
        "date": 1773854167030,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.112,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.131,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 142.203,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 11.081,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 229.632,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 10.286,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 13.622,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.311,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.481,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.579,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 155.894,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.947,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 232.182,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 4.67,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.163,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.957,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.922,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.522,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 191.173,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 10.57,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 238.489,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 0.791,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 12.94,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.801,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 100.392,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 3.395,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1553.784,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 78.304,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 241.245,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.069,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 12.969,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.052,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 198.761,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.477,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2970.562,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 147.513,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 244.652,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.284,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 12.8,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.154,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 999.92,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 24.372,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23245.747,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 961.253,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 733.304,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 743.384,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 12.798,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.147,
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
          "id": "2154d0d7c56b919ba3add4529e12e1557b4114d6",
          "message": "ci: enforce MISS_HIT complexity metrics and enable more style rules\n\nAdd mh_metric --ci to CI workflow with thresholds for cyclomatic\ncomplexity, nesting depth, parameter count, and function length.\nUn-suppress 7 low-count style rules and auto-fix violations across\nthe codebase (whitespace around brackets, semicolons, colons,\nassignments, continuations, and operator placement).\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T18:23:49+01:00",
          "tree_id": "7fab65657b46df1ae76bb1783094ffa1cca10632",
          "url": "https://github.com/HanSur94/FastSense/commit/2154d0d7c56b919ba3add4529e12e1557b4114d6"
        },
        "date": 1773855043826,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.091,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.064,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 141.895,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.799,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 228.114,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 5.982,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 13.554,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.3,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.816,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.047,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 153.769,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.028,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 229.777,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.761,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 12.949,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.842,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.377,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.228,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 174.632,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.43,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 237.941,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 2.382,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 12.632,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.759,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 96.971,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.072,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1531.715,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 88.378,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 237.174,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.85,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 12.874,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.058,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 194.953,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.152,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2922.751,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 173.967,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 242.122,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 0.491,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 12.773,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.162,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 972.16,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 25.628,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22847.489,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 501.856,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 749.234,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 695.171,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.742,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 2.145,
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
          "id": "33a5f17f677da1953ecb4a85cc545f1fac1bf218",
          "message": "fix: update Dashboard Engine wiki guide — fastplot to fastsense rename\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T18:24:43+01:00",
          "tree_id": "68fddc9d332127eb040af06a33ee749ab15af955",
          "url": "https://github.com/HanSur94/FastSense/commit/33a5f17f677da1953ecb4a85cc545f1fac1bf218"
        },
        "date": 1773855116797,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.075,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.032,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 144.578,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.999,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 231.854,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 8.646,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.599,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.339,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.918,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.051,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.922,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.25,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 234.837,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 0.936,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.004,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.735,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.511,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.186,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 177.862,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.732,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 240.611,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.221,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.835,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.99,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 98.9,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.181,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1572.595,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 76.978,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 239.351,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.591,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.843,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.931,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 194.564,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.594,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2994.072,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 173.281,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 246.71,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.746,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.495,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.071,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 986.273,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 32.529,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22562.383,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 578.291,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 770.984,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 689.299,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 16.674,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 5.804,
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
          "id": "27f2d75c3b830c08ac57909c55e0b622d8238298",
          "message": "fix: update CI workflows to use install() instead of removed setup()\n\nThe setup() function was renamed to install() but CI workflows still\nreferenced the old name, breaking MEX builds across all pipelines.\nAlso set failIfEmpty: false for wiki link check since wiki files use\n[[Page]] syntax that lychee cannot parse.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T20:02:59+01:00",
          "tree_id": "050c397e1beeb8ada19cbeff2ad1fb78176c1d32",
          "url": "https://github.com/HanSur94/FastSense/commit/27f2d75c3b830c08ac57909c55e0b622d8238298"
        },
        "date": 1773861088442,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.083,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.028,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 143.993,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.765,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 237.185,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 8.811,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.543,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.436,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.849,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.087,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 155.993,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.498,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 234.304,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.53,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.981,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.605,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.2,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.067,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 177.777,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.988,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 242.492,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 4.939,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.784,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 1.44,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 96.19,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.191,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1548.597,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 85.396,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 242.042,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.672,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.963,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.127,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 191.619,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.681,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2960.663,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 172.534,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 246.862,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.194,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.637,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.039,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1044.068,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 61.19,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23141.933,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1402.93,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 649.634,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 528.34,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.117,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.487,
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
          "id": "3127a9eac7c0cda75add92b64e490ae6e0ad5b20",
          "message": "fix: run each Octave test in a subprocess to prevent crash from killing suite\n\nOctave 8.x crashes during handle-class cleanup (break_closure_cycles),\nwhich was killing the process after ~28 tests, leaving 35 tests unrun.\nNow each test runs in an isolated subprocess with a success marker so\nthe suite continues even if individual tests crash during cleanup.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T20:28:54+01:00",
          "tree_id": "628d3c773801bb26895d498226a4a041c32fe6ff",
          "url": "https://github.com/HanSur94/FastSense/commit/3127a9eac7c0cda75add92b64e490ae6e0ad5b20"
        },
        "date": 1773862562038,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.074,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.033,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 145.48,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.161,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 234.512,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.522,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.405,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.354,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.583,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.517,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 158.593,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.638,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 238.347,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.425,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.937,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.925,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 20.824,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.25,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 179.448,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.57,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 243.794,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 0.517,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.502,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.882,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 105.44,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.843,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1567.652,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 87.377,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 244.707,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.506,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.719,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.189,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 221.946,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 5.279,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 3011.807,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 190.804,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 251.599,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 0.661,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.869,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.122,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1121.755,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 22.19,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22692.151,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 267.548,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 367.9,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 47.058,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.756,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.033,
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
          "id": "5a4edaf13c0be24327e817ac89528372ba341220",
          "message": "fix: resolve 12 Octave test failures across EventDetection and SensorThreshold\n\n- Replace Event.empty()/NotificationRule.empty() with [] (Octave lacks\n  .empty() on classdef classes)\n- Compute unique() 3rd output manually in mergeResolvedByLabel (Octave\n  lacks J output for cell arrays)\n- Replace RandStream with global RNG fallback in MockDataSource\n- Use get(ax,'YLim') instead of ax.YLim in generateEventSnapshot\n- Use property comparison instead of handle == in test_sensor_todisk\n- Handle break_closure_cycles crash as passed in test runner\n- Skip test_event_store and test_event_viewer on Octave (require\n  datetime/EventViewer MATLAB-only features)\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T20:45:55+01:00",
          "tree_id": "fe2b3d84a8a5536cfb559b86700b9d144f333891",
          "url": "https://github.com/HanSur94/FastSense/commit/5a4edaf13c0be24327e817ac89528372ba341220"
        },
        "date": 1773863556563,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.088,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.045,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 144.623,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 14.508,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 233.604,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 10.168,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.77,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.189,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.818,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.076,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.813,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.731,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 236.784,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 0.899,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.475,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 2.157,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.308,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.063,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 178.592,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 1.402,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 240.401,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 0.788,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.737,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.884,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 97.429,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.37,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1550.342,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 83.01,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 243.625,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.822,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.892,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.175,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 192.771,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.434,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2945.1,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 169.733,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 247.418,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 0.8,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.967,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.027,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 984.754,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 43.876,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23856.727,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 2322.805,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 564.081,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 374.988,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 19.047,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 9.59,
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
          "id": "51daf96be554b0b8183844e784baba771cef2555",
          "message": "fix: resolve remaining 4 Octave test failures\n\n- Use .' (transpose) instead of ' (ctranspose) for Event arrays\n- Replace array(end+1)=obj with concatenation for [] arrays in Octave\n- Use -v7 save format on Octave (lacks -v7.3)\n- Skip deterministic seed test on Octave (no RandStream isolation)\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T20:56:54+01:00",
          "tree_id": "c8cca6abf1a9c1ac828a5e353e516e00294e63c4",
          "url": "https://github.com/HanSur94/FastSense/commit/51daf96be554b0b8183844e784baba771cef2555"
        },
        "date": 1773864220603,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 3.756,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.041,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 126.523,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 11.716,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 204.202,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 7.324,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 11.127,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 3.665,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 20.179,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.196,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 141.136,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.019,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 216.463,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 3.183,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 9.954,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.411,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 40.023,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.159,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 164.909,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.971,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 229.798,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.214,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 9.33,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.7,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 205.58,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.687,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1404.783,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 32.794,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 219.801,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.124,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 10.516,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.189,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 407.315,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.72,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2675.418,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 122.156,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 228.789,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 3.313,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 10.791,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.854,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 2047.052,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 27.097,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 24365.552,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1911.632,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 372.701,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 25.876,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 10.344,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.908,
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
          "id": "1c75079423ee224faaa6b740e18100ec3ea5f9fe",
          "message": "fix: handle Octave classdef array ops — avoid transpose and [] concat\n\nOctave cannot transpose or horzcat classdef objects with []. Use\nif-isempty guards for typed array initialization. Loop-append in\nEventStore.append instead of transpose. Skip timer test on Octave.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T21:06:57+01:00",
          "tree_id": "69458e51cce4e01f4f38938e7749c49e536a4f6d",
          "url": "https://github.com/HanSur94/FastSense/commit/1c75079423ee224faaa6b740e18100ec3ea5f9fe"
        },
        "date": 1773864832411,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.288,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.203,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 154.576,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 15.445,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 247.726,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 7.353,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 16.824,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.507,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.555,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.084,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 169.178,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.394,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 251.906,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.211,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 15.904,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.789,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 20.738,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.18,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 191.313,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 3.325,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 257.503,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 3.005,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 15.674,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.926,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 105.07,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.631,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1662.073,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 56.806,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 261.091,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 4.149,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 15.868,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.062,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 204.957,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.509,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 3154.375,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 179.913,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 269.673,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 3.869,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 16.167,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.297,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1042.439,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 38.799,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 24546.097,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 2222.206,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 753.575,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 651.752,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 16.349,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.247,
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
          "id": "0f005433c0c2eeb16897a52d7ee0984287082094",
          "message": "chore: add generated process diagram for info page example\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T21:07:43+01:00",
          "tree_id": "42bd8f6f798ee2e6746882a39f5d766e41a19c25",
          "url": "https://github.com/HanSur94/FastSense/commit/0f005433c0c2eeb16897a52d7ee0984287082094"
        },
        "date": 1773864870414,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.095,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.025,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 142.703,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.035,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 231.63,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 7.133,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.346,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.134,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.924,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.035,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.477,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.32,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 234.193,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.753,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.973,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.713,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.725,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.258,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 179.127,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 2.237,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 241.517,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.446,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.494,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.993,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 99.638,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.335,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1551.282,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 85.929,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 240.098,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.595,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.584,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.93,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 196.266,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 3.618,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2957.995,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 173.289,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 245.678,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.237,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.766,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.155,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 994.708,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 35.079,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22947.042,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1033.339,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 788.288,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 857.809,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 15.182,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.357,
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
          "id": "3a859a4c15bba3a680fd1e2454217ebd79e3a415",
          "message": "fix: restore missing end statement and skip mat-save test on Octave\n\nFix syntax error from dropped end in IncrementalEventDetector. Skip\ntest_event_store_rw on Octave — cannot serialize classdef objects\nto .mat files.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T21:15:56+01:00",
          "tree_id": "399c7c546ac1501d810657beeac125a7b91d9d3d",
          "url": "https://github.com/HanSur94/FastSense/commit/3a859a4c15bba3a680fd1e2454217ebd79e3a415"
        },
        "date": 1773865366238,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.096,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.043,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 147.374,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.435,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 233.76,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.249,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 15.344,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.344,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.876,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.036,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 158.838,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.905,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 235.046,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.753,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.481,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.652,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 20.115,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.682,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 182.817,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 3.237,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 247.875,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 2.107,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 14.416,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 1.009,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 99.354,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.816,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1558.569,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 86.799,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 242.918,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.892,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 14.491,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.926,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 197.124,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.956,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2974.573,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 169.959,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 249.256,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.859,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 14.187,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.385,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1005.88,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 51.244,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 24679.932,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 3638.29,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 421.647,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 130.554,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.826,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.629,
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
          "id": "a48a0b31c0a12d054612e5a4c16872344eefe72d",
          "message": "fix: skip severity escalation and store-save assertions on Octave\n\nOctave cannot serialize classdef objects to .mat or handle complex\nclassdef inheritance chains. Skip these specific sub-tests while\nkeeping the rest of each test running.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T21:24:55+01:00",
          "tree_id": "d4704acb6ae2893ed721cbf6f24288c291dc9fa8",
          "url": "https://github.com/HanSur94/FastSense/commit/a48a0b31c0a12d054612e5a4c16872344eefe72d"
        },
        "date": 1773865923865,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.113,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.095,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 146.997,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 15.686,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 233.417,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 12.086,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 15.142,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.341,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.906,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.032,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 158.33,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.309,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 236.208,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.314,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.303,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.76,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.593,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.204,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 180.049,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 3.035,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 242.561,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 0.609,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 14.043,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.593,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 98.764,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.842,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1572.997,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 71.168,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 243.856,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 5.277,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 14.711,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.604,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 196.266,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 2.597,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2987.992,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 195.532,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 248.171,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.584,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.931,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.051,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1024.209,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 43.825,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22567.679,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 211.463,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 493.415,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 292.274,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 15.608,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.993,
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
          "id": "14f9f1c2828a4eb3c8ca5a55fc9723b63f34722d",
          "message": "fix: skip store-load test on Octave (classdef serialization)\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T21:33:26+01:00",
          "tree_id": "6b597e80a7ad8b193066621334881593e030b7c7",
          "url": "https://github.com/HanSur94/FastSense/commit/14f9f1c2828a4eb3c8ca5a55fc9723b63f34722d"
        },
        "date": 1773866433940,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.075,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.029,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 148.052,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 18.129,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 234.85,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 8.515,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.481,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.295,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.046,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.248,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.687,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.986,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 234.983,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.792,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.957,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.892,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 20.786,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.208,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 179.536,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 1.726,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 241.543,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 3.15,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.718,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.856,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 102.984,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.764,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1562.309,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 87.27,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 243.521,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.998,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.727,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.127,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 199.385,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.176,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2953.323,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 175.545,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 245.587,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.354,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.959,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.274,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 994.871,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 13.085,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22444.345,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 536.321,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 722.418,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 685.146,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.105,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.658,
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
          "id": "acfa90b6a873850b8f238a1ed713962e44df7e9b",
          "message": "docs: replace setup with install in README and wiki\n\nThe function was renamed from setup() to install() but documentation\nstill referenced the old name.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T21:51:32+01:00",
          "tree_id": "132c6fd8a10fbc02132a7c7a0ff988618327500f",
          "url": "https://github.com/HanSur94/FastSense/commit/acfa90b6a873850b8f238a1ed713962e44df7e9b"
        },
        "date": 1773867513473,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.07,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.041,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 142.503,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 11.794,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 230.424,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 7.545,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.419,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.248,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.769,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.029,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 155.981,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.674,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 233.334,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.013,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.781,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.82,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.132,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.089,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 178.61,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.566,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 240.003,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.431,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.341,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.863,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 95.249,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.057,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1549.19,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 85.511,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 239.233,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.331,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.591,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.007,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 189.36,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.402,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2956.411,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 180.719,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 247.915,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.116,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.614,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.986,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 960.714,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 25.061,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 25692.779,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 3287.16,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 590.516,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 334.848,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.837,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.213,
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
          "id": "eb27ec270b81c04e8a718cdd72583922f5d50369",
          "message": "fix: escape markdown link examples in MarkdownRenderer doc comment\n\nWrap `[links](url)` and `![images](src)` in backticks so the wiki\nlink checker does not treat them as real file references.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
          "timestamp": "2026-03-18T21:57:30+01:00",
          "tree_id": "ace318c96172fc9e9d9d29ba1221f5c7dd339785",
          "url": "https://github.com/HanSur94/FastSense/commit/eb27ec270b81c04e8a718cdd72583922f5d50369"
        },
        "date": 1773867861922,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.161,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.178,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 147.488,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 15.816,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 238.639,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.898,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 15.798,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.336,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.134,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.116,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 159.014,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.32,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 241.059,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 4.243,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 15.24,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.793,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.959,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.326,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 183.377,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 2.933,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 245.479,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 4.696,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 14.619,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 1.022,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 99.718,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 1.615,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1568.181,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 76.02,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 244.44,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.933,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 14.449,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.71,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 195.733,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.892,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2992.654,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 176.273,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 248.679,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 0.283,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 15.237,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.054,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1001.995,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 36.125,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23433.146,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1408.758,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 733.02,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 600.088,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.592,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.073,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "50265832+HanSur94@users.noreply.github.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "2df32a93163ef2cd080cfe82bbdc11a199207d4b",
          "message": "Merge pull request #32 from HanSur94/wiki-update/eb27ec2\n\ndocs: update wiki pages [auto-generated]",
          "timestamp": "2026-03-18T22:09:34+01:00",
          "tree_id": "cbd7239c126beea97dc38ff6ecbd15826bc5b060",
          "url": "https://github.com/HanSur94/FastSense/commit/2df32a93163ef2cd080cfe82bbdc11a199207d4b"
        },
        "date": 1773868581530,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.095,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.069,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 143.956,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.52,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 233.8,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 9.753,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.346,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.196,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.935,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.062,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.555,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.336,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 234.502,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.007,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.695,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.688,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.713,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.087,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 178.071,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.376,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 243.028,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 2.155,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.251,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.946,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 97.95,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.221,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1547.246,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 90.572,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 243.708,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.405,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.475,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.169,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 196.073,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.567,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2969.142,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 188.372,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 247.831,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.483,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.556,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.204,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 986.499,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 30.284,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 26013.284,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 2882.494,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 649.322,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 431.104,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.989,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.107,
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
          "id": "b4816da78ab33e54f94cf0f226fe4b98818e8909",
          "message": "feat(dashboard): add GroupWidget container with panel/collapsible/tabbed modes",
          "timestamp": "2026-03-18T21:09:38Z",
          "url": "https://github.com/HanSur94/FastSense/pull/33/commits/b4816da78ab33e54f94cf0f226fe4b98818e8909"
        },
        "date": 1773870284658,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 4.142,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.097,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 130.421,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.43,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 216.46,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 9.187,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 12.493,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.039,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 20.758,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.053,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 148.218,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.244,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 228.239,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 0.603,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 11.993,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.336,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 42.632,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.84,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 176.977,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 2.416,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 237.841,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.398,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 12.358,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 1.04,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 213.479,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 2.909,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1533.07,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 56.292,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 232.477,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.532,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 11.31,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.117,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 421.531,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 3.554,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2945.473,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 94.455,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 239.329,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 3.855,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 12.033,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.026,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 2132.945,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 17.372,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23731.451,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 346.466,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 335.286,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 49.673,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 12.139,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.235,
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
          "id": "fd9954bb3c968192c3c82bd1314ec1ad5cb458ad",
          "message": "feat(dashboard): add 6 new widget types (Phase B)",
          "timestamp": "2026-03-18T21:09:38Z",
          "url": "https://github.com/HanSur94/FastSense/pull/34/commits/fd9954bb3c968192c3c82bd1314ec1ad5cb458ad"
        },
        "date": 1773870842484,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.062,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.038,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 142.614,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 14.9,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 229.113,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 8.017,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 13.967,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.298,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.723,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.151,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 150.716,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 2.496,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 229.258,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.917,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.419,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.649,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 18.747,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.215,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 171.708,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 4.052,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 237.665,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.285,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.059,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.854,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 95.671,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 1.702,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1530.337,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 97.228,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 239.23,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.937,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.472,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.108,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 188.132,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.542,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2913.336,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 173.981,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 243.714,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.578,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.302,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.099,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 960.358,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 27.627,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23182.649,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1430.992,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 717.356,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 647.51,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 15.97,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 5.92,
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
          "id": "309787867add97a942c426a13b7ed2f7941a033c",
          "message": "feat(dashboard): add 6 new widget types (Phase B)",
          "timestamp": "2026-03-18T21:09:38Z",
          "url": "https://github.com/HanSur94/FastSense/pull/34/commits/309787867add97a942c426a13b7ed2f7941a033c"
        },
        "date": 1773871467048,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.085,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.03,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 147.675,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.723,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 233.155,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.679,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.974,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.293,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.02,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.112,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 158.261,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 2.166,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 234.255,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.19,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.347,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.703,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.846,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.236,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 177.536,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.914,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 241.196,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.38,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 14.13,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.779,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 100.037,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.25,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1576.678,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 72.615,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 243.234,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.559,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 14.725,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.912,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 200.181,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.73,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2965.89,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 181.467,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 247.734,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.473,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 14.807,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.38,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1022.273,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 27.111,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23707.666,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1582.54,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 645.154,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 571.792,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.785,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.279,
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
          "id": "27770bd9ad3b3fc4c42046ce7be804b5b61bf23a",
          "message": "feat(dashboard): add 6 new widget types (Phase B)",
          "timestamp": "2026-03-18T21:09:38Z",
          "url": "https://github.com/HanSur94/FastSense/pull/34/commits/27770bd9ad3b3fc4c42046ce7be804b5b61bf23a"
        },
        "date": 1773871568287,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 3.849,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.133,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 126.428,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.232,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 208.068,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 10.245,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 11.226,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 3.873,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 20.225,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.083,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 144.771,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.568,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 216.165,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 0.693,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 10.788,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.345,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 40.217,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.187,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 171.536,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 3.184,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 231.409,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 3.712,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 10.441,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.877,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 207.356,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 1.556,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1394.658,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 51.625,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 219.337,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.913,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 10.388,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.141,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 408.595,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.454,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2698.192,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 102.321,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 232.821,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 4.606,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 10.767,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.03,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 2053.213,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 6.097,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23118.816,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 66.784,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 329.174,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 58.683,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 11.298,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.986,
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
          "id": "960ff36e548c20049ca357eb8cce2b81f21a8b98",
          "message": "feat: add ExternalSensorRegistry for external .mat data integration",
          "timestamp": "2026-03-18T21:09:38Z",
          "url": "https://github.com/HanSur94/FastSense/pull/35/commits/960ff36e548c20049ca357eb8cce2b81f21a8b98"
        },
        "date": 1773871904853,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.091,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.045,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 146.528,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 11.768,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 233.062,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.323,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 15.123,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.116,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.07,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.064,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 162.91,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 6.992,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 235.496,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.595,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.409,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.875,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.747,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.093,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 178.879,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.305,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 243.039,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 3.056,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.825,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 1.11,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 101.435,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.374,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1566.765,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 82.654,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 245.422,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.423,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.691,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.006,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 197.496,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.308,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2971.01,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 153.506,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 245.928,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.96,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.837,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.315,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1002.275,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 43.896,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23935.728,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 2174.061,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 532.221,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 207.499,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.055,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.272,
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
          "id": "e9ed50b045ff6b5b4241f44de593a903eb60b1ce",
          "message": "feat: add ExternalSensorRegistry for external .mat data integration",
          "timestamp": "2026-03-18T21:09:38Z",
          "url": "https://github.com/HanSur94/FastSense/pull/35/commits/e9ed50b045ff6b5b4241f44de593a903eb60b1ce"
        },
        "date": 1773872092851,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.145,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.094,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 149.734,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.716,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 239.809,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 5.83,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 16.275,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.406,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.161,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.096,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 170.671,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.282,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 251.795,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.77,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 15.445,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 2.004,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.601,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.221,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 183.525,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.26,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 249.57,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 2.011,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 15.566,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.961,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 97.879,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.207,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1584.607,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 85.805,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 249.107,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.565,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 15.523,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.832,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 194.348,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.431,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 3048.813,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 182.87,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 253.967,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.346,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 15.532,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.028,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 987.865,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 28.112,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23521.183,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1336.046,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 639.59,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 300.822,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 16.757,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.399,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "50265832+HanSur94@users.noreply.github.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "58157fcb2d1f102f20577e9afd07386bb5d61441",
          "message": "feat(dashboard): add GroupWidget container with panel/collapsible/tabbed modes (#33)\n\nfeat(dashboard): add GroupWidget container with panel/collapsible/tabbed modes",
          "timestamp": "2026-03-18T23:08:42+01:00",
          "tree_id": "8a4787ba4fe3f38b7193174543c6d7776679cf16",
          "url": "https://github.com/HanSur94/FastSense/commit/58157fcb2d1f102f20577e9afd07386bb5d61441"
        },
        "date": 1773872136927,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.09,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.029,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 145.944,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 14.117,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 233.679,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 9.695,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 15.037,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.334,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.08,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.049,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 159.518,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.396,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 240.823,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 4.041,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.955,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.668,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.79,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.209,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 179.018,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.417,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 241.975,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.316,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.981,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.936,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 100.082,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.51,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1574.36,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 83.755,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 242.419,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.396,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 14.689,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.944,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 199.202,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.665,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2994.938,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 164.458,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 252.519,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 4.26,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 15.753,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.432,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1003.01,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 38.333,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 26448.032,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 3751.41,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 545.29,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 202.614,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 20.888,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 12.077,
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
          "id": "02be3c68b7cb3cf023acbe0de56a764dd63d9821",
          "message": "feat(dashboard): add 6 new widget types (Phase B)",
          "timestamp": "2026-03-18T22:09:04Z",
          "url": "https://github.com/HanSur94/FastSense/pull/34/commits/02be3c68b7cb3cf023acbe0de56a764dd63d9821"
        },
        "date": 1773872333148,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.058,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.027,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 144.26,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.584,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 229.894,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 7.004,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.403,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.221,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.926,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.105,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.461,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.676,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 233.543,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.152,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.634,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.704,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.521,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.13,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 176.775,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 1.423,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 239.519,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.86,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.206,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.968,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 102.116,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 4.408,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1587.98,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 120.054,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 251.469,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 22.064,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.362,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.9,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 192.846,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.094,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2950.862,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 182.399,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 244.558,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.19,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.601,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.04,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1034.578,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 13.14,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23333.914,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1018.04,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 618.457,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 513.817,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.961,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.986,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "50265832+HanSur94@users.noreply.github.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "2044fed5c43b6881c8b5256a2f1e2e72ab9a82ed",
          "message": "Merge pull request #35 from HanSur94/feat/external-sensor-registry\n\nfeat: add ExternalSensorRegistry for external .mat data integration",
          "timestamp": "2026-03-18T23:15:42+01:00",
          "tree_id": "73715c18a57fc0b015bc4c94c90435cff9911c42",
          "url": "https://github.com/HanSur94/FastSense/commit/2044fed5c43b6881c8b5256a2f1e2e72ab9a82ed"
        },
        "date": 1773872537889,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.098,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.042,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 147.042,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.775,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 233.139,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 8.828,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.333,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.198,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.842,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.052,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 158.762,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 2.01,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 243.541,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 0.781,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.949,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.624,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.975,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.355,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 190.041,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 6.589,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 253.715,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 3.994,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 15.791,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.985,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 99.521,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.389,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1599.802,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 59.03,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 247.762,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 3.859,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 14.705,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.204,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 196.652,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 2.523,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 3001.688,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 169.338,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 266.086,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 4.88,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 15.318,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.022,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 986.582,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 28.796,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23081.154,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 778.334,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 694.798,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 526.461,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 19.594,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 11.354,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "50265832+HanSur94@users.noreply.github.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "8776ee644e7fe1331bc55b6ffda8096aeb7e2f03",
          "message": "feat(dashboard): add 6 new widget types (Phase B) (#34)\n\nfeat(dashboard): add 6 new widget types (Phase B)",
          "timestamp": "2026-03-18T23:19:40+01:00",
          "tree_id": "e4d64b8519d934cefeba20596d2cc726d9196958",
          "url": "https://github.com/HanSur94/FastSense/commit/8776ee644e7fe1331bc55b6ffda8096aeb7e2f03"
        },
        "date": 1773872787141,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 3.742,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.032,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 125.426,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.292,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 207.449,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.146,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 10.963,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 3.923,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 20.212,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.184,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 140.506,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.299,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 213.296,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 0.912,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 10.735,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.481,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 41.53,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.16,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 171.38,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.585,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 231.295,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.15,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 10.668,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.985,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 210.038,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 1.989,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1426.5,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 35.049,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 222.204,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.029,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 9.753,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.967,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 416.001,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.506,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2651.987,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 97.191,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 231.025,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 3.238,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 10.957,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.264,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 2044.689,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.508,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23193.331,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 383.343,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 507.881,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 257.002,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 11.285,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 2.143,
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
          "id": "162001601d069593a1043755b70f73d5631d6dcf",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/162001601d069593a1043755b70f73d5631d6dcf"
        },
        "date": 1773932102443,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 3.736,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.071,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 124.792,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 11.55,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 204.946,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 9.484,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 10.962,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 3.89,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 20.265,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.185,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 142.649,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.05,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 216.555,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 3.194,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 10.344,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.613,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 40.214,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.275,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 170.248,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.589,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 230.53,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 2.678,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 10.235,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.864,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 202.93,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.153,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1391.701,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 44.1,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 220.058,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.89,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 10.164,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.241,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 402.56,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.843,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2666.657,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 90.092,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 228.641,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.171,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 10.568,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.934,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 2041.391,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 18.872,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23037.22,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 376.199,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 569.506,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 266.404,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.378,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 6.329,
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
          "id": "6642fb97c095d4c0b4b36d2289d9a413e2d08502",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/6642fb97c095d4c0b4b36d2289d9a413e2d08502"
        },
        "date": 1773939627655,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.081,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.028,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 157.775,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 20.328,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 236.485,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.525,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 15.173,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.487,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.182,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.143,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 166.902,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 2.545,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 239.14,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 4.152,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 16.317,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.857,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 22.414,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 2.117,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 184.704,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 2.98,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 262.101,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 19.742,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 14.595,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.876,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 103.656,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 7.074,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1580.776,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 94.987,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 245.858,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 3.78,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 14.392,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.021,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 208.665,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 12.977,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 3059.449,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 203.821,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 255.698,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 10.146,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.498,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.115,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1072.424,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 28.917,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 27076.751,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 3730.582,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 766.378,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 562.737,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.072,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.667,
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
          "id": "50ac0549a08008e70ace0113f36631902eb76a38",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/50ac0549a08008e70ace0113f36631902eb76a38"
        },
        "date": 1773940402033,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.097,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.053,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 145.163,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 15.404,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 231.364,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 7.18,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.441,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.18,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.026,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.057,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 157.013,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.508,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 234.406,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 4.289,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.724,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.643,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 20.015,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.128,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 177.9,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 2.222,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 241.141,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.953,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.406,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 1.099,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 99.545,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.257,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1552.944,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 87.337,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 240.049,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.756,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.532,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.007,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 198.934,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.187,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2953.45,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 179.536,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 243.725,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.191,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.586,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.145,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 987.612,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 19.69,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22530.792,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 631.365,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 712.375,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 682.67,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.542,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.89,
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
          "id": "76c6727b65b7c0ab4ebeda66dd9e19cabb3edc5b",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/76c6727b65b7c0ab4ebeda66dd9e19cabb3edc5b"
        },
        "date": 1773940438839,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 3.744,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.112,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 132.104,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 13.479,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 211.626,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.506,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 11.311,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.219,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 22.217,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.187,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 149.512,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.872,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 222.782,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.16,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 10.525,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 2.44,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 45.287,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.197,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 179.637,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.886,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 237.879,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 0.412,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 9.973,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.997,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 230.761,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.105,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1623.15,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 218.017,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 231.104,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.704,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 11.025,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.11,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 459.95,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.244,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2901.902,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 113.616,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 237.673,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 3.311,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 10.973,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.541,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 2252.529,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 21.791,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23737.056,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 172.531,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 351.895,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 94.257,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 12.372,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 4.376,
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
          "id": "ecaba36acbfb6f1da808e46a74eb5541b059984b",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/ecaba36acbfb6f1da808e46a74eb5541b059984b"
        },
        "date": 1773940630229,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 3.727,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.037,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 124.324,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.896,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 202.342,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 6.732,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 10.161,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 3.65,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 19.643,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.269,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 138.999,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.352,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 213.744,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 0.796,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 9.542,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.57,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 39.858,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.178,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 164.56,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 1.033,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 226.829,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.403,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 9.297,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.717,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 203.947,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.472,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1392.169,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 41.903,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 219.622,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.014,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 10.197,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.333,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 402.641,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.659,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2647.207,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 100.988,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 224.964,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 3.13,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 10.02,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.333,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 2039.866,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 25.734,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23801.176,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1230.067,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 566.619,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 459.557,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.16,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 6.377,
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
          "id": "ac4dbc2163d903ba48980c9a436f5a39a496c6ea",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/ac4dbc2163d903ba48980c9a436f5a39a496c6ea"
        },
        "date": 1773940722430,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.068,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.024,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 145.234,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.715,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 232.178,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 7.993,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.232,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.143,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.954,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.07,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.913,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.296,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 233.83,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.16,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.699,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.709,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.892,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.137,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 178.107,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 1.298,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 240.877,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.767,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.325,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.89,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 100.283,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 1.39,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1549.946,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 81.379,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 241.282,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 0.618,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.614,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.151,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 198.643,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 2.522,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2961.206,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 169.013,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 248.227,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 3.305,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.614,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.285,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1013.421,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 31.297,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22583.18,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 439.708,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 847.624,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 789.316,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 15.719,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 4.661,
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
          "id": "db5c3cccac995b643b3b72747c5d503ac6faf130",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/db5c3cccac995b643b3b72747c5d503ac6faf130"
        },
        "date": 1773940848621,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.107,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.044,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 145.161,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 12.51,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 234.603,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 8.102,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.479,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.255,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.788,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.045,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.838,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.373,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 237.688,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.804,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 14.233,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 2.019,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.461,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.289,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 179.648,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 0.442,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 245.116,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 1.71,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.731,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.899,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 98.349,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.65,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1552.313,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 87.367,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 248.019,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 1.701,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.867,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.216,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 193.525,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.217,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2958.77,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 174.034,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 250.903,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 0.6,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.973,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.303,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 987.831,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 15.448,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22531.08,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 514.608,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 705.121,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 638.883,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 17.536,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 7.253,
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
          "id": "763306ba6280634c1cedf09d1f2dcef17519bcce",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/763306ba6280634c1cedf09d1f2dcef17519bcce"
        },
        "date": 1773940991879,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.084,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.033,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 139.551,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 1.082,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 229.604,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 4.016,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.501,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.3,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.735,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.031,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 158.349,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 3.821,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 231.671,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 1.436,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.757,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.644,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.143,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.096,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 176.955,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 1.351,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 239.871,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 2.062,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.693,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.707,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 97.118,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.516,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1550.526,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 90.245,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 247.478,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 9.14,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.608,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.043,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 190.334,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.463,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2927.406,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 183.504,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 245.103,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.383,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.617,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.111,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 966.988,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 36.495,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23457.35,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 786.774,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 440.434,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 185.366,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 14.305,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.256,
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
          "id": "d3356a50fb608503d8fc92bbfb8b3ecca6f61836",
          "message": "Claude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-18T22:19:55Z",
          "url": "https://github.com/HanSur94/FastSense/pull/38/commits/d3356a50fb608503d8fc92bbfb8b3ecca6f61836"
        },
        "date": 1773941065768,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.122,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.069,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 143.334,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 1.492,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 237.716,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 1.592,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 16.405,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.353,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 10.421,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.085,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 165.56,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 3.431,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 252.648,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 15.119,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 15.82,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.729,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 20.535,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.215,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 187.684,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 1.618,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 252.927,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 4.126,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 15.5,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.982,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 103.778,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 1.129,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1632.299,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 97.108,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 254.955,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.251,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 15.681,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.809,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 213.427,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 10.31,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 3116.706,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 159.578,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 262.31,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.948,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 15.812,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 0.883,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1042.367,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 33.218,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23505.322,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 1241.429,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 688.837,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 504.688,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.637,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.053,
            "unit": "ms"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "50265832+HanSur94@users.noreply.github.com",
            "name": "Hannes Suhr",
            "username": "HanSur94"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "a1a4ec3bb2356ce9d6903848fbce023dafe23eeb",
          "message": "Merge pull request #38 from HanSur94/claude/optimize-sensor-resolve-1Xpjc\n\nClaude/optimize sensor resolve 1 xpjc",
          "timestamp": "2026-03-19T18:25:27+01:00",
          "tree_id": "d16a1bc3508deca59eeedbe50e834a57512b18c1",
          "url": "https://github.com/HanSur94/FastSense/commit/a1a4ec3bb2356ce9d6903848fbce023dafe23eeb"
        },
        "date": 1773941652185,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.087,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.03,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 141.182,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 1.74,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 231.912,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 2.301,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.8,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.386,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 11.147,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.191,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 161.876,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.05,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 239.274,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 3.149,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.866,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.954,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 22.451,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.136,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 184.683,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 5.976,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 246.656,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 0.959,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.556,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.93,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 112.158,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.211,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1591.185,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 90.758,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 249.976,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 6.956,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.843,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.192,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 225.567,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.281,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 3058.139,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 191.687,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 251.26,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 2.291,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.844,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.149,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 1134.469,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 30.238,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 23373.919,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 836.561,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 434.157,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 138.304,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 13.832,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.182,
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
          "id": "4b1dc3111c510f6d4a9ab541b84dfb224d8100be",
          "message": "ci: add Windows MEX build job",
          "timestamp": "2026-03-19T17:25:36Z",
          "url": "https://github.com/HanSur94/FastSense/pull/39/commits/4b1dc3111c510f6d4a9ab541b84dfb224d8100be"
        },
        "date": 1773941767412,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 2.093,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.032,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 137.783,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 0.587,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 229.225,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 1.875,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 14.35,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 4.228,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 9.849,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.032,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 156.461,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 0.79,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 236.118,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 2.137,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 13.846,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.806,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 19.487,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.073,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 177.228,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 2.027,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 242.761,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 2.407,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 13.339,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 0.867,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 100.328,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.432,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1545.304,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 88.973,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 245.675,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 5.858,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 13.617,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 1.026,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 194.161,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 1.71,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2947.545,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 175.199,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 247.028,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 1.097,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 13.993,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.526,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 984.842,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 20.724,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 22759.192,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 593.678,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 424.597,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 115.233,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 23.888,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 18.276,
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
          "id": "2298f19bed09a9f8ce6803070c700740a85e55bd",
          "message": "ci: add Windows MEX build job",
          "timestamp": "2026-03-19T17:25:36Z",
          "url": "https://github.com/HanSur94/FastSense/pull/39/commits/2298f19bed09a9f8ce6803070c700740a85e55bd"
        },
        "date": 1773941968938,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Downsample mean (1M)",
            "value": 3.811,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(1M)",
            "value": 0.057,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (1M)",
            "value": 121.294,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(1M)",
            "value": 0.991,
            "unit": "ms"
          },
          {
            "name": "Render mean (1M)",
            "value": 208.24,
            "unit": "ms"
          },
          {
            "name": "Render mean std(1M)",
            "value": 4.334,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (1M)",
            "value": 11.726,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(1M)",
            "value": 3.93,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (5M)",
            "value": 20.492,
            "unit": "ms"
          },
          {
            "name": "Downsample mean std(5M)",
            "value": 0.177,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (5M)",
            "value": 142.539,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean std(5M)",
            "value": 1.779,
            "unit": "ms"
          },
          {
            "name": "Render mean (5M)",
            "value": 216.738,
            "unit": "ms"
          },
          {
            "name": "Render mean std(5M)",
            "value": 0.799,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (5M)",
            "value": 11.289,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean std(5M)",
            "value": 1.541,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (10M)",
            "value": 40.679,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std10M)",
            "value": 0.099,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (10M)",
            "value": 172.688,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std10M)",
            "value": 3.1,
            "unit": "ms"
          },
          {
            "name": "Render mean (10M)",
            "value": 232.705,
            "unit": "ms"
          },
          {
            "name": "Render mean  std10M)",
            "value": 3.55,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (10M)",
            "value": 10.725,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std10M)",
            "value": 1.029,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (50M)",
            "value": 207.195,
            "unit": "ms"
          },
          {
            "name": "Downsample mean  std50M)",
            "value": 0.475,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (50M)",
            "value": 1414.412,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean  std50M)",
            "value": 49.241,
            "unit": "ms"
          },
          {
            "name": "Render mean (50M)",
            "value": 221.922,
            "unit": "ms"
          },
          {
            "name": "Render mean  std50M)",
            "value": 2.014,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (50M)",
            "value": 11.104,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean  std50M)",
            "value": 0.918,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (100M)",
            "value": 409.632,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 0.894,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (100M)",
            "value": 2751.649,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 103.136,
            "unit": "ms"
          },
          {
            "name": "Render mean (100M)",
            "value": 234.07,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 0.944,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (100M)",
            "value": 11.214,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.134,
            "unit": "ms"
          },
          {
            "name": "Downsample mean (500M)",
            "value": 2127.027,
            "unit": "ms"
          },
          {
            "name": "Downsample mean ( std00M)",
            "value": 57.943,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean (500M)",
            "value": 24606.626,
            "unit": "ms"
          },
          {
            "name": "Instantiation mean ( std00M)",
            "value": 406.398,
            "unit": "ms"
          },
          {
            "name": "Render mean (500M)",
            "value": 368.324,
            "unit": "ms"
          },
          {
            "name": "Render mean ( std00M)",
            "value": 48.363,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean (500M)",
            "value": 11.245,
            "unit": "ms"
          },
          {
            "name": "Zoom cycle mean ( std00M)",
            "value": 1.123,
            "unit": "ms"
          }
        ]
      }
    ]
  }
}