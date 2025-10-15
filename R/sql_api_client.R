#' SnowflakeSQLAPIClient: Prototype Snowflake SQL API client
#'
#' @description
#' `SnowflakeSQLAPIClient` offers an experimental, non-ODBC connectivity option
#' powered by the Snowflake SQL REST API. The client focuses on statement
#' submission and polling while leaving credential issuance (OAuth, key pair,
#' external browser) to the caller. Use this class to validate workloads before
#' promoting SQL API connectivity to production.
#'
#' @export
SnowflakeSQLAPIClient <- R6::R6Class(
  classname = "SnowflakeSQLAPIClient",
  public = list(
    #' @field account Snowflake account identifier (e.g. `xy12345.eu-central-1`).
    account = NULL,

    #' @field region Optional Snowflake region override used to build the host URL.
    region = NULL,

    #' @field warehouse Default warehouse for statements executed through the client.
    warehouse = NULL,

    #' @field database Default database for statements executed through the client.
    database = NULL,

    #' @field schema Default schema for statements executed through the client.
    schema = NULL,

    #' @field role Default role for statements executed through the client.
    role = NULL,

    #' @field token Session token or OAuth bearer token used for authentication.
    token = NULL,

    #' @description
    #' Create a new SQL API client. Provide a valid session token obtained via an
    #' approved authentication flow (e.g. OAuth, key pair SSO, external browser).
    #' Tokens are **not** persisted by the client.
    initialize = function(account, token = NULL, warehouse = NULL, database = NULL,
                          schema = NULL, role = NULL, region = NULL,
                          request_factory = httr2::request,
                          perform_request = httr2::req_perform,
                          parse_response = httr2::resp_body_json) {
      stopifnot(!missing(account))
      self$account <- account
      self$token <- token
      self$warehouse <- warehouse
      self$database <- database
      self$schema <- schema
      self$role <- role
      self$region <- region
      private$request_factory <- request_factory
      private$perform_request <- perform_request
      private$parse_response <- parse_response
    },

    #' @description
    #' Set or refresh the OAuth/session token.
    set_token = function(token) {
      self$token <- token
      invisible(self)
    },

    #' @description
    #' Execute a SQL statement via the Snowflake SQL API.
    #' @param SQL Statement to execute.
    #' @param parameters Optional list of named `value`/`type` pairs for bindings.
    #' @param async Logical; if `TRUE`, returns the response body without polling.
    #' @param timeout Request timeout in seconds when waiting for synchronous completion.
    submit_statement = function(SQL, parameters = NULL, async = FALSE, timeout = 60) {
      private$ensure_token()
      body <- private$build_request_body(SQL, parameters, async, timeout)
      req <- private$request_factory(private$endpoint("/api/v2/statements"))
      req <- httr2::req_headers(req, Authorization = paste("Bearer", self$token))
      req <- httr2::req_body_json(req, body)
      req <- httr2::req_timeout(req, timeout)

      resp <- private$perform_request(req)
      private$parse_response(resp, simplifyVector = TRUE)
    },

    #' @description
    #' Return the fully-qualified endpoint for custom API calls.
    #' @param path API path (e.g. `/api/v2/statements`).
    endpoint = function(path) {
      private$endpoint(path)
    }
  ),
  private = list(
    request_factory = NULL,
    perform_request = NULL,
    parse_response = NULL,

    ensure_token = function() {
      if (is.null(self$token) || !nzchar(self$token)) {
        stop("Set a Snowflake SQL API token with `$set_token()` before making requests", call. = FALSE)
      }
    },

    endpoint = function(path) {
      host <- if (is.null(self$region)) {
        sprintf("https://%s.snowflakecomputing.com", self$account)
      } else {
        sprintf("https://%s.%s.snowflakecomputing.com", self$account, self$region)
      }
      paste0(host, path)
    },

    build_request_body = function(SQL, parameters, async, timeout) {
      body <- list(
        statement = SQL,
        resultSetMetaData = list(format = "json"),
        warehouse = self$warehouse,
        database = self$database,
        schema = self$schema,
        role = self$role,
        timeout = timeout * 1000,
        asynchronous = isTRUE(async)
      )
      body <- Filter(function(x) !is.null(x), body)

      if (!is.null(parameters)) {
        stopifnot(is.list(parameters))
        body$binds <- lapply(names(parameters), function(name) {
          value <- parameters[[name]]
          if (is.list(value) && all(c("type", "value") %in% names(value))) {
            list(name = name, type = value$type, value = value$value)
          } else {
            list(name = name, value = value)
          }
        })
      }
      body
    }
  )
)
