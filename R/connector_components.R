#' Internal helpers for SnowflakeConnector modularisation
#'
#' These R6 classes are intentionally kept internal (not exported) to separate
#' concerns inside `SnowflakeConnector` and improve testability without leaking
#' additional surface area to package consumers.
#'
#' @keywords internal
NULL

#' Manage lifecycle for an ODBC connection
#'
#' @keywords internal
OdbcConnectionManager <- R6::R6Class(
  classname = "OdbcConnectionManager",
  public = list(
    initialize = function(connection_args) {
      stopifnot(is.list(connection_args))
      private$connection_args <- connection_args
      private$open_connection()
    },

    get_connection = function() {
      private$ensure_connection()
      private$connection
    },

    close = function() {
      if (!is.null(private$connection)) {
        try(DBI::dbDisconnect(private$connection), silent = TRUE)
        private$connection <- NULL
      }
      invisible(TRUE)
    },

    is_valid = function() {
      !is.null(private$connection) && tryCatch(
        DBI::dbIsValid(private$connection),
        error = function(...) FALSE
      )
    }
  ),
  private = list(
    connection = NULL,
    connection_args = list(),

    open_connection = function() {
      private$connection <- do.call(
        DBI::dbConnect,
        c(list(drv = odbc::odbc()), private$connection_args)
      )
    },

    ensure_connection = function() {
      if (!self$is_valid()) {
        stop("Snowflake ODBC connection is not available", call. = FALSE)
      }
    }
  )
)

#' Track query history for observability and debugging
#'
#' @keywords internal
SnowflakeQueryLogger <- R6::R6Class(
  classname = "SnowflakeQueryLogger",
  public = list(
    initialize = function() {
      private$history <- data.table::data.table(
        timestamp = as.POSIXct(character()),
        query = character(),
        status = factor(levels = c("passed", "failed")),
        message = character()
      )
    },

    log_success = function(query) {
      private$append_record(query, "passed", NA_character_)
    },

    log_failure = function(query, message) {
      private$append_record(query, "failed", message)
    },

    get_history = function() {
      data.table::copy(private$history)
    }
  ),
  private = list(
    history = NULL,

    append_record = function(query, status, message) {
      private$history <- data.table::rbindlist(
        list(
          private$history,
          data.table::data.table(
            timestamp = Sys.time(),
            query = query,
            status = factor(status, levels = c("passed", "failed")),
            message = message
          )
        ),
        use.names = TRUE,
        fill = TRUE
      )
    }
  )
)

#' Apply lineage metadata to query results
#'
#' @keywords internal
SnowflakeLineageTracker <- R6::R6Class(
  classname = "SnowflakeLineageTracker",
  public = list(
    add_lineage = function(result, sql) {
      if (!data.table::is.data.table(result)) {
        result <- data.table::as.data.table(result)
      }
      sources <- tryCatch(
        sqlQuerySources(sql),
        error = function(err) character()
      )
      data.table::setattr(
        result,
        "snowflake-sources",
        paste(sources, collapse = ", ")
      )
      result
    }
  )
)

#' Execute SQL statements using a connection manager
#'
#' @keywords internal
SnowflakeQueryExecutor <- R6::R6Class(
  classname = "SnowflakeQueryExecutor",
  public = list(
    initialize = function(connection_manager, logger, lineage_tracker) {
      private$connection_manager <- connection_manager
      private$logger <- logger
      private$lineage_tracker <- lineage_tracker
    },

    run_query = function(SQL, literal = FALSE, glue_envir = parent.frame(1L)) {
      conn <- private$connection_manager$get_connection()
      stmt <- glue::glue_sql(
        SQL,
        .con = conn,
        .envir = glue_envir,
        .literal = literal
      )

      result <- try(DBI::dbGetQuery(conn, stmt), silent = TRUE)
      if (inherits(result, "try-error")) {
        message <- conditionMessage(attr(result, "condition"))
        private$logger$log_failure(SQL, message)
        stop(message, call. = FALSE)
      }

      private$logger$log_success(SQL)
      private$lineage_tracker$add_lineage(result, SQL)
    }
  ),
  private = list(
    connection_manager = NULL,
    logger = NULL,
    lineage_tracker = NULL
  )
)
