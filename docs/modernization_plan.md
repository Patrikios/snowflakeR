# snowflakeR Modernization Plan

## 1. Current State Overview

- `SnowflakeConnector` encapsulates an ODBC connection via `DBI::dbConnect(odbc::odbc())`, offering query execution, write helpers, basic transaction support, and query history tracking through an R6 class.\
  (See `R/r6_snowflake_connection.R`.)
- `snowflake_get_query_dsn()` provides a convenience wrapper for one-off queries using the same ODBC connection path without instantiating the R6 class.\
  (See `R/connection_utils.R`.)
- Documentation emphasises DSN-driven configuration, safe SQL interpolation with `glue::glue_sql()`, lineage tagging of results, and assumes manual management of Snowflake credentials via DSNs or arguments.\
  (See `README.md`.)

## 2. Modernisation Goals

1. **Strengthen R6 Architecture**
   - Introduce private helpers for connection health checks, logging, and retry logic to reduce duplication.
   - Implement context managers (e.g., temporary role/schema switching) using R6 methods that automatically restore state.
   - Provide lifecycle hooks (pre-/post-query) to integrate observability and caching layers.

2. **Enhance Developer Experience**
   - Support structured configuration inputs (environment variables, `.Renviron`, keyring) with explicit opt-in to keep no-YAML stance but reduce boilerplate.
   - Offer consistent error classes with richer metadata (SQL state, error codes) to aid debugging and programmatic handling.
   - Add `dbplyr` translator integration so users can use `dplyr` verbs transparently.

3. **Improve Operational Capabilities**
   - Implement connection pooling and `with_transaction()` helpers for deterministic transaction scopes.
   - Add async / background query execution via `future` or `callr` for long-running Snowflake jobs.
   - Provide bulk load utilities (PUT/COPY) and staged file management wrappers.

4. **Testing & CI**
   - Expand unit tests with mocked DBI interfaces and add integration test harness gated behind environment flags.
   - Configure GitHub Actions for R CMD check, lintr, and pkgdown deployment.

## 3. Feature Roadmap Suggestions

- **Enhanced Query History**: persist run history beyond the session (e.g., write to configurable log sinks or R6-managed SQLite cache).
- **Schema Introspection**: add methods like `$list_tables()`, `$describe_table()` using Snowflake's `information_schema`.
- **Role/Context Guardrails**: implement `$with_context(role = ..., warehouse = ...)` using `ALTER SESSION` statements with automatic rollback on error.
- **Observability**: integrate optional tracing (OpenTelemetry, logging package) for query timings and status metrics.
- **Parameterized Stored Procedure Calls**: helper for `CALL` statements with argument validation.
- **Retry & Backoff**: resilience for transient network/warehouse suspension errors.

## 4. Alternatives to Pure ODBC Connectivity

- **Snowflake SQL API**: implement an HTTP client (e.g., using `httr2`) targeting Snowflake's SQL REST API for headless/serverless use without ODBC. Supports async polling and key-pair or OAuth authentication. Requires signing requests but removes DSN dependency.
- **Snowpark / Python Connector Interop**: integrate via `reticulate` to leverage the official `snowflake-connector-python` and Snowpark APIs (session management, DataFrame transformations) when ODBC drivers are unavailable.
- **JDBC Driver**: expose RJDBC-backed connection path as an alternative for environments where JDBC is approved but ODBC is not.
- **Upcoming Native Clients**: monitor Snowflake's announced Native App and Snowpark Container Services roadmap, which may surface REST or gRPC endpoints suited for direct R bindings.

## 5. Maintainer Backlog & Feedback Loop

| Priority | Theme | Description | Owner | Feedback Mechanism |
| --- | --- | --- | --- | --- |
| P0 | Architecture hardening | Finish modularising the R6 connector (connection manager, query executor, lineage/logging) and stabilise the automated test harness before shipping. | Core maintainers | Weekly triage call; track regressions in GitHub Projects "Connector" board. |
| P0 | Connectivity options | Validate the SQL API prototype with early adopters; define promotion criteria (performance parity, auth coverage, observability). | Maintainers + security steward | Dedicated GitHub Discussions thread and quarterly security review. |
| P1 | Developer experience | Implement structured configuration helpers and improved error classes; document migration guides in README/vignettes. | Maintainers | Monthly office hours; collect snippets from issue templates. |
| P2 | Operational tooling | Explore pooling, async execution, and enhanced logging integrations. Sequence work after SQL API MVP feedback. | Community contributors | Bi-monthly community sync; surveys embedded in pkgdown site. |
| P2 | Ecosystem integration | Investigate dbplyr/Snowpark interop once core refactor + SQL API are stable. | Maintainers + external partners | Coordinate via roadmap updates posted to `docs/` folder. |

### Feedback cadences

- **Monthly maintainer retro** (last Wednesday): prioritise backlog, assign owners, and review support metrics.
- **Quarterly user survey** distributed via pkgdown site and README badges to capture friction points (authentication, deployment, performance).
- **Issue templates** now include a "Pain point" checkbox so maintainers can tag recurring themes for follow-up.
- **Design Partner cohort** (2–3 power users) invited to test pre-release SQL API builds and share security/compliance requirements.

## 6. Action Plan

1. Prototype SQL API client to validate non-ODBC connectivity and document security implications.
2. Incrementally refactor R6 class to isolate concerns (connection, query execution, lineage, logging) for better testability.
3. Introduce automated CI pipelines and testing harness.
4. Update documentation and vignettes to highlight new capabilities and alternative connection modes.
5. Launch maintainer feedback loop (see Section 5) and publish quarterly summaries in `docs/status/`.

