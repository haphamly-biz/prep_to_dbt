-- Tableau Prep flow: L04 - Working on your Birthday
-- Flow LUID: c54920d0-f919-423b-bef6-b5c47dd39b23
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-09 14:48

{{ config(materialized='view') }}

with l03_planning_detailed_ds as (
    select * from {{ ref('l03_planning_detailed_ds') }}
),

l03_birthdays_ds as (
    select * from {{ ref('l03_birthdays_ds') }}
),

-- Apply input actions: remove columns Username-1, Employee Role, Employee Start Date, Employee Status, and 80 more
planning_filtered as (
    select
        employee_name,
        employee_email_address,
        employee_team,
        deal_name,
        deal_id,
        product_name,
        product_category,
        planning_status,
        shortcode,
        engagement_code,
        week_number,
        customer_name,
        engagement_date,
        username
    from l03_planning_detailed_ds
),

-- Container: Cheat for match
cheat_for_match as (
    select
        *,
        dateadd(day, 2, engagement_date)::date as engagement_date_for_match
    from planning_filtered
),

-- Container: Clean 1
clean_1 as (
    select
        *,
        lower(first_name) || '.' || lower(last_name) as username,
        dateadd(year, 26, raw_date)::date as birthday_in_2026
    from l03_birthdays_ds
),

-- Join 1: inner join on Username and Engagement Date for match = Birthday in 2026
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

-- Container: Clean 2 - remove original Engagement Date, rename Engagement Date for match
clean_2 as (
    select
        employee_name,
        employee_email_address,
        employee_team,
        deal_name,
        deal_id,
        product_name,
        product_category,
        planning_status,
        shortcode,
        engagement_code,
        week_number,
        customer_name,
        username,
        engagement_date_for_match as engagement_date,
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
        employee_name,
        employee_email_address,
        employee_team,
        deal_name,
        deal_id,
        product_name,
        product_category,
        planning_status,
        shortcode,
        engagement_code,
        week_number,
        customer_name,
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