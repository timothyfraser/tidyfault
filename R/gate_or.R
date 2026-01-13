#' gate_or() Function
#'
#' This function produces the OR gate polygons for fault trees.
#' 
#' @param size (Default = 2) Numeric value controlling the base size/diameter of the OR gate shape. The shape is scaled proportionally. Default is `2`.
#' @param res (Required) Numeric value describing the resolution, or number of line segments used to draw the curved portions of the gate shape. Higher values create smoother curves. Typically set to 50 or higher.
#' 
#' @return A data.frame (tibble) with columns `x` and `y` containing coordinate pairs that define an OR gate polygon shape. The coordinates are centered at the origin (0, 0) and represent a curved shape with a concave top and convex bottom, characteristic of OR gates in fault tree diagrams. The shape is symmetric and can be translated and scaled as needed.
#' 
#' @details This function generates the geometric shape for OR gates in fault tree visualizations:
#'   \itemize{
#'     \item Creates a curved shape with a concave top edge and convex bottom edge
#'     \item Uses square root functions with different scaling factors for the top and bottom curves
#'     \item Combines two curve segments (top and bottom) to form the complete gate shape
#'     \item Centers the shape at the origin (0, 0) for easy translation
#'     \item The shape follows standard fault tree analysis conventions where OR gates are represented as curved shapes
#'   }
#'   The OR gate shape uses different mathematical curves for the top (concave, using `1/size * sqrt(x)`) and bottom (convex, using `size * sqrt(x)`) to create the distinctive curved appearance. The two curve segments are combined and centered to form the final polygon.
#' 
#' @keywords fault tree gate polygon maker
#' @export

gate_or = function(size = 2, res){
  # Let's write a function for making an or gate
  
  xmid = size/2
  
  bind_rows(
    # Draw something
    dplyr::tibble(
      x = seq(from = 0, to = size, length.out = res),
      y = dplyr::case_when(
        # On left side,
        x < xmid ~ 1/(size)*sqrt(x) * 2/3,
        # On right side...
        x >= xmid ~ 1/(size)*sqrt(size - x)*2/3 )),
    dplyr::tibble(
      x = seq(from = size, to = 0, length.out = res),
      y = dplyr::case_when(
        # On left side,
        x < xmid ~  size*sqrt(x) * 2/3,
        # On right side...
        x >= xmid ~ size*sqrt(size - x) * 2/3))
  ) %>%
    # Offset, so middle is center
    mutate(x = x - xmid,
           y = y - max(y, na.rm = TRUE) / 2)
}
