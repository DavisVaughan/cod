# Walltime measurement.
#
# Unlike simulation, the CodSpeed runner does not compute walltime numbers
# itself. The integration measures per-round latencies, computes summary
# statistics, and writes them to `$CODSPEED_PROFILE_FOLDER/results/<pid>.json`.
# The C loop also brackets the run with an instrument-hooks window + markers so
# the runner's profiler can build a flamegraph.

# Default measurement budget. The C loop stops at whichever limit is hit first.
walltime_config <- function() {
  list(
    warmup_time_ns = 0.1 * 1e9, # 100ms untimed warmup
    max_time_ns = 3 * 1e9, # 3s measurement budget
    max_rounds = 1e5
  )
}

run_walltime <- function(name, expr, env, uri, pid, hooks) {
  cfg <- walltime_config()

  res <- .Call(
    ffi_walltime_run,
    hooks,
    expr,
    env,
    cfg$warmup_time_ns,
    cfg$max_time_ns,
    cfg$max_rounds,
    pid
  )

  report_executed(name, uri, pid, hooks)

  benchmark <- walltime_benchmark(name, uri, res$samples, res$warmup, cfg)
  the$results <- c(the$results, list(benchmark))
  write_walltime_results(the$results)

  invisible(NULL)
}

# Build one benchmark entry matching CodSpeed's walltime results schema.
# Quantiles use linear interpolation (R type 7), and outliers use the same
# 1.5*IQR / 3*stdev rules as the other CodSpeed integrations.
walltime_benchmark <- function(name, uri, samples, warmup, cfg) {
  n <- length(samples)
  mean_ns <- mean(samples)
  stdev_ns <- if (n > 1) stats::sd(samples) else 0

  quantiles <- stats::quantile(
    samples,
    c(0.25, 0.5, 0.75),
    type = 7,
    names = FALSE
  )
  q1_ns <- quantiles[[1]]
  median_ns <- quantiles[[2]]
  q3_ns <- quantiles[[3]]
  iqr_ns <- q3_ns - q1_ns

  iqr_outliers <- sum(
    samples < q1_ns - 1.5 * iqr_ns | samples > q3_ns + 1.5 * iqr_ns
  )
  stdev_outliers <- sum(
    samples < mean_ns - 3 * stdev_ns | samples > mean_ns + 3 * stdev_ns
  )

  list(
    name = name,
    uri = uri,
    config = list(
      warmup_time_ns = cfg$warmup_time_ns,
      min_round_time_ns = NULL,
      max_time_ns = cfg$max_time_ns,
      max_rounds = NULL
    ),
    stats = list(
      min_ns = min(samples),
      max_ns = max(samples),
      mean_ns = mean_ns,
      stdev_ns = stdev_ns,
      q1_ns = q1_ns,
      median_ns = median_ns,
      q3_ns = q3_ns,
      rounds = n,
      total_time = sum(samples) / 1e9,
      iqr_outlier_rounds = iqr_outliers,
      stdev_outlier_rounds = stdev_outliers,
      iter_per_round = 1L,
      warmup_iters = warmup
    )
  )
}

# Folder the runner reads walltime results from. Falls back to `.codspeed/` in
# the working directory when not running under the runner.
walltime_result_dir <- function() {
  folder <- Sys.getenv("CODSPEED_PROFILE_FOLDER")
  if (nzchar(folder)) {
    file.path(folder, "results")
  } else {
    file.path(getwd(), ".codspeed")
  }
}

write_walltime_results <- function(benchmarks) {
  dir <- walltime_result_dir()
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, paste0(Sys.getpid(), ".json"))

  data <- list(
    creator = list(
      name = "cod",
      version = as.character(utils::packageVersion("cod")),
      pid = Sys.getpid()
    ),
    instrument = list(type = "walltime"),
    benchmarks = benchmarks
  )

  json <- jsonlite::toJSON(
    data,
    auto_unbox = TRUE,
    null = "null",
    digits = NA,
    pretty = TRUE
  )
  writeLines(json, path)

  invisible(path)
}
