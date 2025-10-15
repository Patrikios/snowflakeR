#' SnowflakeConnector: An R6 Snowflake ODBC helper
#'
#' @description
#' `SnowflakeConnector` encapsulates a Snowflake ODBC connection with modular
#' components that manage the connection lifecycle, query execution, lineage
#' tagging, and logging. The refactored design improves testability while
#' retaining the external API that existing users depend on.
#'
#' @section Public fields:
#' \describe{
#'   \item{connection}{Active binding returning the live DBI ODBC connection.}
#'   \item{run_query_history}{Active binding returning a `data.table` summarising executed queries.}
#' }
#'
#' @param dsn ODBC DSN name.
#' @param uid Optional user id (overrides DSN).
#' @param pwd Optional password (overrides DSN).
#' @param database Optional default database.
#' @param schema Optional default schema.
#' @param role Optional default role.
#' @param warehouse Optional default warehouse.
#' @param timezone Server timezone for the connection. Defaults to `Sys.timezone()`.
#' @param timezone_out Timezone for datetimes returned to R. Defaults to `Sys.timezone()`.
#' @param ... Additional arguments passed to `DBI::dbConnect()`.
#'
#' @seealso \code{\link{snowflake_get_query_dsn}}, \code{\link{sqlQuerySources}}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' con <- SnowflakeConnector$new(
#'   dsn = "snowflake-bi",
#'   role = "ANALYST",
#'   warehouse = "BI_WH",
#'   database = "PROD_DB",
#'   schema = "PRESENTATION"
#' )
#' con$run_query("show tables;")
#' con$run_query("select 1 as x")
#' con$run_query_history
#' con$close()
#' }
SnowflakeConnector <- R6::R6Class(
  classname = "SnowflakeConnector",
  public = list(

    #' @description Construct a new connector (opens a connection).
    initialize = function(
      dsn,
      uid = NULL,
      pwd = NULL,
      database = NULL,
      schema = NULL,
      role = NULL,
      warehouse = NULL,
      timezone = Sys.timezone(),
      timezone_out = Sys.timezone(),
      ...
    ) {
      connection_args <- Filter(
        function(x) !is.null(x),
        list(
        dsn = dsn,
        uid = uid,
        pwd = pwd,
        database = database,
        schema = schema,
        role = role,
        warehouse = warehouse,
        timezone = timezone,
        timezone_out = timezone_out,
        ...
        )
      )
      private$connection_manager <- OdbcConnectionManager$new(connection_args)
      private$query_logger <- SnowflakeQueryLogger$new()
      private$lineage_tracker <- SnowflakeLineageTracker$new()
      private$query_executor <- SnowflakeQueryExecutor$new(
        private$connection_manager,
        private$query_logger,
        private$lineage_tracker
      )
      invisible(self)
    },

    #' @description Close the connection.
    close = function() {
      private$connection_manager$close()
      invisible(TRUE)
    },

    #' @description Execute a SELECT and return a `data.table` (with lineage attribute).
    #' @param SQL SQL string (glue placeholders allowed).
    #' @param literal If `TRUE`, skip parameter quoting (passed to `glue_sql()`).
    #' @param glue_envir Environment where glue placeholders are evaluated.
    run_query = function(SQL, literal = FALSE, glue_envir = parent.frame(1L)) {
      private$query_executor$run_query(SQL, literal, glue_envir)
    },

    #' @description Write a data.frame / data.table into Snowflake.
    #' @param table Target table name (`character`) or `DBI::Id`.
    #' @param value Data to write (`data.frame` / `data.table`).
    #' @param ... Passed to `DBI::dbWriteTable()` (e.g., `append = TRUE`, `overwrite = TRUE`).
    write_data = function(table, value, ...) {
      conn <- private$connection_manager$get_connection()
      DBI::dbWriteTable(conn, name = table, value = value, ...)
      invisible(TRUE)
    },

    #' @description Begin a transaction.
    transaction_begin = function() {
      conn <- private$connection_manager$get_connection()
      DBI::dbBegin(conn)
    },

    #' @description Commit a transaction.
    transaction_commit = function() {
      conn <- private$connection_manager$get_connection()
      DBI::dbCommit(conn)
    },

    #' @description Roll back a transaction.
    transaction_rollback = function() {
      conn <- private$connection_manager$get_connection()
      DBI::dbRollback(conn)
    }
  ),
  active = list(
    #' @field connection Active binding exposing the underlying DBI connection.
    connection = function(value) {
      if (missing(value)) {
        private$connection_manager$get_connection()
      } else {
        stop("`connection` is read-only", call. = FALSE)
      }
    },

    #' @field run_query_history Active binding exposing the query logger history.
    run_query_history = function(value) {
      if (missing(value)) {
        private$query_logger$get_history()
      } else {
        stop("`run_query_history` is read-only", call. = FALSE)
      }
    }
  ),
  private = list(
    connection_manager = NULL,
    query_logger = NULL,
    lineage_tracker = NULL,
    query_executor = NULL,

    finalize = function() {
      if (!is.null(private$connection_manager)) {
        private$connection_manager$close()
      }
    }
  )
)
