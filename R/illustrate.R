#' illustrate() Function
#'
#' This function takes a dataset of nodes and edges dataset from a fault tree, calculate a **tree** layout using `tidygraph` and `ggraph`, and then outputs ggplot-friendly data.frames of nodes and edges. 
#' 
#' @param nodes (Required) dataset of nodes, including an `id` field (or whatever is written in `node_key`)
#' @param edges (Required) dataset of edges, including `from` and `to` fields corresponding to the `id` of each node
#' @param type (Optional) Character string specifying output format. Default is `"both"`, which returns a list with `"nodes"`, `"edges"`, and `"gates"`. Other options: `"nodes"` returns only node coordinates, `"edges"` returns only edge coordinates, `"all"` returns nodes, edges, gates, and pairwise edge data.
#' @param node_key (Optional) Character string naming the column in `nodes` that contains unique node identifiers. Default is `"id"`.
#' @param layout (Optional) Character string specifying the graph layout algorithm. Default is `"tree"`. `"dendrogram"` also works well. See `ggraph::create_layout()` for more layout options (e.g., `"fr"`, `"kk"`, `"nicely"`).
#' @param size (Optional) Numeric value passed to `gate()` function for constructing polygons. Controls the diameter of gate shapes. Defaults to `0.25`.
#' @param res (Optional) Numeric value passed to `gate()` function for constructing polygons. Controls the number of line segments used to draw curved gate shapes. Defaults to `50`.
#' 
#' @return The return type depends on the `type` parameter:
#'   \itemize{
#'     \item For `type = "nodes"`: A data.frame with node coordinates (`x`, `y`) and all original columns from `nodes`
#'     \item For `type = "edges"`: A data.frame with edge coordinates formatted for `geom_line()`, containing columns `direction`, `id`, `x`, `y`, `edge_id`
#'     \item For `type = "both"` (default): A named list with three elements:
#'       \itemize{
#'         \item `nodes`: Node coordinates data.frame
#'         \item `edges`: Edge coordinates data.frame
#'         \item `gates`: Gate polygon coordinates data.frame with `x`, `y` columns for drawing gate shapes
#'       }
#'     \item For `type = "all"`: A named list with four elements: `nodes`, `edges`, `gates`, and `pairwise` (edge data with from/to coordinates)
#'   }
#' 
#' @details This function prepares fault tree data for visualization with ggplot2 by:
#'   \itemize{
#'     \item Creating a `tidygraph` object from nodes and edges
#'     \item Computing graph layout coordinates using `ggraph::create_layout()` with the specified layout algorithm
#'     \item Extracting node coordinates and preserving original node attributes
#'     \item Computing edge coordinates by joining node positions to edge endpoints
#'     \item Generating gate polygon shapes for AND, OR, and top event gates using the `gate()` function
#'   }
#'   The output is designed to work seamlessly with ggplot2. Nodes can be plotted with `geom_point()`, edges with `geom_line()`, and gates with `geom_polygon()`. The tree layout algorithm positions nodes hierarchically, making fault tree structure easy to visualize.
#' 
#' @seealso \code{\link{gate}} for generating gate polygons, \code{\link[tidygraph]{tbl_graph}} for creating graph objects, \code{\link[ggraph]{create_layout}} for layout algorithms
#' 
#' @keywords ggplot visualize network
#' @importFrom dplyr %>% select left_join mutate group_by reframe any_of n
#' @importFrom tidygraph tbl_graph
#' @importFrom ggraph create_layout
#' @importFrom purrr set_names
#' @importFrom rlang sym
#' @export

illustrate = function(nodes, edges, type = c("nodes", "edges", "both", "all"), node_key = "id", layout = "tree", size = 0.25, res = 50){
  
  require(dplyr)
  require(tidygraph)
  require(ggraph)
  
  # Match type argument
  type = match.arg(type)
  
  # get the tidygraph of our rooted fault tree
  g = tbl_graph(
    nodes = nodes, edges = edges, 
    directed = TRUE, node_key = node_key)
  
  # Get graph layout data
  gnodes = g %>%
    create_layout(layout = layout) %>%
    # Keep any columns that match x and y plus the names from nodes
    select(any_of(c("x", "y", names(nodes))))
  
  # If the user requests the nodes, return g
  if(type == "nodes"){
    return(gnodes)
  }else{
    
    gpairs = edges %>%
      # Join in coordinates for from id
      left_join(by = c("from" = node_key), 
                y = gnodes %>% select(!!sym(node_key), from_x = x, from_y = y)) %>%
      # Join in coordinates for to id
      left_join(by = c("to" = node_key),
                y = gnodes %>% select(!!sym(node_key), to_x = x, to_y = y))  %>%
      # give each edge an id
      mutate(edge_id = seq_len(n()))
    
    # Then simplify this into something readable by geom_line
    gedges = gpairs %>%
      # For each edge,
      group_by(edge_id) %>%
      reframe(
        # I'm stacking an identifier for direction atop each other
        direction = c("from", "to"),
        # I'm just stacking the from and to ids on top of each other, in that order
        id = c(from, to),
        # I'm also stacking the variables for x
        x = c(from_x, to_x),
        # and the variables for y
        y = c(from_y, to_y))

    # Extract the gate polygons for this network
    ggates = gnodes %>%
      gate(group = "id", gate = "type", size = size, res = res)
    
    # If the user requests edges
    if(type == "edges"){
      return(gedges)
      
      # alternatively, if the use requests BOTH
    }else if(type == "both"){
      # Bind the nodes and edges together as a list and return them!
      list(gnodes, gedges, ggates) %>% 
        purrr::set_names(nm = c("nodes", "edges", "gates")) %>%
        return()
    }else if(type == "all"){
      # Alternatively, if you select "all"
      # then return every version of the data
      list(gnodes, gedges, ggates, gpairs) %>% 
        purrr::set_names(nm = c("nodes", "edges", "pairwise", "gates")) %>%
        return()
    }
  }
}