{{ config(materialized="table") }}

select *
from {{ source("crypto_bitcoin_cash", "transactions") }}
where block_timestamp >= timestamp(date_sub(current_date(), interval 3 month))
