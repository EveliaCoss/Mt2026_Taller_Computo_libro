#' Reveal stored instructor answers
#'
#' The `reveal()` function displays instructor-provided answers for a given
#' question or puzzle ID. It checks whether the hidden `.answers` object is
#' loaded in the current session. If answers are not available, it prints a
#' message indicating that the instructor must provide them.
#'
#' @param qid Character string. The identifier of the question or puzzle
#'   to reveal. For example:
#'   \itemize{
#'     \item Questions: use the number after "QUESTION" in the prompt,
#'           e.g. `reveal("1.2b")`.
#'     \item Puzzles: use the number after "PUZZLE" in the prompt,
#'           e.g. `reveal("1.9/A")`.
#'   }
#'
#' @return Invisibly returns the answer object (a list with fields such as
#'   `kind`, `block`, `step`, `prompt`, `answer`, `demo`, `plot`).
#'   Prints formatted output to the console.
#'
#' @details
#' - If `.answers` is not loaded, the function informs the user that
#'   instructor answers are missing.
#' - If the provided `qid` is not found, it prints the available IDs.
#' - When found, the function prints a formatted block with the prompt,
#'   answer, and optional demo or plot information.
#'
#' @examples
#' # Assuming `.answers` has been loaded by the instructor:
#' reveal("1.2b")
#' reveal("1.9/A")
#'
#' @export
reveal <- function(qid) {
  if (!exists(".answers", inherits = TRUE)) {
    cat("Instructor answers not loaded in this session.\n")
    cat("Ask the instructor for the answer to ", qid, ".\n", sep = "")
    return(invisible(NULL))
  }
  if (!qid %in% names(.answers)) {
    cat("ID '", qid, "' not found. Available IDs:\n", sep = "")
    print(names(.answers))
    return(invisible(NULL))
  }
  x   <- .answers[[qid]]
  bar <- strrep("=", 76)
  cat(bar, "\n", sep = "")
  cat(x$kind, " ", qid, "  (Block ", x$block, ", Step ", x$step, ")\n",
      sep = "")
  cat("\nPROMPT:\n", x$prompt, "\n", sep = "")
  cat("\nANSWER:\n", x$answer, "\n", sep = "")
  if (nzchar(x$demo)) cat("\nLIVE DEMO:\n", x$demo, sep = "")
  if (nzchar(x$plot)) cat("\nPLOT / OUTPUT: ", x$plot, "\n", sep = "")
  cat(bar, "\n", sep = "")
  invisible(x)
}
