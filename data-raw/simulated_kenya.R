set.seed(20260329)

n <- 20043L

region_labels <- c(
    "1" = "Mombasa",
    "2" = "Kwale",
    "3" = "Kilifi",
    "4" = "Tana River",
    "5" = "Lamu",
    "6" = "Taita Taveta",
    "7" = "Garissa",
    "8" = "Wajir",
    "9" = "Mandera",
    "10" = "Marsabit",
    "11" = "Isiolo",
    "12" = "Meru",
    "13" = "Tharaka-Nithi",
    "14" = "Embu",
    "15" = "Kitui",
    "16" = "Machakos",
    "17" = "Makueni",
    "18" = "Nyandarua",
    "19" = "Nyeri",
    "20" = "Kirinyaga",
    "21" = "Murang'a",
    "22" = "Kiambu",
    "23" = "Turkana",
    "24" = "West Pokot",
    "25" = "Samburu",
    "26" = "Trans Nzoia",
    "27" = "Uasin Gishu",
    "28" = "Elgeyo-Marakwet",
    "29" = "Nandi",
    "30" = "Baringo",
    "31" = "Laikipia",
    "32" = "Nakuru",
    "33" = "Narok",
    "34" = "Kajiado",
    "35" = "Kericho",
    "36" = "Bomet",
    "37" = "Kakamega",
    "38" = "Vihiga",
    "39" = "Bungoma",
    "40" = "Busia",
    "41" = "Siaya",
    "42" = "Kisumu",
    "43" = "Homa Bay",
    "44" = "Migori",
    "45" = "Kisii",
    "46" = "Nyamira",
    "47" = "Nairobi"
)

draw_factor <- function(counts) {
    values <- rep.int(names(counts), counts)
    factor(sample(values, length(values)), levels = names(counts))
}

county_prob <- c(
    Mombasa = 0.024,
    Kwale = 0.018,
    Kilifi = 0.028,
    `Tana River` = 0.010,
    Lamu = 0.004,
    `Taita Taveta` = 0.011,
    Garissa = 0.014,
    Wajir = 0.013,
    Mandera = 0.014,
    Marsabit = 0.011,
    Isiolo = 0.006,
    Meru = 0.032,
    `Tharaka-Nithi` = 0.009,
    Embu = 0.011,
    Kitui = 0.025,
    Machakos = 0.031,
    Makueni = 0.021,
    Nyandarua = 0.016,
    Nyeri = 0.016,
    Kirinyaga = 0.012,
    `Murang'a` = 0.022,
    Kiambu = 0.058,
    Turkana = 0.024,
    `West Pokot` = 0.014,
    Samburu = 0.009,
    `Trans Nzoia` = 0.020,
    `Uasin Gishu` = 0.024,
    `Elgeyo-Marakwet` = 0.009,
    Nandi = 0.021,
    Baringo = 0.017,
    Laikipia = 0.012,
    Nakuru = 0.050,
    Narok = 0.022,
    Kajiado = 0.021,
    Kericho = 0.018,
    Bomet = 0.017,
    Kakamega = 0.045,
    Vihiga = 0.014,
    Bungoma = 0.040,
    Busia = 0.020,
    Siaya = 0.020,
    Kisumu = 0.026,
    `Homa Bay` = 0.023,
    Migori = 0.024,
    Kisii = 0.025,
    Nyamira = 0.014,
    Nairobi = 0.073
)
county_prob <- county_prob / sum(county_prob)

county_wealth_effect <- c(
    Mombasa = 0.20,
    Kwale = -0.10,
    Kilifi = -0.05,
    `Tana River` = -0.45,
    Lamu = 0.05,
    `Taita Taveta` = 0.05,
    Garissa = -0.35,
    Wajir = -0.55,
    Mandera = -0.60,
    Marsabit = -0.45,
    Isiolo = -0.20,
    Meru = 0.12,
    `Tharaka-Nithi` = 0.04,
    Embu = 0.08,
    Kitui = -0.08,
    Machakos = 0.10,
    Makueni = -0.03,
    Nyandarua = 0.14,
    Nyeri = 0.24,
    Kirinyaga = 0.20,
    `Murang'a` = 0.16,
    Kiambu = 0.38,
    Turkana = -0.52,
    `West Pokot` = -0.42,
    Samburu = -0.38,
    `Trans Nzoia` = 0.02,
    `Uasin Gishu` = 0.10,
    `Elgeyo-Marakwet` = 0.08,
    Nandi = 0.06,
    Baringo = -0.10,
    Laikipia = 0.18,
    Nakuru = 0.18,
    Narok = -0.02,
    Kajiado = 0.12,
    Kericho = 0.06,
    Bomet = -0.01,
    Kakamega = -0.03,
    Vihiga = -0.02,
    Bungoma = -0.06,
    Busia = -0.15,
    Siaya = -0.10,
    Kisumu = 0.05,
    `Homa Bay` = -0.22,
    Migori = -0.12,
    Kisii = 0.02,
    Nyamira = 0.00,
    Nairobi = 0.55
)

county_risk_effect <- c(
    Mombasa = -0.10,
    Kwale = 0.10,
    Kilifi = 0.08,
    `Tana River` = 0.30,
    Lamu = 0.04,
    `Taita Taveta` = -0.02,
    Garissa = 0.22,
    Wajir = 0.32,
    Mandera = 0.38,
    Marsabit = 0.22,
    Isiolo = 0.12,
    Meru = -0.04,
    `Tharaka-Nithi` = -0.02,
    Embu = -0.04,
    Kitui = 0.06,
    Machakos = -0.02,
    Makueni = 0.04,
    Nyandarua = -0.08,
    Nyeri = -0.10,
    Kirinyaga = -0.08,
    `Murang'a` = -0.06,
    Kiambu = -0.16,
    Turkana = 0.34,
    `West Pokot` = 0.26,
    Samburu = 0.18,
    `Trans Nzoia` = -0.02,
    `Uasin Gishu` = -0.04,
    `Elgeyo-Marakwet` = -0.02,
    Nandi = -0.03,
    Baringo = 0.06,
    Laikipia = -0.05,
    Nakuru = -0.06,
    Narok = 0.02,
    Kajiado = -0.03,
    Kericho = -0.02,
    Bomet = 0.00,
    Kakamega = 0.03,
    Vihiga = 0.02,
    Bungoma = 0.04,
    Busia = 0.10,
    Siaya = 0.08,
    Kisumu = 0.00,
    `Homa Bay` = 0.16,
    Migori = 0.10,
    Kisii = -0.02,
    Nyamira = -0.01,
    Nairobi = -0.20
)

reg <- factor(
    sample(
        unname(region_labels),
        size = n,
        replace = TRUE,
        prob = county_prob[unname(region_labels)]
    ),
    levels = unname(region_labels)
)

rural <- draw_factor(c(Urban = 4766L, Rural = 15277L))
ed <- draw_factor(c(`a education` = 15640L, `b no education` = 4403L))
ped <- draw_factor(c(`a education` = 18297L, `b no education` = 1746L))
mocc <- draw_factor(
    c(
        `a other` = 4229L,
        `c Household, unskilled manual, not working` = 5885L,
        `d Agriculture` = 9929L
    )
)
pocc <- draw_factor(
    c(
        `a other` = 7433L,
        `c Household, unskilled manual, not working` = 3545L,
        `d Agriculture` = 9065L
    )
)
birth <- draw_factor(
    c(
        `a first` = 3233L,
        `b 2-4 short` = 2560L,
        `c 2-4 long` = 6623L,
        `d 5+ short` = 2211L,
        `e 5+ long` = 5416L
    )
)
agemoth <- draw_factor(c(`a20 or more` = 19143L, `less than 20` = 900L))
male <- draw_factor(c(Female = 9859L, Male = 10184L))

wealth_breaks <- c(-1.48827, -0.65074, -0.40014, 0.08516, 3.69123)
wealth_score <-
    county_wealth_effect[as.character(reg)] +
    ifelse(rural == "Rural", -0.18, 0.22) +
    ifelse(ed == "a education", 0.16, -0.22) +
    ifelse(ped == "a education", 0.12, -0.18) +
    ifelse(mocc == "d Agriculture", -0.15, 0.06) +
    ifelse(pocc == "d Agriculture", -0.10, 0.04) +
    ifelse(birth %in% c("d 5+ short", "e 5+ long"), -0.06, 0.03) +
    rnorm(n, mean = 0, sd = 0.35)

wealth_u <- (rank(wealth_score, ties.method = "random") - 0.5) / n
wealth <- numeric(n)

seg1 <- wealth_u < 0.25
seg2 <- wealth_u >= 0.25 & wealth_u < 0.50
seg3 <- wealth_u >= 0.50 & wealth_u < 0.75
seg4 <- wealth_u >= 0.75

wealth[seg1] <- wealth_breaks[1] +
    (wealth_breaks[2] - wealth_breaks[1]) * ((wealth_u[seg1] / 0.25)^1.05)
wealth[seg2] <- wealth_breaks[2] +
    (wealth_breaks[3] - wealth_breaks[2]) *
        (((wealth_u[seg2] - 0.25) / 0.25)^1.00)
wealth[seg3] <- wealth_breaks[3] +
    (wealth_breaks[4] - wealth_breaks[3]) *
        (((wealth_u[seg3] - 0.50) / 0.25)^0.95)
wealth[seg4] <- wealth_breaks[4] +
    (wealth_breaks[5] - wealth_breaks[4]) *
        (((wealth_u[seg4] - 0.75) / 0.25)^1.85)

high_n <- 8599L
wealth_rank <- rank(wealth, ties.method = "random")
quint <- factor(
    ifelse(wealth_rank > (n - high_n), "a high", "b low"),
    levels = c("a high", "b low")
)

unskilled_score <- 0.9 * (mocc != "a other") +
    0.7 * (pocc != "a other") +
    0.9 * (ed == "b no education") +
    0.4 * (ped == "b no education") +
    0.2 * (rural == "Rural") +
    rnorm(n, mean = 0, sd = 0.6)
unskilled_rank <- rank(unskilled_score, ties.method = "random")
unskilled <- factor(
    ifelse(unskilled_rank > (n - 7427L), "Yes", "No"),
    levels = c("No", "Yes")
)

log_weight <- rnorm(
    n,
    mean = ifelse(rural == "Rural", -0.72, -0.38),
    sd = 0.92
)
sample_weight <- exp(log_weight)
sample_weight <- sample_weight * (0.895486 / mean(sample_weight))
sample_weight <- pmin(sample_weight, 7.945959)
sample_weight[sample_weight < 0.009932] <- 0.009932

case_weight <- round(sample_weight / sum(sample_weight) * 1000346)
case_weight[case_weight < 1] <- 1L
gap <- 1000346L - sum(case_weight)
if (gap != 0L) {
    if (gap > 0L) {
        idx <- order(sample_weight, decreasing = TRUE)
        take <- idx[seq_len(gap)]
        case_weight[take] <- case_weight[take] + 1L
    } else {
        idx <- order(sample_weight, decreasing = TRUE)
        idx <- idx[case_weight[idx] > 1L]
        take <- idx[seq_len(abs(gap))]
        case_weight[take] <- case_weight[take] - 1L
    }
}

linpred <- -3.1 +
    0.60 * scale(-wealth)[, 1] +
    0.35 * (rural == "Rural") +
    0.28 * (ed == "b no education") +
    0.18 * (ped == "b no education") +
    0.20 * (unskilled == "Yes") +
    0.22 * (birth %in% c("d 5+ short", "e 5+ long")) +
    0.18 * (agemoth == "less than 20") +
    0.06 * (male == "Male") +
    county_risk_effect[as.character(reg)]

target_prevalence <- 0.07254
intercept <- uniroot(
    function(a) mean(plogis(a + linpred)) - target_prevalence,
    interval = c(-10, 5)
)$root

deadu5_num <- rbinom(n, size = 1L, prob = plogis(intercept + linpred))

kenya <- data.frame(
    wealth = wealth,
    deadu5_num = deadu5_num,
    quint = quint,
    unskilled = unskilled,
    male = male,
    birth = birth,
    agemoth = agemoth,
    rural = rural,
    ed = ed,
    ped = ped,
    mocc = mocc,
    pocc = pocc,
    reg = reg,
    sample_weight = sample_weight,
    case_weight = as.integer(case_weight)
)

usethis::use_data(kenya, overwrite = TRUE)
checkhelper::use_data_doc(
    "kenya",
    description = "Simulated Kenya child survival dataset.",
    source = "Simulated in data-raw/simulated_kenya.R."
)

doc_file <- file.path("R", "doc_kenya.R")
doc_lines <- readLines(doc_file)
doc_lines[1] <- "#' Simulated Kenya Child Survival Dataset"
doc_lines[3] <- "#' Simulated Kenya child survival dataset."
format_idx <- grep("^#' @format", doc_lines)[1]
doc_lines <- append(
    doc_lines,
    values = c("#' @name kenya", "#' @docType data", "#'"),
    after = format_idx - 1L
)
doc_lines[length(doc_lines)] <- "NULL"
writeLines(doc_lines, doc_file)
