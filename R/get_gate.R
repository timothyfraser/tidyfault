#' get_gate() Function
#'
#' This function produces the gate polygons for a set of supplied gate types and their x and y coordinates.
#' 
#' @param x (Required) x coordinate of gate in the layout.
#' @param y (Required) y coordinate of gate in the layout.
#' @param gate (Required) vector of gate names. Must be one of c("top", "and", "or")
#' @keywords fault tree gate polygon maker
#' @export

get_gate = function(x,y, gate, size = 1, res = 50){
  # Let's make a wrapper function for rendering any gate
  # Get the first gate in your group
  # Your group should have only one gate in it
  gate = unique(gate)[1]
  
  if(gate == "or"){
    g = gate_or(res = res)
  }
  
  if(gate == "and"){
    g = gate_and(res = res)
  }
  
  if(gate == "top"){
    g = gate_top(res = res)
  }
  if(!gate %in% c("top", "and", "or")){
    next()
  }
  # Adjust shape to match point coordinates
  tibble(
    x = x + scales::rescale(g$x, to = c(-size, size)),
    y = y + scales::rescale(g$y, to = c(-size, size))) %>%
    return()
}