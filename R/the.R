# Internal package state.
#
# - `hooks`: the singleton `InstrumentHooks` external pointer, created lazily by
#   `cod_hooks()` on first use.
# - `file_path`: the git-relative path of the benchmark file currently being
#   sourced, set by `test_file()` and read by `test()`.
# - `mode`: the cached CodSpeed measurement mode, resolved by `cod_mode()`.
# - `results`: accumulated walltime benchmark results, flushed to the results
#   file after each `test()` in walltime mode.
the <- new.env(parent = emptyenv())
the$hooks <- NULL
the$file_path <- NULL
the$mode <- NULL
the$results <- NULL
