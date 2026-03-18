window.BENCHMARK_DATA = {
  "lastUpdate": 1773866434787,
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
      }
    ]
  }
}