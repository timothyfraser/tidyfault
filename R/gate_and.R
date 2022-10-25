#' gate_and() Function
#'
#' This function produces the top gate polygons for fault trees.
#' 
#' @param res (Required) A numeric value describing the resolution, or number of line segments spanning x-axis.
#' @keywords fault tree gate polygon maker
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
