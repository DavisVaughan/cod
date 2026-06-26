test_that("cod_mode() maps CODSPEED_RUNNER_MODE", {
  the <- cod:::the
  reset_mode <- function() the$mode <- NULL

  with_mode <- function(value) {
    reset_mode()
    on.exit(reset_mode(), add = TRUE)
    old <- Sys.getenv("CODSPEED_RUNNER_MODE", unset = NA)
    on.exit(
      if (is.na(old)) {
        Sys.unsetenv("CODSPEED_RUNNER_MODE")
      } else {
        Sys.setenv(CODSPEED_RUNNER_MODE = old)
      },
      add = TRUE
    )
    if (is.na(value)) {
      Sys.unsetenv("CODSPEED_RUNNER_MODE")
    } else {
      Sys.setenv(CODSPEED_RUNNER_MODE = value)
    }
    cod:::cod_mode()
  }

  expect_identical(with_mode("walltime"), "walltime")
  expect_identical(with_mode("instrumentation"), "simulation")
  expect_identical(with_mode("simulation"), "simulation")
  expect_identical(with_mode("memory"), "simulation")
  expect_identical(with_mode(NA), "simulation")
})
