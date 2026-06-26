#include "cod.h"
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

// Initialize the vendored rlang C library. Called from `.onLoad()`.
r_obj* cod_init_library(r_obj* ns) {
    r_init_library(ns);
    return r_null;
}

// Lifecycle
extern r_obj* ffi_hooks_init(void);
extern r_obj* ffi_hooks_deinit(r_obj*);

// Bindings
extern r_obj* ffi_is_instrumented(r_obj*);
extern r_obj* ffi_start_benchmark(r_obj*);
extern r_obj* ffi_start_benchmark_inline(r_obj*);
extern r_obj* ffi_stop_benchmark(r_obj*);
extern r_obj* ffi_stop_benchmark_inline(r_obj*);
extern r_obj* ffi_set_executed_benchmark(r_obj*, r_obj*, r_obj*);
extern r_obj* ffi_set_integration(r_obj*, r_obj*, r_obj*);
extern r_obj* ffi_add_marker(r_obj*, r_obj*, r_obj*, r_obj*);
extern r_obj* ffi_current_timestamp(void);
extern r_obj* ffi_set_feature(r_obj*, r_obj*);
extern r_obj* ffi_callgrind_start_instrumentation(void);
extern r_obj* ffi_callgrind_stop_instrumentation(void);
extern r_obj* ffi_callgrind_toggle_collect(void);
extern r_obj* ffi_callgrind_add_obj_skip(r_obj*);
extern r_obj* ffi_set_environment(r_obj*, r_obj*, r_obj*, r_obj*);
extern r_obj* ffi_set_environment_list(r_obj*, r_obj*, r_obj*, r_obj*);
extern r_obj* ffi_write_environment(r_obj*, r_obj*);

// Measurement
extern r_obj* ffi_instrument(r_obj*, r_obj*, r_obj*, r_obj*);
extern r_obj* ffi_walltime_run(
    r_obj*,
    r_obj*,
    r_obj*,
    r_obj*,
    r_obj*,
    r_obj*,
    r_obj*
);

static const R_CallMethodDef call_entries[] = {
    {"cod_init_library", (DL_FUNC) &cod_init_library, 1},

    {"ffi_hooks_init", (DL_FUNC) &ffi_hooks_init, 0},
    {"ffi_hooks_deinit", (DL_FUNC) &ffi_hooks_deinit, 1},

    {"ffi_is_instrumented", (DL_FUNC) &ffi_is_instrumented, 1},
    {"ffi_start_benchmark", (DL_FUNC) &ffi_start_benchmark, 1},
    {"ffi_start_benchmark_inline", (DL_FUNC) &ffi_start_benchmark_inline, 1},
    {"ffi_stop_benchmark", (DL_FUNC) &ffi_stop_benchmark, 1},
    {"ffi_stop_benchmark_inline", (DL_FUNC) &ffi_stop_benchmark_inline, 1},
    {"ffi_set_executed_benchmark", (DL_FUNC) &ffi_set_executed_benchmark, 3},
    {"ffi_set_integration", (DL_FUNC) &ffi_set_integration, 3},
    {"ffi_add_marker", (DL_FUNC) &ffi_add_marker, 4},
    {"ffi_current_timestamp", (DL_FUNC) &ffi_current_timestamp, 0},
    {"ffi_set_feature", (DL_FUNC) &ffi_set_feature, 2},
    {"ffi_callgrind_start_instrumentation",
     (DL_FUNC) &ffi_callgrind_start_instrumentation,
     0},
    {"ffi_callgrind_stop_instrumentation",
     (DL_FUNC) &ffi_callgrind_stop_instrumentation,
     0},
    {"ffi_callgrind_toggle_collect",
     (DL_FUNC) &ffi_callgrind_toggle_collect,
     0},
    {"ffi_callgrind_add_obj_skip", (DL_FUNC) &ffi_callgrind_add_obj_skip, 1},
    {"ffi_set_environment", (DL_FUNC) &ffi_set_environment, 4},
    {"ffi_set_environment_list", (DL_FUNC) &ffi_set_environment_list, 4},
    {"ffi_write_environment", (DL_FUNC) &ffi_write_environment, 2},

    {"ffi_instrument", (DL_FUNC) &ffi_instrument, 4},
    {"ffi_walltime_run", (DL_FUNC) &ffi_walltime_run, 7},

    {NULL, NULL, 0}
};

attribute_visible void R_init_cod(DllInfo* dll) {
    R_registerRoutines(dll, NULL, call_entries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
