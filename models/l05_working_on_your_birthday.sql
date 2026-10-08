-- Tableau Prep flow: 
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-08 16:04

{{ config(materialized='view') }}

with

l03_planning_detailed_ds as (
  select * from {{ ref('l03_planning_detailed_ds') }}
),

-- Apply RemoveColumns actions from input node
planning_cleaned as (
  select
    customer_name,
    deal_id,
    deal_name,
    employee_email_address,
    employee_last_name,
    employee_member_type,
    employee_name,
    employee_team,
    engagement_code,
    engagement_date,
    planning_status,
    product_category,
    product_name,
    shortcode,
    username,
    week_number
  from l03_planning_detailed_ds
),

cheat_for_match as (
  select
    *,
    (engagement_date + interval '2 day')::date as engagement_date_for_match
  from planning_cleaned
),

l03_birthdays_ds as (
  select * from {{ ref('l03_birthdays_ds') }}
),

clean_1 as (
  select
    *,
    lower(first_name) || '.' || lower(last_name) as username,
    dateadd(year, 26, raw_date)::date as birthday_in_2026
  from l03_birthdays_ds
),

join_1 as (
  select
    cheat.*,
    clean_1.first_name,
    clean_1.last_name,
    clean_1.status,
    clean_1.member_type,
    clean_1.anniversary_or_birthday,
    clean_1.raw_date,
    clean_1.username as username_1,
    clean_1.birthday_in_2026
  from cheat_for_match as cheat
  inner join clean_1
    on cheat.username = clean_1.username
    and cheat.engagement_date_for_match = clean_1.birthday_in_2026
),

clean_2 as (
  select
    * exclude (engagement_date, engagement_date_for_match),
    engagement_date_for_match as engagement_date
  from join_1
),

final as (
  select
    customer_name,
    deal_id,
    deal_name,
    employee_email_address,
    employee_last_name,
    employee_member_type,
    employee_name,
    employee_team,
    engagement_code,
    planning_status,
    product_category,
    product_name,
    shortcode,
    week_number,
    username,
    engagement_date,
    first_name,
    last_name,
    status,
    member_type,
    anniversary_or_birthday,
    raw_date,
    username_1,
    birthday_in_2026
  from clean_2
)

select * from final