
# ineqTrees

<!-- badges: start -->

[![R-CMD-check](https://github.com/m-mburu/ineqTrees/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/m-mburu/ineqTrees/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

`ineqTrees` provides tools for studying socioeconomic inequality in
health outcomes with tree-based models. The package includes weighted
rank and concentration-index utilities, inequality-aware split scoring,
and wrappers for fitting greedy concentration-index trees and forests.

## Installation

You can install the development version of ineqTrees like so:

``` r
remotes::install_github("m-mburu/ineqTrees")
```

## Fitting a tree

The example below fits an inequality-aware greedy tree on a sample from
the built-in `kenya` dataset. The response combines the ranking variable
(`wealth`) and the health outcome (`deadu5_num`), while the split
criterion is based on concentration-index reduction.

### load data and set seed for reproducibility

``` r
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  suppressMessages(pkgload::load_all(export_all = FALSE))
} else {
  library(ineqTrees)
}
library(data.table)
load("data/kenya.rda")

set.seed(1)
```

### Fit tree

- This is a concentration-index tree, so the response is a two-column
  matrix of the ranking variable and the outcome. The `rank_name` and
  `outcome_name` arguments specify which columns of the data to use for
  those roles. The split criterion is based on concentration-index
  reduction, so the `control` argument specifies greedy controls rather
  than conditional-inference test controls.

``` r
fit_tree <- ci_tree(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = kenya,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  control = ci_tree_control(maxdepth = 4L)
)
```

``` r
fit_tree
```

### Greedy concentration-index tree

**Formula:** `cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled`
**Criterion:** CI **Tree size:** 15 inner nodes, 16 terminal nodes, max
depth 4

| node | n | weight | depth | CI | outcome_mean | outcome_percent | rule |
|---:|---:|---:|---:|---:|---:|---:|:---|
| 20 | 4281 | 4281 | 4 | 0.279 | 0.043 | 4.3 | rural in {Rural} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Baringo, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & ed in {a education} & reg in {Mombasa, Kwale, Lamu, Machakos, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Elgeyo-Marakwet, Nandi, Nakuru, Vihiga, Nyamira, Nairobi} |
| 16 | 153 | 153 | 4 | 0.211 | 0.163 | 16.3 | rural in {Urban} & reg in {Kwale, Kilifi, Tana River, Lamu, Garissa, Wajir, Mandera, Marsabit, Tharaka-Nithi, Embu, Kitui, Machakos, Nyandarua, Murang’a, Turkana, West Pokot, Samburu, Elgeyo-Marakwet, Baringo, Narok, Bungoma, Siaya, Kisumu, Nyamira} & ed in {b no education} & reg in {Lamu, Garissa, Wajir, Marsabit, Kitui, Turkana, West Pokot, Samburu, Narok} |
| 30 | 568 | 568 | 4 | 0.207 | 0.153 | 15.3 | rural in {Rural} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Siaya, Homa Bay, Migori} & unskilled in {Yes} & ed in {a education} |
| 6 | 761 | 761 | 4 | 0.187 | 0.033 | 3.3 | rural in {Urban} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Nakuru, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Homa Bay, Migori, Kisii, Nairobi} & ed in {a education} & reg in {Isiolo, Makueni, Nyeri, Nakuru, Kakamega, Busia, Homa Bay, Migori} |
| 21 | 5564 | 5564 | 4 | 0.170 | 0.075 | 7.5 | rural in {Rural} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Baringo, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & ed in {a education} & reg in {Kilifi, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Makueni, Nyandarua, Murang’a, Uasin Gishu, Baringo, Laikipia, Narok, Kajiado, Kericho, Bomet, Kakamega, Bungoma, Busia, Kisumu, Kisii} |
| 12 | 1030 | 1030 | 4 | 0.167 | 0.033 | 3.3 | rural in {Urban} & reg in {Kwale, Kilifi, Tana River, Lamu, Garissa, Wajir, Mandera, Marsabit, Tharaka-Nithi, Embu, Kitui, Machakos, Nyandarua, Murang’a, Turkana, West Pokot, Samburu, Elgeyo-Marakwet, Baringo, Narok, Bungoma, Siaya, Kisumu, Nyamira} & ed in {a education} & reg in {Lamu, Garissa, Marsabit, Tharaka-Nithi, Kitui, Machakos, Nyandarua, Murang’a, West Pokot, Baringo, Narok, Bungoma, Kisumu, Nyamira} |
| 13 | 553 | 553 | 4 | 0.160 | 0.065 | 6.5 | rural in {Urban} & reg in {Kwale, Kilifi, Tana River, Lamu, Garissa, Wajir, Mandera, Marsabit, Tharaka-Nithi, Embu, Kitui, Machakos, Nyandarua, Murang’a, Turkana, West Pokot, Samburu, Elgeyo-Marakwet, Baringo, Narok, Bungoma, Siaya, Kisumu, Nyamira} & ed in {a education} & reg in {Kwale, Kilifi, Tana River, Wajir, Mandera, Embu, Turkana, Samburu, Elgeyo-Marakwet, Siaya} |
| 9 | 450 | 450 | 4 | 0.155 | 0.049 | 4.9 | rural in {Urban} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Nakuru, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Homa Bay, Migori, Kisii, Nairobi} & ed in {b no education} & reg in {Mombasa, Taita Taveta, Meru, Kiambu, Trans Nzoia, Nandi, Laikipia, Nakuru, Kericho, Kakamega, Busia, Homa Bay, Migori, Kisii, Nairobi} |
| 31 | 457 | 457 | 4 | 0.117 | 0.199 | 19.9 | rural in {Rural} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Siaya, Homa Bay, Migori} & unskilled in {Yes} & ed in {b no education} |
| 5 | 1389 | 1389 | 4 | 0.115 | 0.011 | 1.1 | rural in {Urban} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Nakuru, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Homa Bay, Migori, Kisii, Nairobi} & ed in {a education} & reg in {Mombasa, Taita Taveta, Meru, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Kajiado, Kericho, Bomet, Vihiga, Kisii, Nairobi} |
| 15 | 314 | 314 | 4 | 0.114 | 0.070 | 7.0 | rural in {Urban} & reg in {Kwale, Kilifi, Tana River, Lamu, Garissa, Wajir, Mandera, Marsabit, Tharaka-Nithi, Embu, Kitui, Machakos, Nyandarua, Murang’a, Turkana, West Pokot, Samburu, Elgeyo-Marakwet, Baringo, Narok, Bungoma, Siaya, Kisumu, Nyamira} & ed in {b no education} & reg in {Kwale, Kilifi, Tana River, Mandera, Tharaka-Nithi, Embu, Machakos, Nyandarua, Murang’a, Elgeyo-Marakwet, Baringo, Bungoma, Siaya, Kisumu, Nyamira} |
| 24 | 1661 | 1661 | 4 | 0.105 | 0.138 | 13.8 | rural in {Rural} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Baringo, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & ed in {b no education} & reg in {Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Embu, Kitui, Machakos, Makueni, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Baringo, Nakuru, Kajiado, Kericho, Kakamega, Bungoma, Kisumu, Kisii, Nyamira} |
| 28 | 1244 | 1244 | 4 | 0.100 | 0.132 | 13.2 | rural in {Rural} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Siaya, Homa Bay, Migori} & unskilled in {No} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Homa Bay} |
| 27 | 420 | 420 | 4 | 0.080 | 0.093 | 9.3 | rural in {Rural} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Siaya, Homa Bay, Migori} & unskilled in {No} & reg in {Siaya, Migori} |
| 23 | 1082 | 1082 | 4 | 0.068 | 0.079 | 7.9 | rural in {Rural} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Baringo, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & ed in {b no education} & reg in {Mombasa, Tharaka-Nithi, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Nandi, Laikipia, Narok, Bomet, Vihiga, Busia, Nairobi} |
| 8 | 116 | 116 | 4 | 0.000 | 0.000 | 0.0 | rural in {Urban} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Nakuru, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Homa Bay, Migori, Kisii, Nairobi} & ed in {b no education} & reg in {Isiolo, Makueni, Nyeri, Kirinyaga, Uasin Gishu, Kajiado, Bomet, Vihiga} |

Terminal-node summary with subgroup rules

``` r
ci_tree_terminal_summary(fit_tree)
#>      node     n weight depth         ci outcome_mean outcome_percent
#>     <int> <int>  <num> <int>      <num>        <num>           <num>
#>  1:     5  1389   1389     4 0.11450528   0.01079914        1.079914
#>  2:     6   761    761     4 0.18736842   0.03285151        3.285151
#>  3:     8   116    116     4 0.00000000   0.00000000        0.000000
#>  4:     9   450    450     4 0.15549706   0.04888889        4.888889
#>  5:    12  1030   1030     4 0.16732407   0.03300971        3.300971
#>  6:    13   553    553     4 0.15962158   0.06509946        6.509946
#>  7:    15   314    314     4 0.11443509   0.07006369        7.006369
#>  8:    16   153    153     4 0.21052632   0.16339869       16.339869
#>  9:    20  4281   4281     4 0.27940894   0.04321420        4.321420
#> 10:    21  5564   5564     4 0.17041553   0.07494608        7.494608
#> 11:    23  1082   1082     4 0.06787428   0.07948244        7.948244
#> 12:    24  1661   1661     4 0.10506129   0.13786875       13.786875
#> 13:    27   420    420     4 0.08035004   0.09285714        9.285714
#> 14:    28  1244   1244     4 0.10034731   0.13183280       13.183280
#> 15:    30   568    568     4 0.20736281   0.15316901       15.316901
#> 16:    31   457    457     4 0.11702333   0.19912473       19.912473
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                rule
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              <char>
#>  1:                                                                                                                                                                                           rural in {Urban} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Nakuru, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Homa Bay, Migori, Kisii, Nairobi} & ed in {a education} & reg in {Mombasa, Taita Taveta, Meru, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Kajiado, Kericho, Bomet, Vihiga, Kisii, Nairobi}
#>  2:                                                                                                                                                                                                                                                                    rural in {Urban} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Nakuru, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Homa Bay, Migori, Kisii, Nairobi} & ed in {a education} & reg in {Isiolo, Makueni, Nyeri, Nakuru, Kakamega, Busia, Homa Bay, Migori}
#>  3:                                                                                                                                                                                                                                                            rural in {Urban} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Nakuru, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Homa Bay, Migori, Kisii, Nairobi} & ed in {b no education} & reg in {Isiolo, Makueni, Nyeri, Kirinyaga, Uasin Gishu, Kajiado, Bomet, Vihiga}
#>  4:                                                                                                                                                                                             rural in {Urban} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Nandi, Laikipia, Nakuru, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Homa Bay, Migori, Kisii, Nairobi} & ed in {b no education} & reg in {Mombasa, Taita Taveta, Meru, Kiambu, Trans Nzoia, Nandi, Laikipia, Nakuru, Kericho, Kakamega, Busia, Homa Bay, Migori, Kisii, Nairobi}
#>  5:                                                                                                                                                                                   rural in {Urban} & reg in {Kwale, Kilifi, Tana River, Lamu, Garissa, Wajir, Mandera, Marsabit, Tharaka-Nithi, Embu, Kitui, Machakos, Nyandarua, Murang'a, Turkana, West Pokot, Samburu, Elgeyo-Marakwet, Baringo, Narok, Bungoma, Siaya, Kisumu, Nyamira} & ed in {a education} & reg in {Lamu, Garissa, Marsabit, Tharaka-Nithi, Kitui, Machakos, Nyandarua, Murang'a, West Pokot, Baringo, Narok, Bungoma, Kisumu, Nyamira}
#>  6:                                                                                                                                                                                                                            rural in {Urban} & reg in {Kwale, Kilifi, Tana River, Lamu, Garissa, Wajir, Mandera, Marsabit, Tharaka-Nithi, Embu, Kitui, Machakos, Nyandarua, Murang'a, Turkana, West Pokot, Samburu, Elgeyo-Marakwet, Baringo, Narok, Bungoma, Siaya, Kisumu, Nyamira} & ed in {a education} & reg in {Kwale, Kilifi, Tana River, Wajir, Mandera, Embu, Turkana, Samburu, Elgeyo-Marakwet, Siaya}
#>  7:                                                                                                                                                                 rural in {Urban} & reg in {Kwale, Kilifi, Tana River, Lamu, Garissa, Wajir, Mandera, Marsabit, Tharaka-Nithi, Embu, Kitui, Machakos, Nyandarua, Murang'a, Turkana, West Pokot, Samburu, Elgeyo-Marakwet, Baringo, Narok, Bungoma, Siaya, Kisumu, Nyamira} & ed in {b no education} & reg in {Kwale, Kilifi, Tana River, Mandera, Tharaka-Nithi, Embu, Machakos, Nyandarua, Murang'a, Elgeyo-Marakwet, Baringo, Bungoma, Siaya, Kisumu, Nyamira}
#>  8:                                                                                                                                                                                                                                        rural in {Urban} & reg in {Kwale, Kilifi, Tana River, Lamu, Garissa, Wajir, Mandera, Marsabit, Tharaka-Nithi, Embu, Kitui, Machakos, Nyandarua, Murang'a, Turkana, West Pokot, Samburu, Elgeyo-Marakwet, Baringo, Narok, Bungoma, Siaya, Kisumu, Nyamira} & ed in {b no education} & reg in {Lamu, Garissa, Wajir, Marsabit, Kitui, Turkana, West Pokot, Samburu, Narok}
#>  9:                                                                             rural in {Rural} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang'a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Baringo, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & ed in {a education} & reg in {Mombasa, Kwale, Lamu, Machakos, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Elgeyo-Marakwet, Nandi, Nakuru, Vihiga, Nyamira, Nairobi}
#> 10:       rural in {Rural} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang'a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Baringo, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & ed in {a education} & reg in {Kilifi, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Makueni, Nyandarua, Murang'a, Uasin Gishu, Baringo, Laikipia, Narok, Kajiado, Kericho, Bomet, Kakamega, Bungoma, Busia, Kisumu, Kisii}
#> 11:                                                                             rural in {Rural} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang'a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Baringo, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & ed in {b no education} & reg in {Mombasa, Tharaka-Nithi, Nyandarua, Nyeri, Kirinyaga, Murang'a, Kiambu, Nandi, Laikipia, Narok, Bomet, Vihiga, Busia, Nairobi}
#> 12: rural in {Rural} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang'a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Baringo, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & ed in {b no education} & reg in {Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Embu, Kitui, Machakos, Makueni, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Baringo, Nakuru, Kajiado, Kericho, Kakamega, Bungoma, Kisumu, Kisii, Nyamira}
#> 13:                                                                                                                                                                                                                                                                                                                                                                                                                                   rural in {Rural} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Siaya, Homa Bay, Migori} & unskilled in {No} & reg in {Siaya, Migori}
#> 14:                                                                                                                                                                                                                                                                                                                                                           rural in {Rural} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Siaya, Homa Bay, Migori} & unskilled in {No} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Homa Bay}
#> 15:                                                                                                                                                                                                                                                                                                                                                                                                                                     rural in {Rural} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Siaya, Homa Bay, Migori} & unskilled in {Yes} & ed in {a education}
#> 16:                                                                                                                                                                                                                                                                                                                                                                                                                                  rural in {Rural} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Siaya, Homa Bay, Migori} & unskilled in {Yes} & ed in {b no education}
```

``` r
readme_tree_plot(fit_tree, kenya, "deadu5_num")
```

<img src="man/figures/README-readme-tree-plot-1.png" alt="A concentration-index tree fitted to under-five mortality in the Kenya example data." width="100%" />

## Fitting a forest

The forest interface uses the same response specification, but averages
predictions across many greedy concentration-index trees. The tuned
workflow later in the README uses the same model family with
cross-validation.

``` r
fit_forest <- ci_forest(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = kenya,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  ntree = 10L,
  mtry = 1L,
  control = ci_tree_control(maxdepth = 5L)
)
fit_forest
```

### Greedy concentration-index forest

**Formula:** `cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled`
**Criterion:** CI **Trees:** 10

| ntree | mtry | type | n | mean_outcome | mean_prediction | outcome_ci | prediction_ci | mean_terminal_nodes | mean_max_depth |
|---:|---:|:---|---:|---:|---:|---:|---:|---:|---:|
| 10 | 1 | CI | 20043 | 0.074 | 0.074 | 0.312 | 0.108 | 6.8 | 3.5 |

Forest summary

``` r
ci_forest_summary(fit_forest)
#>    ntree  mtry   type     n mean_outcome mean_prediction outcome_ci
#>    <int> <int> <char> <int>        <num>           <num>      <num>
#> 1:    10     1     CI 20043   0.07369156       0.0736521  0.3115051
#>    prediction_ci mean_terminal_nodes mean_max_depth
#>            <num>               <num>          <num>
#> 1:     0.1079965                 6.8            3.5
```

### Fit surrogarete tree to forest predictions

- The surrogate is a greedy concentration-index tree that approximates
  the predictions of the fitted forest. This is useful for interpreting
  the forest , since the surrogate can be refit on held-out data and
  scored with CI gain.

``` r
setDT(kenya)
kenya[, forest_risk := readme_forest_predict(
   fit_forest, .SD
), .SDcols = readme_predictors]

surrogate_tree <- ci_tree(
  formula = cbind(wealth, forest_risk) ~ rural + ed + reg + unskilled,
  data = kenya,
  rank_name = "wealth",
  outcome_name = "forest_risk",
  control = ci_tree_control(maxdepth = 4L)
)
surrogate_tree
```

### Greedy concentration-index tree

**Formula:** `cbind(wealth, forest_risk) ~ rural + ed + reg + unskilled`
**Criterion:** CI **Tree size:** 15 inner nodes, 16 terminal nodes, max
depth 4

| node | n | weight | depth | CI | outcome_mean | outcome_percent | rule |
|---:|---:|---:|---:|---:|---:|---:|:---|
| 15 | 136 | 136 | 4 | 0.014 | 0.078 | 7.8 | rural in {Urban} & ed in {b no education} & reg in {Kwale, Kilifi, Tana River, Garissa, Wajir, Mandera, Marsabit, Embu, Kitui, Turkana, West Pokot, Samburu, Baringo, Bungoma, Siaya, Homa Bay} & reg in {Kwale, Marsabit, Kitui, West Pokot, Bungoma, Homa Bay} |
| 16 | 161 | 161 | 4 | 0.009 | 0.091 | 9.1 | rural in {Urban} & ed in {b no education} & reg in {Kwale, Kilifi, Tana River, Garissa, Wajir, Mandera, Marsabit, Embu, Kitui, Turkana, West Pokot, Samburu, Baringo, Bungoma, Siaya, Homa Bay} & reg in {Kilifi, Tana River, Garissa, Wajir, Mandera, Embu, Turkana, Samburu, Baringo, Siaya} |
| 28 | 1492 | 1492 | 4 | 0.009 | 0.106 | 10.6 | rural in {Rural} & ed in {b no education} & reg in {Mombasa, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Samburu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & reg in {Mombasa, Lamu, Taita Taveta, Isiolo, Meru, Embu, Kitui, Machakos, Makueni, Murang’a, Samburu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Kericho, Bomet, Kakamega, Bungoma, Busia, Kisumu, Kisii, Nyamira} |
| 31 | 435 | 435 | 4 | 0.009 | 0.142 | 14.2 | rural in {Rural} & ed in {b no education} & reg in {Kwale, Kilifi, Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Baringo, Siaya, Homa Bay, Migori} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Homa Bay} |
| 20 | 1598 | 1598 | 4 | 0.008 | 0.065 | 6.5 | rural in {Rural} & ed in {a education} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Kisumu, Kisii, Nyamira, Nairobi} & reg in {Lamu, Kiambu, Nairobi} |
| 30 | 384 | 384 | 4 | 0.007 | 0.125 | 12.5 | rural in {Rural} & ed in {b no education} & reg in {Kwale, Kilifi, Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Baringo, Siaya, Homa Bay, Migori} & reg in {Kwale, Kilifi, Baringo, Siaya, Migori} |
| 9 | 213 | 213 | 4 | 0.007 | 0.065 | 6.5 | rural in {Urban} & ed in {a education} & reg in {Kwale, Kilifi, Tana River, Garissa, Wajir, Mandera, Marsabit, Embu, Turkana, West Pokot, Samburu, Baringo, Siaya, Homa Bay, Migori} & reg in {Tana River, Wajir, Turkana, Samburu} |
| 8 | 693 | 693 | 4 | 0.007 | 0.051 | 5.1 | rural in {Urban} & ed in {a education} & reg in {Kwale, Kilifi, Tana River, Garissa, Wajir, Mandera, Marsabit, Embu, Turkana, West Pokot, Samburu, Baringo, Siaya, Homa Bay, Migori} & reg in {Kwale, Kilifi, Garissa, Mandera, Marsabit, Embu, West Pokot, Baringo, Siaya, Homa Bay, Migori} |
| 21 | 7816 | 7816 | 4 | 0.006 | 0.070 | 7.0 | rural in {Rural} & ed in {a education} & reg in {Mombasa, Kwale, Kilifi, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Kisumu, Kisii, Nyamira, Nairobi} & reg in {Mombasa, Kwale, Kilifi, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Kisumu, Kisii, Nyamira} |
| 13 | 320 | 320 | 4 | 0.006 | 0.065 | 6.5 | rural in {Urban} & ed in {b no education} & reg in {Mombasa, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Kisumu, Migori, Kisii, Nyamira, Nairobi} & reg in {Lamu, Tharaka-Nithi, Machakos, Nyandarua, Murang’a, Kiambu, Trans Nzoia, Narok, Kericho, Kakamega, Migori, Kisii} |
| 27 | 1059 | 1059 | 4 | 0.005 | 0.093 | 9.3 | rural in {Rural} & ed in {b no education} & reg in {Mombasa, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Embu, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Samburu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & reg in {Tharaka-Nithi, Nyandarua, Nyeri, Kirinyaga, Kiambu, Nandi, Laikipia, Nakuru, Narok, Kajiado, Vihiga, Nairobi} |
| 6 | 781 | 781 | 4 | 0.004 | 0.041 | 4.1 | rural in {Urban} & ed in {a education} & reg in {Mombasa, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & reg in {Tharaka-Nithi, Kitui, Nyandarua, Murang’a, Kakamega, Bungoma, Busia, Kisii} |
| 23 | 967 | 967 | 4 | 0.002 | 0.085 | 8.5 | rural in {Rural} & ed in {a education} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Baringo, Busia, Siaya, Homa Bay, Migori} & reg in {Baringo, Busia, Siaya, Migori} |
| 12 | 416 | 416 | 4 | 0.001 | 0.053 | 5.3 | rural in {Urban} & ed in {b no education} & reg in {Mombasa, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Busia, Kisumu, Migori, Kisii, Nyamira, Nairobi} & reg in {Mombasa, Taita Taveta, Isiolo, Meru, Makueni, Nyeri, Kirinyaga, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Kajiado, Bomet, Vihiga, Busia, Kisumu, Nyamira, Nairobi} |
| 24 | 1526 | 1526 | 4 | 0.001 | 0.100 | 10.0 | rural in {Rural} & ed in {a education} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Baringo, Busia, Siaya, Homa Bay, Migori} & reg in {Tana River, Garissa, Wajir, Mandera, Marsabit, Turkana, West Pokot, Samburu, Homa Bay} |
| 5 | 2046 | 2046 | 4 | 0.001 | 0.037 | 3.7 | rural in {Urban} & ed in {a education} & reg in {Mombasa, Lamu, Taita Taveta, Isiolo, Meru, Tharaka-Nithi, Kitui, Machakos, Makueni, Nyandarua, Nyeri, Kirinyaga, Murang’a, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Kakamega, Vihiga, Bungoma, Busia, Kisumu, Kisii, Nyamira, Nairobi} & reg in {Mombasa, Lamu, Taita Taveta, Isiolo, Meru, Machakos, Makueni, Nyeri, Kirinyaga, Kiambu, Trans Nzoia, Uasin Gishu, Elgeyo-Marakwet, Nandi, Laikipia, Nakuru, Narok, Kajiado, Kericho, Bomet, Vihiga, Kisumu, Nyamira, Nairobi} |

Terminal-node summary with subgroup rules

## plot

``` r
readme_tree_plot(
  surrogate_tree,
  kenya,
  outcome_name = "forest_risk",
  outcome_label = "Predicted risk"
)
```

<img src="man/figures/README-surrogate-tree-plot-1.png" alt="A surrogate concentration-index tree approximating fitted forest predictions." width="100%" />

## SHAP-based decomposition

- Approximate SHAP values for the fitted forest with
  `fastshap::explain()`, using a prediction wrapper that returns the
  predicted outcome for each observation.
- Decompose the concentration index of those predicted risks with
  `shap_conc_decomp()`.

``` r
set.seed(20260328)
shap_eval_n <- min(400L, nrow(kenya))
shap_rows <- sort(sample.int(nrow(kenya), shap_eval_n))
forest_X <- kenya[, ..readme_predictors]
shap_X_eval <- forest_X[shap_rows, , drop = FALSE]
forest_pred_eval <- readme_forest_predict(fit_forest, shap_X_eval)
wealth_eval <- kenya$wealth[shap_rows]

forest_shap <- fastshap::explain(
  object = fit_forest,
  X = forest_X,
  pred_wrapper = readme_forest_predict,
  newdata = shap_X_eval,
  nsim = 64,
  adjust = TRUE
)

decomp <- shap_conc_decomp(
  shap = forest_shap,
  rank = wealth_eval,
  prediction = forest_pred_eval
)

shap_diagnostics <- as.data.frame(decomp$diagnostics)
shap_contrib_table <- as.data.frame(decomp$contributions)
shap_contrib_table <- shap_contrib_table[
  order(-shap_contrib_table$abs_contribution),
  ,
  drop = FALSE
]
```

``` r
knitr::kable(
  shap_diagnostics,
  digits = 3,
  caption = "SHAP decomposition diagnostics"
)
```

| n | type | mean_prediction | concentration_index | shap_sum | additivity_gap | centered_rank_sum | prediction_source |
|---:|:---|---:|---:|---:|---:|---:|:---|
| 400 | CI | 0.074 | -0.099 | -0.099 | 0 | 0 | prediction |

SHAP decomposition diagnostics

``` r
knitr::kable(
  shap_contrib_table,
  digits = 3,
  caption = "SHAP-based concentration-index contributions"
)
```

| feature   | D_k_SHAP | pct_contribution | abs_contribution |
|:----------|---------:|-----------------:|-----------------:|
| rural     |   -0.036 |           36.488 |            0.036 |
| reg       |   -0.033 |           32.850 |            0.033 |
| ed        |   -0.022 |           21.821 |            0.022 |
| unskilled |   -0.009 |            8.842 |            0.009 |

SHAP-based concentration-index contributions

``` r
library(ggplot2)
ggplot(
  shap_contrib_table,
  aes(
    x = stats::reorder(feature, pct_contribution),
    y = pct_contribution,
    fill = pct_contribution > 0
  )
) +
  geom_col(width = 0.7) +
  coord_flip() +
  scale_fill_manual(
    values = c("#2166ac", "#b2182b"),
    guide = "none"
  ) +
  labs(
    x = NULL,
    y = "Percentage contribution",
    title = "SHAP-based concentration-index decomposition"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())
```

<img src="man/figures/README-shap-decomposition-plot-1.png" alt="A horizontal bar chart of SHAP-based percentage contributions to the concentration index." width="100%" />

``` r
set.seed(20260507)
tuning_n <- min(800L, nrow(kenya))
tuning_rows <- sort(sample.int(nrow(kenya), tuning_n))
tuning_data <- kenya[tuning_rows, , drop = FALSE]
```

## Tune tree hyperparameters

The current model-selection workflow uses `ci_tree_control_grid()` to
define candidate greedy controls and `tune_ci_tree()` to score them with
cross-validation. The concentration-index variant is tuned alongside the
tree controls by passing several values to `type`.

``` r
tree_tune_grid <- ci_tree_control_grid(
  minsplit = c(100L),
  minbucket = c(50L, 100L),
  maxdepth = c(3L:6L),
  minprob = c(0.01, 0.1)
)
```

``` r
tree_tuning <- tune_ci_tree(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = tuning_data,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  type = c("CI", "CIg", "CIc", "L"),
  control_grid = tree_tune_grid,
  v = 5L,
  strata = "deadu5_num",
  seed = 20260507,
  metric = "validation_gain",
  refit = TRUE
)
#> Warning: `type = "L"` uses observed socioeconomic levels rather than fractional
#> ranks. The first response column contains negative values; the
#> Erreygers-Kessels level-dependent index is intended for meaningful ratio-scale
#> socioeconomic levels such as income, consumption, or expenditure. Centered
#> wealth-index scores with negative values may be inappropriate for this
#> criterion. See https://doi.org/10.3390/ijerph14070673. This warning is shown
#> once per R session.
```

``` r
tree_tuning_table <- readme_tuning_table(
  tree_tuning$summary,
  columns = c(
    "type",
    "minsplit",
    "minbucket",
    "maxdepth",
    "mean_score",
    "sd_score",
    "mean_terminal_nodes"
  ),
  labels = c(
    "type",
    "minsplit",
    "minbucket",
    "maxdepth",
    "mean_validation_gain",
    "sd_validation_gain",
    "mean_terminal_nodes"
  )
)

knitr::kable(
  tree_tuning_table,
  digits = 3,
  caption = "Cross-validated greedy tree tuning results"
)
```

| type | minsplit | minbucket | maxdepth | mean_validation_gain | sd_validation_gain | mean_terminal_nodes |
|:---|---:|---:|---:|---:|---:|---:|
| L | 100 | 100 | 3 | 3.805 | 7.516 | 4.2 |
| L | 100 | 100 | 3 | 3.805 | 7.516 | 4.2 |
| L | 100 | 100 | 4 | 3.805 | 7.516 | 4.2 |
| L | 100 | 100 | 4 | 3.805 | 7.516 | 4.2 |
| L | 100 | 100 | 5 | 3.805 | 7.516 | 4.2 |
| L | 100 | 100 | 5 | 3.805 | 7.516 | 4.2 |
| L | 100 | 100 | 6 | 3.805 | 7.516 | 4.2 |
| L | 100 | 100 | 6 | 3.805 | 7.516 | 4.2 |
| L | 100 | 50 | 3 | 3.671 | 7.152 | 5.2 |
| L | 100 | 50 | 3 | 3.671 | 7.152 | 5.2 |
| L | 100 | 50 | 5 | 3.671 | 7.152 | 5.6 |
| L | 100 | 50 | 5 | 3.671 | 7.152 | 5.6 |
| L | 100 | 50 | 6 | 3.671 | 7.152 | 5.6 |
| L | 100 | 50 | 6 | 3.671 | 7.152 | 5.6 |
| L | 100 | 50 | 4 | 3.665 | 7.156 | 5.6 |
| L | 100 | 50 | 4 | 3.665 | 7.156 | 5.6 |
| CI | 100 | 50 | 4 | 0.023 | 0.106 | 6.2 |
| CI | 100 | 50 | 4 | 0.023 | 0.106 | 6.2 |
| CI | 100 | 50 | 5 | 0.023 | 0.106 | 6.4 |
| CI | 100 | 50 | 5 | 0.023 | 0.106 | 6.4 |
| CI | 100 | 50 | 6 | 0.023 | 0.106 | 6.4 |
| CI | 100 | 50 | 6 | 0.023 | 0.106 | 6.4 |
| CIc | 100 | 50 | 5 | 0.007 | 0.018 | 6.8 |
| CIc | 100 | 50 | 6 | 0.007 | 0.018 | 6.8 |
| CIc | 100 | 50 | 5 | 0.007 | 0.018 | 6.8 |
| CIc | 100 | 50 | 6 | 0.007 | 0.018 | 6.8 |
| CIc | 100 | 50 | 3 | 0.003 | 0.012 | 5.4 |
| CIc | 100 | 50 | 3 | 0.003 | 0.012 | 5.4 |
| CIc | 100 | 50 | 4 | 0.002 | 0.014 | 6.4 |
| CIc | 100 | 50 | 4 | 0.002 | 0.014 | 6.4 |
| CIg | 100 | 50 | 5 | 0.002 | 0.004 | 6.8 |
| CIg | 100 | 50 | 5 | 0.002 | 0.004 | 6.8 |
| CIg | 100 | 50 | 6 | 0.002 | 0.004 | 6.8 |
| CIg | 100 | 50 | 6 | 0.002 | 0.004 | 6.8 |
| CIc | 100 | 100 | 3 | 0.001 | 0.006 | 3.4 |
| CIc | 100 | 100 | 3 | 0.001 | 0.006 | 3.4 |
| CIc | 100 | 100 | 4 | 0.001 | 0.006 | 3.4 |
| CIc | 100 | 100 | 4 | 0.001 | 0.006 | 3.4 |
| CIc | 100 | 100 | 5 | 0.001 | 0.006 | 3.4 |
| CIc | 100 | 100 | 5 | 0.001 | 0.006 | 3.4 |
| CIc | 100 | 100 | 6 | 0.001 | 0.006 | 3.4 |
| CIc | 100 | 100 | 6 | 0.001 | 0.006 | 3.4 |
| CIg | 100 | 50 | 3 | 0.001 | 0.003 | 5.4 |
| CIg | 100 | 50 | 3 | 0.001 | 0.003 | 5.4 |
| CIg | 100 | 50 | 4 | 0.001 | 0.003 | 6.4 |
| CIg | 100 | 50 | 4 | 0.001 | 0.003 | 6.4 |
| CIg | 100 | 100 | 3 | 0.000 | 0.001 | 3.4 |
| CIg | 100 | 100 | 3 | 0.000 | 0.001 | 3.4 |
| CIg | 100 | 100 | 4 | 0.000 | 0.001 | 3.4 |
| CIg | 100 | 100 | 4 | 0.000 | 0.001 | 3.4 |
| CIg | 100 | 100 | 5 | 0.000 | 0.001 | 3.4 |
| CIg | 100 | 100 | 5 | 0.000 | 0.001 | 3.4 |
| CIg | 100 | 100 | 6 | 0.000 | 0.001 | 3.4 |
| CIg | 100 | 100 | 6 | 0.000 | 0.001 | 3.4 |
| CI | 100 | 50 | 3 | -0.016 | 0.098 | 5.2 |
| CI | 100 | 50 | 3 | -0.016 | 0.098 | 5.2 |
| CI | 100 | 100 | 3 | -0.029 | 0.103 | 3.2 |
| CI | 100 | 100 | 5 | -0.029 | 0.103 | 3.2 |
| CI | 100 | 100 | 6 | -0.029 | 0.103 | 3.2 |
| CI | 100 | 100 | 3 | -0.030 | 0.100 | 3.2 |
| CI | 100 | 100 | 4 | -0.030 | 0.100 | 3.2 |
| CI | 100 | 100 | 4 | -0.030 | 0.100 | 3.2 |
| CI | 100 | 100 | 5 | -0.030 | 0.100 | 3.2 |
| CI | 100 | 100 | 6 | -0.030 | 0.100 | 3.2 |

Cross-validated greedy tree tuning results

``` r
readme_tree_plot(
  fit = tree_tuning$best_fit,
  data = tuning_data,
  outcome_name = "deadu5_num"
)
```

<img src="man/figures/README-tree-tuning-plot-1.png" alt="The best concentration-index tree selected by cross-validated tuning." width="100%" />

## Tune forest hyperparameters

For forests, `tune_ci_forest()` uses the same greedy controls and adds
`ntree` when that column is present in the tuning grid. Each candidate
forest is summarized by a surrogate greedy CI tree, and the grid is
ranked by held-out CI validation gain from that surrogate.

``` r
forest_tune_grid <- ci_tree_control_grid(
  minsplit = c(100L),
  minbucket = c(50L, 100L),
  maxdepth = c(3L:6L),
  mtry = c(1L, 2L),
  ntree = c(10L, 50L),
  minprob = c(0.01, 0.1)
)
```

``` r
forest_tuning <- tune_ci_forest(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = tuning_data,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  type = c("CI", "CIg", "CIc", "L"),
  control_grid = forest_tune_grid,
  v = 5L,
  strata = "deadu5_num",
  seed = 20260508,
  prediction_name = "forest_risk",
  refit = TRUE
)
```

``` r
forest_tuning_table <- readme_tuning_table(
  forest_tuning$summary,
  columns = c(
    "type",
    "ntree",
    "mtry",
    "maxdepth",
    "mean_score",
    "sd_score",
    "mean_terminal_nodes"
  ),
  labels = c(
    "type",
    "ntree",
    "mtry",
    "maxdepth",
    "mean_validation_gain",
    "sd_validation_gain",
    "mean_terminal_nodes"
  )
)

knitr::kable(
  forest_tuning_table,
  digits = 3,
  caption = "Cross-validated greedy forest tuning results ranked by validation gain"
)
```

| type | ntree | mtry | maxdepth | mean_validation_gain | sd_validation_gain | mean_terminal_nodes |
|:---|---:|---:|---:|---:|---:|---:|
| L | 10 | 2 | 3 | 1.646 | 1.929 | 3.6 |
| L | 50 | 1 | 4 | 1.632 | 1.860 | 4.6 |
| L | 10 | 2 | 5 | 1.622 | 1.918 | 6.2 |
| L | 50 | 2 | 4 | 1.620 | 1.916 | 5.0 |
| L | 50 | 2 | 4 | 1.610 | 1.952 | 4.2 |
| L | 50 | 2 | 3 | 1.599 | 1.876 | 4.4 |
| L | 50 | 2 | 6 | 1.597 | 1.796 | 2.8 |
| L | 10 | 2 | 6 | 1.593 | 1.971 | 3.0 |
| L | 10 | 2 | 6 | 1.585 | 1.975 | 4.2 |
| L | 10 | 1 | 4 | 1.584 | 1.946 | 6.0 |
| L | 10 | 1 | 5 | 1.570 | 1.934 | 3.8 |
| L | 50 | 2 | 5 | 1.548 | 2.059 | 4.2 |
| L | 10 | 2 | 3 | 1.546 | 1.962 | 4.6 |
| L | 50 | 2 | 3 | 1.540 | 1.961 | 4.4 |
| L | 50 | 2 | 6 | 1.537 | 2.001 | 4.4 |
| L | 10 | 2 | 5 | 1.535 | 1.954 | 4.4 |
| L | 50 | 1 | 6 | 1.528 | 1.997 | 3.2 |
| L | 50 | 1 | 6 | 1.526 | 1.990 | 3.8 |
| L | 50 | 2 | 5 | 1.518 | 2.038 | 3.0 |
| L | 50 | 2 | 3 | 1.510 | 2.046 | 2.8 |
| L | 50 | 2 | 4 | 1.501 | 2.044 | 3.0 |
| L | 50 | 1 | 3 | 1.500 | 1.960 | 3.2 |
| L | 10 | 1 | 6 | 1.499 | 1.798 | 3.2 |
| L | 10 | 2 | 6 | 1.495 | 2.041 | 4.6 |
| L | 50 | 1 | 5 | 1.494 | 2.026 | 3.2 |
| L | 10 | 1 | 5 | 1.493 | 1.762 | 5.4 |
| L | 10 | 1 | 6 | 1.485 | 2.001 | 6.2 |
| L | 50 | 2 | 6 | 1.477 | 1.783 | 4.4 |
| L | 10 | 2 | 4 | 1.476 | 1.991 | 3.0 |
| L | 50 | 2 | 4 | 1.470 | 2.073 | 2.8 |
| L | 50 | 1 | 5 | 1.468 | 2.103 | 3.4 |
| L | 10 | 2 | 5 | 1.467 | 2.067 | 2.6 |
| L | 50 | 2 | 6 | 1.464 | 1.995 | 3.0 |
| L | 50 | 2 | 3 | 1.463 | 2.062 | 3.0 |
| L | 50 | 1 | 4 | 1.455 | 2.114 | 3.4 |
| L | 50 | 1 | 3 | 1.455 | 2.122 | 3.6 |
| L | 10 | 2 | 4 | 1.448 | 1.815 | 3.6 |
| L | 10 | 1 | 3 | 1.438 | 1.843 | 5.0 |
| L | 10 | 2 | 6 | 1.430 | 1.687 | 2.8 |
| L | 10 | 1 | 6 | 1.423 | 1.889 | 4.2 |
| L | 50 | 1 | 3 | 1.406 | 2.118 | 5.0 |
| L | 10 | 1 | 5 | 1.406 | 2.064 | 3.6 |
| L | 50 | 1 | 5 | 1.336 | 1.926 | 5.8 |
| L | 10 | 1 | 3 | 1.322 | 2.105 | 3.6 |
| L | 50 | 1 | 6 | 1.310 | 2.288 | 5.0 |
| L | 10 | 1 | 4 | 1.289 | 1.680 | 2.8 |
| L | 10 | 2 | 3 | 1.285 | 1.921 | 5.2 |
| L | 10 | 1 | 4 | 1.280 | 1.841 | 6.0 |
| L | 50 | 2 | 5 | 1.279 | 2.322 | 2.6 |
| L | 50 | 1 | 5 | 1.277 | 2.271 | 6.0 |
| L | 50 | 1 | 3 | 1.242 | 2.261 | 5.8 |
| L | 10 | 1 | 3 | 1.235 | 2.079 | 3.2 |
| L | 50 | 2 | 5 | 1.233 | 2.367 | 3.8 |
| L | 10 | 2 | 4 | 1.231 | 1.774 | 4.2 |
| L | 50 | 1 | 4 | 1.226 | 2.324 | 5.8 |
| L | 10 | 1 | 6 | 1.219 | 1.728 | 3.0 |
| L | 10 | 1 | 5 | 1.174 | 2.403 | 3.2 |
| L | 50 | 1 | 6 | 1.069 | 2.358 | 5.4 |
| L | 10 | 2 | 4 | 0.905 | 2.969 | 4.6 |
| L | 10 | 2 | 3 | 0.877 | 2.642 | 2.8 |
| L | 10 | 2 | 5 | 0.846 | 1.302 | 3.4 |
| L | 50 | 1 | 4 | 0.817 | 3.100 | 2.8 |
| L | 10 | 1 | 4 | 0.699 | 1.322 | 2.6 |
| CI | 10 | 2 | 5 | 0.124 | 0.055 | 5.0 |
| CI | 50 | 2 | 3 | 0.084 | 0.095 | 4.6 |
| CI | 10 | 2 | 3 | 0.078 | 0.094 | 2.8 |
| CI | 50 | 1 | 5 | 0.078 | 0.112 | 5.2 |
| CI | 10 | 2 | 3 | 0.076 | 0.109 | 4.6 |
| CI | 50 | 1 | 3 | 0.056 | 0.076 | 5.4 |
| CI | 10 | 1 | 3 | 0.055 | 0.135 | 4.8 |
| CI | 50 | 2 | 4 | 0.055 | 0.048 | 5.4 |
| CI | 10 | 2 | 6 | 0.051 | 0.106 | 5.2 |
| CI | 50 | 2 | 4 | 0.046 | 0.078 | 4.6 |
| CI | 10 | 1 | 3 | 0.045 | 0.062 | 4.8 |
| CI | 50 | 2 | 5 | 0.044 | 0.072 | 4.4 |
| CI | 50 | 1 | 4 | 0.040 | 0.045 | 2.8 |
| CI | 10 | 1 | 4 | 0.039 | 0.096 | 5.2 |
| CI | 10 | 1 | 5 | 0.036 | 0.128 | 3.8 |
| CI | 50 | 2 | 6 | 0.034 | 0.041 | 2.2 |
| CI | 10 | 2 | 4 | 0.033 | 0.078 | 5.2 |
| CI | 10 | 2 | 6 | 0.031 | 0.028 | 2.6 |
| CI | 10 | 2 | 4 | 0.031 | 0.035 | 3.0 |
| CI | 50 | 2 | 4 | 0.030 | 0.029 | 2.2 |
| CI | 10 | 1 | 4 | 0.029 | 0.040 | 2.4 |
| CI | 50 | 2 | 5 | 0.029 | 0.019 | 2.2 |
| CI | 50 | 2 | 4 | 0.028 | 0.094 | 3.0 |
| CI | 50 | 1 | 5 | 0.027 | 0.046 | 2.6 |
| CI | 10 | 2 | 3 | 0.025 | 0.037 | 2.4 |
| CIc | 10 | 2 | 4 | 0.023 | 0.018 | 5.8 |
| CI | 10 | 1 | 3 | 0.023 | 0.066 | 2.6 |
| CI | 10 | 1 | 4 | 0.022 | 0.080 | 2.8 |
| CI | 10 | 2 | 4 | 0.022 | 0.051 | 2.8 |
| CI | 50 | 1 | 4 | 0.021 | 0.081 | 2.6 |
| CI | 10 | 1 | 5 | 0.021 | 0.057 | 3.0 |
| CI | 50 | 2 | 6 | 0.019 | 0.031 | 2.4 |
| CI | 10 | 2 | 5 | 0.019 | 0.038 | 2.8 |
| CI | 10 | 2 | 5 | 0.018 | 0.038 | 4.6 |
| CI | 10 | 2 | 6 | 0.017 | 0.139 | 5.0 |
| CIc | 50 | 2 | 4 | 0.015 | 0.014 | 5.6 |
| CIc | 50 | 2 | 3 | 0.015 | 0.018 | 5.2 |
| CI | 10 | 1 | 6 | 0.015 | 0.027 | 2.8 |
| CIc | 50 | 1 | 6 | 0.015 | 0.015 | 5.6 |
| CIc | 10 | 1 | 4 | 0.015 | 0.014 | 5.2 |
| CIc | 50 | 1 | 4 | 0.014 | 0.020 | 6.0 |
| CIc | 10 | 2 | 4 | 0.014 | 0.024 | 6.6 |
| CI | 50 | 2 | 3 | 0.014 | 0.136 | 5.0 |
| CIc | 50 | 1 | 3 | 0.014 | 0.017 | 5.2 |
| CIc | 50 | 2 | 3 | 0.014 | 0.012 | 4.6 |
| CIc | 50 | 2 | 4 | 0.014 | 0.019 | 5.8 |
| CIc | 50 | 1 | 3 | 0.013 | 0.013 | 5.4 |
| CIc | 50 | 2 | 6 | 0.013 | 0.018 | 5.4 |
| CI | 10 | 1 | 6 | 0.013 | 0.083 | 5.4 |
| CI | 50 | 2 | 3 | 0.012 | 0.018 | 2.2 |
| CIc | 50 | 1 | 5 | 0.011 | 0.020 | 5.8 |
| CIc | 10 | 2 | 4 | 0.011 | 0.025 | 3.4 |
| CIc | 50 | 1 | 4 | 0.011 | 0.017 | 5.2 |
| CIc | 50 | 2 | 6 | 0.011 | 0.025 | 2.8 |
| CIc | 10 | 1 | 3 | 0.011 | 0.022 | 3.0 |
| CIc | 10 | 1 | 6 | 0.010 | 0.015 | 5.8 |
| CI | 50 | 1 | 4 | 0.010 | 0.079 | 6.4 |
| CIc | 10 | 1 | 5 | 0.010 | 0.014 | 6.0 |
| CIc | 10 | 1 | 3 | 0.010 | 0.021 | 4.6 |
| CI | 10 | 1 | 5 | 0.010 | 0.115 | 4.4 |
| CI | 50 | 1 | 4 | 0.010 | 0.092 | 6.0 |
| CI | 50 | 1 | 6 | 0.009 | 0.048 | 5.0 |
| CI | 50 | 2 | 3 | 0.009 | 0.024 | 2.0 |
| CI | 50 | 1 | 3 | 0.009 | 0.019 | 2.4 |
| CIc | 10 | 2 | 3 | 0.009 | 0.018 | 5.0 |
| CIc | 10 | 2 | 4 | 0.009 | 0.017 | 3.2 |
| CIc | 50 | 1 | 5 | 0.008 | 0.019 | 6.2 |
| CI | 50 | 1 | 3 | 0.008 | 0.097 | 3.0 |
| CIc | 50 | 1 | 6 | 0.008 | 0.010 | 6.2 |
| CIc | 10 | 1 | 3 | 0.008 | 0.014 | 5.0 |
| CIc | 10 | 2 | 6 | 0.007 | 0.027 | 6.0 |
| CIc | 50 | 2 | 5 | 0.007 | 0.021 | 5.4 |
| CIc | 10 | 1 | 4 | 0.006 | 0.008 | 5.6 |
| CIc | 10 | 1 | 6 | 0.006 | 0.030 | 3.6 |
| CIc | 10 | 2 | 5 | 0.005 | 0.023 | 6.2 |
| CI | 10 | 1 | 6 | 0.005 | 0.169 | 4.8 |
| CIg | 10 | 2 | 4 | 0.005 | 0.004 | 6.6 |
| CIc | 50 | 1 | 4 | 0.004 | 0.027 | 3.4 |
| CIc | 10 | 2 | 3 | 0.004 | 0.011 | 5.2 |
| CIg | 50 | 2 | 3 | 0.004 | 0.004 | 5.4 |
| CIg | 50 | 1 | 5 | 0.003 | 0.004 | 6.8 |
| CIc | 10 | 1 | 6 | 0.003 | 0.020 | 5.6 |
| CIg | 50 | 1 | 6 | 0.003 | 0.005 | 6.8 |
| CIg | 50 | 1 | 4 | 0.003 | 0.003 | 6.6 |
| CIc | 10 | 1 | 5 | 0.003 | 0.027 | 3.4 |
| CIg | 50 | 1 | 3 | 0.003 | 0.005 | 6.2 |
| CIg | 50 | 1 | 4 | 0.003 | 0.003 | 7.2 |
| CIg | 50 | 2 | 3 | 0.002 | 0.003 | 5.4 |
| CIg | 10 | 1 | 4 | 0.002 | 0.006 | 3.2 |
| CIg | 10 | 2 | 6 | 0.002 | 0.005 | 6.8 |
| CIc | 50 | 1 | 3 | 0.002 | 0.016 | 3.0 |
| CIg | 10 | 1 | 3 | 0.002 | 0.005 | 2.8 |
| CIg | 10 | 1 | 3 | 0.002 | 0.003 | 5.6 |
| CIc | 10 | 1 | 5 | 0.002 | 0.019 | 3.0 |
| CIg | 10 | 2 | 3 | 0.002 | 0.003 | 5.8 |
| CIg | 50 | 2 | 6 | 0.002 | 0.006 | 6.4 |
| CIg | 50 | 2 | 4 | 0.002 | 0.004 | 6.6 |
| CI | 50 | 2 | 5 | 0.002 | 0.018 | 2.4 |
| CIc | 10 | 2 | 5 | 0.002 | 0.016 | 5.4 |
| CIg | 50 | 1 | 5 | 0.002 | 0.006 | 3.6 |
| CIc | 10 | 2 | 5 | 0.002 | 0.021 | 3.2 |
| CIg | 50 | 1 | 3 | 0.002 | 0.005 | 3.2 |
| CIg | 50 | 1 | 5 | 0.002 | 0.004 | 6.4 |
| CIc | 50 | 2 | 5 | 0.002 | 0.016 | 6.4 |
| CIg | 50 | 1 | 3 | 0.001 | 0.007 | 5.8 |
| CIg | 10 | 2 | 5 | 0.001 | 0.004 | 6.8 |
| CIg | 50 | 2 | 5 | 0.001 | 0.001 | 6.4 |
| CIg | 10 | 1 | 6 | 0.001 | 0.005 | 5.8 |
| CIc | 10 | 1 | 4 | 0.001 | 0.018 | 3.2 |
| CIg | 10 | 2 | 5 | 0.001 | 0.007 | 3.0 |
| CIg | 50 | 2 | 6 | 0.001 | 0.005 | 3.0 |
| CIc | 50 | 1 | 5 | 0.001 | 0.023 | 3.0 |
| CIg | 10 | 1 | 6 | 0.001 | 0.007 | 3.8 |
| CIg | 10 | 2 | 3 | 0.001 | 0.008 | 3.0 |
| CI | 50 | 2 | 6 | 0.001 | 0.111 | 4.8 |
| CIg | 10 | 1 | 6 | 0.001 | 0.007 | 3.8 |
| CIg | 10 | 1 | 4 | 0.001 | 0.003 | 6.8 |
| CIc | 10 | 2 | 6 | 0.001 | 0.014 | 5.8 |
| CIc | 10 | 2 | 3 | 0.001 | 0.017 | 3.0 |
| CIg | 10 | 2 | 3 | 0.001 | 0.003 | 2.6 |
| CIg | 50 | 2 | 4 | 0.001 | 0.005 | 3.2 |
| CIg | 10 | 1 | 6 | 0.000 | 0.005 | 5.4 |
| CIg | 50 | 1 | 3 | 0.000 | 0.005 | 3.4 |
| CIg | 50 | 2 | 6 | 0.000 | 0.004 | 6.8 |
| CIg | 50 | 1 | 5 | 0.000 | 0.006 | 3.2 |
| CIg | 10 | 1 | 3 | 0.000 | 0.006 | 3.6 |
| CIg | 50 | 2 | 5 | 0.000 | 0.005 | 3.8 |
| CI | 50 | 1 | 6 | 0.000 | 0.112 | 5.8 |
| CIg | 10 | 2 | 4 | 0.000 | 0.003 | 4.2 |
| CIg | 50 | 2 | 3 | 0.000 | 0.006 | 3.2 |
| CIg | 10 | 1 | 4 | 0.000 | 0.005 | 3.6 |
| CIg | 50 | 1 | 4 | 0.000 | 0.006 | 3.8 |
| CIg | 10 | 2 | 5 | 0.000 | 0.003 | 6.6 |
| CIg | 50 | 1 | 6 | 0.000 | 0.007 | 7.4 |
| CIg | 50 | 1 | 4 | 0.000 | 0.007 | 4.0 |
| CIg | 10 | 2 | 6 | 0.000 | 0.005 | 3.0 |
| CIg | 10 | 2 | 3 | 0.000 | 0.005 | 5.2 |
| CIg | 50 | 2 | 4 | 0.000 | 0.007 | 3.2 |
| CIg | 10 | 1 | 5 | 0.000 | 0.003 | 6.6 |
| CIc | 50 | 1 | 6 | 0.000 | 0.018 | 3.8 |
| CIg | 10 | 2 | 4 | 0.000 | 0.007 | 4.0 |
| CIc | 50 | 1 | 6 | 0.000 | 0.024 | 2.8 |
| CIg | 10 | 2 | 5 | 0.000 | 0.005 | 3.2 |
| CIg | 10 | 2 | 4 | 0.000 | 0.005 | 5.8 |
| CIg | 10 | 2 | 6 | 0.000 | 0.002 | 7.6 |
| CIg | 10 | 1 | 5 | 0.000 | 0.006 | 3.2 |
| CIg | 10 | 1 | 3 | -0.001 | 0.007 | 5.8 |
| CIg | 10 | 2 | 6 | -0.001 | 0.005 | 3.2 |
| CIg | 10 | 1 | 5 | -0.001 | 0.004 | 3.4 |
| CIg | 50 | 2 | 3 | -0.001 | 0.005 | 3.2 |
| CIg | 50 | 2 | 5 | -0.001 | 0.005 | 6.6 |
| CIg | 50 | 1 | 6 | -0.001 | 0.006 | 3.2 |
| CIg | 50 | 2 | 4 | -0.001 | 0.004 | 6.6 |
| CIc | 50 | 2 | 3 | -0.001 | 0.019 | 2.6 |
| CIc | 10 | 1 | 3 | -0.001 | 0.025 | 3.6 |
| CIc | 50 | 2 | 4 | -0.001 | 0.025 | 3.4 |
| CIc | 10 | 2 | 6 | -0.002 | 0.024 | 3.6 |
| CIc | 10 | 1 | 6 | -0.002 | 0.020 | 3.2 |
| CIg | 10 | 1 | 5 | -0.002 | 0.005 | 6.8 |
| CIc | 10 | 2 | 3 | -0.002 | 0.022 | 2.6 |
| CIg | 10 | 1 | 4 | -0.002 | 0.005 | 6.6 |
| CI | 10 | 1 | 3 | -0.002 | 0.061 | 2.6 |
| CIc | 10 | 1 | 5 | -0.002 | 0.023 | 5.6 |
| CIg | 50 | 2 | 6 | -0.003 | 0.008 | 3.2 |
| CIg | 50 | 1 | 6 | -0.003 | 0.007 | 4.2 |
| CIc | 50 | 2 | 4 | -0.003 | 0.024 | 2.8 |
| CIg | 50 | 2 | 5 | -0.003 | 0.007 | 3.6 |
| CIc | 50 | 2 | 3 | -0.003 | 0.018 | 2.8 |
| CI | 10 | 1 | 5 | -0.003 | 0.067 | 5.0 |
| CIc | 50 | 2 | 5 | -0.003 | 0.021 | 2.8 |
| CIc | 50 | 2 | 5 | -0.003 | 0.021 | 2.8 |
| CIc | 50 | 2 | 6 | -0.004 | 0.018 | 2.6 |
| CIc | 50 | 2 | 6 | -0.004 | 0.017 | 6.2 |
| CIc | 50 | 1 | 4 | -0.005 | 0.024 | 3.2 |
| CIc | 10 | 1 | 4 | -0.005 | 0.017 | 3.2 |
| CIc | 50 | 1 | 5 | -0.005 | 0.019 | 3.6 |
| CIc | 10 | 2 | 6 | -0.005 | 0.027 | 2.8 |
| CI | 10 | 2 | 4 | -0.007 | 0.056 | 4.6 |
| CIc | 50 | 1 | 3 | -0.008 | 0.033 | 3.2 |
| CI | 50 | 1 | 5 | -0.009 | 0.065 | 2.6 |
| CIc | 10 | 2 | 5 | -0.010 | 0.014 | 3.0 |
| CI | 50 | 1 | 3 | -0.012 | 0.131 | 4.8 |
| CI | 10 | 2 | 6 | -0.012 | 0.089 | 3.0 |
| CI | 10 | 1 | 4 | -0.016 | 0.106 | 6.4 |
| CI | 50 | 1 | 6 | -0.017 | 0.049 | 2.8 |
| CI | 50 | 1 | 6 | -0.018 | 0.111 | 2.6 |
| CI | 10 | 2 | 5 | -0.020 | 0.097 | 2.6 |
| CI | 10 | 2 | 3 | -0.021 | 0.063 | 4.2 |
| CI | 50 | 2 | 5 | -0.024 | 0.114 | 4.4 |
| CI | 50 | 2 | 6 | -0.025 | 0.070 | 4.6 |
| CI | 50 | 1 | 5 | -0.065 | 0.095 | 6.2 |
| CI | 10 | 1 | 6 | -0.089 | 0.120 | 3.4 |
| L | 10 | 1 | 3 | -2.605 | 10.530 | 5.8 |

Cross-validated greedy forest tuning results ranked by validation gain

``` r
best_tuned_forest <- forest_tuning$best_fit
forest_surrogate_data <- forest_tuning$best_surrogate_data
```

``` r
forest_surrogate_fit <- forest_tuning$best_surrogate
```

``` r
readme_tree_plot(
  fit = forest_surrogate_fit,
  data = forest_surrogate_data,
  outcome_name = "forest_risk",
  outcome_label = "Predicted risk"
)
```

<img src="man/figures/README-forest-surrogate-plot-1.png" alt="A surrogate tree summarizing the best tuned concentration-index forest." width="100%" />
