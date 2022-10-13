#' illustrate() Function
#'
#' This function takes a dataset of nodes and edges dataset from a fault tree, calculate a **tree** layout using `tidygraph` and `ggraph`, and then outputs ggplot-friendly data.frames of nodes and edges. 
#' 
#' @param nodes (Required) dataset of nodes, including an `id` field (or whatever is written in `node_key`)
#' @param edges (Required) dataset of edges, including `from` and `to` fields corresponding to the `id` of each node
#' @param type (Optional) By default, returns `"both"` the `"nodes"` and `"edges"` as items in a list. Alternatively, you can select just `"nodes"`, `"edges"`, or `"all"` to receive other formats of outputs.
#' @param node_key (Optional) By default, `node_key` = `"id'` from `nodes`
#' @param layout (Optional) By default, network layout is `"tree"`. `"dendrogram"` also works pretty well. See `ggraph` package for more layout options.
#' @keywords ggplot visualize network
#' @export

illustrate = function(nodes, edges, type = c("nodes", "edges", "both", "all"), node_key = "id", layout = "tree"){
  
  require(dplyr)
  require(tidygraph)
  require(ggraph)
  
  # get the tidygraph of our rooted fault tree
  gnodes = tbl_graph(
    nodes = nodes, edges = edges, 
    directed = TRUE, node_key = node_key) %>%
    # Get graph layout
    ggraph(layout = layout) %>%
    # Extract data
    with(data) %>%
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
      mutate(edge_id = 1:n())
    
    # Then simplify this into something readable by geom_line
    gedges = gpairs %>%
      # For each edge,
      group_by(edge_id) %>%
      summarize(
        # I'm stacking an identifier for direction atop each other
        direction = c("from", "to"),
        # I'm just stacking the from and to ids on top of each other, in that order
        id = c(from, to),
        # I'm also stacking the variables for x
        x = c(from_x, to_x),
        # and the variables for y
        y = c(from_y, to_y))

    # If the user requests edges
    if(type == "edges"){
      return(gedges)
      
      # alternatively, if the use requests BOTH
    }else if(type == "both"){
      # Bind the nodes and edges together as a list and return them!
      list(gnodes, gedges) %>% 
        set_names(nm = c("nodes", "edges")) %>%
        return()
    }else if(type == "all"){
      # Alternatively, if you select "all"
      # then return every version of the data
      list(gnodes, gedges, gpairs) %>% 
        setnames(nm = c("nodes", "edges", "pairwise")) %>%
        return()
    }
  }
}