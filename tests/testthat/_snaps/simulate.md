# simulate(): invalid p_range

    Code
      simulate(p_range = c(0, 0.5), seed = 1L)
    Condition
      Error in `simulate()`:
      ! p_range must satisfy 0 < p_range[1] < p_range[2] < 1.

# simulate(): invalid n_basic

    Code
      simulate(n_basic = 0L, seed = 1L)
    Condition
      Error in `simulate()`:
      ! n_basic must be an integer >= 1.

