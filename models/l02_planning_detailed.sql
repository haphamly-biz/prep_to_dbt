-- Tableau Prep flow: L02 - Planning Detailed
-- Flow LUID: e33f5f84-f21d-4bc4-9575-a8f5a7751419
-- Output data source: L03 - Planning Detailed DS

{{ config(materialized='view') }}

with

l01_planning_ds as (
  select * from {{ ref('l01_planning_ds') }}
),

l01_hubspot_deals_ds as (
  select * from {{ ref('l01_hubspot_deals_ds') }}
),

final as (
  select * from l01_planning_ds
)

select * from final