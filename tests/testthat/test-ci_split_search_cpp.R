test_that("best_numeric_split_cpp matches R numeric split search", {
  x <- c(2, 4, 6, 8, 10, 12, 14, 16)
  y <- cbind(
    rank = c(10, 20, 30, 40, 50, 60, 70, 80),
    outcome = c(1, 0, 1, 0, 1, 1, 0, 1)
  )
  wt <- c(1, 2, 1, 2, 1, 2, 1, 2)
  ctrl <- ci_tree_control(minsplit = 1, minbucket = 1, minprob = 0)

  current <- best_numeric_split(
    x = x,
    y = y,
    wt = wt,
    varid = 1L,
    ctrl = ctrl,
    ci_fun = ci_factory("CI"),
    return = "candidate"
  )
  cpp <- best_numeric_split_cpp(
    x = x,
    y = y,
    wt = wt,
    varid = 1L,
    ctrl = ctrl,
    type = "CI",
    return = "candidate"
  )

  expect_equal(cpp$gain, current$gain, tolerance = 1e-12)
  expect_equal(cpp$cutpoint, current$cutpoint)
  expect_equal(cpp$left, current$left)
})

test_that("best_factor_split_cpp matches R factor split search", {
  x <- factor(
    c("low", "mid", "high", "low", "mid", "high", "top", "top"),
    levels = c("low", "mid", "high", "top", "unused")
  )
  keep <- rep(TRUE, length(x))
  y <- cbind(
    rank = c(10, 20, 30, 40, 50, 60, 70, 80),
    outcome = c(1, 2, 5, 1, 2, 5, 8, 7)
  )
  wt <- c(1, 2, 1, 2, 1, 2, 1, 2)
  ctrl <- ci_tree_control(minsplit = 1, minbucket = 1, minprob = 0)

  current <- best_factor_split(
    x_full = x,
    keep = keep,
    y_full = y,
    wt_full = wt,
    varid = 1L,
    ctrl = ctrl,
    ci_fun = ci_factory("CI"),
    return = "candidate"
  )
  cpp <- best_factor_split_cpp(
    x_full = x,
    keep = keep,
    y_full = y,
    wt_full = wt,
    varid = 1L,
    ctrl = ctrl,
    type = "CI",
    return = "candidate"
  )

  expect_equal(cpp$gain, current$gain, tolerance = 1e-12)
  expect_equal(cpp$left, current$left)
  expect_equal(cpp$left_levels, current$left_levels)
  expect_equal(cpp$right_levels, current$right_levels)
})

test_that("best_global_ci_split_cpp matches R global split search on mixed predictors", {
  predictors <- data.frame(
    z = c(2, 4, 6, 8, 10, 12, 14, 16),
    group = factor(c("a", "b", "c", "a", "b", "c", "d", "d"))
  )
  y <- cbind(
    rank = c(10, 20, 30, 40, 50, 60, 70, 80),
    outcome = c(1, 0, 1, 0, 1, 1, 0, 1)
  )
  wt <- rep(1, nrow(predictors))
  ctrl <- ci_tree_control(minsplit = 1, minbucket = 1, minprob = 0)

  current <- best_global_ci_split(
    x = predictors,
    y = y,
    wt = wt,
    ctrl = ctrl,
    ci_fun = ci_factory("CI")
  )
  cpp <- best_global_ci_split_cpp(
    x = predictors,
    y = y,
    wt = wt,
    ctrl = ctrl,
    type = "CI"
  )

  expect_equal(cpp$gain, current$gain, tolerance = 1e-12)
  expect_equal(cpp$varid, current$varid)
  expect_equal(cpp$left, current$left)
})
