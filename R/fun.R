
#' A function
#' @param n a number
#' @param seed optional seed
#' @export

myfun <- function(n, seed = NULL) {
  if (!is.null(seed))
    set.seed(seed)

  stats::rnorm(n)
}
