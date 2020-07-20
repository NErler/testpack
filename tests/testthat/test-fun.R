context("test")

library("testpack")

test_that("seed works", {
  expect_snapshot_output(myfun(5, seed = 123))
})


test_that("inits work", {
  expect_snapshot_output(get_inits(seed = 2020, n.chains = 3))
})
