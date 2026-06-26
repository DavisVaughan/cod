// Single translation unit for the vendored instrument-hooks amalgamation.
//
// The amalgamation is generated code that produces a number of harmless
// warnings. They are suppressed here with file-scoped pragmas (which override
// R's `-Wall`, unlike `-Wno-*` flags whose effect depends on command-line
// ordering). The suppression is confined to this translation unit, so cod's own
// code is still compiled with full warnings.

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-but-set-variable"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wstrict-prototypes"
#pragma clang diagnostic ignored "-Wformat-security"
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
#elif defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpragmas"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wstrict-prototypes"
#pragma GCC diagnostic ignored "-Wformat-security"
#pragma GCC diagnostic ignored "-Wformat"
#pragma GCC diagnostic ignored "-Wincompatible-pointer-types"
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#pragma GCC diagnostic ignored "-Wtype-limits"
#endif

#include "vendor/instrument-hooks/dist/core.c"

#if defined(__clang__)
#pragma clang diagnostic pop
#elif defined(__GNUC__)
#pragma GCC diagnostic pop
#endif
