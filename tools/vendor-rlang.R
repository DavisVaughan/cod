#!/usr/bin/env Rscript

# Vendor the rlang C library into `src/rlang/` + `src/rlang.c`.
#
# Uses rlang's own (unexported) `use_rlang_c_library()`, which copies the
# library from `$RLANG_PATH` (a local rlang checkout) or, if unset, downloads
# the development version from GitHub.
#
# Usage:
#   RLANG_PATH=/path/to/rlang Rscript tools/vendor-rlang.R

# Default to the local rlang checkout used during development.
if (!nzchar(Sys.getenv("RLANG_PATH"))) {
  Sys.setenv(RLANG_PATH = "/Users/davis/files/r/packages/rlang")
}
Sys.setenv(RLANG_LIB_NO_PROMPT = "true")

proj <- normalizePath(".")
usethis::proj_set(proj, force = TRUE)
dir.create(file.path(proj, "src"), showWarnings = FALSE)

rlang_ns <- asNamespace("rlang")
get("use_rlang_c_library", envir = rlang_ns)()

cat("Vendored rlang C library from", Sys.getenv("RLANG_PATH"), "\n")
