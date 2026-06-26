# Example CodSpeed benchmark file.
#
# Run under CodSpeed with, e.g.:
#   codspeed run --skip-upload -- Rscript -e 'cod::test_file("tests/bench/example.R")'
#
# Outside of CodSpeed, each `test()` simply evaluates its expression.

setup <- 1:1e6 + 0L
cod::test("something mildly complex", {
  unique(setup)
})
