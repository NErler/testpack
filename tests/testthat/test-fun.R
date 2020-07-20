context("test")

library("testpack")

test_that("seed works", {
  expect_snapshot_output(myfun(5, seed = 123))
})
