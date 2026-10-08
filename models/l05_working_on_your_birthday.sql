-- Tableau Prep flow: L04 - Working on your Birthday
-- Flow LUID: c54920d0-f919-423b-bef6-b5c47dd39b23
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-08

{{ config(materialized='view') }}

with l03_planning_detailed_ds as (
  select * from {{ ref('l03_planning_detailed_ds') }}
),

l03_birthdays_ds as (
  select * from {{ ref('l03_birthdays_ds') }}
),

cheat_for_match as (
  select
    *,
    date(dateadd(day, 2, engagement_date)) as engagement_date_for_match
  from l03_planning_detailed_ds
),

clean_1 as (
  select
    *,
    lower(first_name) || '.' || lower(last_name) as username,
    date(dateadd(year, 26, raw_date)) as birthday_in_2026
  from l03_birthdays_ds
),

join_1 as (
  select
    cheat.*,
    clean.anniversary_or_birthday,
    clean.first_name,
    clean.last_name,
    clean.member_type,
    clean.raw_date,
    clean.status,
    clean.username as username_1,
    clean.birthday_in_2026
  from cheat_for_match as cheat
  inner join clean_1 as clean
    on cheat.username = clean.username
    and cheat.engagement_date_for_match = clean.birthday_in_2026
),

clean_2 as (
  select
    customer_name,
    deal_id,
    deal_name,
    employee_email_address,
    employee_name,
    engagement_code,
    engagement_date_for_match as engagement_date,
    planning_status,
    product_category,
    product_name,
    shortcode,
    username,
    week_number,
    engagement_date_for_match,
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
    employee_name,
    engagement_code,
    engagement_date,
    planning_status,
    product_category,
    product_name,
    shortcode,
    username,
    week_number,
    engagement_date_for_match,
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