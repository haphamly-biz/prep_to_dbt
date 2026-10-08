-- Tableau Prep flow: L04 - Working on your Birthday
-- Flow LUID: c54920d0-f919-423b-bef6-b5c47dd39b23
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-08

{{ config(materialized='view') }}

with l03_planning_detailed_ds_input as (
    select * from {{ ref('l03_planning_detailed_ds') }}
),

l03_birthdays_ds_input as (
    select * from {{ ref('l03_birthdays_ds') }}
),

cheat_for_match as (
    select
        customer_name,
        employee_email_address,
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
        dateadd(day, 2, engagement_date)::date as engagement_date_for_match
    from l03_planning_detailed_ds_input
),

clean_1 as (
    select
        anniversary_or_birthday,
        first_name,
        last_name,
        member_type,
        raw_date,
        status,
        lower(first_name) || '.' || lower(last_name) as username,
        dateadd(year, 26, raw_date)::date as birthday_in_2026
    from l03_birthdays_ds_input
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
        employee_email_address,
        employee_name,
        employee_team,
        engagement_code,
        engagement_date_for_match,
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
        birthday_in_2026,
        engagement_date_for_match as engagement_date
    from join_1
),

final as (
    select
        customer_name,
        employee_email_address,
        employee_name,
        employee_team,
        engagement_code,
        engagement_date_for_match,
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
        birthday_in_2026,
        engagement_date
    from clean_2
)

select * from final