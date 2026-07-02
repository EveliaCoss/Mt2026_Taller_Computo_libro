#' Internal factory for namespace-safe accessors
#'
#' Creates a wrapper around Seurat accessor functions (`Assays()`, `Layers()`,
#' `Reductions()`) to ensure reliable resolution across different versions of
#' \pkg{Seurat} and \pkg{SeuratObject}. This avoids namespace conflicts caused
#' by other Bioconductor packages that may define competing S4 generics.
#'
#' @param fname Character string. The name of the accessor function to wrap.
#'
#' @return A function that safely calls the requested accessor.
#'
#' @keywords internal
.safe_accessor <- function(fname) {
  function(...) {
    if (exists(fname, where = asNamespace("SeuratObject"), inherits = FALSE)) {
      return(get(fname, envir = asNamespace("SeuratObject"))(...))
    }
    if (requireNamespace("Seurat", quietly = TRUE) &&
        exists(fname, where = asNamespace("Seurat"), inherits = FALSE)) {
      return(get(fname, envir = asNamespace("Seurat"))(...))
    }
    get(fname, mode = "function")(...)
  }
}

#' Safe accessor for Assays
#'
#' Wrapper around \code{Assays()} that resolves namespace conflicts
#' between \pkg{SeuratObject}, \pkg{Seurat}, and other packages.
#'
#' @param ... Arguments passed to \code{Assays()}.
#'
#' @return The result of calling \code{Assays()} safely.
#'
#' @examples
#' # Safe usage:
#' SafeAssays(seurat_object)
#'
#' @export
SafeAssays <- .safe_accessor("Assays")

#' Safe accessor for Layers
#'
#' Wrapper around \code{Layers()} that resolves namespace conflicts
#' between \pkg{SeuratObject}, \pkg{Seurat}, and other packages.
#'
#' @param ... Arguments passed to \code{Layers()}.
#'
#' @return The result of calling \code{Layers()} safely.
#'
#' @examples
#' # Safe usage:
#' SafeLayers(seurat_object)
#'
#' @export
SafeLayers <- .safe_accessor("Layers")

#' Safe accessor for Reductions
#'
#' Wrapper around \code{Reductions()} that resolves namespace conflicts
#' between \pkg{SeuratObject}, \pkg{Seurat}, and other packages.
#'
#' @param ... Arguments passed to \code{Reductions()}.
#'
#' @return The result of calling \code{Reductions()} safely.
#'
#' @examples
#' # Safe usage:
#' SafeReductions(seurat_object)
#'
#' @export
SafeReductions <- .safe_accessor("Reductions")
