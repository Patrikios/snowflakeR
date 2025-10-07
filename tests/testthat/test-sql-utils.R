testthat::test_that("sqlQuerySources finds FROM and JOIN targets", {
  SQL <- "select * from DB.SCH.TBL a join DB.SCH.OTHER b on a.id=b.id"
  src <- snowflakeR:::sqlQuerySources(SQL)
  testthat::expect_true(any(grepl("DB.SCH.TBL", src)))
  testthat::expect_true(any(grepl("DB.SCH.OTHER", src)))
})

testthat::test_that("sqlQuerySources handles missing tokens", {
  SQL <- "select 1"
  src <- snowflakeR:::sqlQuerySources(SQL)
  testthat::expect_identical(src, "no_snowflake_sources_found")
})
