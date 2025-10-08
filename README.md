
# snowflakeR

> Lightweight **R6** Connector & helpers for **Snowflake** over **ODBC**.

- **No YAML**: credentials are **not** read from files; use your **DSN** and/or pass `uid`, `pwd`, etc.
- **Safe SQL**: `glue::glue_sql()` with `.con` binds parameters safely.
- **Lineage**: each result gets a `data.table` attribute `"snowflake-sources"` listing objects seen in SQL (`FROM`/`JOIN`/`CALL`).
- **Transactions**: begin/commit/rollback helpers.
- **Dev-friendly**: works smoothly with `devtools::load_all()` and `devtools::document()`.

## Installation

```r
# Recommended
install.packages("remotes")
remotes::install_github("Patrikios/snowflakeR", build_vignettes = FALSE)

# or with devtools
# install.packages("devtools")
devtools::install_github("Patrikios/snowflakeR", build_vignettes = FALSE)
```

## Requirements

- Snowflake ODBC driver installed and a working DSN on your machine: [Snowflake ODBC Documentation](https://docs.snowflake.com/en/developer-guide/odbc/odbc)

The R6 Class `SnowflakeConnector` accepts connection parameters as found in [ODBC Connection Configuration page](https://docs.snowflake.com/en/developer-guide/odbc/odbc-parameters).

- A Snowflake user with access to your role/warehouse/db/schema.

- R ≥ 4.1

This package deliberately does not parse YAML files or manage secrets.
Keep secrets in the DSN, environment variables, or pass them as arguments.

## Quick start

```r
library(snowflakeR)

# R6 connector
# New SnowflakeConnector instance using key-pair authentication.
# Key-pair authentication (AUTHENTICATOR = "SNOWFLAKE_JWT") disregards the 
# password field and uses the 'PRIV_KEY_FILE' file path to the private key (for
# example file name for the provate key could be 'rsa_key.p8' saved in 
# directory 'keys' in user's home folder).
# read more on Snowflake's key-pair authentication at https://docs.snowflake.com/en/user-guide/key-pair-auth

key_path <- "~/keys/rsa_key.p8"
con <- SnowflakeConnector$new(
  dsn           = "your-snowflake-dsn",
  uid           = "your-snowflake-user",
  role          = "your-snowflake-role",
  warehouse     = "your-snowflake-warehouse",
  database      = "your-snowflake-database",
  schema        = "your-snowflake-schema"
  tz            = "Europe/Berlin",
  tz_out        = "Europe/Berlin",
  AUTHENTICATOR = "SNOWFLAKE_JWT",
  PRIV_KEY_FILE = key_path
)

# run query 1, return data.table object
con$run_query("show tables")

# get a table
res <- con$run_query("SELECT * FROM your_schema.your_table LIMIT 100")

# returns data.table object
str(res)

# automatic parses the sources that were queried within statement
attr(res, "snowflake-sources")

# show query history on the connection
con$run_query_history


# Parameterized, safely interpolated query
min_id <- 1000
res <- con$run_query(
  "SELECT * FROM your_schema.your_table WHERE id > {min_id} LIMIT 100"
  )
str(res)
attr(res, "snowflake-sources")

# Write data
con$write_data(
  DBI::Id(schema = "STAGE", table = "TMP_UPLOAD"), 
  value = res, 
  overwrite = TRUE
  )

# Transactions
con$transaction_begin()
# ... your dbExecute/dbWriteTable calls ...
con$transaction_commit()
# or con$transaction_rollback()

# Close
con$close()
```

## Usage patterns

### 1) Safe parameter interpolation

```r
country <- "DE"
since   <- as.POSIXct("2025-01-01", tz = "UTC")

con$run_query("
  SELECT country, COUNT(*) AS n
  FROM sales.orders
  WHERE country = {country}
    AND created_at >= {since}
  GROUP BY country
")
```

### 2) Switching context (role/db/schema/warehouse)

Prefer doing this in the DSN. If needed, pass other context in the constructor,
give the user has rights to use the selected objects and roles:

```r
SnowflakeConnector$new(
  dsn = "snowflake-dsn",
  role = "DATA_SCIENTIST",
  warehouse = "COMPUTE_WH",
  database = "ANALYTICS",
  schema = "PUBLIC"
  ...
)
```

### 3) Writing efficiently

For bulk loads, prefer staging + COPY INTO in your SQL. For small/medium frames:

```r
con$write_data(
  DBI::Id(schema = "UTIL", table = "SMALL_LOAD"), 
  mtcars, 
  overwrite = TRUE
  )
```

### Development

```r
# 1) Load dev helpers
devtools::load_all()

# 2) Generate docs
devtools::document()

# 3) Run tests (live tests are opt-in)
testthat::test_local()           # unit tests
Sys.setenv(SNOWFLAKER_RUN_LIVE = "true", SNOWFLAKER_DSN = "snowflake-data-science")
testthat::test_file("tests/testthat/test-r6-connector.R")
```

### Testing strategy

Unit tests cover pure helpers (sqlQuerySources, etc.) without Snowflake.

Live tests are skipped by default; enable with env var
SNOWFLAKER_RUN_LIVE=true and provide SNOWFLAKER_DSN.


### FAQ

**Q**: **Where do credentials come from?**  
**A**: *From your ODBC DSN and/or arguments (uid, pwd). We don’t read YAML.*

**Q**: **How do I use key-pair auth?**  
**A**: *Configure it in the DSN / driver settings (outside this package) or pass the*
*relevant connect arguments supported by odbc/Snowflake (e.g. authenticator,*
*priv_key_file) directly to SnowflakeConnector$new(..., authenticator="SNOWFLAKE_JWT", priv_key_file="...").*
*This package forwards ... to DBI::dbConnect().*

**Q**: **Can I interpolate identifiers?**  
**A**: *Use DBI::Id(schema="...", table="...") for write targets; for dynamic*
*identifiers in SELECTs, build strings carefully or use glue::glue_sql() with*
*SQL objects. Keep it safe.*

### License

MIT + file LICENSE
