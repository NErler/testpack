% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_refs.R
\name{set_refcat}
\alias{set_refcat}
\title{Specify reference categories for all categorical covariates in the model}
\usage{
set_refcat(data, formula, covars, auxvars = NULL)
}
\arguments{
\item{data}{a \code{data.frame}}

\item{formula}{optional; model formula or a list of formulas
(used to select subset of relevant columns of \code{data})}

\item{covars}{optional; vector containing the names of relevant columns of
\code{data}}

\item{auxvars}{optional; formula containing the names of relevant columns of
\code{data} that should be considered additionally to the
columns occurring in the \code{formula}}
}
\description{
The function is a helper function that asks questions and, depending on the
answers given by the user,
returns the input for the argument \code{refcats} in the main analysis
functions
\code{\link[testpack:model_imp]{*_imp}}.
}
\details{
The arguments \code{formula}, \code{covars} and \code{auxvars} can be used
to specify a subset of the \code{data} to be considered. If non of these
arguments is specified, all variables in \code{data} will be considered.
}
\examples{
\dontrun{
# Example 1: set reference categories for the whole dataset and choose
# answer option 3:
set_refcat(data = NHANES)
3

# insert the returned string as argument refcats
mod1 <- lm_imp(SBP ~ age + race + creat + educ, data = NHANES,
               refcats = 'largest')

# Example 2:
# specify a model formula
fmla <- SBP ~ age + gender + race + bili + smoke + alc

# write the output of set_refcat to an object
ref_mod2 <- set_refcat(data = NHANES, formula = fmla)
4
2
5
1
1

# enter the output in the model specification
mod2 <- lm_imp(formula = fmla, data = NHANES, refcats = ref_mod2,
               n.adapt = 0)
}

}
