# Reusable helpers for cleaner partykit tree plots.

.tree_default_name <- function(x) {
  gsub("_", " ", x, fixed = TRUE)
}

tree_pretty_var_name <- function(var_name, var_labels = NULL) {
  if (!is.null(var_labels) && var_name %in% names(var_labels)) {
    return(unname(var_labels[[var_name]]))
  }
  .tree_default_name(var_name)
}

tree_compact_split_label <- function(
    var_name,
    label,
    var_labels = NULL,
    max_items = 3L,
    max_chars = 24L,
    plural_overrides = NULL) {
  display_name <- tree_pretty_var_name(var_name, var_labels = var_labels)
  label <- gsub("\\s+", " ", trimws(label))

  if (!grepl(",", label, fixed = TRUE)) {
    return(paste(strwrap(paste0(display_name, "\n", label), width = max_chars), collapse = "\n"))
  }

  parts <- trimws(strsplit(label, ",", fixed = TRUE)[[1L]])
  if (length(parts) <= max_items && nchar(label) <= max_chars) {
    return(paste(strwrap(paste0(display_name, "\n", label), width = max_chars), collapse = "\n"))
  }

  shown <- paste(parts[seq_len(min(max_items, length(parts)))], collapse = ", ")
  bucket_label <- "levels"
  if (!is.null(plural_overrides) && display_name %in% names(plural_overrides)) {
    bucket_label <- plural_overrides[[display_name]]
  }

  paste0(display_name, "\n", length(parts), " ", bucket_label, "\n", shown, ", ...")
}

tree_edge_panel_compact <- function(
    obj,
    var_labels = NULL,
    digits = 3,
    fill = "white",
    justmin = 4,
    just = c("alternate", "increasing", "decreasing", "equal"),
    max_items = 3L,
    max_chars = 24L,
    plural_overrides = NULL) {
  meta <- obj$data

  justfun <- function(i, split_labels) {
    myjust <- if (mean(nchar(split_labels)) > justmin) {
      match.arg(just, c("alternate", "increasing", "decreasing", "equal"))
    } else {
      "equal"
    }

    k <- length(split_labels)
    rval <- switch(
      myjust,
      equal = rep.int(0, k),
      alternate = rep(c(0.5, -0.5), length.out = k),
      increasing = seq(from = -k / 2, to = k / 2, by = 1),
      decreasing = seq(from = k / 2, to = -k / 2, by = -1)
    )

    grid::unit(0.5, "npc") + grid::unit(rval[i], "lines")
  }

  function(node, i) {
    split_info <- partykit::character_split(partykit::split_node(node), meta, digits = digits)
    split_labels <- vapply(
      split_info$levels,
      tree_compact_split_label,
      character(1L),
      var_name = split_info$name,
      var_labels = var_labels,
      max_items = max_items,
      max_chars = max_chars,
      plural_overrides = plural_overrides
    )

    y <- justfun(i, split_labels)
    label <- split_labels[[i]]
    label_lines <- strsplit(label, "\n", fixed = TRUE)[[1L]]
    widest_line <- label_lines[which.max(nchar(label_lines))]

    grid::grid.rect(
      y = y,
      gp = grid::gpar(fill = fill, col = NA),
      width = grid::unit(1.05, "strwidth", widest_line),
      height = grid::unit(max(1L, length(label_lines)), "lines")
    )
    grid::grid.text(label, y = y, just = "center")
  }
}
class(tree_edge_panel_compact) <- "grapcon_generator"

tree_inner_panel_labeled <- function(
    obj,
    var_labels = NULL,
    id = FALSE,
    show_p = TRUE,
    gp = grid::gpar(),
    fill = "white") {
  meta <- obj$data

  extract_label <- function(node) {
    if (partykit::is.terminal(node)) {
      return(c("", ""))
    }

    split_info <- partykit::character_split(partykit::split_node(node), meta)
    varlab <- tree_pretty_var_name(split_info$name, var_labels = var_labels)

    plab <- ""
    if (show_p) {
      pvalue <- tryCatch(partykit::info_node(node)$p.value, error = function(e) NA_real_)
      plab <- if (is.na(pvalue)) {
        ""
      } else if (pvalue < 0.001) {
        "p < 0.001"
      } else {
        paste0("p = ", format(round(pvalue, 3), nsmall = 3))
      }
    }

    c(varlab, plab)
  }

  maxstr <- function(node) {
    lab <- extract_label(node)
    klab <- if (partykit::is.terminal(node)) {
      ""
    } else {
      unlist(lapply(partykit::kids_node(node), maxstr))
    }
    lab <- c(lab, klab)
    lab <- unlist(lapply(lab, function(x) strsplit(x, "\n", fixed = TRUE)))
    lab <- lab[which.max(nchar(lab))]
    if (length(lab) < 1L) "" else lab
  }

  nstr <- maxstr(partykit::node_party(obj))
  if (nchar(nstr) < 8L) {
    nstr <- "aaaaaaaa"
  }

  function(node) {
    lab <- extract_label(node)

    grid::pushViewport(grid::viewport(gp = gp))
    grid::pushViewport(
      grid::viewport(
        x = grid::unit(0.5, "npc"),
        y = grid::unit(0.5, "npc"),
        width = grid::unit(1.15, "strwidth", nstr),
        height = grid::unit(2.8, "lines")
      )
    )

    grid::grid.roundrect(r = grid::unit(0.15, "snpc"), gp = grid::gpar(fill = fill))
    grid::grid.text(lab[1L], y = grid::unit(if (lab[2L] != "") 1.7 else 1.4, "lines"))
    if (lab[2L] != "") {
      grid::grid.text(lab[2L], y = grid::unit(0.8, "lines"), gp = grid::gpar(cex = 0.85))
    }

    grid::upViewport(2)
  }
}
class(tree_inner_panel_labeled) <- "grapcon_generator"

tree_build_terminal_stats <- function(fit, data, stat_funs, node_col = "node_id") {
  if (!inherits(fit, "party")) {
    stop("`fit` must inherit from class `party`.", call. = FALSE)
  }
  if (!is.list(stat_funs) || length(stat_funs) == 0L || is.null(names(stat_funs))) {
    stop("`stat_funs` must be a named list of functions.", call. = FALSE)
  }

  data_dt <- data.table::as.data.table(data)
  data_dt[, (node_col) := predict(fit, newdata = data, type = "node")]

  stats_dt <- data_dt[
    ,
    lapply(stat_funs, function(fun) {
      value <- fun(.SD)
      if (length(value) != 1L) {
        stop("Each terminal-node summary function must return a single value.", call. = FALSE)
      }
      value
    }),
    by = node_col
  ]

  data.table::setorderv(stats_dt, node_col)
  stats_dt
}

tree_terminal_panel_stats <- function(
    obj,
    stats_dt,
    node_col = "node_id",
    stat_labels = NULL,
    stat_formatters = list(),
    gp = NULL,
    fill = "lightgray",
    width_lines = 10.5,
    height_lines = 3.2) {
  label_for <- function(col_name, value) {
    display_name <- if (!is.null(stat_labels) && col_name %in% names(stat_labels)) {
      stat_labels[[col_name]]
    } else {
      .tree_default_name(col_name)
    }

    value_chr <- if (col_name %in% names(stat_formatters)) {
      stat_formatters[[col_name]](value)
    } else if (is.numeric(value)) {
      format(round(value, 2), nsmall = 2)
    } else {
      as.character(value)
    }

    paste0(display_name, " = ", value_chr)
  }

  function(node) {
    node_stats <- stats_dt[get(node_col) == partykit::id_node(node)]

    label <- if (nrow(node_stats) == 0L) {
      c("terminal node")
    } else {
      stat_cols <- setdiff(names(node_stats), node_col)
      vapply(
        stat_cols,
        function(col_name) label_for(col_name, node_stats[[col_name]][[1L]]),
        character(1L)
      )
    }

    if (!is.null(gp)) {
      grid::pushViewport(grid::viewport(gp = gp))
    }

    grid::pushViewport(
      grid::viewport(
        x = grid::unit(0.5, "npc"),
        y = grid::unit(0.5, "npc"),
        just = c("center", "center"),
        width = grid::unit(width_lines, "lines"),
        height = grid::unit(height_lines, "lines")
      )
    )

    grid::grid.rect(gp = grid::gpar(fill = fill))
    for (i in seq_along(label)) {
      grid::grid.text(
        label[i],
        x = grid::unit(0.08, "npc"),
        y = grid::unit(length(label) - i + 0.5, "lines"),
        just = c("left", "center")
      )
    }

    if (is.null(gp)) {
      grid::upViewport()
    } else {
      grid::upViewport(2)
    }
  }
}
class(tree_terminal_panel_stats) <- "grapcon_generator"
