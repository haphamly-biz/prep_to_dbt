-- Tableau Prep flow: L04 - Working on your Birthday
-- Flow LUID: c54920d0-f919-423b-bef6-b5c47dd39b23
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-08 18:02

{{ config(materialized='view') }}

with

l03_planning_detailed_ds as (
  select * from {{ ref('l03_planning_detailed_ds') }}
),

planning_after_removals as (
  select
    customer_name,
    deal_id,
    deal_name,
    employee_email_address,
    employee_id,
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
    dateadd(day, 2, engagement_date)::date as engagement_date_for_match
  from planning_after_removals
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
    l.*,
    r.first_name,
    r.last_name,
    r.status,
    r.member_type,
    r.anniversary_or_birthday,
    r.raw_date,
    r.username as username_1,
    r.birthday_in_2026
  from cheat_for_match as l
  inner join clean_1 as r
    on l.username = r.username
    and l.engagement_date_for_match = r.birthday_in_2026
),

clean_2 as (
  select
    customer_name,
    deal_id,
    deal_name,
    employee_email_address,
    employee_id,
    employee_name,
    employee_team,
    engagement_code,
    engagement_date_for_match as engagement_date,
    planning_status,
    product_category,
    product_name,
    shortcode,
    username,
    week_number,
    first_name,
    last_name,
    status,
    member_type,
    anniversary_or_birthday,
    raw_date,
    username_1,
    birthday_in_2026
  from join_1
),

final as (
  select
    customer_name,
    deal_id,
    deal_name,
    employee_email_address,
    employee_id,
    employee_name,
    employee_team,
    engagement_code,
    engagement_date,
    planning_status,
    product_category,
    product_name,
    shortcode,
    username,
    week_number,
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