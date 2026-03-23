{{ config(materialized="table") }}

-- We anchor the 3-month window to the latest timestamp available
-- in the public dataset (instead of current_date) so the model
-- remains stable even if the source data is not updated recently.
with latest as (
    select max(block_timestamp) as max_ts
    from {{ source("crypto_bitcoin_cash", "transactions") }}
)

-- Keep only transactions from the last 3 months relative to max_ts.
-- This satisfies the challenge scope while reducing query cost.
select t.*
from {{ source("crypto_bitcoin_cash", "transactions") }} t
cross join latest
where t.block_timestamp >= timestamp(date_sub(date(latest.max_ts), interval 3 month))
