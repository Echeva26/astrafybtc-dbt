{{ config(materialized="table") }}

with latest as (
    select max(block_timestamp) as max_ts
    from {{ source("crypto_bitcoin_cash", "transactions") }}
)

select t.*
from {{ source("crypto_bitcoin_cash", "transactions") }} t
cross join latest
where t.block_timestamp >= timestamp(date_sub(date(latest.max_ts), interval 3 month))
