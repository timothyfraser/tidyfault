#' gate_and() Function
#'
#' This function produces the AND gate polygons for fault trees.
#' 
#' @param size (Default = 2) Numeric value controlling the base size/diameter of the AND gate shape. The shape is scaled proportionally. Default is `2`.
#' @param res (Required) Numeric value describing the resolution, or number of line segments used to draw the curved portions of the gate shape. Higher values create smoother curves. Typically set to 50 or higher.
#' 
#' @return A data.frame (tibble) with columns `x` and `y` containing coordinate pairs that define an AND gate polygon shape. The coordinates are centered at the origin (0, 0) and represent a rounded rectangle shape characteristic of AND gates in fault tree diagrams. The shape is symmetric and can be translated and scaled as needed.
#' 
#' @details This function generates the geometric shape for AND gates in fault tree visualizations:
#'   \itemize{
#'     \item Creates a rounded rectangle shape with curved sides
#'     \item Uses square root functions to generate smooth curves on the left and right sides
#'     \item Centers the shape at the origin (0, 0) for easy translation
#'     \item The shape follows standard fault tree analysis conventions where AND gates are represented as rounded rectangles
#'   }
#'   The AND gate shape is generated using mathematical curves: the left side uses `sqrt(x)` and the right side uses `sqrt(size - x)` to create symmetric rounded edges. The shape is then centered vertically and horizontally.
#' 
#' @keywords fault tree gate polygon maker
#' @importFrom dplyr %>% tibble bind_rows mutate case_when
#' @export

gate_and = function(size = 2, res){
  
  # Let's write a function for making an and gate
  xmid = size/2
  
  bind_rows(
    # Draw something
    dplyr::tibble(
      x = seq(from = 0, to = size, length.out = 1),
      y = 0),
    dplyr::tibble(
      x = seq(from = size, to = 0, length.out = res),
      y = dplyr::case_when(
        # On left side,
        x < xmid ~  size*sqrt(x) * 2/3,
        # On right side...
        x >= xmid ~ size*sqrt(size - x) * 2/3 ))
  ) %>%
    mutate(x = x - xmid,
           y = y - max(y, na.rm = TRUE) / 2)
  
}
