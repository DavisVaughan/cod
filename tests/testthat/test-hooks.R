test_that("hooks can be initialized and deinitialized", {
  h <- .Call(cod:::ffi_hooks_init)
  expect_type(h, "externalptr")

  # Explicit deinit, then the finalizer running again, must not crash.
  expect_null(.Call(cod:::ffi_hooks_deinit, h))
  expect_null(.Call(cod:::ffi_hooks_deinit, h))
})

test_that("not running under CodSpeed when not instrumented", {
  expect_false(cod::is_instrumented())
})

test_that("measurement bindings succeed (no-op when not instrumented)", {
  h <- .Call(cod:::ffi_hooks_init)
  on.exit(.Call(cod:::ffi_hooks_deinit, h))

  expect_identical(.Call(cod:::ffi_start_benchmark, h), 0L)
  expect_identical(.Call(cod:::ffi_stop_benchmark, h), 0L)
  expect_identical(.Call(cod:::ffi_start_benchmark_inline, h), 0L)
  expect_identical(.Call(cod:::ffi_stop_benchmark_inline, h), 0L)
  expect_identical(.Call(cod:::ffi_set_integration, h, "cod", "1.0.0"), 0L)
  expect_identical(
    .Call(
      cod:::ffi_set_executed_benchmark,
      h,
      Sys.getpid(),
      "tests/bench/x.R::y"
    ),
    0L
  )
  expect_identical(
    .Call(
      cod:::ffi_add_marker,
      h,
      Sys.getpid(),
      2L,
      .Call(cod:::ffi_current_timestamp)
    ),
    0L
  )
})

test_that("current_timestamp is monotonic nanoseconds", {
  t1 <- .Call(cod:::ffi_current_timestamp)
  t2 <- .Call(cod:::ffi_current_timestamp)
  expect_type(t1, "double")
  expect_gte(t2, t1)
})

test_that("callgrind controls and feature flags are safe no-ops outside Valgrind", {
  expect_null(.Call(cod:::ffi_callgrind_start_instrumentation))
  expect_null(.Call(cod:::ffi_callgrind_stop_instrumentation))
  expect_null(.Call(cod:::ffi_callgrind_toggle_collect))
  expect_identical(.Call(cod:::ffi_callgrind_add_obj_skip, "/path/to/obj"), 0L)
  expect_null(.Call(cod:::ffi_set_feature, 0, TRUE))
})

test_that("deref rejects non-pointers and freed pointers", {
  expect_error(.Call(cod:::ffi_is_instrumented, 1L), "external pointer")

  h <- .Call(cod:::ffi_hooks_init)
  .Call(cod:::ffi_hooks_deinit, h)
  expect_error(.Call(cod:::ffi_is_instrumented, h), "deinitialized")
})
