% Generated manually (roxygen unavailable in CI sandbox)
\name{SnowflakeSQLAPIClient}
\alias{SnowflakeSQLAPIClient}
\title{SnowflakeSQLAPIClient: Prototype Snowflake SQL API client}
\description{
\code{SnowflakeSQLAPIClient} is an experimental R6 helper that talks to the Snowflake SQL REST API.
It targets workflows where the ODBC driver is unavailable (CI pipelines, restricted desktops) and
lets you validate statement execution with bearer tokens obtained through OAuth, key pair SSO, or
other supported authenticators.
}
\section{Public fields}{
\describe{
  \item{account}{Snowflake account identifier (for example, \code{xy12345.eu-central-1}).}
  \item{region}{Optional region suffix used when constructing the hostname.}
  \item{warehouse}{Default warehouse applied to submitted statements.}
  \item{database}{Default database applied to submitted statements.}
  \item{schema}{Default schema applied to submitted statements.}
  \item{role}{Default role applied to submitted statements.}
  \item{token}{Bearer token used for authentication (never persisted to disk).}
}
}
\section{Methods}{
\subsection{Public methods}{
\itemize{
  \item \code{SnowflakeSQLAPIClient$new(account, token = NULL, warehouse = NULL, database = NULL, schema = NULL, role = NULL, region = NULL, request_factory = httr2::request, perform_request = httr2::req_perform, parse_response = httr2::resp_body_json)}}
  \item \code{$set_token(token)}
  \item \code{$submit_statement(SQL, parameters = NULL, async = FALSE, timeout = 60)}
  \item \code{$endpoint(path)}
}
}
\details{
The client delegates authentication to the caller. Provide short-lived bearer tokens via \code{$set_token()}
and avoid writing tokens to disk. Responses are parsed with \code{httr2::resp_body_json()} by default but you can
inject custom request/response handlers when constructing the client to facilitate testing.
}
\examples{
\dontrun{
client <- SnowflakeSQLAPIClient$new(
  account = "xy12345",
  warehouse = "COMPUTE_WH",
  database = "ANALYTICS",
  schema = "PUBLIC"
)
client$set_token(Sys.getenv("SNOWFLAKE_SQLAPI_TOKEN"))
client$submit_statement("SELECT CURRENT_ROLE()", async = TRUE)
}
}
