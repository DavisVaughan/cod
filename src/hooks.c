#include "cod.h"

// ---------------------------------------------------------------------------
// InstrumentHooks lifecycle (external pointer + finalizer)
// ---------------------------------------------------------------------------

static void hooks_finalize(r_obj* ptr) {
    InstrumentHooks* hooks = (InstrumentHooks*) R_ExternalPtrAddr(ptr);
    if (hooks == NULL) {
        return;
    }
    instrument_hooks_deinit(hooks);
    R_ClearExternalPtr(ptr);
}

static InstrumentHooks* hooks_deref(r_obj* ptr) {
    if (r_typeof(ptr) != R_TYPE_pointer) {
        r_abort("`hooks` must be an external pointer.");
    }
    InstrumentHooks* hooks = (InstrumentHooks*) R_ExternalPtrAddr(ptr);
    if (hooks == NULL) {
        r_abort("CodSpeed hooks have already been deinitialized.");
    }
    return hooks;
}

r_obj* ffi_hooks_init(void) {
    InstrumentHooks* hooks = instrument_hooks_init();
    if (hooks == NULL) {
        r_abort("Failed to initialize CodSpeed instrument hooks.");
    }
    r_obj* ptr = KEEP(R_MakeExternalPtr(hooks, r_sym("cod_hooks"), r_null));
    R_RegisterCFinalizerEx(ptr, hooks_finalize, TRUE);
    FREE(1);
    return ptr;
}

r_obj* ffi_hooks_deinit(r_obj* ptr) {
    InstrumentHooks* hooks = (InstrumentHooks*) R_ExternalPtrAddr(ptr);
    if (hooks != NULL) {
        instrument_hooks_deinit(hooks);
        R_ClearExternalPtr(ptr);
    }
    return r_null;
}

// ---------------------------------------------------------------------------
// Thin 1:1 bindings over the instrument-hooks C API.
//
// Functions returning `uint8_t` (0 = success) are surfaced to R as integers so
// the R layer can check the return code.
// ---------------------------------------------------------------------------

r_obj* ffi_is_instrumented(r_obj* ptr) {
    return r_lgl(instrument_hooks_is_instrumented(hooks_deref(ptr)));
}

r_obj* ffi_start_benchmark(r_obj* ptr) {
    return r_int(instrument_hooks_start_benchmark(hooks_deref(ptr)));
}

r_obj* ffi_start_benchmark_inline(r_obj* ptr) {
    return r_int(instrument_hooks_start_benchmark_inline(hooks_deref(ptr)));
}

r_obj* ffi_stop_benchmark(r_obj* ptr) {
    return r_int(instrument_hooks_stop_benchmark(hooks_deref(ptr)));
}

r_obj* ffi_stop_benchmark_inline(r_obj* ptr) {
    return r_int(instrument_hooks_stop_benchmark_inline(hooks_deref(ptr)));
}

r_obj* ffi_set_executed_benchmark(r_obj* ptr, r_obj* pid, r_obj* uri) {
    uint8_t rc = instrument_hooks_set_executed_benchmark(
        hooks_deref(ptr),
        (int32_t) Rf_asInteger(pid),
        r_chr_get_c_string(uri, 0)
    );
    return r_int(rc);
}

r_obj* ffi_set_integration(r_obj* ptr, r_obj* name, r_obj* version) {
    uint8_t rc = instrument_hooks_set_integration(
        hooks_deref(ptr),
        r_chr_get_c_string(name, 0),
        r_chr_get_c_string(version, 0)
    );
    return r_int(rc);
}

r_obj* ffi_add_marker(
    r_obj* ptr,
    r_obj* pid,
    r_obj* marker_type,
    r_obj* timestamp
) {
    uint8_t rc = instrument_hooks_add_marker(
        hooks_deref(ptr),
        (int32_t) Rf_asInteger(pid),
        (uint8_t) Rf_asInteger(marker_type),
        (uint64_t) Rf_asReal(timestamp)
    );
    return r_int(rc);
}

// Returns the monotonic timestamp in nanoseconds as a double. Doubles hold
// integers exactly up to 2^53, i.e. ~104 days of nanoseconds, which is ample
// for intra-process deltas.
r_obj* ffi_current_timestamp(void) {
    return r_dbl((double) instrument_hooks_current_timestamp());
}

r_obj* ffi_set_feature(r_obj* feature, r_obj* enabled) {
    instrument_hooks_set_feature(
        (uint64_t) Rf_asReal(feature),
        (bool) Rf_asLogical(enabled)
    );
    return r_null;
}

r_obj* ffi_callgrind_start_instrumentation(void) {
    callgrind_start_instrumentation();
    return r_null;
}

r_obj* ffi_callgrind_stop_instrumentation(void) {
    callgrind_stop_instrumentation();
    return r_null;
}

r_obj* ffi_callgrind_toggle_collect(void) {
    callgrind_toggle_collect();
    return r_null;
}

r_obj* ffi_callgrind_add_obj_skip(r_obj* path) {
    return r_int(
        instrument_hooks_callgrind_add_obj_skip(r_chr_get_c_string(path, 0))
    );
}

r_obj* ffi_set_environment(
    r_obj* ptr,
    r_obj* section,
    r_obj* key,
    r_obj* value
) {
    uint8_t rc = instrument_hooks_set_environment(
        hooks_deref(ptr),
        r_chr_get_c_string(section, 0),
        r_chr_get_c_string(key, 0),
        r_chr_get_c_string(value, 0)
    );
    return r_int(rc);
}

r_obj* ffi_set_environment_list(
    r_obj* ptr,
    r_obj* section,
    r_obj* key,
    r_obj* values
) {
    r_ssize n = r_length(values);
    const char** c_values = (const char**) R_alloc(n, sizeof(const char*));
    for (r_ssize i = 0; i < n; ++i) {
        c_values[i] = r_chr_get_c_string(values, i);
    }
    uint8_t rc = instrument_hooks_set_environment_list(
        hooks_deref(ptr),
        r_chr_get_c_string(section, 0),
        r_chr_get_c_string(key, 0),
        c_values,
        (uint32_t) n
    );
    return r_int(rc);
}

r_obj* ffi_write_environment(r_obj* ptr, r_obj* pid) {
    uint8_t rc = instrument_hooks_write_environment(
        hooks_deref(ptr),
        (int32_t) Rf_asInteger(pid)
    );
    return r_int(rc);
}

// ---------------------------------------------------------------------------
// The instrumented measurement window.
// ---------------------------------------------------------------------------

#if defined(_MSC_VER)
#define COD_NOINLINE __declspec(noinline)
#else
#define COD_NOINLINE __attribute__((noinline))
#endif

// The benchmarked expression must run inside a function whose name begins with
// `__codspeed_root_frame__` and which is never inlined, so that flamegraphs
// have a clean root.
static COD_NOINLINE r_obj* __codspeed_root_frame__cod_eval(
    r_obj* expr,
    r_obj* env
) {
    return r_eval(expr, env);
}

// Simulation (Callgrind) measurement: evaluate `expr` exactly `n_iters` times
// inside a tight `start_benchmark_inline` / `stop_benchmark_inline` window. The
// inline variants zero and start Callgrind instrumentation, so the simulated
// instruction count reflects only the evaluations. Callgrind output is
// collected by the runner, so no results file is written here.
r_obj* ffi_instrument(r_obj* ptr, r_obj* expr, r_obj* env, r_obj* n_iters) {
    InstrumentHooks* hooks = hooks_deref(ptr);
    int n = Rf_asInteger(n_iters);

    if (instrument_hooks_start_benchmark_inline(hooks) != 0) {
        r_abort("Failed to start CodSpeed benchmark.");
    }

    for (int i = 0; i < n; ++i) {
        __codspeed_root_frame__cod_eval(expr, env);
    }

    if (instrument_hooks_stop_benchmark_inline(hooks) != 0) {
        r_abort("Failed to stop CodSpeed benchmark.");
    }

    return r_null;
}

// Walltime measurement: time repeated evaluations of `expr` and return the
// per-round latencies (nanoseconds) plus the warmup iteration count.
//
// Unlike simulation, the runner does not compute walltime numbers itself; the
// integration measures them (here) and writes a results file (in R). The
// instrument-hooks start/stop window and the single BENCHMARK_START/END marker
// pair only bracket the measured loop for the runner's flamegraph profiler;
// each evaluation runs through the `__codspeed_root_frame__` so samples can be
// attributed to the benchmark.
//
// The loop runs until `max_time_ns` elapses or `max_rounds` is reached
// (whichever comes first), after an untimed warmup of at least `warmup_time_ns`.
r_obj* ffi_walltime_run(
    r_obj* ptr,
    r_obj* expr,
    r_obj* env,
    r_obj* warmup_time_ns,
    r_obj* max_time_ns,
    r_obj* max_rounds,
    r_obj* pid
) {
    InstrumentHooks* hooks = hooks_deref(ptr);
    double warmup_ns = Rf_asReal(warmup_time_ns);
    double max_ns = Rf_asReal(max_time_ns);
    int32_t c_pid = (int32_t) Rf_asInteger(pid);

    R_xlen_t cap = (R_xlen_t) Rf_asReal(max_rounds);
    if (cap < 1) {
        cap = 1;
    }

    // Untimed warmup, routed through the root frame.
    uint64_t warmup_start = instrument_hooks_current_timestamp();
    int warmup_iters = 0;
    do {
        __codspeed_root_frame__cod_eval(expr, env);
        warmup_iters++;
    } while ((double) (instrument_hooks_current_timestamp() - warmup_start) <
             warmup_ns);

    r_obj* buffer = KEEP(Rf_allocVector(REALSXP, cap));
    double* samples = REAL(buffer);

    instrument_hooks_start_benchmark(hooks);
    uint64_t run_start = instrument_hooks_current_timestamp();

    R_xlen_t rounds = 0;
    while (rounds < cap) {
        uint64_t t0 = instrument_hooks_current_timestamp();
        __codspeed_root_frame__cod_eval(expr, env);
        uint64_t t1 = instrument_hooks_current_timestamp();
        samples[rounds++] = (double) (t1 - t0);
        if ((double) (t1 - run_start) >= max_ns) {
            break;
        }
    }

    uint64_t run_end = instrument_hooks_current_timestamp();
    instrument_hooks_stop_benchmark(hooks);

    instrument_hooks_add_marker(
        hooks,
        c_pid,
        MARKER_TYPE_BENCHMARK_START,
        run_start
    );
    instrument_hooks_add_marker(hooks, c_pid, MARKER_TYPE_BENCHMARK_END, run_end);

    // Return only the rounds actually run.
    r_obj* out_samples = KEEP(Rf_allocVector(REALSXP, rounds));
    memcpy(REAL(out_samples), samples, (size_t) rounds * sizeof(double));

    r_obj* out = KEEP(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(out, 0, out_samples);
    SET_VECTOR_ELT(out, 1, Rf_ScalarInteger(warmup_iters));

    r_obj* names = KEEP(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, Rf_mkChar("samples"));
    SET_STRING_ELT(names, 1, Rf_mkChar("warmup"));
    Rf_setAttrib(out, R_NamesSymbol, names);

    FREE(4);
    return out;
}
