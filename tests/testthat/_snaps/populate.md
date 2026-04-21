# populate(): invalid event_probs columns

    Code
      populate(tibble::tibble(A = 1L), data.frame(wrong = 1, cols = 2))
    Condition
      Error in `populate()`:
      ! event_probs must have columns 'event' and 'probability'.

# populate(): missing probability for event

    Code
      populate(tibble::tibble(A = 1L, B = 0L), tibble::tibble(event = "A",
        probability = 0.5))
    Condition
      Error in `populate()`:
      ! event_probs missing probabilities for events: B

