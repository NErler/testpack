#' Summarize the results from an object of class testpack
#'
#' Obtain and print the \code{summary}, (fixed effects) coefficients
#' (\code{coef}) and credible interval (\code{confint}) for an object of
#' class 'testpack'.
#'
#' @inheritParams base::print
#' @param quantiles posterior quantiles
#' @inheritParams sharedParams
#' @param missinfo logical; should information on the number and proportion of
#'                 missing values be included in the summary?
#' @param \dots currently not used
#'
#' @examples
#' mod1 <- lm_imp(y ~ C1 + C2 + M2, data = wideDF, n.iter = 100)
#'
#' summary(mod1, missinfo = TRUE)
#' coef(mod1)
#' confint(mod1)
#'
#'
#' @seealso The model fitting functions \code{\link{lm_imp}},
#'          \code{\link{glm_imp}}, \code{\link{clm_imp}}, \code{\link{lme_imp}},
#'          \code{\link{glme_imp}}, \code{\link{survreg_imp}} and
#'          \code{\link{coxph_imp}},
#'          and the vignette
#'          \href{https://nerler.github.io/testpack/articles/SelectingParameters.html}{Parameter Selection}
#'          for examples how to specify the parameter \code{subset}.
#'
#' @export
summary.testpack <- function(object, start = NULL, end = NULL, thin = NULL,
                            quantiles = c(0.025, 0.975), subset = NULL,
                            exclude_chains = NULL, missinfo = FALSE,
                            warn = TRUE, mess = TRUE, ...) {

  if (is.null(object$MCMC)) errormsg("There is no MCMC sample.")

  cl <- as.list(match.call())[-1]
  autoburnin <- if (is.null(cl$autoburnin)) FALSE else eval(cl$autoburnin)

  MCMC <- prep_MCMC(object, start = start, end = end, thin = thin,
                    subset = subset, exclude_chains = exclude_chains,
                    warn = warn, mess = mess, ...)

  # create results matrices
  statnames <- c("Mean", "SD", paste0(quantiles * 100, "%"), "tail-prob.",
                 "GR-crit", "MCE/SD")

  res_list <- sapply(names(object$coef_list), function(varname) {
    MCMCsub <- MCMC[, intersect(
      colnames(MCMC),
      c(
        object$coef_list[[varname]]$coef,
        grep(paste0("_", object$info_list[[varname]]$varname, "\\b"),
             colnames(MCMC),
             value = TRUE
        ),
        grep(paste0("_", object$info_list[[varname]]$varname, "_"),
             colnames(MCMC),
             value = TRUE
        )
      )
    ), drop = FALSE]



    if (ncol(MCMCsub) > 0) {

      grcrit <- if (length(object$MCMC) - length(exclude_chains) > 1) {
        GR_crit(object = object, start = start, end = end, thin = thin,
                warn = warn, mess = FALSE, multivariate = FALSE,
                exclude_chains = exclude_chains,
                subset = list(other = colnames(MCMCsub), analysis_main = FALSE),
                autoburnin = autoburnin)[[1]][, "Upper C.I."]
      }

      mcerror <- if (length(object$MCMC) - length(exclude_chains) > 1) {
        try(MC_error(object,
                     subset = list(other = colnames(MCMCsub),
                                   analysis_main = FALSE),
                     exclude_chains = exclude_chains,
                     start = start, end = end, thin = thin,
                     digits = 2, warn = FALSE, mess = FALSE))
      }

      colnames(MCMCsub)[na.omit(match(object$coef_list[[varname]]$coef,
                                      colnames(MCMCsub)))] <-
        object$coef_list[[varname]]$varnam_print

      stats <- matrix(nrow = length(colnames(MCMCsub)),
                      ncol = length(statnames),
                      dimnames = list(colnames(MCMCsub), statnames))

      stats[, "Mean"] <- apply(MCMCsub, 2, mean)
      stats[, "SD"] <- apply(MCMCsub, 2, sd)
      stats[, paste0(quantiles * 100, "%")] <- t(apply(MCMCsub, 2,
                                                       quantile, quantiles))
      stats[, "tail-prob."] <- apply(MCMCsub, 2, computeP)

      if (length(object$MCMC) - length(exclude_chains) > 1)
        stats[, "GR-crit"] <- grcrit

      if (length(object$MCMC) - length(exclude_chains) > 1) {
        if (!inherits(mcerror, 'try-error'))
          stats[, "MCE/SD"] <- mcerror$data_scale[, 'MCSE/SD']
      }

      regcoef <- stats[intersect(rownames(stats),
                                 object$coef_list[[varname]]$varnam_print), ,
                       drop = FALSE]


      sigma <- if (object$info_list[[varname]]$family %in%
                   c("gaussian", "Gamma", "lognorm") &&
                   !is.null(object$info_list[[varname]]$family)) {
        sig <- grep(paste0("sigma_", varname), rownames(stats))

        if (length(sig) > 0) {
          stats[sig, -which(colnames(stats) == "tail-prob."), drop = FALSE]
        }
      }

      intercepts <- if (object$info_list[[varname]]$modeltype %in%
                        c('clm', 'clmm'))
        get_intercepts(stats, varname, levels(object$Mlist$refs[[varname]]),
                       rev = object$info_list[[varname]]$rev)


      rd_vcov <- if (!is.null(object$info_list[[varname]]$hc_list)) {
        Ds <- stats[grep(paste0("^D_", object$info_list[[varname]]$varname, "_",
                                paste0(names(object$Mlist$group_lvls),
                                       collapse = "|"),
                                "\\[[[:digit:]]+,[[:digit:]]+\\]"),
                         rownames(stats), value = TRUE), , drop = FALSE]

        if (nrow(Ds) > 0) {
          Ddiag <- sapply(strsplit(sub("\\]", '',
                                       sub("^[[:print:]]*\\[", '', rownames(Ds))
          ), ","),
          function(i) length(unique(i)) == 1)

          Ds[Ddiag, 'tail-prob.'] <- NA
          Ds
        }
      }

      assoc_type <- if (object$info_list[[varname]]$modeltype %in% "JM") {
        object$info_list[[which(sapply(object$info_list,
                                       "[[", "modeltype") == "JM")]]$assoc_type
      }

      wb_shape <- if (object$info_list[[varname]]$modeltype %in% c('survreg')) {
        stats[c(paste0("shape_", object$info_list[[varname]]$varname)),
              -which(colnames(stats) == 'tail-prob.'), drop = FALSE]
      }

      events <- if (object$info_list[[varname]]$modeltype %in%
                    c('survreg', 'coxph', 'JM')) {
        mat <- object$info_list[[1]]$resp_mat[2]
        col <- object$info_list[[1]]$resp_col[2]
        sum(object$data_list[[mat]][, col])
      }

      other <- setdiff(rownames(stats),
                       c(rownames(regcoef),
                         rownames(sigma),
                         attr(intercepts, 'rownames_orig'),
                         rownames(rd_vcov),
                         rownames(wb_shape))
      )

      otherpars <- if (length(other) > 0)
        stats[other, , drop = FALSE]


      list(modeltype = object$info_list[[varname]]$modeltype,
           family = object$info_list[[varname]]$family,
           regcoef = regcoef, sigma = sigma, intercepts = intercepts,
           rd_vcov = rd_vcov, wb_shape = wb_shape, assoc_type = assoc_type,
           events = events,
           grcrit = grcrit, otherpars = otherpars)
    }
  }, simplify = FALSE)


  out <- list()
  out$call <- object$call
  out$start <- ifelse(is.null(start), start(object$MCMC),
                      max(start, start(object$MCMC)))
  out$end <- ifelse(is.null(end), end(object$MCMC), min(end, end(object$MCMC)))
  out$thin <- coda::thin(object$MCMC)
  out$nchain <- coda::nchain(object$MCMC) - sum(exclude_chains %in%
                                                  seq_along(object$MCMC))
  out$res <- res_list
  out$missinfo <- if (missinfo) get_missinfo(object)


  out$analysis_type <- object$analysis_type
  out$size <- object$Mlist$N

  class(out) <- "summary.testpack"
  return(out)
}


#' @rdname summary.testpack
#' @param x an object of class \code{summary.testpack} or \code{testpack}
#' @export
print.summary.testpack <- function(x, digits = max(3, .Options$digits - 4),
                                  ...) {

  if (!inherits(x, "summary.testpack"))
    errormsg("Use only with 'summary.testpack' objects.")

  cat("\n")

  if (sum(!sapply(x$res, is.null)) > 1)
    cat("Bayesian joint model fitted with testpack", "\n")
  else
    cat('Bayesian', print_type(x$res[[1]]$modeltype, x$res[[1]]$family),
        'fitted with testpack\n')

  cat("\nCall:\n", paste(deparse(x$call), sep = "\n", collapse = "\n"),
      "\n", sep = "")

  for (k in seq_along(x$res)) {
    if (!is.null(x$res[[k]])) {
      cat("\n\n")
      if (sum(!sapply(x$res, is.null)) > 1)
        cat(paste0(
          '# ', paste0(c(rep('-', 69)), collapse = ''), ' #\n',
          '  ', 'Bayesian ',
          print_type(x$res[[k]]$modeltype, x$res[[k]]$family), ' for ',
          dQuote(names(x$res)[k]), '\n',
          '# ', paste0(c(rep('-', 35)), collapse = ' '), ' #\n\n'
        ))


      if (!is.null(x$res[[k]]$events))
        cat("Number of events:", x$res[[k]]$events, "\n\n")


      if (!is.null(x$res[[k]]$regcoef)) {
        cat("Posterior summary:\n")
        print(x$res[[k]]$regcoef, digits = digits, na.print = "")
      }

      if (!is.null(x$res[[k]]$intercepts)) {
        # remove the attributes to avoid printing them
        attr(x$res[[k]]$intercepts, 'rownames_orig') <- NULL

        cat("\nPosterior summary of the intercepts:\n")
        print(x$res[[k]]$intercepts, digits = digits, na.print = "")
      }

      if (!is.null(x$res[[k]]$rd_vcov)) {
        cat("\nPosterior summary of random effects covariance matrix:\n")
        print(x$res[[k]]$rd_vcov, digits = digits, na.print = "")
      }

      if (!is.null(x$res[[k]]$sigma)) {
        cat("\nPosterior summary of residual std. deviation:\n")
        print(x$res[[k]]$sigma, digits = digits, na.print = "")
      }

      if (!is.null(x$res[[k]]$wb_shape)) {
        cat("\nPosterior summary of the shape of the Weibull distribution:\n")
        print(x$res[[k]]$wb_shape, digits = digits, na.print = "")
      }

      if (!is.null(x$res[[k]]$assoc_type)) {
        cat("\nAssociation types:\n")
        cat(paste0(names(x$res[[k]]$assoc_type), ": ",
                   sapply(x$res[[k]]$assoc_type, function(i)
                     switch(i,
                            'underl.value' = "underlying value",
                            'obs.value' = 'observed value')
                   ), collapse = "\n"), "\n")

      }

      if (!is.null(x$res[[k]]$otherpars)) {
        cat("\nPosterior summary of other parameters:\n")
        print(x$res[[k]]$otherpars, digits = digits, na.print = "")
      }
    }
  }

  cat('\n\n')
  if (sum(!sapply(x$res, is.null)) > 1)
    cat('#', paste0(c(rep('-', 59)), collapse = ''), '#\n\n')

  cat("MCMC settings:\n")
  cat("Iterations = ", x$start, ":", x$end, "\n", sep = "")
  cat("Sample size per chain =", (x$end - x$start)/x$thin +
        1, "\n")
  cat("Thinning interval =", x$thin, "\n")
  cat("Number of chains =", x$nchain, "\n")
  cat("\n")
  cat("Number of observations:", x$size['lvlone'], "\n")
  if (length(x$size) > 1) {
    i <- which(!names(x$size) %in% 'lvlone')
    cat("Number of groups:\n",
        paste0('- ', names(x$size)[i], ": ", x$size[i], "\n")
    )
  }

  if (!is.null(x$missinfo)) {
    cat('\n\n')
    cat('Number and proportion of complete cases:\n')
    print(x$missinfo$complete_cases, digits = digits)
    cat('\nNumber and proportion of missing values:\n')
    for (k in seq_along(x$missinfo$miss_list)) {
      print(x$missinfo$miss_list[[k]], digits = digits)
      cat('\n')
    }
  }

  invisible(x)
}





#' @rdname summary.testpack
#' @export
coef.testpack <- function(object, start = NULL, end = NULL, thin = NULL,
                         subset = NULL, exclude_chains = NULL,
                         warn = TRUE, mess = TRUE, ...) {

  if (!inherits(object, "testpack")) errormsg("Use only with 'testpack' objects.")

  if (is.null(object$MCMC)) errormsg("There is no MCMC sample.")


  MCMC <- prep_MCMC(object, start, end, thin, subset,
                    exclude_chains = exclude_chains, mess = mess, warn = warn)


  coefs <- sapply(names(object$fixed), function(k) {
    x <- object$coef_list[[k]]
    rev <- object$info_list[[k]]$rev

    c(
      if (object$info_list[[k]]$modeltype %in% c('clm', 'clmm')) {
        interc <- colMeans(MCMC)[grep(paste0('gamma_', k, "\\["),
                                      colnames(MCMC))]

        lvl <- levels(object$Mlist$refs[[k]])
        if (isTRUE(rev)) {
          names(interc) <- paste(k, "\u2264", lvl[-length(lvl)])
        } else {
          names(interc) <- paste(k, ">", lvl[-length(lvl)])
        }
        interc
      },
      if (length(intersect(colnames(MCMC), x$coef)))
        setNames(colMeans(MCMC[, intersect(colnames(MCMC), x$coef),
                               drop = FALSE]),
                 x$varname[match(x$coef, intersect(colnames(MCMC), x$coef))]
        )
    )
  }, simplify = FALSE)

  return(coefs)
}

#' @export
coef.summary.testpack <- function(object, start = NULL, end = NULL, thin = NULL,
                                 subset = NULL, exclude_chains = NULL,
                                 warn = TRUE, mess = TRUE, ...) {

  if (!inherits(object, "summary.testpack"))
    errormsg("Use only with 'summary.testpack' objects.")

  Filter(Negate(is.null),
         lapply(object$res, "[[", 'regcoef')
  )
}



#' @rdname summary.testpack
#' @param parm same as \code{subset}
#' @param level confidence level (default is 0.95)
#' @export
confint.testpack <- function(object, parm = NULL, level = 0.95,
                            quantiles = NULL,
                            start = NULL, end = NULL, thin = NULL,
                            subset = NULL, exclude_chains = NULL,
                            warn = TRUE, mess = TRUE, ...) {

  if (!inherits(object, "testpack")) errormsg("Use only with 'testpack' objects.")

  if (is.null(object$MCMC)) errormsg("There is no MCMC sample.")


  if (is.null(subset) & !is.null(parm)) subset <- parm

  if (!is.null(subset) & !is.null(parm))
    errormsg('At least one of "parm" and "subset" should be NULL.')

  if (is.null(quantiles) & !is.null(level))
    quantiles <- c((1 - level)/2, 1 - (1 - level)/2)

  MCMC <- prep_MCMC(object, start, end, thin, subset,
                    exclude_chains = exclude_chains,
                    mess = mess, warn = warn)



  sapply(names(object$fixed), function(k) {
    x <- object$coef_list[[k]]
    rev <- object$info_list[[k]]$rev

    rbind(
      if (object$info_list[[k]]$modeltype %in% c('clm', 'clmm')) {
        lvl <- levels(object$Mlist$refs[[k]])
        interc <- apply(MCMC[, grep(paste0('gamma_', k, "\\["),
                                    colnames(MCMC))], 2, quantile, quantiles)

        if (isTRUE(rev)) {
          colnames(interc) <- paste(k, "\u2264", lvl[-length(lvl)])
        } else {
          colnames(interc) <- paste(k, ">", lvl[-length(lvl)])
        }
        t(interc)
      },
      if (length(intersect(colnames(MCMC), x$coef))) {
        quants <- t(apply(MCMC[, intersect(colnames(MCMC), x$coef),
                               drop = FALSE], 2, quantile, quantiles))

        rownames(quants) <- x$varname[match(x$coef,
                                            intersect(colnames(MCMC), x$coef))]
        quants
      }
    )
  }, simplify = FALSE)
}


#' @rdname summary.testpack
#' @export
print.testpack <- function(x, digits = max(4, getOption("digits") - 4), ...) {

  if (!inherits(x, "testpack")) errormsg("Use only with 'testpack' objects.")


  MCMC <- if (!is.null(x$MCMC)) {
    prep_MCMC(x,
              start = NULL, end = NULL, thin = NULL, subset = NULL,
              exclude_chains = NULL,
              mess = TRUE, warn = TRUE, ...
    )
  }


  cat("\nCall:\n")
  print(x$call)

  if (!is.null(MCMC)) {
    coefs <- coef(x)

    for (k in seq_along(coefs)) {
      varname <- names(coefs)[k]
      cat("\n", "Bayesian",
          print_type(x$info_list[[varname]]$modeltype,
                     x$info_list[[varname]]$family), "for",
          dQuote(varname), '\n')
      if (x$info_list[[names(coefs)[k]]]$modeltype %in%
          c('glmm', 'clmm', 'mlogitmm')) {
        cat("\nFixed effects:\n")
        print(coefs[[k]], digits = digits)

        cat("\n\nRandom effects covariance matrix:\n")
        print(get_Dmat(object = x, varname = varname), digits = digits)

      } else {
        if (length(coefs[[k]] > 0)) {
          cat("\n\nCoefficients:\n")
          print(coefs[[k]], digits = digits)
        }
      }

      if (paste0("sigma_", varname) %in% colnames(MCMC)) {
        cat("\n\nResidual standard deviation:\n")
        print(colMeans(MCMC[, paste0("sigma_", names(coefs)[k]),
                            drop = FALSE]),
              digits = digits)
      }
    }
  } else {
    cat("\n(The object does not contain an MCMC sample.)")
  }

  invisible(x)
}


#' @export
print.modelstring <- function(x, ...) {

  if (!inherits(x, "modelstring"))
    errormsg("Use only with 'modelstring' objects.")

  cat(x)
}





#' Obtain a summary of the missing values involved in an object of class testpack
#'
#' This function returns a \code{data.frame} or a \code{list} of
#' \code{data.frame}s per grouping level. Each of the \code{data.frames}
#' has columns \code{variable}, \code{#NA} (number of missing values) and
#' \code{\%NA} (proportion of missing values in percent).
#'
#' @param object object inheriting from class testpack
#'
#' @export
#'
#' @examples
#' mod <-  lm_imp(y ~ C1 + B2 + C2, data = wideDF, n.iter = 100)
#' get_missinfo(mod)
#'
#'
get_missinfo <- function(object) {

  if (!(inherits(object, "testpack") | inherits(object, "testpack_errored")))
    errormsg("Use only with 'testpack' objects.")


  allvars <- all_vars(c(object$fixed, object$random, object$Mlist$auxvars,
                        object$Mlist$timevar))

  cc <- complete.cases(object$data[, allvars])

  groups <- object$Mlist$groups


  complcases <- lapply(names(groups), function(k) {
    cc0 <- cc[match(unique(groups[[k]]), groups[[k]])]

    as.data.frame(
      Filter(Negate(is.null),
             list(
               level = if (length(object$Mlist$groups) > 1) k,
               '#' = sum(cc0),
               '%' = mean(cc0) * 100
             )
      ), check.names = FALSE, row.names = k)
  })

  dat_lvls <- sapply(object$data[allvars], check_varlevel,
                     groups = object$Mlist$groups)

  miss_list <- sapply(unique(dat_lvls), function(lvl) {
    subdat <- object$data[match(unique(object$Mlist$groups[[lvl]]),
                                object$Mlist$groups[[lvl]]),
                          names(dat_lvls)[dat_lvls == lvl], drop = FALSE]
    missinfo <- as.data.frame(
      Filter(Negate(is.null),
             list(
               # variable = names(subdat),
               level = if (length(unique(dat_lvls)) > 1) lvl,
               '# NA' = colSums(is.na(subdat)),
               '% NA' = colMeans(is.na(subdat)) * 100
             )
      ),
      check.names = FALSE
    )
    missinfo[order(missinfo$`# NA`), ]
  }, simplify = FALSE)

  list('complete_cases' = do.call(rbind, complcases),
       miss_list = miss_list
  )
}
