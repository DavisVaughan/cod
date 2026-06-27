# Demonstrates benchmarking a C function defined in cod itself.
#
# Because the work runs inside cod.so (compiled with debug info), CodSpeed can
# symbolize the native frames and build an execution profile for it - unlike a
# pure-R benchmark, whose work runs inside the stripped R interpreter.

cod::test("fibonacci", {
  cod:::demo_fib(30L)
})
