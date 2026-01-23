#' curate() Function
#'
#' This function *curates* a `data.frame` of N `gates` and the `sets` of events immediately linked to those gates.
#' 
#' @param nodes (Required) data.frame of N `nodes` (1 to N rows), with a unique `id` for each node, an `event` name describing the node (some events occur multiple times), and a `type` vector categorizing nodes as `"and"` | `"or"` gates, `"top"` nodes, or `"not"` a gate or top node (ie. a normal node)
#' @param edges (Required) data.frame of N `edges` (1 to N rows), showing ties between the `from` node's `id` to the `to` node's `id`.
#' 
#' @return A `data.frame` (tibble) with one row per gate, containing:
#'   \itemize{
#'     \item `gate`: Character vector of gate/event names
#'     \item `type`: Factor or character vector indicating gate type (`"top"`, `"and"`, or `"or"`)
#'     \item `class`: Factor with levels `"top"` and `"gate"`, classifying nodes as top events or intermediate gates
#'     \item `n`: Integer count of events immediately connected to this gate
#'     \item `set`: Character string containing the boolean expression for this gate's inputs, using `*` for AND operations and `+` for OR operations, wrapped in parentheses
#'     \item `items`: List column containing character vectors of event names that are inputs to this gate
#'   }
#'   Rows are sorted with top events first, followed by gates in alphabetical order.
#' 
#' @details This function performs the initial curation step in the fault tree analysis workflow:
#'   \itemize{
#'     \item Filters nodes to only gates and top events (excludes basic events with `type == "not"`)
#'     \item Joins edge information to identify which events connect to each gate
#'     \item Converts gate relationships into boolean expressions: AND gates use `*` (multiplication), OR gates use `+` (addition)
#'     \item Wraps each gate's set expression in parentheses to preserve order of operations
#'     \item Creates both string (`set`) and list (`items`) representations of gate inputs for different downstream uses
#'   }
#'   The output serves as the foundation for subsequent steps: `equate()` uses the `set` column to build the complete boolean equation, while `mocus()` uses the `items` list column for cutset generation.
#' 
#' @seealso \code{\link{equate}} for building the complete boolean equation from curated gates, \code{\link{illustrate}} for visualizing the fault tree structure
#' 
#' @keywords fault tree
#' @importFrom dplyr %>% filter left_join select group_by summarize mutate arrange ungroup case_when
#' @importFrom tibble tibble
#' @importFrom stringr str_replace_all
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
#' formula <- curate(nodes = fakenodes, edges = fakeedges) %>%
#'    equate() %>%
#'    formulate()
#' curate(nodes = fakenodes, edges = fakeedges) %>%
#'    equate() %>%
#'    formulate() %>%
#'    calculate() %>%
#'    concentrate() %>% 
#'    tabulate(formula = formula)

curate = function(nodes, edges){
  
  # Let's write a function to identify the paths for each gate

  require(dplyr)
  require(tibble)
  require(stringr)
  
  # Take our list of nodes
  nodes %>%
    # Filter to just gates (meaning AND or OR operators)
    filter(type %in% c("top", "and", "or")) %>%
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
      # Classify our gates into top event versus gate
      class = case_when(
        type == "top" ~ "top",
        type %in% c("and", "or") ~ "gate"),
      # Order as factor
      class = factor(class, levels = c("top", "gate")),
      # Count the number of events immediately following that gate
      n = length(to_event),
      # concatenate together all the to_events, separated by a "|" symbol
      set = paste(to_event, collapse = "|"),
      # Also contain the events in a list item
      items = list(to_event)) %>%
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
      # If the node is the top event, it will only have ONE node linked, 
      # G1, the first gate, so we can leave it as is.
      type == "top" ~ set,
      # If the gate is not a gate (this shouldn't happen)
      # Just keep it as is
      type == "not" ~ set),
      # Finally, let's bind them together between parentheses,
      # So as to respect order of operations
      set = paste(" (", set, ") ", sep = "")) %>%
    # Sort so that the top event comes first, followed by the gates
    arrange(class, gate) %>%
    ungroup() %>%
    # Return the result
    return()
  
}