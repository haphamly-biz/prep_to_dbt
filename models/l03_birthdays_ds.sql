-- Tableau Prep flow: L02 - Birthdays
-- Flow LUID: 88214647-36b8-4486-82f2-0ee24b401f2a
-- Output data source: L03 - Birthdays DS
-- Created by Autom8 on 2026-10-12 16:57
{{ config(materialized='view') }}

with rpt_birthday_anniversary as (
    select * from {{ source('client_inh_reporting', 'rpt_birthday_anniversary') }}
),

clean_2 as (
    select
        "First Name" as first_name,
        "Last Name" as last_name,
        "Status" as status,
        -- Remap: 'Core ' (trailing space) is merged into 'Core'
        case when "Member Type" in ('Core', 'Core ') then 'Core' else "Member Type" end as member_type,
        "Anniversary or Birthday" as anniversary_or_birthday,
        "Raw Date" as raw_date
    from rpt_birthday_anniversary
),

exclude_status_inactive_1 as (
    select * from clean_2
    where status is distinct from 'Inactive'
),

keep_only_anniversary_or_birthday_birthday_date_1 as (
    select * from exclude_status_inactive_1
    where anniversary_or_birthday = 'BIRTHDAY_DATE'
),

final as (
    select
        first_name,
        last_name,
        status,
        member_type,
        anniversary_or_birthday,
        raw_date
    from keep_only_anniversary_or_birthday_birthday_date_1
)

select * from final
