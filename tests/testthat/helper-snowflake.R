# Skip live tests unless explicitly enabled by env var
skip_live <- function() {
  testthat::skip_if_not(
    identical(Sys.getenv("SNOWFLAKER_RUN_LIVE"), "true"),
    "Set SNOWFLAKER_RUN_LIVE=true to run live Snowflake tests"
  )
}