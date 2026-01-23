#' get_gate() Function
#'
#' This function produces the gate polygons for a set of supplied gate types and their x and y coordinates.
#' 
#' @param x (Required) Numeric value or vector representing the x coordinate(s) of the gate center in the layout.
#' @param y (Required) Numeric value or vector representing the y coordinate(s) of the gate center in the layout.
#' @param gate (Required) Character vector of gate type names. Must contain one or more of `"top"`, `"and"`, or `"or"`. If multiple values are provided, only the first unique value is used.
#' @param size (Default = 1) Numeric value controlling the diameter of the gate polygon. The shape is scaled proportionally around the center point. Default is `1`.
#' @param res (Default = 50) Numeric value controlling the resolution (number of line segments) used to draw curved gate shapes. Higher values create smoother curves. Default is `50`.
#' 
#' @return A data.frame (tibble) with columns `x` and `y` containing coordinate pairs that define the gate polygon shape. The coordinates are centered at the provided `(x, y)` position and scaled according to `size`. The shape depends on the gate type: AND gates have a rounded rectangle shape, OR gates have a curved shape, and top events have a rectangular shape.
#' 
#' @details This function is a wrapper that selects and generates the appropriate gate shape based on the gate type:
#'   \itemize{
#'     \item Determines the gate type from the `gate` parameter (uses first unique value if multiple provided)
#'     \item Calls the appropriate shape-generating function: `gate_and()` for AND gates, `gate_or()` for OR gates, or `gate_top()` for top events
#'     \item Scales and translates the base shape to match the specified `(x, y)` coordinates and `size` parameter
#'     \item Returns coordinates ready for use with `geom_polygon()` in ggplot2
#'   }
#'   The function handles coordinate transformation using `scales::rescale()` to position the gate shape correctly. Each gate type has a distinct visual representation following standard fault tree analysis conventions.
#' 
#' @seealso \code{\link{gate_and}} for AND gate shape generation, \code{\link{gate_or}} for OR gate shape generation, \code{\link{gate_top}} for top event shape generation
#' 
#' @keywords fault tree gate polygon maker
#' @importFrom dplyr tibble
#' @importFrom scales rescale
#' @export

get_gate = function(x,y, gate, size = 1, res = 50){
  # Let's make a wrapper function for rendering any gate
  # Get the first gate in your group
  # Your group should have only one gate in it
  gate = unique(gate)[1]
  
  if(gate == "or"){
    g = gate_or(size = size, res = res)
  }
  
  if(gate == "and"){
    g = gate_and(size = size, res = res)
  }
  
  if(gate == "top"){
    g = gate_top(size = size, res = res)
    # For top gate, preserve 2:1 aspect ratio (height:width)
    return(tibble(
      x = x + scales::rescale(g$x, to = c(-1.5*size, 1.5*size)),
      y = y + scales::rescale(g$y, to = c(-size, size))))
  }
  if(!gate %in% c("top", "and", "or")){
    return(NULL)
  }
  # Adjust shape to match point coordinates
  tibble(
    x = x + scales::rescale(g$x, to = c(-size, size)),
    y = y + scales::rescale(g$y, to = c(-size, size))) %>%
    return()
}