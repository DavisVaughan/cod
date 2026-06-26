#!/usr/bin/env Rscript

# Vendor the CodSpeed instrument-hooks C library into
# `src/vendor/instrument-hooks/`.
#
# Copies the amalgamated `dist/core.c`, the public `includes/` headers, and the
# license files from a local instrument-hooks checkout given by
# `$INSTRUMENT_HOOKS_PATH` (default: the development checkout below).
#
# Usage:
#   INSTRUMENT_HOOKS_PATH=/path/to/instrument-hooks Rscript tools/vendor-instrument-hooks.R

src <- Sys.getenv(
  "INSTRUMENT_HOOKS_PATH",
  "/Users/davis/files/programming/instrument-hooks"
)
if (!dir.exists(src)) {
  stop("instrument-hooks checkout not found at: ", src)
}

dest <- file.path(normalizePath("."), "src", "vendor", "instrument-hooks")
unlink(dest, recursive = TRUE)
dir.create(file.path(dest, "dist"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(dest, "includes"), recursive = TRUE, showWarnings = FALSE)

file.copy(file.path(src, "dist", "core.c"), file.path(dest, "dist", "core.c"))

headers <- list.files(file.path(src, "includes"), pattern = "\\.h$", full.names = TRUE)
file.copy(headers, file.path(dest, "includes"), overwrite = TRUE)

licenses <- list.files(src, pattern = "^LICENSE", full.names = TRUE)
file.copy(licenses, dest, overwrite = TRUE)

# Record the vendored commit for provenance.
rev <- tryCatch(
  system2("git", c("-C", src, "rev-parse", "HEAD"), stdout = TRUE, stderr = NULL),
  error = function(e) NA_character_
)
writeLines(
  c(
    "instrument-hooks vendored from:",
    paste0("  source: ", src),
    paste0("  commit: ", if (length(rev)) rev[[1]] else "unknown"),
    paste0("  date:   ", format(Sys.Date()))
  ),
  file.path(dest, "VENDORED")
)

cat("Vendored instrument-hooks from", src, "\n")
