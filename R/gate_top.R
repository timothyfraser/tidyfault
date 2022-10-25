#' gate_top() Function
#'
#' This function produces the top gate polygons for fault trees.
#' 
#' @param res (Required) A numeric value describing the resolution, or number of line segments spanning x-axis.
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