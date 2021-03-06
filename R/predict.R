#' Create a new data frame for prediction
#'
#' Build a \code{data.frame} for prediction, where one variable
#' varies and all other variables are set to the reference value (median for
#' continuous variables).
#'
#' @inheritParams model_imp
#' @inheritParams sharedParams
#' @param vars name of variable that should be varying
#' @param length number of values used in the sequence when \code{vars} is
#'               continuous
#' @param ... optional, additional arguments (currently not used)
#'
#' @seealso \code{\link{predict.testpack}}, \code{\link{lme_imp}},
#'          \code{\link{glm_imp}}, \code{\link{lm_imp}}
#' @examples
#' # fit a testpack model
#' mod <- lm_imp(y ~ C1 + C2 + M2, data = wideDF, n.iter = 100)
#'
#' # generate a data frame with varying "C2" and reference values for all other
#' # variables in the model
#' newDF <- predDF(mod, vars = ~ C2)
#'
#' head(newDF)
#'
#' @export

predDF <- function(object, ...) {
  UseMethod("predDF", object)
}


#' @rdname predDF
#' @export
predDF.testpack <- function(object, vars, length = 100, ...) {

  if (!inherits(object, "testpack"))
    stop("Use only with 'testpack' objects.\n")

  predDF.list(formulas = c(object$fixed,
                           object$random,
                           object$auxvars,
                           if (!is.null(object$Mlist$timevar))
                             as.formula(paste0("~", object$Mlist$timevar))
  ),
  dat = object$data, vars = vars,
  length = length, idvar = object$Mlist$idvar, ...)
}


# @rdname predDF
# @export
predDF.formula <- function(formula, dat, vars, length = 100, ...) {
  if (!inherits(formula, "formula"))
    stop("Use only with 'formula' objects.\n")

  predDF(formulas = check_formula_list(formula), dat = dat, vars = vars,
         length = length, ...)
}

# @rdname predDF
# @export
predDF.list <- function(formulas, dat, vars, length = 100, idvar = NULL, ...) {

  id_vars <- extract_id(vars, warn = FALSE)
  varying <- all_vars(vars)

  if (is.null(idvar))
    idvar <- "id"

  allvars <- all_vars(formulas)

  if (any(!varying %in% allvars)) {
    errormsg("%s was not used in the model formula.", varying)
  }

  vals <- sapply(allvars, function(k) {
    if (k %in% varying) {
      if (is.factor(dat[, k])) {
        if (k %in% names(list(...))) {
          list(...)[[k]]
        } else {
          unique(na.omit(dat[, k]))
        }
      } else {
        if (k %in% names(list(...))) {
          list(...)[[k]]
        } else {
          seq(min(dat[, k], na.rm = TRUE),
              max(dat[, k], na.rm = TRUE), length = length)
        }
      }
    } else {
      if (is.factor(dat[, k])) {
        factor(levels(dat[, k])[1], levels = levels(dat[, k]))
      } else if (is.logical(dat[, k]) | is.character(dat[, k])) {
        factor(levels(as.factor(dat[, k]))[1],
               levels = levels(as.factor(dat[, k])))
      } else if (is.numeric(dat[, k])) {
        median(dat[, k], na.rm = TRUE)
      }
    }
  })

  ndf <- expand.grid(vals)

  if (!is.null(id_vars)) {
    id_df <- unique(subset(ndf, select = id_vars))
    id_df[, idvar] <- seq_len(nrow(id_df))
    ndf <- merge(subset(ndf, select = !names(ndf) %in% idvar),
                 id_df)
  }
  ndf
}






#' Predict values from an object of class testpack
#'
#' Obtains predictions and corresponding credible intervals from an object of
#' class 'testpack'.
#' @inheritParams summary.testpack
#' @param newdata optional new dataset for prediction. If left empty, the
#'                original data is used.
#' @param quantiles quantiles of the predicted distribution of the outcome
#' @param type the type of prediction. The default is on the scale of the
#'         linear predictor (\code{"link"} or \code{"lp"}). For generalized
#'         linear (mixed) models \code{type = "response"} transforms the
#'         predicted values to the scale of the response. For ordinal (mixed)
#'         models \code{type} may be \code{"prob"} (to obtain probabilities per
#'         class) or \code{"class"} to obtain the class with the highest
#'         posterior probability.
#' @param outcome vector of variable names or numbers identifying for which
#'        outcome(s) the prediction should be performed.
#'
#' @details A \code{model.matrix} \eqn{X} is created from the model formula
#'          (currently fixed effects only) and \code{newdata}. \eqn{X\beta}
#'          is then calculated for
#'          each iteration of the MCMC sample in \code{object}, i.e.,
#'          \eqn{X\beta} has \code{n.iter} rows and \code{nrow(newdata)}
#'          columns.
#'          A subset of the MCMC sample can be selected using \code{start},
#'          \code{end} and  \code{thin}.
#'
#' @return A list with entries \code{dat}, \code{fit} and \code{quantiles},
#'         where
#'         \code{fit} contains the predicted values (mean over the values
#'         calculated from the iterations of the MCMC sample),
#'         \code{quantiles} contain the specified quantiles (by default 2.5\%
#'         and 97.5\%),
#'         and \code{dat} is \code{newdata}, extended with \code{fit} and
#'         \code{quantiles}
#'         (unless prediction for an ordinal outcome is done with
#'         \code{type = "prob"},
#'         in which case the quantiles are an array with three dimensions and
#'         are therefore not included in \code{dat}).
#'
#' @seealso \code{\link{predDF.testpack}}, \code{\link[testpack:model_imp]{*_imp}}
#'
#' @section Note:
#' \itemize{
#' \item So far, \code{predict} cannot calculate predicted values for cases
#'       with missing values in covariates. Predicted values for such cases are
#'       \code{NA}.
#' \item For repeated measures models prediction currently only uses fixed
#'       effects.
#' }
#' Functionality will be extended in the future.
#'
#' @examples
#' # fit model
#' mod <- lm_imp(y ~ C1 + C2 + I(C2^2), data = wideDF, n.iter = 100)
#'
#' # calculate the fitted values
#' fit <- predict(mod)
#'
#' # create dataset for prediction
#' newDF <- predDF(mod, vars = ~ C2)
#'
#' # obtain predicted values
#' pred <- predict(mod, newdata = newDF)
#'
#' # plot predicted values and 95% confidence band
#' matplot(newDF$C2, pred$fitted, lty = c(1, 2, 2), type = "l", col = 1,
#' xlab = 'C2', ylab = 'predicted values')
#'

#' @export
predict.testpack <- function(object, outcome = 1, newdata,
                            quantiles = c(0.025, 0.975),
                            type = "lp",
                            start = NULL, end = NULL, thin = NULL,
                            exclude_chains = NULL, mess = TRUE,
                            warn = TRUE, ...) {


  if (!inherits(object, "testpack")) errormsg("Use only with 'testpack' objects.")

  # if (any(sapply(object$info_list, "[[", "modeltype") %in%
  #         c("glmm", "clmm", "mlogitmm")) & warn) {
  #   warnmsg("Prediction for multi-level models is currently only possible on
  #           the population level (not using random effects).")
  # }

  if (missing(newdata)) {
    newdata <- object$data
  } else {
    newdata <- convert_variables(data = newdata,
                                 allvars = unique(c(all_vars(object$fixed),
                                                    all_vars(object$random),
                                                    all_vars(object$auxvars))),
                                 mess = FALSE,
                                 data_orig = object$data)
  }


  MCMC <- prep_MCMC(object, start = start, end = end, thin = thin,
                    subset = FALSE, exclude_chains = exclude_chains,
                    mess = mess, ...)


  if (length(type) == 1 & length(outcome == 1)) {
    types <- setNames(rep(type, length(object$fixed)),
                      names(object$fixed))
  } else {
    if (any(!names(type) %in% names(object$fixed))) {
      errormsg("When %s is a named vector, the names must match outcome
               variables, i.e., %s.", dQuote("type"),
               dQuote(names(object$fixed)))


    }
    types <- setNames(rep(type, length(object$fixed)),
                      names(object$fixed))
    types[names(type)] <- type
  }

  preds <- sapply(names(object$fixed)[outcome], function(varname) {

    if (!is.null(object$info_list[[varname]]$hc_list) & warn) {
      warnmsg("Prediction in multi-level settings currently only takes into
               account the fixed effects, i.e., assumes that the random effect
               realizations are equal to zero.")
    }

    predict_fun <- switch(object$info_list[[varname]]$modeltype,
                          glm = predict_glm,
                          glmm = predict_glm,
                          clm = predict_clm,
                          mlogit = predict_mlogit,
                          clmm = predict_clm,
                          mlogitmm = predict_mlogit,
                          survreg = predict_survreg,
                          coxph = predict_coxph,
                          JM = predict_JM
    )
    if (!is.null(predict_fun)) {
      predict_fun(formula = object$fixed[[varname]],
                  newdata = newdata, type = types[varname], data = object$data,
                  MCMC = MCMC, varname = varname,
                  Mlist = get_Mlist(object), srow = object$data_list$srow,
                  coef_list = object$coef_list, info_list = object$info_list,
                  quantiles = quantiles, mess = mess, warn = warn,
                  contr_list = lapply(object$Mlist$refs, attr, "contr_matrix"))
    } else {
      errormsg("Prediction is not yet implemented for a model of type %s.",
               dQuote(object$info_list[[varname]]$modeltype))
    }
  },  simplify = FALSE)


  list(
    newdata = if (length(preds) == 1) cbind(newdata, preds[[1]])
    else cbind(newdata, unlist(preds, recursive = FALSE)),
    fitted = if (length(preds) == 1) preds[[1]] else preds
  )
}


predict_glm <- function(formula, newdata, type = c("link", "response", "lp"),
                        data, MCMC, varname, coef_list, info_list,
                        quantiles = c(0.025, 0.975), mess = TRUE,
                        contr_list, Mlist, ...) {

  type <- match.arg(type)

  if (type == "lp")
    type <- "link"

  linkinv <- if (info_list[[varname]]$family %in%
                 c("gaussian", "binomial", "Gamma", "poisson")) {
    get(info_list[[varname]]$family)(link = info_list[[varname]]$link)$linkinv
  } else if (info_list[[varname]]$family %in% "lognorm") {
    gaussian(link = "log")$linkinv
  } else if (info_list[[varname]]$family %in% "beta") {
    plogis
  }

  coefs <- coef_list[[varname]]

  scale_pars <- if (attr(terms(formula), 'intercept') == 0) {
    scale_pars <- do.call(rbind, unname(Mlist$scale_pars))
    if (!is.null(scale_pars)) {
      scale_pars$center[is.na(scale_pars$center)] <- 0
    }
    scale_pars
  }


  mf <- model.frame(as.formula(paste(formula[-2], collapse = " ")),
                    data, na.action = na.pass)
  mt <- attr(mf, "terms")

  op <- options(na.action = na.pass)

  X <- model.matrix(mt, data = newdata,
                    contrasts.arg = contr_list[intersect(
                      names(contr_list),
                      sapply(attr(mt, "variables")[-1], deparse,
                             width.cutoff = 500)
                    )]
  )


  if (mess & any(is.na(X)))
    msg("Note: Prediction for cases with missing covariates is not yet
        implemented.
        I will report %s instead of predicted values for those cases.",
        dQuote("NA"), exdent = 6)


  # linear predictor values for the selected iterations of the MCMC sample
  pred <- calc_lp(
    regcoefs = MCMC[, coefs$coef[match(colnames(X),
                                       coefs$varname)], drop = FALSE],
    design_mat = X,
    scale_pars)

  # fitted values: mean over the (transformed) predicted values
  fit <- if (type == "response") {
    if (info_list[[varname]]$family == "poisson") {
      round(colMeans(linkinv(pred)))
    } else {
      colMeans(linkinv(pred))
    }
  } else {
    colMeans(pred)
  }

  # qunatiles
  quants <- if (!is.null(quantiles)) {
    if (type == "response") {
      t(apply(pred, 2, function(q) {
        quantile(linkinv(q), probs = quantiles, na.rm  = TRUE)
      }))
    } else {
      t(apply(pred, 2, quantile, quantiles, na.rm  = TRUE))
    }
  }

  on.exit(options(op))

  res_df <- if (!is.null(quantiles)) {
    cbind(data.frame(fit = fit),
          as.data.frame(quants))
  } else {
    data.frame(fit = fit)
  }

  return(res_df)
}



predict_survreg <- function(formula, newdata, type = c("response", "link",
                                                       "lp",
                                                       "linear"),
                            data, MCMC, varname, coef_list, info_list,
                            quantiles = c(0.025, 0.975), warn = TRUE,
                            contr_list, ...) {

  type <- match.arg(type)

  if (type == "link")
    type <- "lp"

  if (type == "linear")
    type <- "lp"

  coefs <- coef_list[[varname]]

  mf <- model.frame(as.formula(paste(formula[-2], collapse = " ")),
                    data, na.action = na.pass)
  mt <- attr(mf, "terms")

  op <- options(na.action = na.pass)
  X <- model.matrix(mt, data = newdata,
                    contr_list[intersect(
                      names(contr_list),
                      sapply(attr(mt, "variables")[-1], deparse,
                             width.cutoff = 500)
                    )]
  )


  if (warn & any(is.na(X)))
    warnmsg("Prediction for cases with missing covariates is not yet
            implemented.")


  # linear predictor values for the selected iterations of the MCMC sample
  pred <- sapply(seq_len(nrow(X)), function(i)
    MCMC[, coefs$coef[match(colnames(X), coefs$varname)],
         drop = FALSE] %*% X[i, ])

  # fitted values: mean over the (transformed) predicted values
  fit <- if (type == "response") {
    colMeans(exp(pred))
  } else {
    colMeans(pred)
  }

  # quantiles
  quants <- if (!is.null(quantiles)) {
    if (type == "response") {
      t(apply(pred, 2, function(q) {
        quantile(exp(q), probs = quantiles, na.rm  = TRUE)
      }))
    } else {
      t(apply(pred, 2, quantile, quantiles, na.rm  = TRUE))
    }}

  on.exit(options(op))

  res_df <- if (!is.null(quantiles)) {
    cbind(data.frame(fit = fit),
          as.data.frame(quants))
  } else {
    data.frame(fit = fit)
  }

  return(res_df)
}



predict_coxph <- function(Mlist, coef_list, MCMC, newdata, data, info_list,
                          type = c("lp", "risk", "expected", "survival"),
                          varname, quantiles = c(0.025, 0.975),
                          srow = NULL, mess = TRUE, contr_list,  ...) {
  type <- match.arg(type)

  coefs <- coef_list[[varname]]

  survinfo <- get_survinfo(info_list, Mlist)[varname]


  resp_mat <- info_list[[varname]]$resp_mat[2]
  surv_lvl <- survinfo[[1]]$surv_lvl
  # surv_colnames <- names(Mlist$outcomes$outcomes[[varname]])

  mf <- model.frame(as.formula(paste(Mlist$fixed[[varname]][-2],
                                     collapse = " ")),
                    data, na.action = na.pass)
  mt <- attr(mf, "terms")


  op <- options(na.action = na.pass)

  X0 <- model.matrix(mt, data = newdata,
                     contr_list[intersect(
                       names(contr_list),
                       sapply(attr(mt, "variables")[-1], deparse,
                              width.cutoff = 500)
                     )]
  )[, -1, drop = FALSE]

  X <- sapply(names(Mlist$M), function(lvl) {
    X0[, colnames(X0) %in% colnames(Mlist$M[[lvl]]), drop = FALSE]
  }, simplify = FALSE)


  if (mess & any(is.na(X)))
    msg("Prediction for cases with missing covariates is not yet
            implemented.")

  scale_pars <- do.call(rbind, unname(Mlist$scale_pars))
  if (!is.null(scale_pars)) {
    scale_pars$center[is.na(scale_pars$center)] <- 0
  }

  lp_list <- sapply(X, function(x) {
    sapply(seq_len(nrow(x)), function(i)
      if (!is.null(scale_pars)) {
        MCMC[, coefs$coef[match(colnames(x), coefs$varname)], drop = FALSE] %*%
          (x[i, ] - scale_pars$center[match(colnames(x), rownames(scale_pars))])
      } else {
        MCMC[, coefs$coef[match(colnames(x),
                                coefs$varname)], drop = FALSE] %*% x[i, ]
      }
    )
  }, simplify = FALSE)

  lps <- array(unlist(lp_list), dim = c(nrow(lp_list[[1]]),
                                        ncol(lp_list[[1]]),
                                        length(lp_list)),
               dimnames = list(c(), c(), gsub("M_", "", names(lp_list))))


  eta_surv <- if (any(Mlist$group_lvls >=
                      Mlist$group_lvls[gsub("M_", "", resp_mat)])) {
    apply(lps[, , names(which(Mlist$group_lvls >=
                                Mlist$group_lvls[gsub("M_", "", resp_mat)]))],
        c(1, 2), sum)
  } else {
    0
  }

  eta_surv_long <- if (any(Mlist$group_lvls <
                           Mlist$group_lvls[gsub("M_", "", resp_mat)])) {
    apply(lps[, , names(which(Mlist$group_lvls <
                              Mlist$group_lvls[gsub("M_", "", resp_mat)]))],
          c(1, 2), sum)
  } else {
    0
  }

  gkx <- gauss_kronrod()$gkx
  ordgkx <- order(gkx)
  gkw <- gauss_kronrod()$gkw[ordgkx]


  srow <- if (is.null(Mlist$timevar)) {
    seq_len(nrow(Mlist$M[[resp_mat]]))
  } else {
    which(Mlist$M$M_lvlone[, Mlist$timevar] ==
            Mlist$M[[resp_mat]][Mlist$groups[[surv_lvl]],
                                survinfo[[1]]$time_name])
  }


  h0knots <- get_knots_h0(nkn = Mlist$df_basehaz - 4,
                          Time = survinfo[[1]]$survtime,
                          event = NULL, gkx = gkx)

  if (type %in% c("expected", "survival")) {

    Bsh0 <-
      splines::splineDesign(h0knots,
                            c(t(outer(newdata[, survinfo[[1]]$time_name] / 2,
                                      gkx + 1))),
                            ord = 4, outer.ok = TRUE)

    logh0s <- lapply(seq_len(nrow(MCMC)), function(m) {
      matrix(Bsh0 %*% MCMC[m, grep(paste0("\\bbeta_Bh0_",
                                          clean_survname(varname), "\\b"),
                                   colnames(MCMC))],
             ncol = 15, nrow = nrow(newdata), byrow = TRUE)
    })


    tvpred <- if (any(Mlist$group_lvls <
                      Mlist$group_lvls[gsub("M_", "", resp_mat)])) {
      Mgk <- do.call(rbind,
                      get_Mgk(Mlist, gkx, surv_lvl = gsub("M_", "", resp_mat),
                              survinfo = survinfo, data = newdata,
                              rows = seq_len(nrow(newdata)),
                              td_cox = unique(
                                sapply(survinfo,
                                       "[[", "modeltype")) == "coxph"))

      vars <- coefs$varname[na.omit(match(dimnames(Mgk)[[2]], coefs$varname))]

      lapply(seq_len(nrow(MCMC)), function(m) {
        if (!is.null(scale_pars)) {
          matrix((Mgk[, vars, drop = FALSE] -
                    outer(rep(1, prod(dim(Mgk)[-2])),
                          scale_pars$center[match(vars,
                                                  rownames(scale_pars))])) %*%
                   MCMC[m, coefs$coef[match(vars, coefs$varname)]],
                 nrow = nrow(newdata), ncol = length(gkx))
        } else {
          matrix(Mgk[, vars, drop = FALSE] %*%
                   MCMC[m, coefs$coef[match(vars, coefs$varname)]],
                 nrow = nrow(newdata), ncol = length(gkx))
        }
      })
    } else {
      0
    }

    surv <- mapply(function(logh0s, tvpred) {
      exp(logh0s + tvpred) %*% gkw
    }, logh0s = logh0s, tvpred = tvpred)

    log_surv <- -exp(t(eta_surv)) * surv *
      outer(newdata[, survinfo[[1]]$time_name],
            rep(1, nrow(MCMC))) / 2

  } else {

    Bh0 <- splines::splineDesign(h0knots, newdata[, survinfo[[1]]$time_name],
                                 ord = 4, outer.ok = TRUE)

    logh0 <- sapply(seq_len(nrow(Bh0)), function(i) {
      MCMC[, grep("beta_Bh0", colnames(MCMC))] %*% Bh0[i, ]
    })


    logh <- logh0 + eta_surv + eta_surv_long
  }


  # fitted values: mean over the (transformed) predicted values
  fit <- if (type == "risk") {
    colMeans(exp(logh))
  } else if (type == "lp") {
    colMeans(logh)
  } else if (type == "expected") {
    rowMeans(-log_surv)
  } else if (type == "survival") {
    rowMeans(exp(log_surv))
  }

  # quantiles
  quants <- if (!is.null(quantiles)) {
    if (type == "risk") {
      t(apply(exp(logh), 2, quantile, quantiles, na.rm  = TRUE))
    } else if (type == "lp") {
      t(apply(logh, 2, quantile, quantiles, na.rm  = TRUE))
    } else if (type == "expected") {
      t(apply(-log_surv, 1, quantile, quantiles, na.rm  = TRUE))
    } else if (type == "survival") {
      t(apply(exp(log_surv), 1, quantile, quantiles, na.rm  = TRUE))
    }
  }

  on.exit(options(op))

  res_df <- if (!is.null(quantiles)) {
    cbind(data.frame(fit = fit),
          as.data.frame(quants))
  } else {
    data.frame(fit = fit)
  }
  return(res_df)
}


predict_clm <- function(formula, newdata,
                        type = c("prob", "lp", "class", "response"),
                        data, MCMC, varname, coef_list, info_list,
                        quantiles = c(0.025, 0.975), warn = TRUE,
                        contr_list, Mlist, ...) {

  type <- match.arg(type)

  if (type == "response")
    type <- "class"


  coefs <- coef_list[[varname]]

  scale_pars <- do.call(rbind, unname(Mlist$scale_pars))
  if (!is.null(scale_pars)) {
    scale_pars$center[is.na(scale_pars$center)] <- 0
  }

  mf <- model.frame(as.formula(paste(formula[-2], collapse = " ")),
                    data, na.action = na.pass)
  mt <- attr(mf, "terms")

  op <- options(na.action = na.pass)
  X <- model.matrix(mt,
                    data = newdata,
                    contrasts.arg = contr_list[intersect(
                      names(contr_list),
                      sapply(attr(mt, "variables")[-1], deparse,
                             width.cutoff = 500)
                    )]
  )[, -1, drop = FALSE]

  if (warn & any(is.na(X)))
    warnmsg("Prediction for cases with missing covariates is not yet
            implemented.")

  # multiply MCMC sample with design matrix to get linear predictor
  coefs_prop <- coefs[is.na(coefs$outcat) & coefs$varname %in% colnames(X), ]
  coefs_nonprop <- coefs[!is.na(coefs$outcat) &
                           coefs$varname %in% colnames(X), ]
  coefs_nonprop <- split(coefs_nonprop, coefs_nonprop$outcat)


  eta <- calc_lp(regcoefs = MCMC[, coefs_prop$coef, drop = FALSE],
                 design_mat = X[, coefs_prop$varname, drop = FALSE],
                 scale_pars)

  eta_nonprop <- if (length(coefs_nonprop) > 0) {
    lapply(coefs_nonprop, function(c_np_k) {
      calc_lp(regcoefs = MCMC[, c_np_k$coef, drop = FALSE],
              design_mat = X[, c_np_k$varname, drop = FALSE],
              scale_pars = scale_pars)
    })
  }


  gammas <- lapply(
    grep(paste0("gamma_", varname), colnames(MCMC), value = TRUE),
    function(k)
      matrix(nrow = nrow(eta), ncol = ncol(eta),
             data = rep(MCMC[, k], ncol(eta)),
             byrow = FALSE)
  )


  # add the category specific intercepts to the linear predictor
  lp <- sapply(seq_along(gammas), function(k) {
                   gammas[[k]] + eta +
      if (is.null(eta_nonprop)) 0 else eta_nonprop[[k]]
  }, simplify = FALSE)

  mat1 <- matrix(nrow = nrow(eta), ncol = ncol(eta), data = 1)
  mat0 <- mat1 * 0


  if (info_list[[varname]]$rev) {
    names(lp) <- paste0("logOdds(", varname, "<=", seq_along(lp), ")")
    pred <- rev(c(lapply(rev(lp), plogis), list(mat0)))

    probs <- lapply(seq_along(pred)[-1], function(k) {
      minmax_mat(pred[[k]] - pred[[k - 1]])
    })

    probs <- c(probs,
               list(
                 1 - minmax_mat(
                   apply(array(dim = c(dim(probs[[1]]), length(probs)),
                               unlist(probs)), c(1, 2), sum)
                 ))
    )
  } else {
    names(lp) <- paste0("logOdds(", varname, ">", seq_along(lp), ")")
    pred <- c(lapply(lp, plogis), list(mat0))

    probs <- lapply(seq_along(pred)[-1], function(k) {
      minmax_mat(pred[[k - 1]] - pred[[k]])
    })

    probs <- c(list(
      1 - minmax_mat(
        apply(array(dim = c(dim(probs[[1]]), length(probs)),
                    unlist(probs)), c(1, 2), sum)
      )),
      probs)
  }
  names(probs) <- paste0("P(", varname, "=",
                         levels(data[, varname]),
                         ")")

  if (type == "lp") {
    fit <- lapply(lp, colMeans)
    quants <- if (!is.null(quantiles)) {
      sapply(lp, function(x) {
        t(apply(x, 2, quantile, probs = quantiles, na.rm = TRUE))
      }, simplify = FALSE)
    }
  } else if (type == "prob") {
    fit <- lapply(probs, colMeans)
    quants <- if (!is.null(quantiles)) {
      sapply(probs, function(x) {
        t(apply(x, 2, quantile, probs = quantiles, na.rm = TRUE))
      }, simplify = FALSE)
    }
  } else if (type == "class") {
    fit <- apply(do.call(cbind, lapply(probs, colMeans)), 1,
                 function(x) if (all(is.na(x))) NA else which.max(x))
    quants <- NULL
  }

  res_df <- if (!is.null(quants)) {
    res <- mapply(function(f, q) {
      cbind(fit = f, q)
    }, f = fit, q = quants, SIMPLIFY = FALSE)

    array(dim = c(dim(res[[1]]), length(res)),
          dimnames = list(c(), colnames(res[[1]]), names(res)),
          unlist(res))
  } else {
    data.frame(fit, check.names = FALSE)
  }

  on.exit(options(op))
  res_df
}




predict_mlogit <- function(formula, newdata,
                           type = c("prob", "lp", "class", "response"),
                           data, MCMC, varname, coef_list, info_list,
                           quantiles = c(0.025, 0.975), warn = TRUE,
                           contr_list, Mlist, ...) {

  type <- match.arg(type)

  if (type == "response")
    type <- "class"


  coefs <- coef_list[[varname]]

  scale_pars <- do.call(rbind, unname(Mlist$scale_pars))
  if (!is.null(scale_pars)) {
    scale_pars$center[is.na(scale_pars$center)] <- 0
  }

  mf <- model.frame(as.formula(paste(formula[-2], collapse = " ")),
                    data, na.action = na.pass)
  mt <- attr(mf, "terms")

  op <- options(na.action = na.pass)
  X <- model.matrix(mt,
                    data = newdata,
                    contrasts.arg = contr_list[intersect(
                      names(contr_list),
                      sapply(attr(mt, "variables")[-1], deparse,
                             width.cutoff = 500)
                    )]
  )

  if (warn & any(is.na(X)))
    warnmsg("Prediction for cases with missing covariates is not yet
            implemented.")

  # multiply MCMC sample with design matrix to get linear predictor
  coefs_nonprop <- split(coefs, coefs$outcat)

  etas <- lapply(coefs_nonprop, function(c_np_k) {
    calc_lp(regcoefs = MCMC[, c_np_k$coef, drop = FALSE],
            design_mat = X[, c_np_k$varname, drop = FALSE],
            scale_pars = NULL)
  })


  mat0 <- matrix(nrow = nrow(etas[[1]]), ncol = ncol(etas[[1]]), data = 0)
  lp <- c(list(mat0), etas)

  phis <- lapply(lp, exp)
  sum_phis <- apply(array(dim = c(dim(phis[[1]]), length(phis)),
                    unlist(phis)), c(1, 2), sum)

  probs <- lapply(seq_along(phis), function(k) {
    minmax_mat(phis[[k]] / sum_phis)
  })

  names(probs) <- paste0("P(", varname, "=",
                         levels(data[, varname]),
                         ")")

  if (type == "lp") {
    fit <- lapply(lp, colMeans)
    quants <- if (!is.null(quantiles)) {
      sapply(lp, function(x) {
        t(apply(x, 2, quantile, probs = quantiles, na.rm = TRUE))
      }, simplify = FALSE)
    }
  } else if (type == "prob") {
    fit <- lapply(probs, colMeans)
    quants <- if (!is.null(quantiles)) {
      sapply(probs, function(x) {
        t(apply(x, 2, quantile, probs = quantiles, na.rm = TRUE))
      }, simplify = FALSE)
    }
  } else if (type == "class") {
    fit <- apply(do.call(cbind, lapply(probs, colMeans)), 1,
                 function(x) if (all(is.na(x))) NA else which.max(x))
    quants <- NULL
  }

  res_df <- if (!is.null(quants)) {
    res <- mapply(function(f, q) {
      cbind(fit = f, q)
    }, f = fit, q = quants, SIMPLIFY = FALSE)

    array(dim = c(dim(res[[1]]), length(res)),
          dimnames = list(c(), colnames(res[[1]]), names(res)),
          unlist(res))
  } else {
    data.frame(fit, check.names = FALSE)
  }

  on.exit(options(op))
  res_df
}



predict_JM <- function(...) {
  errormsg("Prediction is not yet implemented for models for joint models for
           longitudinal and survival data.")
}



fitted_values <- function(object, ...) {

  types <- sapply(names(object$fixed), function(k) {
    switch(object$info_list[[k]]$modeltype,
           glm = "response",
           glmm = "response",
           clm = "prob",
           clmm = "prob",
           survreg = "response",
           coxph = "lp")
  })


  fit <- predict(object, outcome = seq_along(object$fixed), quantiles = NULL,
                 type = types, ...)$fitted

  if (length(fit) == 1) {
    c(fit$fit)
  } else {
    lapply(fit, "[[", "fit")
  }
}
