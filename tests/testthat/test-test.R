test_that("test() evaluates expr and returns invisibly when not instrumented", {
  hits <- 0L
  res <- withVisible(cod::test("noop", {
    hits <- hits + 1L
  }))
  expect_identical(hits, 1L)
  expect_false(res$visible)
  expect_null(res$value)
})

test_that("test() captures expr lazily (not pre-evaluated)", {
  expect_error(
    cod::test("boom", stop("should not run eagerly")),
    "should not run"
  )
})

test_that("benchmark_uri uses the file path when set", {
  the <- cod:::the
  old <- the$file_path
  on.exit(the$file_path <- old)

  the$file_path <- "tests/bench/arith.R"
  expect_identical(
    cod:::benchmark_uri("addition"),
    "tests/bench/arith.R::addition"
  )

  the$file_path <- NULL
  the$warned_no_file <- TRUE # silence the one-time warning
  expect_identical(cod:::benchmark_uri("addition"), "addition")
})

test_that("test_file() sets a tests/bench path and restores it", {
  bench <- tempfile(fileext = ".R")
  on.exit(unlink(bench))
  writeLines(
    c(
      'assign("seen_path", cod:::the$file_path, envir = globalenv())',
      'cod::test("inner", { assign("inner_ran", TRUE, envir = globalenv()) })'
    ),
    bench
  )

  cod::test_file(bench)

  expect_identical(
    get("seen_path", globalenv()),
    file.path("tests", "bench", basename(bench))
  )
  expect_true(get("inner_ran", globalenv()))
  expect_null(cod:::the$file_path) # restored

  rm("seen_path", "inner_ran", envir = globalenv())
})

test_that("ffi_instrument evaluates the expression n times", {
  h <- .Call(cod:::ffi_hooks_init)
  on.exit(.Call(cod:::ffi_hooks_deinit, h))

  counter <- new.env()
  counter$n <- 0L
  expr <- quote(counter$n <- counter$n + 1L)

  .Call(cod:::ffi_instrument, h, expr, environment(), 5L)
  expect_identical(counter$n, 5L)
})

test_that("ffi_walltime_run returns per-round samples and a warmup count", {
  h <- .Call(cod:::ffi_hooks_init)
  on.exit(.Call(cod:::ffi_hooks_deinit, h))

  res <- .Call(
    cod:::ffi_walltime_run,
    h,
    quote(sum(1:100)),
    environment(),
    1e6, # 1ms warmup
    5e6, # 5ms measurement budget
    1e5,
    Sys.getpid()
  )

  expect_type(res$samples, "double")
  expect_gte(length(res$samples), 1L)
  expect_true(all(res$samples >= 0))
  expect_gte(res$warmup, 1L)
})

test_that("walltime_benchmark matches the CodSpeed results schema", {
  samples <- c(10, 20, 30, 40, 1000) # ns, with one outlier
  bench <- cod:::walltime_benchmark(
    "b",
    "tests/bench/x.R::b",
    samples,
    warmup = 3L,
    cfg = cod:::walltime_config()
  )

  expect_identical(bench$name, "b")
  expect_identical(bench$stats$rounds, 5L)
  expect_identical(bench$stats$min_ns, 10)
  expect_identical(bench$stats$max_ns, 1000)
  expect_identical(bench$stats$iter_per_round, 1L)
  expect_identical(bench$stats$warmup_iters, 3L)
  # Quantiles use R type 7 (linear interpolation).
  expect_equal(bench$stats$median_ns, 30)
  expect_gte(bench$stats$iqr_outlier_rounds, 1L)
})

test_that("write_walltime_results writes a parseable results file", {
  dir <- tempfile("cod-profile")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  old <- Sys.getenv("CODSPEED_PROFILE_FOLDER", unset = NA)
  Sys.setenv(CODSPEED_PROFILE_FOLDER = dir)
  on.exit(
    if (is.na(old)) {
      Sys.unsetenv("CODSPEED_PROFILE_FOLDER")
    } else {
      Sys.setenv(CODSPEED_PROFILE_FOLDER = old)
    },
    add = TRUE
  )

  bench <- cod:::walltime_benchmark(
    "b",
    "tests/bench/x.R::b",
    c(10, 20, 30),
    warmup = 2L,
    cfg = cod:::walltime_config()
  )
  path <- cod:::write_walltime_results(list(bench))

  expect_true(file.exists(path))
  parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expect_identical(parsed$creator$name, "cod")
  expect_identical(parsed$instrument$type, "walltime")
  expect_length(parsed$benchmarks, 1L)
  expect_identical(parsed$benchmarks[[1]]$uri, "tests/bench/x.R::b")
})

test_that("check_string rejects non-strings", {
  expect_error(cod::test(c("a", "b"), 1), "single string")
  expect_error(cod::test_file(1L), "single string")
})
