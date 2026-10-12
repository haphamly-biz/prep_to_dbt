-- Tableau Prep flow: L02 - Planning Detailed
-- Flow LUID: e33f5f84-f21d-4bc4-9575-a8f5a7751419
-- Output data source: L03 - Planning Detailed DS
-- Created by Autom8 on 2026-10-12 16:32
{{ config(materialized='view') }}

with l01_planning_ds as (
    select * from {{ ref('l01_planning_ds') }}
),

l01_hubspot_deals_ds as (
    select * from {{ ref('l01_hubspot_deals_ds') }}
),

join_1 as (
    -- inner join on Deal Detail Id (left) = Deal Detail ID (right); colliding right-side columns renamed
    select
        planning.*,
        hubspot.* exclude (deal_name, deal_type, deal_id, deal_detail_id),
        hubspot.deal_name as deal_name_1,
        hubspot.deal_type as deal_type_1,
        hubspot.deal_id as deal_id_2,
        hubspot.deal_detail_id as deal_detail_id_2
    from l01_planning_ds as planning
    inner join l01_hubspot_deals_ds as hubspot
        on planning.deal_detail_id = hubspot.deal_detail_id
),

final as (
    select
        customer_name,
        deal_close_date,
        deal_detail_id,
        deal_id,
        deal_name,
        deal_owner_name,
        deal_type,
        employee_birthday_date,
        employee_country,
        employee_email_address_1,
        employee_email_address,
        employee_end_date,
        employee_first_name,
        employee_full_name,
        employee_hk,
        employee_id,
        employee_id_2,
        employee_last_name,
        employee_member_type,
        employee_name,
        employee_role_1,
        employee_role,
        employee_start_date_1,
        employee_start_date,
        employee_status_1,
        employee_status,
        employee_team_1,
        employee_team,
        engagement_code,
        engagement_date,
        engagement_hours,
        first_available_date,
        hubspot_url,
        is_public_holiday,
        planning_status,
        product_category,
        product_name,
        reports_to,
        request_date,
        request_details,
        shortcode,
        tabmove,
        tabmove_2,
        username_1,
        username,
        week_number,
        additional_information,
        bill_rate,
        category,
        close_date,
        currency,
        current_stage,
        customer_hk,
        deal_currency_code,
        deal_description,
        deal_detail_amount_eur,
        deal_detail_amount_gbp,
        deal_detail_amount,
        deal_detail_cost_eur,
        deal_detail_cost_gbp,
        deal_detail_cost,
        deal_detail_create_date,
        deal_detail_description,
        deal_detail_discount_eur,
        deal_detail_discount_gbp,
        deal_detail_discount_percentage,
        deal_detail_discount,
        deal_detail_hk_1,
        deal_detail_hk,
        deal_detail_id_2,
        deal_detail_margin_eur,
        deal_detail_margin_gbp,
        deal_detail_margin,
        deal_detail_price_eur,
        deal_detail_price_gbp,
        deal_detail_price,
        deal_details,
        deal_entity,
        deal_hk_1,
        deal_hk,
        deal_id_2,
        deal_name_uppercase,
        deal_name_1,
        deal_pipeline,
        deal_type_1,
        domain,
        fivetran_order,
        hours,
        invoicing,
        last_activity_date,
        notes_for_invoicing,
        owner_hk,
        product_description,
        product,
        quantity,
        snowflake_order,
        sub_category,
        tableau_order,
        vendor
    from join_1
)

select * from final
