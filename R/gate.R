#' gate() Function
#'
#' This internal function gathers all gate polygons for a set of supplied gate types and their x and y coordinates.
#' 
#' @param data (Required) data.frame of any nodes. Must include at least 1 row where gate vector = "and", "or", or "top"
#' @param id (Default = `"id"`) string name of unique id vector in `data`. 
#' @param gate (Default = `"type"`) string name of vector containing gate types. Default is "type"
#' @param size (Default = 1) Default diameter of gate polygons.  
#' @param res (Default = 50) Default number of line segments spanning x axis.
#' @keywords fault tree gate polygon maker
#' @export

gate = function(data, group = "id", gate = "type", size = 1, res = 50){
  data %>%
    rename(group = !!sym(group), gate = !!sym(gate)) %>%
    filter(gate %in% c("and", "or", "top")) %>%
    group_by(group, gate) %>%
    summarize(get_gate(x,y, gate = gate, size = size, res = res))
}
