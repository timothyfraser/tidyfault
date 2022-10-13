#' curate() Function
#'
#' This function *curates* a `data.frame` of N `gates` and the `sets` of events immediately linked to those gates.
#' 
#' @param nodes (Required) data.frame of N `nodes` (1 to N rows), with a unique `id` for each node, an `event` name describing the node (some events occur multiple times), and a `type` vector categorizing nodes as `"and"` | `"or"` gates, `"top"` nodes, or `"not"` a gate or top node (ie. a normal node)
#' @param edges (Required) data.frame of N `edges` (1 to N rows), showing ties between the `from` node's `id` to the `to` node's `id`.
#' @keywords fault tree
#' @export
#' @examples
#' 
#' # Load dependencies
#' library(tidyverse)
#' library(tidyfault)
#' library(QCA)
#' 
#' # Load example data into our environment
#' data("fakenodes")
#' data("fakeedges")
#' 
#' # Extract minimum cutset from fault tree data
#' curate(nodes = fakenodes, edges = fakeedges) %>%
#'    equate() %>%
#'    formulate() %>%
#'    calculate() %>%
#'    concentrate() %>% 
#'    tabulate()

curate = function(nodes, edges){
  
  # Let's write a function to identify the paths for each gate

  require(dplyr)
  require(tibble)
  require(stringr)
  
  # Take our list of nodes
  nodes %>%
    # Filter to just gates (meaning AND or OR operators)
    filter(type %in% c("and", "or")) %>%
    # And join in the names of the nodes that connect 'to' each gate
    # (where gates are represented by 'id' in nodes dataset, 
    # and 'from' in edges dataset)
    left_join(by = c("id" = "from"), y = edges)   %>%
    # Now that we have the unique ID 'id' for each 'to' node,
    # Let's join in the non-unique 'event' identifier for that 'to' node,
    left_join(by = c("to" = "id"), 
              # We'll name the 'event' identifier 'to_event', 
              # since it's the 'event' name for the 'to' nodes for that gate
              y = nodes %>% select(id, to_event = event)) %>%
    # Now, we only need 3 columns
    # we'll keep the original from event, and name it 'gate' 
    # (they are all gates)
    # as well as the type of that 'from' gate
    # and the event name for the 'to_event' it connected to
    select(gate = event, type, to_event) %>%
    # Finally, let's summarize our data by gate,
    # giving us 1 row per gate,
    group_by(gate) %>%
    # where for each gate, we know...
    summarize(
      # the type of gate
      type = unique(type),
      # concatenate together all the to_events, separated by a "|" symbol
      set = paste(to_event, collapse = "|")) %>%
    # Let's adjust our nomenclature a bit,
    # clarifying based on the gate 'type' whether that "|" signifies 
    # an AND relationship or an OR relationship 
    # between any multiple events shown per gate.
    mutate(set = case_when(
      # If the gate is "AND",
      type == "and" ~ set %>%
        # Replace the "|" divider with a multiplication sign
        str_replace_all(pattern = "[|]", replacement = " * "),
      # If the gate is "OR"
      type == "or" ~ set %>% 
        # Replace the "|" divider with an addition sign
        str_replace_all(pattern = "[|]", replacement = " + "),
      # If the gate is not a gate (this should't happen)
      # Just keep it as is
      type == "not" ~ set,
      type == "top" ~ set),
      # Finally, let's bind them together between parentheses,
      # So as to respect order of operations
      set = paste(" (", set, ") ", sep = "")) %>%
    # Return the result
    return()
  
}

