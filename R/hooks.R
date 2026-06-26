# Lazily create the process-wide `InstrumentHooks` singleton and register the
# integration once. Stored in `the$hooks` and reused by `test()`.
cod_hooks <- function() {
  if (is.null(the$hooks)) {
    the$hooks <- .Call(ffi_hooks_init)
    .Call(ffi_set_integration, the$hooks, "cod", "0.0.1")
  }
  the$hooks
}

# Resolve the active CodSpeed measurement mode from `CODSPEED_RUNNER_MODE`,
# mirroring pytest-codspeed: "walltime" -> walltime; everything else (including
# "instrumentation"/"simulation" and unset-while-instrumented) -> simulation.
# "memory" mode is treated as simulation (single evaluation) for now.
cod_mode <- function() {
  if (is.null(the$mode)) {
    the$mode <- switch(
      Sys.getenv("CODSPEED_RUNNER_MODE"),
      walltime = "walltime",
      "simulation"
    )
  }
  the$mode
}

#' Is the current process running under CodSpeed instrumentation?
#'
#' @return A single logical. `FALSE` when not running under the CodSpeed runner,
#'   in which case [test()] simply evaluates its expression.
#' @export
is_instrumented <- function() {
  .Call(ffi_is_instrumented, cod_hooks())
}
