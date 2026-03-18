<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: Utilities

## `ConsoleProgressBar` --- Single-line console progress bar with indentation.

> Inherits from: `handle`

A lightweight progress indicator that renders an ASCII/Unicode bar
  on a single console line, overwriting itself on each update via
  backspace characters. Supports optional leading indentation so
  multiple bars can be stacked hierarchically.

  The typical lifecycle is:  construct -> start -> update (loop) ->
  freeze or finish. Calling freeze() prints a newline to make the
  current state permanent, allowing a subsequent bar to render on a
  fresh line below. Calling finish() sets progress to 100 % and
  freezes automatically.

  On GNU Octave the bar uses ASCII characters (# and -). On MATLAB
  it uses Unicode block characters for a smoother appearance.

### Constructor

```matlab
obj = ConsoleProgressBar(indent)
```

CONSOLEPROGRESSBAR Construct a progress bar instance.
  pb = ConsoleProgressBar() creates a bar with no indentation.

### Methods

#### `start(obj)`

START Initialize and render the progress bar for the first time.
  pb.start() resets the frozen/started state and prints the
  initial (empty) bar. Must be called before update() will
  have any visible effect.

#### `update(obj, current, total, label)`

UPDATE Set progress counters and redraw the bar.
  pb.update(current, total) updates the progress fraction
  to current/total and redraws the bar in-place.

#### `freeze(obj)`

FREEZE Make the current bar state permanent by printing a newline.
  pb.freeze() redraws the bar one final time, appends a
  newline character, and sets IsFrozen to true. Subsequent
  calls to update() are silently ignored. Use this when you
  want the bar to remain visible while a new bar starts on
  the next line.

#### `finish(obj)`

FINISH Set progress to 100 %, freeze, and mark the bar done.
  pb.finish() fills the bar to completion, prints a newline
  (if not already frozen), and sets IsStarted to false. This
  is a convenience shortcut equivalent to calling
  pb.update(total, total) followed by pb.freeze().

