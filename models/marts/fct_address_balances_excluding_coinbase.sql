{{ config(materialized="table") }}

-- Start from the curated 3-month staging layer to keep cost bounded
-- and centralize filtering logic in a single upstream model.
with tx as (
    select *
    from {{ ref("stg_bch_transactions") }}
),

-- Outputs represent value received by addresses, so they are credits.
-- We unnest outputs and their nested addresses to get one row per address movement.
credits as (
    select
        address,
        cast(output.value as bignumeric) as amount
    from tx
    cross join unnest(outputs) as output
    cross join unnest(output.addresses) as address
),

-- Inputs represent value spent by addresses, so they are debits.
-- We store them as negative amounts to enable a single SUM later.
debits as (
    select
        address,
        -cast(input.value as bignumeric) as amount
    from tx
    cross join unnest(inputs) as input
    cross join unnest(input.addresses) as address
),

-- Unified address-level movement stream: positive (credits) + negative (debits).
movements as (
    select * from credits
    union all
    select * from debits
),

-- Net balance per address over the selected 3-month window.
balances as (
    select
        address,
        sum(amount) as current_balance
    from movements
    group by address
),

-- Identify addresses that appear in at least one coinbase transaction.
-- These addresses are excluded per challenge requirement.
coinbase_addresses as (
    select distinct address
    from tx
    cross join unnest(outputs) as output
    cross join unnest(output.addresses) as address
    where is_coinbase
)

-- Final mart: balances excluding any address linked to coinbase transactions.
select
    b.address,
    b.current_balance
from balances b
left join coinbase_addresses c
    on b.address = c.address
where c.address is null
