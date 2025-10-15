testthat::test_that("query logger records success and failure", {
  logger <- snowflakeR:::SnowflakeQueryLogger$new()
  logger$log_success("SELECT 1")
  logger$log_failure("SELECT 2", "boom")
  history <- logger$get_history()

  testthat::expect_s3_class(history, "data.table")
  testthat::expect_equal(nrow(history), 2L)
  testthat::expect_setequal(
    history$status,
    factor(c("passed", "failed"), levels = c("passed", "failed"))
  )
})


testthat::test_that("lineage tracker decorates result", {
  tracker <- snowflakeR:::SnowflakeLineageTracker$new()
  data <- data.frame(x = 1)
  res <- tracker$add_lineage(data, "SELECT 1")
  testthat::expect_true(data.table::is.data.table(res))
  testthat::expect_false(is.null(attr(res, "snowflake-sources")))
})


testthat::test_that("SQL API client builds payload and calls hooks", {
  recorded <- list()
  fake_request <- function(url) {
    recorded$url <<- url
    structure(list(url = url), class = "fake_request")
  }
  fake_headers <- function(req, ...) {
    req$headers <- list(...)
    req
  }
  fake_body <- function(req, body) {
    req$body <- body
    req
  }
  fake_timeout <- function(req, seconds) {
    req$timeout <- seconds
    req
  }
  fake_perform <- function(req) {
    recorded$performed <<- req
    list()
  }
  fake_parse <- function(resp, simplifyVector = TRUE) {
    list(simplify = simplifyVector, ok = TRUE)
  }

  testthat::with_mocked_bindings({
    client <- SnowflakeSQLAPIClient$new(
      account = "xy12345",
      token = "TOKEN",
      warehouse = "WH",
      database = "DB",
      schema = "SCHEMA",
      role = "ROLE",
      request_factory = fake_request,
      perform_request = fake_perform,
      parse_response = fake_parse
    )
    out <- client$submit_statement(
      "SELECT 1",
      parameters = list(id = list(type = "FIXED", value = 1)),
      async = TRUE
    )
    testthat::expect_true(out$ok)
    testthat::expect_equal(
      recorded$url,
      "https://xy12345.snowflakecomputing.com/api/v2/statements"
    )
    testthat::expect_equal(
      recorded$performed$headers$Authorization,
      "Bearer TOKEN"
    )
    testthat::expect_equal(recorded$performed$body$binds[[1]]$type, "FIXED")
    testthat::expect_true(recorded$performed$body$asynchronous)
  },
  httr2::req_headers = fake_headers,
  httr2::req_body_json = fake_body,
  httr2::req_timeout = fake_timeout)
})


testthat::test_that("SQL API client enforces token", {
  client <- SnowflakeSQLAPIClient$new(account = "xy12345")
  testthat::expect_error(
    client$submit_statement("SELECT 1"),
    "Set a Snowflake SQL API token"
  )
  client$set_token("abc")
  testthat::expect_equal(client$token, "abc")
})


testthat::test_that("connector exposes read-only active bindings", {
  fake_conn <- structure(list(), class = "FakeConnection")
  testthat::with_mocked_bindings({
    connector <- SnowflakeConnector$new(dsn = "demo")
    testthat::expect_s3_class(connector$connection, "FakeConnection")
    testthat::expect_s3_class(connector$run_query_history, "data.table")
    testthat::expect_error(connector$connection <- fake_conn, "read-only")
    testthat::expect_error(connector$run_query_history <- data.table::data.table(), "read-only")
  },
  DBI::dbConnect = function(drv, ...) { fake_conn },
  DBI::dbDisconnect = function(conn) { invisible(TRUE) },
  DBI::dbIsValid = function(conn) TRUE,
  odbc::odbc = function() structure(list(), class = "ODBCDriver"))
})
