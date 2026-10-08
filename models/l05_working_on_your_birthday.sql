-- Tableau Prep flow: 
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-08 15:50

{{ config(materialized='view') }}

with

import_planning_detailed as (
  select * from {{ ref('l03_planning_detailed_ds') }}
),

import_birthdays as (
  select * from {{ ref('l03_birthdays_ds') }}
),

-- Apply RemoveColumns actions from input node
planning_cleaned as (
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
  from import_planning_detailed
),

cheat_for_match as (
  select
    *,
    date(dateadd(day, 2, engagement_date)) as engagement_date_for_match
  from planning_cleaned
),

clean_1 as (
  select
    *,
    lower(first_name) || '.' || lower(last_name) as username,
    date(dateadd(year, 26, raw_date)) as birthday_in_2026
  from import_birthdays
),

join_1 as (
  select
    l.*,
    r.anniversary_or_birthday,
    r.first_name,
    r.last_name,
    r.member_type,
    r.raw_date,
    r.status,
    r.username as username_1,
    r.birthday_in_2026
  from cheat_for_match l
  inner join clean_1 r
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
    anniversary_or_birthday,
    first_name,
    last_name,
    member_type,
    raw_date,
    status,
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
    anniversary_or_birthday,
    first_name,
    last_name,
    member_type,
    raw_date,
    status,
    username_1,
    birthday_in_2026
  from clean_2
)

select * from final