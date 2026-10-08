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

-- Apply input node actions: remove 80 columns
l03_planning_detailed_ds_filtered as (
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
    week_number
  from l03_planning_detailed_ds
),

-- Cheat for match: add Engagement Date for match
cheat_for_match as (
  select
    *,
    dateadd(day, 2, engagement_date)::date as engagement_date_for_match
  from l03_planning_detailed_ds_filtered
),

-- Clean 1: add Username and Birthday in 2026
clean_1 as (
  select
    *,
    lower(first_name) || '.' || lower(last_name) as username,
    dateadd(year, 26, raw_date)::date as birthday_in_2026
  from l03_birthdays_ds
),

-- Join 1: inner join on Username and date match
join_1 as (
  select
    cheat.*,
    clean_1.anniversary_or_birthday,
    clean_1.first_name,
    clean_1.last_name,
    clean_1.member_type,
    clean_1.raw_date,
    clean_1.status,
    clean_1.username as username_1,
    clean_1.birthday_in_2026
  from cheat_for_match as cheat
  inner join clean_1
    on cheat.username = clean_1.username
    and cheat.engagement_date_for_match = clean_1.birthday_in_2026
),

-- Clean 2: remove original Engagement Date and rename Engagement Date for match
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