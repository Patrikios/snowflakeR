#' Get the first token following a given word in SQL (case-insensitive)
#' @param SQL SQL string
#' @param word Word to search for (e.g. "from", "join", "call")
#' @return character vector (possibly empty) or NULL if not found
#' @noRd
sqlQueryFirstWord <- function(SQL, word) {
  if (!grepl(word, SQL, ignore.case = TRUE)) return(NULL)
  parts <- strsplit(toupper(SQL), toupper(word), fixed = FALSE)[[1]]
  if (length(parts) < 2) return(NULL)
  parts <- parts[-1L]
  vapply(parts, function(s) {
    toks <- strsplit(trimws(s), "\\s+")[[1]]
    if (length(toks)) utils::head(toks, 1L) else ""
  }, FUN.VALUE = "")
}

#' SQL sources after FROM
#' @noRd
sqlQuerySourcesFROM <- function(SQL) sqlQueryFirstWord(SQL, "FROM")

#' SQL sources after JOIN
#' @noRd
sqlQuerySourcesJOIN <- function(SQL) sqlQueryFirstWord(SQL, "JOIN")

#' SQL sources after CALL
#' @noRd
sqlQuerySourcesCALL <- function(SQL) sqlQueryFirstWord(SQL, "CALL")

#' Identify sources mentioned in a SQL query
#'
#' @param SQL SQL string
#' @return character vector of unique sources or "no_snowflake_sources_found"
#' @noRd
sqlQuerySources <- function(SQL) {
  out <- sort(unique(c(
    sqlQuerySourcesFROM(SQL),
    sqlQuerySourcesJOIN(SQL),
    sqlQuerySourcesCALL(SQL)
  )))
  if (length(out) == 0L || all(is.na(out))) "no_snowflake_sources_found" else out
}
