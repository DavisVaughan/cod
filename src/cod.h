#ifndef COD_H
#define COD_H

#include <rlang.h>

// The public instrument-hooks C API, found via the `-I` flag in Makevars.
// A few of its declarations use `()` instead of `(void)`, which trips
// `-Wstrict-prototypes`, so suppress that warning just for this header.
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
#elif defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpragmas"
#pragma GCC diagnostic ignored "-Wstrict-prototypes"
#endif

#include "core.h"

#if defined(__clang__)
#pragma clang diagnostic pop
#elif defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

#endif
