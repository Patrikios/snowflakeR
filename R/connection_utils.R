#' SnowflakeConnector
#' One-shot SELECT using a DSN, returning a data.table
#'
#' @description
#' Convenience wrapper for ad-hoc queries without creating an R6 object.
#' Uses `glue::glue_sql()` bound to the connection so you can safely interpolate
#' parameters with `{}` placeholders. Attaches a lineage attribute
#' (`"snowflake-sources"`) via `data.table::setattr()`.
#' 
#' @details
#' **Why keep this function (rationale):**
#'
#' - **One-shot scripts / knitr**: Ideal for reports and quick scripts where you
#'   just need `dt <- snowflake_get_query_dsn("SELECT …", dsn = "…")` without
#'   managing an object lifecycle.
#' - **Low ceremony**: Mirrors `DBI::dbGetQuery()` ergonomics but adds safe
#'   `glue_sql` interpolation and lineage tagging—no need to instantiate or close
#'   an R6 connector for a single query.
#' - **On-ramp / migration**: Familiar entry point for users coming from DBI
#'   one-liners; they can “graduate” to the `SnowflakeConnector` R6 class for
#'   multi-query sessions and advanced features.
#' - **Testing & diagnostics**: Handy for rapid connectivity checks (DSN/role/
#'   timezone) without affecting R6 query history state.
#'
#' When you run **multiple queries**, want **transactions**, or need **writes**,
#' prefer the R6 class `SnowflakeConnector`.
#'
#' @param SQL SQL query string (may contain glue placeholders)
#' @param dsn ODBC DSN name (string)
#' @param uid Optional user id (if not resolved by DSN)
#' @param pwd Optional password (if not resolved by DSN)
#' @param database, schema, role, warehouse Optional Snowflake session defaults
#' @param timezone Server time zone for the connection (default: Sys.timezone())
#' @param timezone_out R timezone for returned datetimes (default: Sys.timezone())
#' @param glue_envir Environment for glue interpolation (default: parent.frame())
#' @param ... Additional arguments passed to `DBI::dbConnect()`
#'
#' @return data.table with attribute `snowflake-sources`
#' 
#' @seealso \code{\link{SnowflakeConnector}} for persistent sessions, transactions, and writes.
#' 
#' @examples
#' \dontrun{
#' dt <- snowflake_get_query_dsn(
#'   "SELECT CURRENT_ROLE(), 
#'   CURRENT_WAREHOUSE(), 
#'   CURRENT_DATABASE(), 
#'   CURRENT_SCHEMA()"
#' , dsn = "snowflake-bi")
#' }
#' @noRd
snowflake_get_query_dsn <- function(
    SQL,
    dsn,
    uid = NULL,
    pwd = NULL,
    database = NULL,
    schema = NULL,
    role = NULL,
    warehouse = NULL,
    timezone = Sys.timezone(),
    timezone_out = Sys.timezone(),
    glue_envir = parent.frame(1L),
    ...
) {
  con <- DBI::dbConnect(
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
  on.exit(try(DBI::dbDisconnect(con), silent = TRUE), add = TRUE)
  
  stmt <- glue::glue_sql(SQL, .con = con, .envir = glue_envir)
  dt <- data.table::as.data.table(DBI::dbGetQuery(con, stmt))
  data.table::setattr(dt, "snowflake-sources",
                      paste(sqlQuerySources(SQL), collapse = ", "))
  dt
}
