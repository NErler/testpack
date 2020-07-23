context("survreg models")
library("testpack")

Sys.setenv("IS_CHECK" = "true")

set_seed(1234)
longDF <- testpack::longDF
# gamma variables
longDF$L1 <- rgamma(nrow(longDF), 2, 4)
longDF$L1mis <- rgamma(nrow(longDF), 2, 4)
longDF$L1mis[sample.int(nrow(longDF), 20)] <- NA

# beta variables
longDF$Be1 <- plogis(longDF$time - longDF$C1)
longDF$Be2 <- plogis(longDF$y + longDF$c1)
longDF$Be2[c(1:20) * 5] <- NA


mod <- lme_imp(c1 ~ c2 + B2 + p2 + L1mis + Be2 + (1 | id), data = longDF,
               n.adapt = 5, n.iter = 10, seed = 2020,
               models = c(p2 = "glmm_poisson_log",
                          L1mis = "glmm_gamma_inverse",
                          Be2 = "glmm_beta"),
               warn = FALSE, mess = FALSE, keep_scaled_mcmc = TRUE)



test_that("software version is the same", {
  expect_known_output(
    cat(paste0("JAGS: ", rjags::jags.version(), "\n",
               "rjags: ", packageVersion("rjags"), "\n")),
    file = 'testout.txt'
  )
})

test_that("inits are the same", {
  expect_known_output(print(
    mod$mcmc_settings$inits),
    file = "testout2.txt"
  )
})


test_that("data lists are the same", {
  expect_known_output(
    print(mod$data_list),
    file = "testout3.txt"
  )
})



test_that("samplers are the same", {
  s <- rjags::list.samplers(mod$model)
  expect_known_output(print(unique(names(s))),
                      file = "testout4.txt")
  expect_known_output(print(
    lapply(unique(names(s)), function(k) {
      unlist(s[names(s) == k])
    })), file = "testout5.txt"
  )
})


test_that("MCMC is the same", {
  expect_known_output(print(
    mod$MCMC), file = "testout6.txt"
  )
})

