#include "cod.h"

// A compute-bound C function used to demonstrate that benchmarking C code in
// your own package produces a CodSpeed execution profile.
//
// The work runs entirely inside `cod.so`, which R compiles with debug info, so
// Callgrind can symbolize the native frames - unlike a pure-R benchmark, whose
// work happens inside the stripped R interpreter and cannot be symbolized.
//
// Recursion keeps the function from being inlined, so it shows up as a clean
// frame in the flame graph.
#if defined(_MSC_VER)
#define COD_NOINLINE __declspec(noinline)
#else
#define COD_NOINLINE __attribute__((noinline))
#endif

static COD_NOINLINE double cod_demo_fib(int n) {
    if (n < 2) {
        return (double) n;
    }
    return cod_demo_fib(n - 1) + cod_demo_fib(n - 2);
}

r_obj* ffi_demo_fib(r_obj* n) {
    return r_dbl(cod_demo_fib(Rf_asInteger(n)));
}
