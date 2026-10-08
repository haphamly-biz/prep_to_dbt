-- Tableau Prep flow: L02 - Birthdays
-- Flow LUID: 88214647-36b8-4486-82f2-0ee24b401f2a
-- Output data source: L03 - Birthdays DS
-- Created by Autom8 on 2026-10-08

{{ config(materialized='view') }}

with

rpt_birthday_anniversary as (
  select * from {{ source('client_inh_reporting', 'rpt_birthday_anniversary') }}
),

rename_input as (
  select
    "First Name" as first_name,
    "Last Name" as last_name,
    "Status" as status,
    "Member Type" as member_type,
    "Anniversary or Birthday" as anniversary_or_birthday,
    "Raw Date" as raw_date
  from rpt_birthday_anniversary
),

group_and_filter as (
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
  from rename_input
  where status is distinct from 'Inactive'
    and anniversary_or_birthday = 'BIRTHDAY_DATE'
),

final as (
  select
    first_name,
    last_name,
    status,
    member_type,
    anniversary_or_birthday,
    raw_date
  from group_and_filter
)

select * from final