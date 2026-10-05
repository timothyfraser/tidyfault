#' equate() Function
#'
#' This function extracts the equation for a fault tree from a `data.frame` of `gate`s and `set`s, outputted by `curate()`.
#' 
#' @param data (Required) data.frame of N gates, containing columns for `gate`, `type`, and `set`. Outputted by `curate()`. Must have at least one row with `class == "top"` representing the top event.
#' 
#' @return A character string containing the complete boolean equation for the entire fault tree. The equation:
#'   \itemize{
#'     \item Uses `*` (multiplication) to represent AND operations
#'     \item Uses `+` (addition) to represent OR operations
#'     \item Contains only basic event names (no gate references)
#'     \item Is wrapped in parentheses to preserve order of operations
#'     \item Represents the top event's boolean logic in terms of all basic events
#'   }
#'   This equation can be passed directly to `formulate()` to create an executable function.
#' 
#' @details This function builds the complete boolean equation through an iterative substitution algorithm:
#'   \itemize{
#'     \item Starts with the top event's `set` expression, which may contain references to other gates
#'     \item Iteratively replaces each gate name with its corresponding `set` boolean expression
#'     \item Continues until no gate names remain in any expression (only basic events remain)
#'     \item Returns the fully expanded equation from the top event (first row of the data.frame)
#'   }
#'   The algorithm processes gates in order and handles nested gate structures by repeatedly substituting until convergence. The substitution preserves the boolean operators (`*` for AND, `+` for OR) and parentheses structure created by `curate()`.
#' 
#' @seealso \code{\link{curate}} for creating the gates data.frame, \code{\link{formulate}} for converting the equation string into an executable function
#' 
#' @keywords fault tree equation
#' @importFrom dplyr %>%
#' @importFrom stringr str_detect str_replace str_replace_all
#' @export
#' @examples
#' 
#' # Load dependencies
#' library(tidyverse)
#' library(tidyfault)
#' 
#' # Load example data into our environment
#' data("fakenodes")
#' data("fakeedges")
#' 
#' # Build gate-level representation and expand to a full boolean equation
#' gates <- curate(nodes = fakenodes, edges = fakeedges)
#' equation <- equate(gates)
#' equation
#'
#' # Example downstream use of equate() output
#' formula <- formulate(equation)
#' calculate(formula)


equate = function(data){

  # Gate names are matched as WHOLE TOKENS only: a gate named `T` must not match
  # inside the basic event `TO`. Names are regex-escaped first, so metacharacters
  # in a name (".", "(", "+") are literal.
  gates = as.character(data$gate)
  patterns = paste0(
    "(?<![A-Za-z0-9_.])", escape_regex(gates), "(?![A-Za-z0-9_.])")

  # For each gate, which gates does its set mention?
  mentions = function(sets) {
    lapply(sets, function(s) {
      which(vapply(patterns, function(p) grepl(p, s, perl = TRUE), logical(1)))
    })
  }

  # A gate that expands into itself, directly or through others, would be
  # substituted forever. Stop and name the gates in the cycle.
  check_acyclic(gates = gates, refs = mentions(data$set))

  # Number of (gate, set) pairs where the gate name still appears in the set
  present = function(sets) {
    sum(vapply(patterns, function(p) sum(grepl(p, sets, perl = TRUE)), numeric(1)))
  }

  # Replace the first whole-token occurrence of `pattern` in each element of `x`
  # with `replacement`, literally (no backreferences).
  replace_first = function(x, pattern, replacement) {
    m = regexpr(pattern, x, perl = TRUE)
    regmatches(x, m) <- replacement
    x
  }

  # Keep substituting until only basic events remain
  while(present(data$set) > 0){
    for(i in seq_along(gates)){
      data$set <- replace_first(data$set, patterns[i], data$set[i])
    }
  }

  # The set for the FIRST gate will be the Boolean expression for the entire fault tree
  equation = data$set[1]

  # Defensive cleanup: replace any remaining | characters with + (OR operator)
  # This ensures the equation always uses + for OR operations, even if curate() missed some cases
  equation = equation %>%
    str_replace_all(pattern = "[|]", replacement = " + ")

  # equation is a character representation of the function.
  return(equation)
}

# Escape regex metacharacters so a gate name matches literally
escape_regex = function(x) {
  gsub("([][{}()+*^$|\\\\?.-])", "\\\\\\1", x)
}

# Depth-first search for a cycle in the gate reference graph.
# `refs[[i]]` holds the indices of gates mentioned in gate i's set.
check_acyclic = function(gates, refs) {
  state = integer(length(gates)) # 0 = unseen, 1 = on the path, 2 = done
  visit = function(i, path) {
    if (state[i] == 1L) {
      cycle = c(path[match(i, path):length(path)], i)
      stop(
        "equate(): gates reference each other in a cycle: ",
        paste(gates[cycle], collapse = " -> "),
        ". Remove the loop so every gate bottoms out in basic events.",
        call. = FALSE)
    }
    if (state[i] == 2L) return(invisible())
    state[i] <<- 1L
    for (j in refs[[i]]) visit(j, c(path, i))
    state[i] <<- 2L
    invisible()
  }
  for (i in seq_along(gates)) visit(i, integer())
  invisible()
}
