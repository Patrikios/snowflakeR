#' snowflakeR: Lightweight R6 Connector for Snowflake via ODBC
#'
#' @section Philosophy:
#' * Keep credentials outside the package (DSN / environment / call args).
#' * Keep usage simple (R6 with `$run_query()`, `$write_data()`, transactions).
#' * Keep strings safe using `glue::glue_sql()` (with `.con` binding).
#' * Attach SQL lineage with `data.table::setattr()`.
#'
#' @section Requirements:
#' You must have the Snowflake ODBC driver installed and working, and a DSN
#' configured on your system. The package does **not** read YAML config files.
#'
#' @keywords internal
"_PACKAGE"
