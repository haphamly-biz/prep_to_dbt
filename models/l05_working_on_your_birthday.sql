-- Tableau Prep flow: L04 - Working on your Birthday
-- Flow LUID: c54920d0-f919-423b-bef6-b5c47dd39b23
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-15 15:36
{{ config(materialized='view') }}

with

import_planning_detailed as (
    select * from {{ ref('l03_planning_detailed_ds') }}
),

import_birthdays as (
    select * from {{ ref('l03_birthdays_ds') }}
),

-- Input actions: remove unused columns from planning detailed
planning_filtered as (
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

-- Cheat for match: add Engagement Date for match = Engagement Date + 2 days
cheat_for_match as (
    select
        *,
        dateadd(day, 2, engagement_date)::date as engagement_date_for_match
    from planning_filtered
),

-- Clean 1: add Username and Birthday in 2026 to birthdays
clean_1 as (
    select
        *,
        lower(first_name) || '.' || lower(last_name) as username,
        dateadd(year, 26, raw_date)::date as birthday_in_2026
    from import_birthdays
),

-- Join 1: inner join on Username and Engagement Date for match = Birthday in 2026
join_1 as (
    select
        l.*,
        r.first_name,
        r.last_name,
        r.status as status_col,  -- REVIEW: "status" is a reserved word
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

-- Clean 2: remove Engagement Date, rename Engagement Date for match to Engagement Date
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
        planning_status,
        product_category,
        product_name,
        shortcode,
        username,
        week_number,
        engagement_date_for_match as engagement_date,
        first_name,
        last_name,
        status_col,
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
        planning_status,
        product_category,
        product_name,
        shortcode,
        username,
        week_number,
        engagement_date,
        first_name,
        last_name,
        status_col,
        member_type,
        anniversary_or_birthday,
        raw_date,
        username_1,
        birthday_in_2026
    from clean_2
)

select * from final