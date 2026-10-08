-- Tableau Prep flow: L00 - Planning
-- Flow LUID: 4abece76-eb9e-4f0e-a4c7-d97a6650c18a
-- Output data source: L01 - Planning DS
-- Created by Autom8 on 2026-10-08

{{ config(materialized='view') }}

with

rpt_planning as (
  select * from {{ source('client_inh_reporting', 'rpt_planning') }}
),

rpt_dim_employee as (
  select * from {{ source('client_inh_datamart', 'rpt_dim_employee') }}
),

last_52_weeks as (
  select
    `Engagement Date` as engagement_date,
    `Week Number` as week_number,
    `Employee Role` as employee_role,
    `Employee Name` as employee_name,
    `Employee Team` as employee_team,
    `Employee Id` as employee_id,
    `Employee Email Address` as employee_email_address,
    `Employee Start Date` as employee_start_date,
    `Employee Status` as employee_status,
    `Planning Status` as planning_status,
    `Engagement Code` as engagement_code,
    `Product Name` as product_name,
    `Product Category` as product_category,
    `Customer Name` as customer_name,
    `Shortcode` as shortcode,
    `Deal Id` as deal_id,
    `Deal Name` as deal_name,
    `Deal Type` as deal_type,
    `Deal Owner Name` as deal_owner_name,
    `Deal Close Date` as deal_close_date,
    `Deal Detail Id` as deal_detail_id,
    `Request Details` as request_details,
    `Request Date` as request_date,
    `Is Public Holiday` as is_public_holiday,
    `Engagement Hours` as engagement_hours,
    `First Available Date` as first_available_date,
    `Hubspot Url` as hubspot_url,
    `TABMOVE` as tabmove
  from rpt_planning
  where `Engagement Date` >= date_add(current_date(), -364) -- last 52 weeks
),

planning_username as (
  select
    *,
    left(employee_email_address, locate('@', employee_email_address) - 1) as username
  from last_52_weeks
),

employee_username as (
  select
    `Employee HK` as employee_hk,
    `Employee ID` as employee_id,
    `Employee Role` as employee_role,
    `Employee Full Name` as employee_full_name,
    `Employee First Name` as employee_first_name,
    `Employee Last Name` as employee_last_name,
    `Employee Email Address` as employee_email_address,
    `Employee Team` as employee_team,
    `Employee Birthday Date` as employee_birthday_date,
    `Employee Start Date` as employee_start_date,
    `Employee End Date` as employee_end_date,
    `Employee Country` as employee_country,
    `Employee Status` as employee_status,
    `Employee Member Type` as employee_member_type,
    `Tabmove` as tabmove,
    `Reports To` as reports_to,
    left(`Employee Email Address`, locate('@', `Employee Email Address`) - 1) as username
  from rpt_dim_employee
),

join_1 as (
  select
    planning_username.*,
    employee_username.employee_hk,
    employee_username.employee_id as employee_id_1,
    employee_username.employee_role as employee_role_1,
    employee_username.employee_full_name,
    employee_username.employee_first_name,
    employee_username.employee_last_name,
    employee_username.employee_email_address as employee_email_address_1,
    employee_username.employee_team as employee_team_1,
    employee_username.employee_birthday_date,
    employee_username.employee_start_date as employee_start_date_1,
    employee_username.employee_end_date,
    employee_username.employee_country,
    employee_username.employee_status as employee_status_1,
    employee_username.employee_member_type,
    employee_username.tabmove as tabmove_1,
    employee_username.reports_to
  from planning_username
  inner join employee_username
    on planning_username.username = employee_username.username
),

final as (
  select
    engagement_date,
    week_number,
    employee_role,
    employee_name,
    employee_team,
    employee_id,
    employee_email_address,
    employee_start_date,
    employee_status,
    planning_status,
    engagement_code,
    product_name,
    product_category,
    customer_name,
    shortcode,
    deal_id,
    deal_name,
    deal_type,
    deal_owner_name,
    deal_close_date,
    deal_detail_id,
    request_details,
    request_date,
    is_public_holiday,
    engagement_hours,
    first_available_date,
    hubspot_url,
    tabmove,
    username,
    employee_hk,
    employee_id_1,
    employee_role_1,
    employee_full_name,
    employee_first_name,
    employee_last_name,
    employee_email_address_1,
    employee_team_1,
    employee_birthday_date,
    employee_start_date_1,
    employee_end_date,
    employee_country,
    employee_status_1,
    employee_member_type,
    tabmove_1,
    reports_to
  from join_1
)

select * from final