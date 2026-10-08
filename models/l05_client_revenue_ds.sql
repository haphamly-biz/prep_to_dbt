-- Output data source: L05 - Client Revenue DS
-- Created by Autom8 on 2026-10-08 15:48

{{ config(materialized='view') }}

with l03_planning_detailed_ds as (
    select * from {{ ref('l03_planning_detailed_ds') }}
),

aggregate_1 as (
    select
        close_date,
        deal_id,
        customer_name,
        current_stage,
        max(deal_detail_amount_eur) as deal_detail_amount_eur
    from l03_planning_detailed_ds
    group by close_date, deal_id, customer_name, current_stage
),

clean_1 as (
    -- Exclude empty string Customer Name (keeps NULLs)
    select *
    from aggregate_1
    where customer_name is distinct from ''
),

final as (
    select
        close_date,
        deal_id,
        customer_name,
        current_stage,
        deal_detail_amount_eur
    from clean_1
)

select * from final