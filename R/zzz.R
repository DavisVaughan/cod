.onLoad <- function(libname, pkgname) {
  .Call(cod_init_library, asNamespace(pkgname))
}
