window.BENCHMARK_DATA = {
  "lastUpdate": 1773855117443,
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
      }
    ]
  }
}