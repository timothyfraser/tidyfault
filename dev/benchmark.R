# benchmark.R

# Benchmark exercise for speed of MOCUS algorithm
library(tidyfault) # for fault trees!
library(tictoc) # for timing
library(purrr) # for iteration
library(readr)
# Define the range of gates and basic events to simulate
n_gates = c(1:20)
n_basic = c(1:20)

# Iterate over the range of gates and basic events
result = purrr::map2_dfr(
  .x = n_gates, 
  .y = n_basic, 
  .f = ~{ 
  # Simulate a random fault tree
  sim = simulate(n_gates = .x, n_basic = .y, p_range = c(0.01, 0.2), seed = 12345)
  # Get the gates metadata from the tree
  gates = curate(nodes = sim$nodes, edges = sim$edges)
  # Benchmark the MOCUS algorithm
  tic() # start timer
  time = system.time({concentrate(gates, method = "mocus_original") })  # MOCUS
  time = toc(quiet = TRUE) # end timer
  # Return results
  output = data.frame(time = time$toc - time$tic, n_gates = .x, n_basic = .y)
  cat("\nProgress: n_gates", .x, "n_basic", .y, "time", time$toc - time$tic)
  output
  }, 
  .id = "id"
 )
# Write result to file
# Tim
# write_csv(result, path = "C:/Users/tmf77/tidyfault_paper/tidyfault/dev/benchmark_results.csv")
# Jingyao
out_file <- file.path("tidyfault", "dev", "benchmark_results_new.csv")
write_csv(result, file = out_file)