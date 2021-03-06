#' Plot an object object inheriting from class 'testpack'
#'
#' @param x object inheriting from class 'testpack'
#' @param ... currently not used
#'
#' @note
#' Currently, \code{plot()} can only be used with (generalized) linear (mixed)
#' models.
#'
#' @examples
#' mod <- lm_imp(y ~ C1 + C2 + B1, data = wideDF, n.iter = 100)
#' plot(mod)
#'
#' @export
plot.testpack <- function(x, ...) {
  if (!inherits(x, "testpack"))
    errormsg("Use only with objects of class testpack.")

  if (!x$analysis_type %in% c('lm', 'lme', 'glm', 'glme'))
    errormsg('At the moment there is not plotting method implemented for a %s
             model of type %s.', dQuote("testpack"), dQuote(x$analysis_type))

  if (length(x$fixed) > 1)
    errormsg("At the moment there is no plotting method implemented for models
             with multiple model formulas.")

  l.fit <- if (x$analysis_type %in% c('glm', 'glme'))  {
    "Predicted values"
  } else {"Fitted values"}

  fit <- x$fitted.values
  r <- x$residuals

  plot(fit, r, xlab = l.fit,
       ylab = "Residuals", main = 'Residuals vs Fitted'
       # ylim = ylim, type = "n"
  )
  panel.smooth(fit, r,
               iter = ifelse(x$analysis_type %in% c('glm', 'glmer'), 0, 3))
  abline(h = 0, lty = 3, col = "gray")
}



#' @export
family.testpack <- function(object, ...) {
  attr(object$analysis_type, "family")
}



