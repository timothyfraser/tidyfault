#' Plot a fault tree from illustrate() output
#'
#' Builds a ggplot of the fault tree using the nodes, edges, and gate polygons
#' returned by \code{\link{illustrate}}. Gate nodes (and, or, top) are drawn as
#' polygons with outlines that follow their shape; other nodes (e.g. basic
#' events) are drawn as circle polygons in the same data coordinate system, so
#' their size stays visually consistent relative to the gates. Nodes and gates
#' are labelled using the \code{event} column from \code{x$nodes}.
#'
#' @param x A list returned by \code{illustrate(..., type = "both")} or
#'   \code{illustrate(..., type = "all")}, with elements \code{nodes},
#'   \code{edges}, and \code{gates}.
#' @param type_col Character. Name of the column in \code{x$nodes} that holds
#'   node type (e.g. \code{"top"}, \code{"and"}, \code{"or"}, \code{"not"}).
#'   Default is \code{"type"}.
#' @param gate_types Character vector. Node types that are drawn as gate
#'   polygons. Default is \code{c("and", "or", "top")}.
#' @param edge_linewidth Numeric. Line width for edges. Default \code{1}.
#' @param gate_linewidth Numeric. Outline width for gate polygons. Default
#'   \code{0.8}.
#' @param gate_alpha Numeric. Fill opacity for gate polygons (0--1). Default
#'   \code{1}.
#' @param point_radius Numeric or \code{NULL}. Radius of basic-event circles in
#'   data units. If \code{NULL} (default), it is estimated from gate sizes (see
#'   \code{basic_radius_ratio}). Set explicitly (e.g. \code{0.1}) for full
#'   control when auto sizing is too small or too big.
#' @param point_n Integer. Number of vertices used to draw each basic-event
#'   circle polygon. Default \code{100}.
#' @param point_linewidth Numeric. Outline width for basic-event circles.
#'   Default \code{0.8}.
#' @param outline_colour Character. Colour for gate polygon and basic-event
#'   outlines. Default \code{"black"}.
#' @param gate_fill Named character vector of fill colours for gate types
#'   (\code{and}, \code{or}, \code{top}) and optionally \code{"basic event"} for
#'   leaf nodes. If \code{NULL} (default), the viridis discrete palette is
#'   used. When provided, \code{scale_fill_manual} is used with these values.
#' @param coord_fixed Logical. If \code{TRUE} (default), use equal aspect ratio so
#'   shapes are not stretched.
#' @param theme_void Logical. If \code{TRUE} (default), remove axes and panel.
#' @param expand Numeric. Fixed padding (in data units) added to the view limits
#'   on each side. Default \code{0.2}. For trees with few nodes, the function
#'   automatically tightens this to \code{0.1}.
#' @param normalize Logical. If \code{TRUE} (default), scale and center node,
#'   edge, and gate coordinates so the plot extent is standardized across
#'   different trees.
#' @param basic_radius_ratio Numeric. Used only when \code{point_radius = NULL}.
#'   Basic-event radius is set to this fraction of the median gate extent (each
#'   gate's extent is half the sum of its x and y span). Default \code{0.18}.
#'   Larger values give bigger circles; smaller values give smaller circles.
#' @param ... Ignored (for compatibility with generic \code{plot}).
#'
#' @return A \code{ggplot} object.
#'
#' @details To avoid pixelated output when saving, use \code{ggsave()} with an
#'   explicit \code{dpi} (e.g. \code{ggsave("plot.png", p, dpi = 300)}). Saving
#'   from the RStudio Plots pane or at a small size often produces
#'   low-resolution images.
#'
#'   Basic-event circle size when \code{point_radius = NULL}: the function
#'   takes each gate polygon's extent (half of x-span + y-span), then uses the
#'   \emph{median} of those extents times \code{basic_radius_ratio}. So circle
#'   size follows a typical gate size. It can still look too small or too big
#'   when gate sizes vary a lot (e.g. one large top gate and many small gates),
#'   or when the layout is very compact or very spread out. In those cases, set
#'   \code{point_radius} explicitly (e.g. \code{0.08} or \code{0.15}) or adjust
#'   \code{basic_radius_ratio}.
#'
#' @examples
#' data(it_security_nodes, it_security_edges, package = "tidyfault")
#' ill <- illustrate(nodes = it_security_nodes, edges = it_security_edges, type = "both")
#' p <- plot(ill)
#' \dontrun{ ggsave("fault_tree.png", p, dpi = 300) }
#'
#' @keywords ggplot visualize fault tree
#' @importFrom dplyr filter group_by left_join mutate select summarise bind_rows
#' @importFrom ggplot2 ggplot aes geom_line geom_polygon geom_text coord_fixed
#'   scale_fill_viridis_d scale_fill_manual theme_void
#' @export
plot <- function(x,
                 type_col = "type",
                 gate_types = c("and", "or", "top"),
                 edge_linewidth = 1,
                 gate_linewidth = 0.8,
                 gate_alpha = 1,
                 point_radius = NULL,
                 point_n = 100,
                 point_linewidth = 0.8,
                 outline_colour = "black",
                 gate_fill = NULL,
                 coord_fixed = TRUE,
                 theme_void = TRUE,
                 expand = 0.2,
                 normalize = TRUE,
                 basic_radius_ratio = 0.18,
                 ...) {

  if (!is.list(x) || !all(c("nodes", "edges", "gates") %in% names(x))) {
    stop(
      "x must be a list from illustrate(..., type = \"both\") or type = \"all\" ",
      "with elements nodes, edges, and gates."
    )
  }

  nodes <- x$nodes
  edges <- x$edges
  gates <- x$gates

  if (!type_col %in% names(nodes)) {
    stop("type_col \"", type_col, "\" not found in x$nodes.")
  }
  if (!"event" %in% names(nodes)) {
    stop("x$nodes must contain an \"event\" column (as returned by illustrate()).")
  }

  # Normalize all coordinates into a common box so plots are comparable
  if (normalize) {
    all_x <- c(nodes$x, gates$x)
    all_y <- c(nodes$y, gates$y)

    x_r <- diff(range(all_x, na.rm = TRUE))
    y_r <- diff(range(all_y, na.rm = TRUE))

    if (x_r < 1e-10) x_r <- 1
    if (y_r < 1e-10) y_r <- 1

    scale_fac <- 2 / max(x_r, y_r)
    x_mid <- mean(range(all_x, na.rm = TRUE))
    y_mid <- mean(range(all_y, na.rm = TRUE))

    nodes <- nodes %>%
      dplyr::mutate(
        x = (x - x_mid) * scale_fac,
        y = (y - y_mid) * scale_fac
      )

    edges <- edges %>%
      dplyr::mutate(
        x = (x - x_mid) * scale_fac,
        y = (y - y_mid) * scale_fac
      )

    gates <- gates %>%
      dplyr::mutate(
        x = (x - x_mid) * scale_fac,
        y = (y - y_mid) * scale_fac
      )
  }

  basic_nodes <- nodes %>%
    dplyr::filter(!.data[[type_col]] %in% gate_types) %>%
    dplyr::mutate(display_type = "basic event")

  n_nodes <- nrow(nodes)
  if (n_nodes <= 6 && expand > 0.1) expand <- 0.1

  # Default circle radius: median gate extent * ratio, clamped to avoid extremes
  if (is.null(point_radius)) {
    if (nrow(gates) > 0) {
      gate_extent <- gates %>%
        dplyr::group_by(.data$group) %>%
        dplyr::summarise(
          extent = (
            diff(range(.data$x, na.rm = TRUE)) +
            diff(range(.data$y, na.rm = TRUE))
          ) / 2,
          .groups = "drop"
        ) %>%
        dplyr::summarise(
          med = stats::median(.data$extent, na.rm = TRUE),
          .groups = "drop"
        )

      if (is.finite(gate_extent$med) && gate_extent$med > 1e-10) {
        point_radius <- gate_extent$med * basic_radius_ratio
        point_radius <- max(0.03, min(0.28, point_radius))
      } else {
        point_radius <- 0.05
      }
    } else {
      point_radius <- 0.05
    }
  }

  # Helper to build circle polygons in data coordinates
  make_circle_df <- function(cx, cy, r, n = 100, group_id = 1, fill_value = "basic event") {
    theta <- seq(0, 2 * pi, length.out = n)
    data.frame(
      x = cx + r * cos(theta),
      y = cy + r * sin(theta),
      group = group_id,
      gate = fill_value,
      stringsAsFactors = FALSE
    )
  }

  # Build basic-event circles as polygons
  basic_polygons <- NULL
  if (nrow(basic_nodes) > 0) {
    circle_list <- lapply(seq_len(nrow(basic_nodes)), function(i) {
      make_circle_df(
        cx = basic_nodes$x[i],
        cy = basic_nodes$y[i],
        r = point_radius,
        n = point_n,
        group_id = paste0("basic_", i),
        fill_value = basic_nodes$display_type[i]
      )
    })
    basic_polygons <- dplyr::bind_rows(circle_list)
  }

  p <- ggplot2::ggplot() +
    ggplot2::geom_line(
      data = edges,
      ggplot2::aes(x = .data$x, y = .data$y, group = .data$edge_id),
      linewidth = edge_linewidth
    ) +
    ggplot2::geom_polygon(
      data = gates,
      ggplot2::aes(
        x = .data$x,
        y = .data$y,
        group = .data$group,
        fill = .data$gate
      ),
      colour = outline_colour,
      linewidth = gate_linewidth,
      alpha = gate_alpha
    )

  if (!is.null(basic_polygons) && nrow(basic_polygons) > 0) {
    p <- p +
      ggplot2::geom_polygon(
        data = basic_polygons,
        ggplot2::aes(
          x = .data$x,
          y = .data$y,
          group = .data$group,
          fill = .data$gate
        ),
        colour = outline_colour,
        linewidth = point_linewidth
      )
  }

  # Gate labels at layout node position (same for all gate types; centroid varies by shape)
  if (nrow(gates) > 0 && "id" %in% names(nodes)) {
    gate_labels <- nodes %>%
      dplyr::filter(.data[[type_col]] %in% gate_types) %>%
      dplyr::select(.data$id, .data$event, .data$x, .data$y)
    if (nrow(gate_labels) > 0) {
      p <- p +
        ggplot2::geom_text(
          data = gate_labels,
          ggplot2::aes(x = .data$x, y = .data$y, label = .data$event),
          inherit.aes = FALSE,
          size = 3,
          colour = "white"
        )
    }
  }

  # Basic-event node labels (no box)
  if (nrow(basic_nodes) > 0) {
    p <- p +
      ggplot2::geom_text(
        data = basic_nodes,
        ggplot2::aes(x = .data$x, y = .data$y, label = .data$event),
        inherit.aes = FALSE,
        size = 2.5,
        colour = "black"
      )
  }

  # Stable legend ordering/labels for the gate fill categories
  fill_levels <- unique(c(as.character(gates$gate), basic_nodes$display_type))
  desired_breaks <- c("top", "and", "or", "basic event")
  plot_breaks <- desired_breaks[desired_breaks %in% fill_levels]
  label_map <- c(
    "top" = "Top Event",
    "and" = "And Gate",
    "or" = "Or Gate",
    "basic event" = "Basic Event"
  )
  plot_labels <- unname(label_map[plot_breaks])

  if (is.null(gate_fill)) {
    if (length(plot_breaks) > 0) {
      p <- p + ggplot2::scale_fill_viridis_d(
        option = "D",
        name = "Gate",
        na.value = "gray70",
        breaks = plot_breaks,
        labels = plot_labels
      )
    } else {
      p <- p + ggplot2::scale_fill_viridis_d(option = "D", name = "Gate", na.value = "gray70")
    }
  } else {
    if (length(plot_breaks) > 0) {
      p <- p + ggplot2::scale_fill_manual(
        values = gate_fill,
        name = "Gate",
        na.value = "gray70",
        breaks = plot_breaks,
        labels = plot_labels
      )
    } else {
      p <- p + ggplot2::scale_fill_manual(values = gate_fill, name = "Gate", na.value = "gray70")
    }
  }

  all_x <- c(nodes$x, gates$x)
  all_y <- c(nodes$y, gates$y)

  # Include basic-event polygon extents in limits
  if (!is.null(basic_polygons) && nrow(basic_polygons) > 0) {
    all_x <- c(all_x, basic_polygons$x)
    all_y <- c(all_y, basic_polygons$y)
  }

  xlim <- range(all_x, na.rm = TRUE) + c(-expand, expand)
  ylim <- range(all_y, na.rm = TRUE) + c(-expand, expand)

  if (coord_fixed) {
    p <- p + ggplot2::coord_fixed(xlim = xlim, ylim = ylim, expand = FALSE)
  } else {
    p <- p +
      ggplot2::scale_x_continuous(limits = xlim, expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = ylim, expand = c(0, 0))
  }

  if (theme_void) {
    p <- p + ggplot2::theme_void()
  }

  p <- p + ggplot2::theme(legend.position = "bottom")
  return(p)
}