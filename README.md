# Astrafy Take-Home Challenge: dbt + CI (Bitcoin Cash)

This repository contains the dbt and CI implementation for the coding part of the Astrafy take-home challenge.  
It transforms Bitcoin Cash blockchain data from BigQuery public datasets into analytics-ready models, and validates every pull request through GitHub Actions.

## Project Goals

- Build a `staging` model from `bigquery-public-data.crypto_bitcoin_cash.transactions`.
- Build a `mart` model with address-level balances.
- Exclude addresses that appear in at least one coinbase transaction.
- Keep transformations cost-aware by using a 3-month window.
- Run `dbt run` and `dbt test` automatically on PRs.

## End-to-End Data Flow

1. **Raw source**
   - Declared in `models/sources.yml`.
   - Source table: `bigquery-public-data.crypto_bitcoin_cash.transactions`.

2. **Staging model**
   - File: `models/staging/stg_bch_transactions.sql`.
   - Computes `max(block_timestamp)` from the source and filters the last 3 months relative to that value.
   - This avoids empty outputs when the public dataset is not updated up to the current date.

3. **Mart model**
   - File: `models/marts/fct_address_balances_excluding_coinbase.sql`.
   - Uses the staging model as input (`ref("stg_bch_transactions")`).
   - Unnests `outputs` to build positive movements (credits).
   - Unnests `inputs` to build negative movements (debits).
   - Aggregates movements to calculate net balance per address.
   - Removes any address associated with a coinbase transaction.

4. **Data quality tests**
   - Defined in:
     - `models/staging/schema.yml`
     - `models/marts/schema.yml`
   - Includes checks such as `not_null` and `unique`.

## SQL Logic Summary

### `stg_bch_transactions.sql`

- Purpose: create a clean 3-month transaction slice for downstream models.
- Key design choice: anchor the time window to the **latest available source timestamp**, not `current_date()`.
- Benefit: consistent behavior even when source refresh is delayed.

### `fct_address_balances_excluding_coinbase.sql`

- Purpose: produce address-level balances excluding coinbase-linked addresses.
- Method:
  - `outputs` -> credits (positive values)
  - `inputs` -> debits (negative values)
  - `credits UNION ALL debits` -> movement stream
  - `SUM(amount) BY address` -> net balance
  - anti-join against coinbase addresses -> final result

> Note: `current_balance` is a **net balance within the selected 3-month window**, not a full historical blockchain balance.

## Macro Behavior

- File: `macros/generate_schema_name.sql`
- Why it exists:
  - dbt default schema naming can concatenate schema names (for example `target_schema_customschema`).
  - In BigQuery this may lead to unintended datasets and permission errors.
- What this macro does:
  - Forces dbt to use the exact configured schema (`staging` or `mart`) without extra suffixes.
- Result:
  - Models are materialized exactly in the Terraform-provisioned datasets.

## CI Pipeline (GitHub Actions)

Workflow: `.github/workflows/dbt-ci.yml`

Triggers:
- `pull_request` (`opened`, `synchronize`, `reopened`, `ready_for_review`)
- `workflow_dispatch` (manual run)

Execution steps:
1. Validate required secrets.
2. Authenticate to GCP via service account JSON.
3. Generate dbt profile for CI target.
4. Run:
   - `dbt deps`
   - `dbt run`
   - `dbt test`

## Required Secrets

- `GCP_SERVICE_ACCOUNT_KEY`: full service account JSON content.
- `GCP_PROJECT_ID`: target GCP project ID.
- `DBT_STAGING_DATASET`: staging dataset name (for example `staging`).
- `DBT_MART_DATASET`: mart dataset name (for example `mart`).

## Repository Structure

- `dbt_project.yml`
- `models/sources.yml`
- `models/staging/stg_bch_transactions.sql`
- `models/staging/schema.yml`
- `models/marts/fct_address_balances_excluding_coinbase.sql`
- `models/marts/schema.yml`
- `macros/generate_schema_name.sql`
- `.github/workflows/dbt-ci.yml`

## Requirements and Usage

Prerequisites:
- Python 3.10+ (3.11 recommended)
- `dbt-core` and `dbt-bigquery`
- GCP project, datasets, and service account created by the Terraform repo (`Task_2_terraform`)

Main commands:

```bash
dbt deps
dbt run
dbt test
```