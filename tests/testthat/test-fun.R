context("test")

library("testpack")

test_that("seed works", {
  expect_snapshot_output(myfun(5, seed = 123))
})


test_that("inits work", {
  expect_snapshot_output(get_inits(seed = 2020, n.chains = 3))
})


test_that("JAGS runs", {
  if (R.version$major <= 3 & R.version$minor < 6.0) {
    suppressWarnings(set.seed(123, sample.kind = "Rounding"))
  } else {
    set.seed(123)
  }

  dat <- list(y = rnorm(20), n = 20)
  inits <- get_inits(seed = 123, n.chains = 2)
  mod = "model{
  for(i in 1:n) {
  y[i] ~ dnorm(mu, tau)
  }
  mu ~ dnorm(0, 0.0001)
  tau ~ dgamma(0.01, 0.001)
  }"

  adapt = rjags::jags.model(file = textConnection(mod), data = dat,
                            inits = inits, n.chains = 2,
                            n.adapt = 50, quiet = TRUE)
  mcmc <- rjags::coda.samples(adapt, n.iter = 10, variable.names = c('mu', 'tau'))

  expect_snapshot_output(mcmc)
})

