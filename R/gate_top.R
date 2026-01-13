#' gate_top() Function
#'
#' This function produces the top event gate polygons for fault trees.
#' 
#' @param size (Default = 2) Numeric value controlling the size of the top event rectangle. The shape is a square with sides of length `size`. Default is `2`.
#' @param res (Required) Numeric value describing the resolution. For rectangular shapes, this parameter is accepted for consistency with other gate functions but does not affect the output (rectangles don't require curve resolution).
#' 
#' @return A data.frame (tibble) with columns `x` and `y` containing coordinate pairs that define a rectangular top event polygon shape. The coordinates are centered at the origin (0, 0) and represent a square shape characteristic of top events in fault tree diagrams. The shape can be translated and scaled as needed.
#' 
#' @details This function generates the geometric shape for top events in fault tree visualizations:
#'   \itemize{
#'     \item Creates a simple rectangular (square) shape
#'     \item Defines the rectangle using corner coordinates
#'     \item Centers the shape at the origin (0, 0) for easy translation
#'     \item The shape follows standard fault tree analysis conventions where top events are represented as rectangles
#'   }
#'   The top event shape is the simplest gate shape, consisting of a square defined by four corner points. The rectangle is created by specifying the four corners in order, then centering the shape by offsetting coordinates by `size/2` in both x and y directions. Unlike AND and OR gates, the top event shape does not use curved edges, so the `res` parameter is included for consistency but doesn't affect the output.
#' 
#' @keywords fault tree gate polygon maker
#' @export

gate_top = function(size = 2, res){
  
  dplyr::tibble(
    xmin = 0,
    xmax = size,
    ymin = 0,
    ymax = size
  ) %>%
    with(
      tribble(
        ~x,   ~y,
        xmin, ymin,
        xmin, ymax,
        xmin, ymax,
        xmax, ymax,
        xmax, ymax,
        xmax, ymin,
        xmax, ymin,
        xmin, ymin)
    ) %>%
    mutate(x = x - size/2,
           y = y - size/2) %>%
    dplyr::select(x, y)

}