-- Tableau Prep flow: L04 - Working on your Birthday
-- Flow LUID: c54920d0-f919-423b-bef6-b5c47dd39b23
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-15 10:52
{{ config(materialized='view') }}

with import_planning_detailed as (
    select * from {{ ref('l03_planning_detailed_ds') }}
),

import_birthdays as (
    select * from {{ ref('l03_birthdays_ds') }}
),

-- Input actions: keep only needed columns from planning detailed
planning_input_cleaned as (
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

-- Cheat for match: add engagement_date_for_match
cheat_for_match as (
    select
        planning_input_cleaned.*,
        dateadd(day, 2, engagement_date)::date as engagement_date_for_match
    from planning_input_cleaned
),

-- Clean 1: add username and birthday_in_2026
clean_1 as (
    select
        import_birthdays.*,
        lower(first_name) || '.' || lower(last_name) as username,
        dateadd(year, 26, raw_date)::date as birthday_in_2026
    from import_birthdays
),

-- Join 1: inner join on username and engagement_date_for_match = birthday_in_2026
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
    from cheat_for_match as l
    inner join clean_1 as r
        on l.username = r.username
        and l.engagement_date_for_match = r.birthday_in_2026
),

-- Clean 2: remove original engagement_date, rename engagement_date_for_match to engagement_date
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
        planning_status,
        product_category,
        product_name,
        shortcode,
        username,
        week_number,
        engagement_date,
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