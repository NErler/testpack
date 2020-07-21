context("test")

library("testpack")

Sys.setenv("IS_CHECK" = "true")

test_that("rng works", {
  expect_snapshot_output(
    get_rng(123, 3)
  )
})

test_that("seed works", {
  expect_snapshot_output(
    get_initial_values(inits = NULL, seed = 123, n.chains = 3, warn = FALSE)
  )
})


m2a0 = survreg_imp(Surv(futime, status != "censored") ~ copper, data = PBC,
                   n.adapt = 5, n.iter = 0, seed = 2020,
                   mess = FALSE, warn = FALSE)

m2a = survreg_imp(Surv(futime, status != "censored") ~ copper, data = PBC,
                   n.adapt = 5, n.iter = 10, seed = 2020,
                   mess = FALSE, warn = FALSE)
test_that("mod2a data list", {
  expect_snapshot_output(
    m2a$data_list
  )
})


test_that("mod2a samplers", {
  expect_snapshot_output(
    rjags::list.samplers(m2a$model)
  )
})

test_that("mod2a0 state", {
  expect_snapshot_output(
    coef(m2a0$model)
  )
})


test_that("mod2a0 model", {
  expect_snapshot_output(
    m2a0$model
  )
})


test_that("mod2a model", {
  expect_snapshot_output(
    m2a$model
  )
})

test_that("mod2a MCMC", {
  expect_snapshot_output(
    m2a$MCMC
  )
})

# test_that("seed works", {
#   expect_snapshot_output(myfun(5, seed = 123))
# })
#
#
# test_that("inits work", {
#   expect_snapshot_output(get_inits(seed = 2020, n.chains = 3))
# })
#
#
# test_that("JAGS runs", {
#   if (R.version$major <= 3 & R.version$minor < 6.0) {
#     suppressWarnings(set.seed(123))
#   } else {
#     suppressWarnings(set.seed(123, sample.kind = "Rounding"))
#   }
#
#   dat <- list(y = rnorm(20), n = 20)
#   inits <- get_inits(seed = 123, n.chains = 2)
#   mod = "model{
#   for(i in 1:n) {
#   y[i] ~ dnorm(mu, tau)
#   }
#   mu ~ dnorm(0, 0.0001)
#   tau ~ dgamma(0.01, 0.001)
#   }"
#
#   adapt = rjags::jags.model(file = textConnection(mod), data = dat,
#                             inits = inits, n.chains = 2,
#                             n.adapt = 50, quiet = TRUE)
#   mcmc <- rjags::coda.samples(adapt, n.iter = 10, variable.names = c('mu', 'tau'))
#
#   expect_snapshot_output(mcmc)
# })
#
#
#
# library("ggplot2")
#
# p <- ggplot(mpg, aes(displ, cty)) + geom_point()
# p1 <- p + facet_grid(rows = vars(drv))
#
# test_that("ggplot works", {
#   expect_silent(p1)
# })
#
#
# test_that("ggpubr works", {
#   if ("ggpubr" %in% installed.packages()[, "Package"]) {
#     expect_silent(ggpubr::ggarrange(p1, p1))
#   } else {
#     expect_error(ggpubr::ggarrange(p1, p1))
#   }
# })
