
#' A function
#' @param n a number
#' @param seed optional seed
#' @export

myfun <- function(n, seed = NULL) {
  if (!is.null(seed))
    if (R.version$major <= 3 & R.version$minor < 6.0) {
      suppressWarnings(set.seed(seed))
    } else {
      suppressWarnings(set.seed(seed, sample.kind = "Rounding"))
    }
  stats::rnorm(n)
}

