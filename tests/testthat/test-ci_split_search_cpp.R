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

test_that("best_numeric_split_cpp matches R scoring with direct weighted covariance", {
  x <- c(1, 2, 3, 4, 5, 6, 7)
  y <- cbind(
    rank = c(20, 10, 40, 30, 70, 50, 60),
    outcome = c(1, 0, 1, 0, 1, 0, 1)
  )
  wt <- c(1, 3, 2, 4, 1, 2, 5)
  ctrl <- ci_tree_control(minsplit = 1, minbucket = 1, minprob = 0)

  r_cig <- best_numeric_split(
    x = x,
    y = y,
    wt = wt,
    varid = 1L,
    ctrl = ctrl,
    ci_fun = ci_factory("CIg"),
    return = "candidate"
  )
  cpp_cig <- best_numeric_split_cpp(
    x = x,
    y = y,
    wt = wt,
    varid = 1L,
    ctrl = ctrl,
    type = "CIg",
    return = "candidate"
  )
  cpp_cic <- best_numeric_split_cpp(
    x = x,
    y = y,
    wt = wt,
    varid = 1L,
    ctrl = ctrl,
    type = "CIc",
    return = "candidate"
  )

  expect_equal(cpp_cig$gain, r_cig$gain, tolerance = 1e-12)
  expect_equal(cpp_cig$cutpoint, r_cig$cutpoint)
  expect_equal(cpp_cig$left, r_cig$left)
  expect_equal(cpp_cic$gain, 4 * cpp_cig$gain, tolerance = 1e-12)
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

test_that("best_global_ci_split_cpp matches R scoring with tied ranks", {
  predictors <- data.frame(
    z = c(1, 2, 3, 4, 5, 6, 7, 8),
    group = factor(c("a", "a", "b", "b", "c", "c", "d", "d"))
  )
  y <- cbind(
    rank = c(10, 20, 20, 40, 40, 60, 60, 80),
    outcome = c(0, 0, 1, 1, 4, 4, 5, 5)
  )
  wt <- c(1, 3, 2, 1, 4, 2, 5, 1)
  ctrl <- ci_tree_control(minsplit = 1, minbucket = 1, minprob = 0)

  current <- best_global_ci_split(
    x = predictors,
    y = y,
    wt = wt,
    ctrl = ctrl,
    ci_fun = ci_factory("CIg")
  )
  cpp <- best_global_ci_split_cpp(
    x = predictors,
    y = y,
    wt = wt,
    ctrl = ctrl,
    type = "CIg"
  )

  expect_equal(cpp$gain, current$gain, tolerance = 1e-12)
  expect_equal(cpp$varid, current$varid)
  expect_equal(cpp$left, current$left)
})

test_that("best_global_ci_split_cpp respects min_relative_gain", {
  predictors <- data.frame(
    x = c(1, 2, 3, 4, 5, 6, 7)
  )
  y <- cbind(
    rank = c(20, 10, 40, 30, 70, 50, 60),
    outcome = c(1, 0, 1, 0, 1, 0, 1)
  )
  wt <- c(1, 3, 2, 4, 1, 2, 5)
  ctrl <- ci_tree_control(
    minsplit = 1,
    minbucket = 1,
    minprob = 0,
    min_relative_gain = 0
  )

  split <- best_global_ci_split_cpp(
    x = predictors,
    y = y,
    wt = wt,
    ctrl = ctrl,
    type = "CIg"
  )

  expect_true(is.finite(split$relative_gain))
  expect_equal(split$parent_impurity, ci_factory("CIg")(y, wt))
  expect_equal(split$relative_gain, split$gain / abs(split$parent_impurity))

  ctrl$min_relative_gain <- split$relative_gain + 1e-8
  expect_null(best_global_ci_split_cpp(
    x = predictors,
    y = y,
    wt = wt,
    ctrl = ctrl,
    type = "CIg"
  ))
})
