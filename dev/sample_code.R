## Data

library(tidyverse)
library(QCA)
library(tidygraph)
library(ggraph)





curate(nodes, edges)

## Functions


# Let's write a function to identify the paths for each gate
curate = function(nodes, edges){
  
  require(dplyr)
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


# Let's write a function to return the boolean equation
# for any data.frame of gates and sets provided
equate = function(data){
  
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



# As our next step we need to format that equation
# transforming it from a character string
# into a function we can compute!

formulate = function(formula){

  require(dplyr)
  require(stringr)
  
  # Can I now remove ANYTHING that is not a (, ), +, or *?
  values = formula %>% 
    # Split into separate values anytime you see an operator
    str_split(pattern = "[(]|[)]|[+]|[*]", simplify = TRUE) %>% 
    # Convert matrix to vector
    as.vector() %>%
    # Trim any spaces
    str_trim(side = "both") %>%
    # If any values are now empty, eg. "", set to NA
    na_if(y = "") %>%
    # Drop NAs
    .[!is.na(.)] %>%
    # Return just the unique list of inputs
    unique() %>%
    # Sort the unique inputs
    sort()
  
  # Get whatever values go into that formula, 
  # and format them as a special list of arguments
  args = values %>%
    paste(., " = ") %>%
    paste(collapse = ", ")  %>%
    paste("alist(", ., ")", sep = "") %>%
    # Parse the phrase
    parse(text = .) %>%
    # And evaluate it, so that formals(functionname) can use it
    eval()
  
  # We need to make an empty function, called 'f()'
  f = function(){ }
  
  # Then parse and assign the text 'equation' to the body of this function
  body(f) <- parse(text = formula)
  
  # Assign our collection to be the formal arguments for this function
  formals(f) <- args
  
  # And return our function!
  return(f)
}



# Let's write a function to extract the truth table
calculate = function(f){

  require(dplyr)
  require(tidyr)
  
  # Extract name of function object as text
  fname = deparse(quote(f))
  
  
  # Extract the names of our formal arguments from the function.
  fargs = f %>% formalArgs() 
  
  # get basic usage of function with all its arguments
  fusage = fargs %>% paste(., collapse = ", ") %>% 
    paste(fname, "(", ., ")", sep = "")
  
  # Generate a grid of all possible binary inputs to the arguments
  # eg. A = 1, B = 0, C = 1, etc.
  fgrid = fargs %>%
    # Paste them into one string, saying Argument1 = c(0,1), Argument2 = .... etc.
    paste(., "= c(0, 1)", collapse = ", ") %>%
    # Put this inside expand_grid()
    paste("expand_grid(", ., ")", sep = "") %>%
    # parse it into an expression
    parse(text = .) %>%
    # And evaluate the expression
    eval()
  
  # Let's generate the truth table!
  ftab = fgrid %>%
    # Now calculate the outcome,
    # having it run our function f using 
    mutate(outcome = fusage %>% parse(text = .) %>% eval()) %>%
    # Simplify the 'outcome' field into a binary,
    # where if 1 means outcome >= 1 while 0 means any 0
    mutate(outcome = as.numeric(outcome >= 1)) %>%
    # Arrange from top to bottom
    arrange(desc(outcome))
  
  return(ftab)
}


# Let's write a function to perfor boolean minimalization
concentrate = function(data){
  
  require(dplyr)
  require(QCA)
  
  data %>%
    # Convert to matrix
    as.matrix() %>%
    # Convert to truth table
    QCA::truthTable(outcome = "outcome") %>%
    # Use boolean minimalization,
    # with the CCubes algorithm, to get the prime implicants!!!
    QCA::minimize("outcome", use.tilde = FALSE, method = "CCubes") %>%
    return()
  
}


tabulate = function(data){
  
  require(dplyr)
  require(tibble)
  require(stringr)
  require(QCA)
  
  # Extract the truth table from the boolean minimalization solution object
  tab = data$tt$tt %>% select(1:OUT) %>% rename(outcome = OUT)
  
  # Extract the solution set as a tibble(),
  # where each column shows one solution, 
  # including however many minimum cutsets there are
  # in that vector named for the solution 
  # (eg. solution M1 gets its own column)
  data %>%
    with(essential) %>%
    tibble(mincut = .) %>%
    # For each minimum cutset,
    group_by(mincut) %>%
    summarize(
      # please extract each of the values in that cutset, one per row
      event = mincut %>% str_split(pattern = "[*]", simplify = TRUE) %>% as.vector(),
      # then classify cutset values as positive (no tilde = 1) or negative (tilde = 0)
      value = if_else(str_detect(event, "[~]"), 0, 1),
      # then construct a label
      label = paste(event, "==", value)) %>%
    # For each cutset
    group_by(mincut) %>%
    # Consolidate labels into 1 query per minimal cutset
    # asking whether you saw these cutset values AND the outcome == 1
    summarize(query = c(label, "outcome == 1") %>%
                # Collapse them into one line, with commas between them
                paste(collapse = ", ") %>%
                # and append a filter function and the name of the data to be filtered,
                paste( deparse(quote(tab)), " %>% ", "filter", "(", ., ")", sep = "")) %>%
    # Finally, for each minimal cutset,
    group_by(mincut) %>%
    # Please claculate...
    mutate(
      # number of cutsets that include these prime implicants
      cutsets = query %>% parse(text = .) %>% eval() %>% nrow(),
      # total cutsets that ever see failure
      failures = tab %>% filter(outcome == 1) %>% nrow(),
      # percentage of cutsets covering prime implicants, out of total cutsets that fail
      # In other words, the explanatory power of our cutsets for system failure
      coverage = cutsets / failures,
      query = query %>% str_remove(pattern = paste( deparse(quote(tab)), " %>% ", sep = "") )) %>%
    ungroup() %>%
    return()
}




## Usage


#curate(nodes, edges) %>% equate() %>% formulate() %>% calculate() %>% concentrate() %>% tabulate()


