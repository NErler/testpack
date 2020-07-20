
#' A function
#' @param n a number
#' @param seed optional seed
#' @export

myfun <- function(n, seed = NULL) {
  if (!is.null(seed))
    set.seed(seed, sample.kind = "Rounding")

  stats::rnorm(n)
}



#' Function to generate initial values
#' @param seed seed value
#' @param n.chains number of chains
#' @export

get_inits <- function(seed, n.chains = 3) {
  old <- .Random.seed
  on.exit({
    .Random.seed <<- old
  })

  get_rng(seed, n.chains)
}



get_rng <- function(seed, n.chains) {
  # get starting values for the random number generator
  # - seed: an optional seed value
  # - n.chains: the number of MCMC chains for which starting values need to be
  #             generated

  if (!is.null(seed))
    set.seed(seed, sample.kind = "Rounding")
  seeds <- sample.int(1e5, size = n.chains)

  # available random number generators
  rng <- c("base::Mersenne-Twister",
           "base::Super-Duper",
           "base::Wichmann-Hill",
           "base::Marsaglia-Multicarry")

  RNGs <- sample(rng, size = n.chains, replace = TRUE)

  lapply(seq_along(RNGs), function(k) {
    list(.RNG.name = RNGs[k],
         .RNG.seed = seeds[k]
    )
  })
}


