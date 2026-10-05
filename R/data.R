#' `ai_probs` AI agent failure fault tree event probabilities
#'
#' Example failure probabilities for the basic events of the AI agent failure fault tree
#' (`ai_nodes`, `ai_edges`). Pass it as `event_probs` to [populate()].
#'
#' @format ## `ai_probs`
#' A tibble with 4 rows and 2 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"AF"` = API failure, `"TO"` = Timeout, `"RL"` = Rate limit, `"CWE"` = Context window exceeded.}
#'   \item{probability}{Probability that the event occurs, between 0 and 1.}
#' }
#'
#' @examples
#' data("ai_probs")
#' ai_probs
#'
#' @seealso [ai_outcomes_prob], [ai_outcomes_binary], [populate()]
"ai_probs"

#' `ai_outcomes_binary` AI agent failure fault tree binary scenarios
#'
#' Ten example scenarios for the basic events of the AI agent failure fault tree, coded
#' 1 if the event occurred and 0 if not. Use it with [quantify()] to evaluate
#' whether the top event occurs under each scenario, or with [populate()].
#'
#' @format ## `ai_outcomes_binary`
#' A tibble with 10 rows and 5 columns:
#' \describe{
#'   \item{scenario}{Scenario number (1 to 10).}
#'   \item{AF, TO, RL, CWE}{One 0/1 column per basic event; 1 means the event occurred.}
#' }
#'
#' @examples
#' data("ai_outcomes_binary")
#' head(ai_outcomes_binary)
#'
#' @seealso [ai_probs], [ai_outcomes_prob], [quantify()], [populate()]
"ai_outcomes_binary"

#' `ai_outcomes_prob` AI agent failure fault tree outcome probabilities
#'
#' Example failure probabilities for the basic events of the AI agent failure fault
#' tree, with one row per event. It holds the same values as [ai_probs].
#'
#' @format ## `ai_outcomes_prob`
#' A tibble with 4 rows and 2 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"AF"` = API failure, `"TO"` = Timeout, `"RL"` = Rate limit, `"CWE"` = Context window exceeded.}
#'   \item{probability}{Probability that the event occurs, between 0 and 1.}
#' }
#'
#' @examples
#' data("ai_outcomes_prob")
#' ai_outcomes_prob
#'
#' @seealso [ai_probs], [ai_outcomes_binary], [ai_outcomes_rates]
"ai_outcomes_prob"

#' `ai_outcomes_rates` AI agent failure fault tree failure rates
#'
#' Example exponential failure rates for the basic events of the AI agent failure fault
#' tree, expressed per 1000 requests.
#'
#' @format ## `ai_outcomes_rates`
#' A tibble with 4 rows and 3 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"AF"` = API failure, `"TO"` = Timeout, `"RL"` = Rate limit, `"CWE"` = Context window exceeded.}
#'   \item{lambda}{Failure rate (failures per 1000 requests).}
#'   \item{time_unit}{Unit of time for `lambda`: `"per_1000_requests"`.}
#' }
#'
#' @examples
#' data("ai_outcomes_rates")
#' ai_outcomes_rates
#'
#' @seealso [ai_probs], [ai_outcomes_prob]
"ai_outcomes_rates"

#' `db_probs` database system failure fault tree event probabilities
#'
#' Example failure probabilities for the basic events of the database system failure fault tree
#' (`db_nodes`, `db_edges`). Pass it as `event_probs` to [populate()].
#'
#' @format ## `db_probs`
#' A tibble with 8 rows and 2 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"DC"` = Data corruption, `"AF"` = Access failure, `"SF"` = Storage failure, `"BF"` = Backup failure, `"NF"` = Network failure, `"AUF"` = Authentication failure, `"HF"` = Hardware failure, `"MF"` = Monitoring failure.}
#'   \item{probability}{Probability that the event occurs, between 0 and 1.}
#' }
#'
#' @examples
#' data("db_probs")
#' db_probs
#'
#' @seealso [db_outcomes_prob], [db_outcomes_binary], [populate()]
"db_probs"

#' `db_outcomes_binary` database system failure fault tree binary scenarios
#'
#' Ten example scenarios for the basic events of the database system failure fault tree, coded
#' 1 if the event occurred and 0 if not. Use it with [quantify()] to evaluate
#' whether the top event occurs under each scenario, or with [populate()].
#'
#' @format ## `db_outcomes_binary`
#' A tibble with 10 rows and 9 columns:
#' \describe{
#'   \item{scenario}{Scenario number (1 to 10).}
#'   \item{DC, AF, SF, BF, NF, AUF, HF, MF}{One 0/1 column per basic event; 1 means the event occurred.}
#' }
#'
#' @examples
#' data("db_outcomes_binary")
#' head(db_outcomes_binary)
#'
#' @seealso [db_probs], [db_outcomes_prob], [quantify()], [populate()]
"db_outcomes_binary"

#' `db_outcomes_prob` database system failure fault tree outcome probabilities
#'
#' Example failure probabilities for the basic events of the database system failure fault
#' tree, with one row per event. It holds the same values as [db_probs].
#'
#' @format ## `db_outcomes_prob`
#' A tibble with 8 rows and 2 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"DC"` = Data corruption, `"AF"` = Access failure, `"SF"` = Storage failure, `"BF"` = Backup failure, `"NF"` = Network failure, `"AUF"` = Authentication failure, `"HF"` = Hardware failure, `"MF"` = Monitoring failure.}
#'   \item{probability}{Probability that the event occurs, between 0 and 1.}
#' }
#'
#' @examples
#' data("db_outcomes_prob")
#' db_outcomes_prob
#'
#' @seealso [db_probs], [db_outcomes_binary], [db_outcomes_rates]
"db_outcomes_prob"

#' `db_outcomes_rates` database system failure fault tree failure rates
#'
#' Example exponential failure rates for the basic events of the database system failure fault
#' tree, expressed per hour.
#'
#' @format ## `db_outcomes_rates`
#' A tibble with 8 rows and 3 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"DC"` = Data corruption, `"AF"` = Access failure, `"SF"` = Storage failure, `"BF"` = Backup failure, `"NF"` = Network failure, `"AUF"` = Authentication failure, `"HF"` = Hardware failure, `"MF"` = Monitoring failure.}
#'   \item{lambda}{Failure rate (failures per hour).}
#'   \item{time_unit}{Unit of time for `lambda`: `"hours"`.}
#' }
#'
#' @examples
#' data("db_outcomes_rates")
#' db_outcomes_rates
#'
#' @seealso [db_probs], [db_outcomes_prob]
"db_outcomes_rates"

#' `security_probs` security breach fault tree event probabilities
#'
#' Example failure probabilities for the basic events of the security breach fault tree
#' (`security_nodes`, `security_edges`). Pass it as `event_probs` to [populate()].
#'
#' @format ## `security_probs`
#' A tibble with 7 rows and 2 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"VE"` = Vulnerability exists, `"ES"` = Exploit successful, `"PH"` = Phishing, `"MW"` = Malware, `"UA"` = Unauthorized access, `"WP"` = Weak password, `"N2F"` = No 2FA.}
#'   \item{probability}{Probability that the event occurs, between 0 and 1.}
#' }
#'
#' @examples
#' data("security_probs")
#' security_probs
#'
#' @seealso [security_outcomes_prob], [security_outcomes_binary], [populate()]
"security_probs"

#' `security_outcomes_binary` security breach fault tree binary scenarios
#'
#' Ten example scenarios for the basic events of the security breach fault tree, coded
#' 1 if the event occurred and 0 if not. Use it with [quantify()] to evaluate
#' whether the top event occurs under each scenario, or with [populate()].
#'
#' @format ## `security_outcomes_binary`
#' A tibble with 10 rows and 8 columns:
#' \describe{
#'   \item{scenario}{Scenario number (1 to 10).}
#'   \item{VE, ES, PH, MW, UA, WP, N2F}{One 0/1 column per basic event; 1 means the event occurred.}
#' }
#'
#' @examples
#' data("security_outcomes_binary")
#' head(security_outcomes_binary)
#'
#' @seealso [security_probs], [security_outcomes_prob], [quantify()], [populate()]
"security_outcomes_binary"

#' `security_outcomes_prob` security breach fault tree outcome probabilities
#'
#' Example failure probabilities for the basic events of the security breach fault
#' tree, with one row per event. It holds the same values as [security_probs].
#'
#' @format ## `security_outcomes_prob`
#' A tibble with 7 rows and 2 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"VE"` = Vulnerability exists, `"ES"` = Exploit successful, `"PH"` = Phishing, `"MW"` = Malware, `"UA"` = Unauthorized access, `"WP"` = Weak password, `"N2F"` = No 2FA.}
#'   \item{probability}{Probability that the event occurs, between 0 and 1.}
#' }
#'
#' @examples
#' data("security_outcomes_prob")
#' security_outcomes_prob
#'
#' @seealso [security_probs], [security_outcomes_binary], [security_outcomes_rates]
"security_outcomes_prob"

#' `security_outcomes_rates` security breach fault tree failure rates
#'
#' Example exponential failure rates for the basic events of the security breach fault
#' tree, expressed per day.
#'
#' @format ## `security_outcomes_rates`
#' A tibble with 7 rows and 3 columns:
#' \describe{
#'   \item{event}{Name of the basic event: `"VE"` = Vulnerability exists, `"ES"` = Exploit successful, `"PH"` = Phishing, `"MW"` = Malware, `"UA"` = Unauthorized access, `"WP"` = Weak password, `"N2F"` = No 2FA.}
#'   \item{lambda}{Failure rate (failures per day).}
#'   \item{time_unit}{Unit of time for `lambda`: `"days"`.}
#' }
#'
#' @examples
#' data("security_outcomes_rates")
#' security_outcomes_rates
#'
#' @seealso [security_probs], [security_outcomes_prob]
"security_outcomes_rates"

#' `breach_nodes` data breach fault tree nodes dataset
#'
#' An example dataset of nodes in a small data breach fault tree. A breach
#' occurs if credentials are stolen through phishing, or if an insider or an
#' unauthorized party gets access.
#'
#' @format ## `breach_nodes`
#' A data frame with 8 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifier (1 to 8) for each node.}
#'   \item{event}{Name of event. `"Breach"` is the top event. `"G1"`, `"G2"`,
#'   `"G3"` are gates. The basic events are `"Phishing"`, `"Credential"`
#'   (credential compromise), `"Insider"` (insider threat), and
#'   `"Unauthorized"` (unauthorized access).}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not"
#'   (meaning "not" a gate).}
#' }
#'
#' @details
#' The fault tree structure:
#' - Top event: Breach
#' - G1 (OR): G2 OR G3
#' - G2 (AND): Phishing AND Credential
#' - G3 (OR): Insider OR Unauthorized
#'
#' @examples
#' data("breach_nodes")
#' head(breach_nodes)
#'
#' @seealso [breach_edges] for the corresponding edges dataset
"breach_nodes"

#' `breach_edges` data breach fault tree edge dataset
#'
#' An example dataset of edges (connections) in the data breach fault tree
#' described in [breach_nodes].
#'
#' @format ## `breach_edges`
#' A data frame with 7 rows and 2 columns:
#' \describe{
#'   \item{from}{Unique `id` of the source/`from` node from which edge originates.}
#'   \item{to}{Unique `id` of the destination/`to` node that edge connects to.}
#' }
#'
#' @examples
#' data("breach_edges")
#' head(breach_edges)
#'
#' @seealso [breach_nodes] for the corresponding nodes dataset
"breach_edges"

#' `it_security_probs` IT security (data leak) fault tree event probabilities
#'
#' Example probabilities for the 10 basic events of the IT security fault tree
#' (`it_security_nodes`, `it_security_edges`), in wide format: one row and one
#' column per basic event. Pass it to [quantify()] with `prob = TRUE`.
#'
#' @format ## `it_security_probs`
#' A tibble with 1 row and 10 columns. Each column is a basic event (two-letter
#' code, as described in [it_security_data]) and holds the probability, between
#' 0 and 1, that the event occurs: `DA`, `EP`, `IM`, `LR`, `MN`, `PO`, `PC`,
#' `PM`, `VS`, `WB`.
#'
#' @examples
#' data("it_security_probs")
#' it_security_probs
#'
#' @seealso [it_security_data], [it_security_outcomes_rates], [quantify()]
"it_security_probs"

#' `it_security_outcomes_rates` IT security (data leak) fault tree failure rates
#'
#' Example exponential failure rates for the 10 basic events of the IT security
#' fault tree, expressed per hour (the reliability-engineering convention): a
#' rate of 0.25 failures per year is stored as 0.25 / 8760 failures per hour,
#' so `pexp(8760, lambda)` is the chance of failing within one year.
#'
#' @format ## `it_security_outcomes_rates`
#' A tibble with 10 rows and 3 columns:
#' \describe{
#'   \item{event}{Two-letter code of the basic event (`"DA"`, `"EP"`, `"IM"`,
#'   `"LR"`, `"MN"`, `"PO"`, `"PC"`, `"PM"`, `"VS"`, `"WB"`); see
#'   [it_security_data] for what each code means.}
#'   \item{lambda}{Failure rate (failures per hour).}
#'   \item{time_unit}{Unit of time for `lambda`: `"hours"`.}
#' }
#'
#' @examples
#' data("it_security_outcomes_rates")
#' it_security_outcomes_rates
#'
#' @seealso [it_security_probs], [it_security_data]
"it_security_outcomes_rates"
