test_that("demo_fib computes Fibonacci numbers", {
  expect_identical(cod:::demo_fib(0L), 0)
  expect_identical(cod:::demo_fib(1L), 1)
  expect_identical(cod:::demo_fib(10L), 55)
  expect_identical(cod:::demo_fib(20L), 6765)
})
