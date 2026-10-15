-- Tableau Prep flow: L02 - Birthdays
-- Flow LUID: 88214647-36b8-4486-82f2-0ee24b401f2a
-- Output data source: L03 - Birthdays DS
-- Created by Autom8 on 2026-10-15 10:19
{{ config(materialized='view') }}

with

rpt_birthday_anniversary as (
    select * from {{ source('client_inh_reporting', 'rpt_birthday_anniversary') }}
),

import_rpt_birthday_anniversary as (
    select
        "First Name" as first_name,
        "Last Name" as last_name,
        "Status" as status,
        "Member Type" as member_type,
        "Anniversary or Birthday" as anniversary_or_birthday,
        "Raw Date" as raw_date
    from rpt_birthday_anniversary
),

-- Container: Group and filter
-- Remap 'Core ' to 'Core' on member_type
clean_2 as (
    select
        first_name,
        last_name,
        status,
        case
            when member_type in ('Core', 'Core ') then 'Core'
            else member_type
        end as member_type,
        anniversary_or_birthday,
        raw_date
    from import_rpt_birthday_anniversary
),

-- Exclude rows where status = 'Inactive' (keep nulls)
exclude_status_inactive as (
    select *
    from clean_2
    where status is distinct from 'Inactive'
),

-- Keep only rows where anniversary_or_birthday = 'BIRTHDAY_DATE'
keep_only_birthday_date as (
    select *
    from exclude_status_inactive
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
    from keep_only_birthday_date
)

select * from final