#' SnowflakeConnector: An R6 Snowflake ODBC helper
#'
#' @description
#' `SnowflakeConnector` encapsulates a Snowflake ODBC connection with:
#' - Safe SQL interpolation via `glue::glue_sql()` bound to the connection
#' - Query history tracking (`run_query_history`)
#' - `data.table::setattr` lineage under `"snowflake-sources"`
#' - Simple transactions (`$transaction_begin/commit/rollback`)
#' - Simple writes (`$write_data`)
#'
#' Credentials are expected to be provided by your DSN and/or the constructor
#' arguments (`uid`, `pwd`, etc.). This package does **not** read YAML files.
#'
#' @section Public fields:
#' \describe{
#'   \item{connection}{The live DBI ODBC connection object.}
#'   \item{run_query_history}{`data.table` with columns `query` and `result`.}
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
    
    #' @field connection The live DBI ODBC connection object.
    connection = "OdbcConnection", # Formal class 'Snowflake' [package ".GlobalEnv"] #NULL,
    
    #' @field run_query_history `data.table` with columns `query` and `result`.
    run_query_history = data.table::data.table(
      query = character(), 
      result = character()
      ),
    
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
      self$connection <- DBI::dbConnect(
        odbc::odbc(),
        dsn          = dsn,
        uid          = uid,
        pwd          = pwd,
        database     = database,
        schema       = schema,
        role         = role,
        warehouse    = warehouse,
        timezone     = timezone,
        timezone_out = timezone_out,
        ...
      )
      invisible(self)
    },
    
    #' @description Close the connection.
    close = function() {
      if (!is.null(self$connection)) {
        try(DBI::dbDisconnect(self$connection), silent = TRUE)
      }
      invisible(TRUE)
    },
    
    #' @description Execute a SELECT and return a `data.table` (with lineage attribute).
    #' @param SQL SQL string (glue placeholders allowed).
    #' @param literal If `TRUE`, skip parameter quoting (passed to `glue_sql()`).
    #' @param glue_envir Environment where glue placeholders are evaluated.
    run_query = function(SQL, literal = FALSE, glue_envir = parent.frame(1L)) {
      stopifnot(DBI::dbIsValid(self$connection))
      stmt <- glue::glue_sql(SQL, .con = self$connection, .envir = glue_envir, .literal = literal)
      res <- try(DBI::dbGetQuery(self$connection, stmt), silent = TRUE)
      
      if (inherits(res, "try-error")) {
        msg <- conditionMessage(attr(res, "condition"))
        self$run_query_history <- data.table::rbindlist(list(
          self$run_query_history,
          data.table::data.table(query = SQL, result = msg)
        ))
        stop(msg, call. = FALSE)
      }
      
      dt <- data.table::as.data.table(res)
      data.table::setattr(dt, "snowflake-sources",
                          paste(sqlQuerySources(SQL), collapse = ", "))
      
      self$run_query_history <- data.table::rbindlist(list(
        self$run_query_history,
        data.table::data.table(query = SQL, result = "passed")
      ))
      dt
    },
    
    #' @description Write a data.frame / data.table into Snowflake.
    #' @param table Target table name (`character`) or `DBI::Id`.
    #' @param value Data to write (`data.frame` / `data.table`).
    #' @param ... Passed to `DBI::dbWriteTable()` (e.g., `append = TRUE`, `overwrite = TRUE`).
    write_data = function(table, value, ...) {
      stopifnot(DBI::dbIsValid(self$connection))
      DBI::dbWriteTable(self$connection, name = table, value = value, ...)
      invisible(TRUE)
    },
    
    #' @description Begin a transaction.
    transaction_begin = function() DBI::dbBegin(self$connection),
    
    #' @description Commit a transaction.
    transaction_commit = function() DBI::dbCommit(self$connection),
    
    #' @description Roll back a transaction.
    transaction_rollback = function() DBI::dbRollback(self$connection)
  ),
  
  private = list(
    # Finalizer: ensure the connection is closed when GC collects the object
    # Docu on finalizers https://r6.r-lib.org/articles/Introduction.html#finalizers
    finalize = function() {
      if (!is.null(self$connection)) {
        try(DBI::dbDisconnect(self$connection), silent = TRUE)
      }
    }
  )
)
