#' equate() Function
#'
#' This function extracts the equation for a fault tree from a `data.frame` of `gate`s and `set`s, outputted by `curate()`.
#' 
#' @param data (Required) data.frame of N gates, containing columns for `gate`, `type`, and `set`. Outputted by `curate()`.
#' @keywords fault tree equation
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


equate = function(data){
  
  # Let's write a function to return the boolean equation
  # for any data.frame of gates and sets provided
  require(dplyr)
  require(stringr)
  
  # As long as [set] contains any value in gates$event,
  # continue doing str_replace
  
  # Let's write a loop to EVALUATE the total number of gates present in each set
  present = function(data){
    gate_present = c()
    for(i in 1:length(data$gate)){
      gate_present[i] = str_detect(data$set, pattern = data$gate[i]) %>% sum()
    }
    # Tally up total number of gates that have a gate present in their set
    sum(gate_present) %>% return()
  }
  
  # present(df)
  
  # Evaluate post-loop how many gates remain present in the set
  # As long as sum(df$gate_present) remains > 0
  # Keep running this loop
  while(present(data = data) > 0){
    
    # print("simplifying...")
    
    # For each gate,
    for(i in 1:length(data$gate)){  
      # Analyze our vector of cells
      data$set <- data$set %>% 
        str_replace(
          # Identify any cells in that vector that 
          # contain the name of gate 'i'
          pattern = data$gate[i], 
          # Replace the name of gate 'i' in that cell 
          # with the contents of gate 'i''s set.
          replacement = data$set[i])
    }
  }
  
  
  # The set for the FIRST gate will be the Boolean expression for the entire fault tree
  equation = data$set[1]
  
  # print("fault tree equation found")
  
  # equation is a character representation of the function.
  return(equation)
}
