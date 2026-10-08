{{ config(materialized='table') }}

with source as (
    select
        close_date,
        deal_id,
        customer_name,
        current_stage,
        deal_detail_amount_eur
    from {{ ref('l03_planning_detailed_ds') }}
    where customer_name is not null
        and customer_name != ''
),

aggregated as (
    select
        close_date,
        deal_id,
        customer_name,
        current_stage,
        max(deal_detail_amount_eur) as deal_detail_amount_eur
    from source
    group by
        close_date,
        deal_id,
        customer_name,
        current_stage
)

select * from aggregated