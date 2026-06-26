#' Benchmark an expression under CodSpeed
#'
#' `test()` records the performance of `expr` when the R process is run under
#' the CodSpeed runner (`codspeed run -- Rscript ...`). When not running under
#' CodSpeed, `expr` is simply evaluated once so that benchmark files remain
#' runnable during development.
#'
#' The measurement strategy depends on the active CodSpeed mode (see
#' `CODSPEED_RUNNER_MODE`):
#'
#' * **Simulation** (CPU/Callgrind): `expr` is evaluated exactly once inside a
#'   tight measurement window, so the simulated instruction count reflects only
#'   the expression.
#' * **Walltime** (perf): `expr` is evaluated many times over a short time
#'   budget; the timing statistics are computed and written to the CodSpeed
#'   results file (`$CODSPEED_PROFILE_FOLDER/results/<pid>.json`).
#'
#' @param name A single string naming the benchmark. Combined with the current
#'   file path (set by [test_file()]) to form the CodSpeed benchmark URI
#'   `tests/bench/<file>::<name>`.
#' @param expr The expression to benchmark. Captured unevaluated and evaluated
#'   in the calling environment.
#'
#' @return `NULL`, invisibly.
#' @export
test <- function(name, expr) {
  check_string(name, "name")
  expr <- substitute(expr)
  env <- parent.frame()

  hooks <- cod_hooks()

  if (!.Call(ffi_is_instrumented, hooks)) {
    eval(expr, env)
    return(invisible(NULL))
  }

  pid <- Sys.getpid()
  uri <- benchmark_uri(name)

  if (cod_mode() == "walltime") {
    run_walltime(name, expr, env, uri, pid, hooks)
  } else {
    run_simulation(name, expr, env, uri, pid, hooks)
  }

  invisible(NULL)
}

# Simulation (Callgrind) measurement. The runner collects the callgrind output
# directly, so we only run the tight window and report which benchmark ran.
run_simulation <- function(name, expr, env, uri, pid, hooks) {
  .Call(ffi_instrument, hooks, expr, env, 1L)
  report_executed(name, uri, pid, hooks)
}

report_executed <- function(name, uri, pid, hooks) {
  rc <- .Call(ffi_set_executed_benchmark, hooks, pid, uri)
  if (rc != 0L) {
    abort(sprintf("CodSpeed failed to record benchmark '%s'.", name))
  }
}

#' Source a benchmark file
#'
#' Sets the benchmark file path used to build benchmark URIs, then sources
#' `path` so that the [test()] calls it contains are executed. Benchmark files
#' live under `tests/bench/` in the package being benchmarked, so the recorded
#' URI path is always `tests/bench/<basename(path)>`.
#'
#' @param path Path to a benchmark file (e.g. `"tests/bench/arith.R"`).
#'
#' @return `NULL`, invisibly.
#' @export
test_file <- function(path) {
  check_string(path, "path")

  old <- the$file_path
  on.exit(the$file_path <- old, add = TRUE)
  the$file_path <- file.path("tests", "bench", basename(path))

  env <- new.env(parent = globalenv())
  sys.source(path, envir = env)

  invisible(NULL)
}

# Build the CodSpeed benchmark URI. `the$file_path` is set by `test_file()`.
benchmark_uri <- function(name) {
  if (is.null(the$file_path)) {
    if (!isTRUE(the$warned_no_file)) {
      inform(
        "`test()` was called outside `test_file()`; benchmark URIs will not include a file path."
      )
      the$warned_no_file <- TRUE
    }
    return(name)
  }
  paste0(the$file_path, "::", name)
}

check_string <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    abort(sprintf("`%s` must be a single string.", arg))
  }
  invisible(x)
}
