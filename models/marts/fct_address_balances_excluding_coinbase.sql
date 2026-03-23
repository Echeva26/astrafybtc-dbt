{{ config(materialized="table") }}

with tx as (
    select *
    from {{ ref("stg_bch_transactions") }}
),

credits as (
    select
        address,
        cast(output.value as bignumeric) as amount
    from tx
    cross join unnest(outputs) as output
    cross join unnest(output.addresses) as address
),

debits as (
    select
        address,
        -cast(input.value as bignumeric) as amount
    from tx
    cross join unnest(inputs) as input
    cross join unnest(input.addresses) as address
),

movements as (
    select * from credits
    union all
    select * from debits
),

balances as (
    select
        address,
        sum(amount) as current_balance
    from movements
    group by address
),

coinbase_addresses as (
    select distinct address
    from tx
    cross join unnest(outputs) as output
    cross join unnest(output.addresses) as address
    where is_coinbase
)

select
    b.address,
    b.current_balance
from balances b
left join coinbase_addresses c
    on b.address = c.address
where c.address is null
