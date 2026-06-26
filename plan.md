# Plan: `cod` — a CodSpeed custom harness for R

## Context

CodSpeed has no R integration. CodSpeed ships `instrument-hooks`, a single-file C
library (`dist/core.c` + `includes/`) that bridges a language's benchmark harness
to the CodSpeed runner over IPC. We will build an R package, **`cod`**, that:

1. Exposes the full `instrument-hooks` C API to R via `.Call` (a thin, 1:1
   binding layer).
2. Builds an ergonomic high-level API on top — `cod::test("desc", expr)` and
   `cod::test_file(path)` — that instruments an R expression so its results are
   recorded when the R process runs under `codspeed run`.

The package follows vctrs/rlang conventions: vendored rlang C library, plain
`R_CallMethodDef` registration, `air`-formatted R, and `clang-format`-formatted C
using rlang's `.clang-format`.

### Key facts established during research

- **C API** (`includes/core.h`): opaque `InstrumentHooks*`; lifecycle is
  `init → is_instrumented → set_integration → start_benchmark → run → stop_benchmark
  → set_executed_benchmark → deinit`. All functions return `uint8_t` (`0` = success).
- **Two measurement modes, opposite needs.** *Simulation* (Callgrind) counts every
  instruction between `start`/`stop`, so the body must run **exactly once** with no
  bookkeeping in the window. *Walltime* (perf) needs **many calibrated iterations**
  with `BENCHMARK_START/END` markers bracketing each real eval.
- **The public API cannot report the active mode.** It is resolved internally
  (Valgrind detection or the FIFO `GetIntegrationMode` handshake). Mode must instead
  be read from the env var **`CODSPEED_RUNNER_MODE`** set by the `codspeed` CLI:
  `"walltime"` → walltime; `"memory"` → memory; anything else / unset-while-instrumented
  → simulation. (Mirrors `pytest-codspeed/src/pytest_codspeed/plugin.py`.)
- **`__codspeed_root_frame__`**: the benchmarked code must run inside a `noinline`
  C function whose name starts with `__codspeed_root_frame__`, for clean flamegraph
  roots.
- **URI convention**: `{git_relative_file_path}::{name}`. Benchmark files live at
  `tests/bench/<file>.R`, so the path always starts with `tests/bench/`.
- **Platform reality**: Simulation/Callgrind is **Linux-only**. macOS (the dev
  machine) supports walltime + environment only; Windows is no-op stubs. End-to-end
  *simulation* verification therefore requires Linux/CI; macOS can exercise the
  not-instrumented and walltime paths.

## Architecture

```
R layer
  cod::test(name, expr)      capture expr unevaluated, build URI, dispatch by mode
  cod::test_file(path)       set the$file_path, source() the file
  cod::is_instrumented()     thin predicate
  the                        internal env: $hooks (singleton extptr), $file_path, $mode

C layer
  ffi_* thin bindings        1:1 over every instrument_hooks_* function
  ffi_hooks_init             returns R_MakeExternalPtr + deinit finalizer
  ffi_instrument(...)        tight in-C measurement loop using the noinline root frame

Vendored
  src/rlang/ + src/rlang.c             rlang C library (r_obj*, KEEP/FREE, r_init_library)
  src/vendor/instrument-hooks/         dist/core.c + includes/ + LICENSEs
```

### Singleton lifecycle

`ffi_hooks_init()` calls `instrument_hooks_init()`, wraps the pointer with
`R_MakeExternalPtr` + `R_RegisterCFinalizerEx` (finalizer calls
`instrument_hooks_deinit`, guarding against NULL/double-free). The high-level API
lazily creates **one** hooks object on first use, calls
`instrument_hooks_set_integration("cod", <pkg version>)` once, and stores it in the
package-internal `the$hooks`.

## Implementation

### 1. Package skeleton

- `DESCRIPTION`: `Imports: rlang`; `Suggests: testthat (>= 3.0.0)`;
  `Config/build/compilation-database: true`; `Config/testthat/edition: 3`;
  `Depends: R (>= 4.0.0)`. Not targeting CRAN (documented).
- `NAMESPACE`: `useDynLib(cod, .registration = TRUE)` + exports.
- `R/zzz.R`: `.onLoad` runs `check_linked_version()` then
  `.Call(cod_init_library, ns_env("cod"))`; `.onUnload` finalizer if needed.
- `R/the.R`: `the <- new.env(parent = emptyenv())`.

### 2. Vendoring (sync scripts in `tools/`)

- **rlang C library**: `tools/vendor-rlang.R` invokes `rlang:::use_rlang_c_library()`
  with `RLANG_PATH=/Users/davis/files/r/packages/rlang` (local source). Produces
  `src/rlang/` and `src/rlang.c`.
- **instrument-hooks**: `tools/vendor-instrument-hooks.R` copies `dist/core.c`,
  `includes/*.h`, and `LICENSE-*` into `src/vendor/instrument-hooks/`, from a path
  given by `INSTRUMENT_HOOKS_PATH` (default the local clone
  `/Users/davis/files/programming/instrument-hooks`), pinned to a recorded
  commit/tag. Mirrors rlang's `RLANG_PATH` convention.
- Vendored licenses recorded (instrument-hooks is MIT/Apache dual; `valgrind.h` /
  `callgrind.h` are Valgrind BSD-style).

### 3. Build (`src/Makevars`)

```make
PKG_CPPFLAGS = -I./rlang -I./vendor/instrument-hooks/includes
PKG_CFLAGS = $(C_VISIBILITY) -Wno-maybe-uninitialized -Wno-unused-variable \
  -Wno-unused-parameter -Wno-unused-but-set-variable -Wno-type-limits \
  -Wno-format -Wno-format-security
```

- Single Makevars (no `.win`), following vctrs. The `-Wno-*` set is the documented
  upstream suppression list; clang silently accepts unknown `-Wno-*`, so it is safe
  on macOS.
- `src/rlang.c` (`#include "rlang/rlang.c"`) and a new
  `src/instrument-hooks.c` (`#include "vendor/instrument-hooks/dist/core.c"`) make
  the amalgamations single, self-contained translation units — R's default rule only
  compiles top-level `src/*.c`, so the subdirectory sources are pulled in via these.

### 4. C files

- `src/cod.h`: includes `<rlang.h>` and `"core.h"`; shared decls.
- `src/init.c`: `R_init_cod()` → `R_registerRoutines` + `R_useDynamicSymbols(FALSE)`;
  `R_CallMethodDef` table for all `ffi_*`; `cod_init_library` (`.Call`) → `r_init_library(ns)`.
- `src/hooks.c`:
  - External-pointer init/finalizer; `hooks_from_extptr()` helper (NULL-checks).
  - **Thin 1:1 bindings** (return code surfaced to R as integer): `ffi_is_instrumented`,
    `ffi_start_benchmark`(+`_inline`), `ffi_stop_benchmark`(+`_inline`),
    `ffi_set_executed_benchmark`, `ffi_set_integration`, `ffi_add_marker`,
    `ffi_current_timestamp` (returns `double`; documents the ~2^53 ns precision limit),
    `ffi_set_feature`, `ffi_callgrind_start/stop_instrumentation`,
    `ffi_callgrind_toggle_collect`, `ffi_callgrind_add_obj_skip`,
    `ffi_set_environment`, `ffi_set_environment_list`, `ffi_write_environment`,
    `ffi_hooks_deinit`.
  - **`__codspeed_root_frame__cod_eval`**: `noinline`, body `return Rf_eval(expr, env);`.
  - **`ffi_instrument(ptr, expr, env, n_iters)`** (simulation): tight window —
    `start_benchmark_inline` → loop `n_iters` calling the root frame →
    `stop_benchmark_inline`. The runner collects the Callgrind output, so no
    results file is needed.
  - **`ffi_walltime_run(ptr, expr, env, warmup_time_ns, max_time_ns, max_rounds, pid)`**
    (walltime): untimed warmup, then time each root-frame evaluation, returning the
    per-round latencies (ns) + warmup count. Brackets the loop with
    `start_benchmark`/`stop_benchmark` and one `BENCHMARK_START/END` marker pair for
    the runner's flamegraph profiler only.

  > **Correction vs. the original design:** instrument-hooks does **not** record
  > walltime numbers — its start/stop/markers only feed the flamegraph. The
  > integration must measure timing itself and write the results JSON (see §5). This
  > is why an early walltime attempt showed "instrumented" but recorded nothing.

### 5. High-level R API (`R/test.R`)

- `cod_hooks()`: lazily init singleton, set integration once, cache in `the$hooks`.
- `cod_mode()`: read `CODSPEED_RUNNER_MODE`; map per the rule above; cache in `the$mode`.
- `cod::test(name, expr)`:
  - `expr <- substitute(expr)`; `env <- parent.frame()`.
  - URI: `paste0(the$file_path %||% <warn/fallback>, "::", name)`.
  - If `!is_instrumented()`: evaluate `expr` once and return invisibly (benchmarks
    stay runnable in normal R sessions / dev).
  - Simulation (`run_simulation`): `ffi_instrument(hooks, expr, env, 1L)` then
    `ffi_set_executed_benchmark`.
  - Walltime (`run_walltime`, in `R/walltime.R`): `ffi_walltime_run(...)` →
    `ffi_set_executed_benchmark` → compute stats from the per-round samples
    (`min/max/mean/stdev`, R type-7 quantiles, 1.5·IQR & 3·stdev outliers,
    `total_time`, `rounds`, `iter_per_round = 1`, `warmup_iters`) → accumulate in
    `the$results` → `write_walltime_results()` to
    `$CODSPEED_PROFILE_FOLDER/results/<pid>.json` (fallback `.codspeed/<pid>.json`),
    matching the CodSpeed `ResultData` schema with `creator.name = "cod"`.
- `cod::test_file(path)`: set `the$file_path <- file.path("tests/bench", basename(path))`,
  `source(path)` (which runs its `cod::test()` calls), restore `the$file_path` on exit.
  Driver usage: `codspeed run -- Rscript -e 'cod::test_file("tests/bench/foo.R")'`.

### 6. Formatting

- `src/.clang-format` copied from rlang verbatim; run `clang-format` on C.
- Run `air format` on R.

## Critical files

- New: `DESCRIPTION`, `NAMESPACE`, `R/zzz.R`, `R/the.R`, `R/test.R`,
  `src/cod.h`, `src/init.c`, `src/hooks.c`, `src/instrument-hooks.c`,
  `src/Makevars`, `src/.clang-format`,
  `tools/vendor-rlang.R`, `tools/vendor-instrument-hooks.R`.
- Vendored (generated): `src/rlang/**`, `src/rlang.c`,
  `src/vendor/instrument-hooks/{dist/core.c,includes/*.h,LICENSE-*}`.
- References: `includes/core.h` (API), `example/main.c` (lifecycle),
  vctrs `src/init.c` + `src/rlang.c` (registration/vendoring patterns),
  rlang `R/c-lib.R` (`use_rlang_c_library`), rlang `src/.clang-format`.

## Verification

1. **Build**: `R CMD INSTALL` (or `pkgbuild::compile_dll()`); confirm `core.c` and the
   rlang lib compile cleanly under the suppression flags on macOS clang.
2. **Unit tests (testthat, run locally on macOS)**:
   - Low-level bindings: `ffi_hooks_init` returns a usable extptr; functions return `0`
     when not instrumented; finalizer + explicit `deinit` don't double-free.
   - `cod::test()` evaluates `expr` and returns its value invisibly when not
     instrumented; URI is `tests/bench/<file>::<name>`.
   - `cod_mode()` mapping for each `CODSPEED_RUNNER_MODE` value.
3. **Instrumented end-to-end** (Linux/CI for simulation; macro runner for walltime):
   `codspeed run --skip-upload -- Rscript -e 'cod::test_file("tests/bench/example.R")'`;
   confirm `is_instrumented()` is true and benchmarks are detected. Then without
   `--skip-upload` to exercise upload.

## Open items / follow-ups

- Walltime calibration defaults are a first pass; refine against real macro-runner output.
- `memory` mode treated as simulation (single eval) for v1.
- `cod::test` / `cod::test_file` naming retained per request (note the conceptual
  overlap with testthat's `test_*`).
- Final plan will also be copied to `cod/plan.md` after exiting plan mode.
