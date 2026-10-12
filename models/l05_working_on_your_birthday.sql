-- Tableau Prep flow: L04 - Working on your Birthday
-- Flow LUID: c54920d0-f919-423b-bef6-b5c47dd39b23
-- Output data source: L05 - Working on your Birthday
-- Created by Autom8 on 2026-10-12 17:30
{{ config(materialized='view') }}

with l03_planning_detailed_ds_example_content as (
    select * from {{ ref('l03_planning_detailed_ds') }}
),

-- Input action "Remove Deal Type + 79 more" (and 4 other removals): keep only the remaining columns
planning_kept_columns as (
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
    from l03_planning_detailed_ds_example_content
),

cheat_for_match as (
    select
        planning.*,
        dateadd(day, 2, planning.engagement_date)::date as engagement_date_for_match
    from planning_kept_columns as planning
),

l03_birthdays_ds_example_content as (
    select * from {{ ref('l03_birthdays_ds') }}
),

clean_1 as (
    select
        birthdays.*,
        lower(birthdays.first_name) || '.' || lower(birthdays.last_name) as username,
        dateadd(year, 26, birthdays.raw_date)::date as birthday_in_2026
    from l03_birthdays_ds_example_content as birthdays
),

join_1 as (
    select
        planning.*,
        birthdays.anniversary_or_birthday,
        birthdays.first_name,
        birthdays.last_name,
        birthdays.member_type,
        birthdays.raw_date,
        birthdays.status,
        birthdays.username as username_1,
        birthdays.birthday_in_2026
    from cheat_for_match as planning
    inner join clean_1 as birthdays
        on planning.username = birthdays.username
        and planning.engagement_date_for_match = birthdays.birthday_in_2026
),

-- Remove "Engagement Date", then rename "Engagement Date for match" to "Engagement Date"
clean_2 as (
    select
        join_1.* exclude (engagement_date, engagement_date_for_match),
        join_1.engagement_date_for_match as engagement_date
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
