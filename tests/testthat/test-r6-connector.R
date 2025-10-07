testthat::test_that("R6 constructor exists", {
  testthat::expect_true(inherits(SnowflakeConnector, "R6ClassGenerator"))
})

testthat::test_that("Live connection optional test", {
  skip_live()
  dsn <- Sys.getenv("SNOWFLAKER_DSN", unset = NA_character_)
  testthat::skip_if(is.na(dsn), "Set SNOWFLAKER_DSN env var for live test")
  
  con <- SnowflakeConnector$new(dsn = dsn)
  out <- con$run_query("select 1 as x")
  testthat::expect_true(is.data.frame(out))
  testthat::expect_equal(out$x, 1)
  con$close()
})
