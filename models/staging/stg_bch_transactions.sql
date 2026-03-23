{{ config(materialized="table") }}

select *
from {{ source("crypto_bitcoin_cash", "transactions") }}
where block_timestamp >= timestamp_sub(current_timestamp(), interval 3 month)
