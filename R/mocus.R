#' mocus() Function
#'
#' This function *simplifies* a `data.frame` of gates and their sets identified by `curate()`, generating each cutset in the fault tree using a simple implementation of the `mocus()` algorithm.
#' 
#' @param data (Required) data.frame containing gates and their sets, outputted by `curate()`.
#' @keywords boolean cutset fault tree
#' @export

mocus = function(data){
  
  # Initialize a list
  m = list()
  
  # To start, let's get the TOP event (always just 1 value)
  m[[1]] = data %>%
    filter(class == "top") %>%
    with(gate) 
  
  continue = TRUE
  system.time(
    # For each ROW/ITEM in the list
    
    while(continue == TRUE){
      
      # For each item k in list m
      # (more items will get added as the loop progresses)
      for(k in 1:length(m)){
        
        # Look at the set in item k! Are there any gates in it?
        isgate = m[[k]] %in% data$gate
        
        # If there ARE ANY gates in the set in item k,
        if(sum(isgate) > 0){
          
          # Identify the name(s) of each gate that is in the set in row/item k
          mygates = m[[k]][ isgate ]
          
          holder = list()
          
          # For the first gate in that set,
          # Note: this is not a typo
          for(j in 1){
            
            # Find the data on the jth gate
            jgate = data %>% 
              filter(gate == mygates[j])
            
            # gather the set events ('items') linked to that gate.
            myset = jgate %>%
              with(items) %>% unlist()
            
            # And record the type of that gate
            mytype = jgate$type
            
            # Identify the LOCATIONS of **gate j** in the set
            # formatted as a vector of the same dimension
            isgatej = m[[k]] %in% mygates[j]
            
            # Now, we're going to format a NEW vector for our list
            # replacing our current gates with the contents of myset
            notgatej = m[[k]][ !isgatej ]
            
            # If it's an AND gate (or if it's a top gate)
            if(mytype == "and" | mytype == "top"){
              
              # And if there are ANY events that are not gate j in item k,          
              if(length(notgatej) > 0){
                # then bind them together into a vector and replace item k
                holder = notgatej %>% matrix(ncol = length(.)) %>%
                  c(myset) %>% list(.)
              }else{   
                # otherwise,
                # just overwrite item k with myset.
                holder = list(myset)
              }
              
              # Alternatively, if it's an OR gate
            }else  if(mytype == "or"){
              
              # Take our vector or items that are **NOT gate j**,
              # replicate them as many times as there are values in myset
              holder = mapply(FUN = rep, notgatej, length(myset)) %>%
                # then column-bind in the myset vector as a single column
                cbind(myset) %>% 
                # And get rid of the names
                unname() %>%
                # Split into as many vectors as there are rows
                split(1:nrow(.)) %>%
                unname()
            }
            
            # I want to say, just append them but keep going
            # Remove m[[k]], which is now outdated
            m[k] <- NULL
            # Update m to include the new items from the jth AND or OR gate,
            m <- c(m, holder)
          }
        }
        # Keep rolling through K 
      }    
      # Finally, evaluate all the values in your finished list.
      # does it contain ANY remaining gates?
      remaining = sum( unlist(m) %in% data$gate )
      
      # Update the reader!
      # print(paste("remaining: ", remaining, sep = ""))
      
      # If it contains any remaining gates, 
      # repeat the loop, looking at each item in k again
      if(remaining > 0){ continue = TRUE  }else{ continue = FALSE  }
    }
    
  )
  
  # Shrink the vectors in our list to just unique values
  m = m %>%
    map(~unique(.))
  
  return(m)
}