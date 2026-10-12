-- Tableau Prep flow: L00 - Hubspot Deals
-- Flow LUID: 2bcf5f5a-f0a3-4de7-adf2-abaacaa9c3b1
-- Output data source: L01 - HubSpot Deals DS
-- Created by Autom8 on 2026-10-12 14:49

{{ config(materialized='view') }}

with

rpt_dim_deal as (
    select * from {{ source('client_inh_datamart', 'rpt_dim_deal') }}
),

rpt_fact_deal_detail as (
    select * from {{ source('client_inh_datamart', 'rpt_fact_deal_detail') }}
),

rpt_dim_deal_detail as (
    select * from {{ source('client_inh_datamart', 'rpt_dim_deal_detail') }}
),

clean_1 as (
    select
        "Deal HK" as deal_hk,
        "Deal ID" as deal_id,
        "Deal Name" as deal_name,
        "Deal Currency Code" as deal_currency_code,
        "Deal Type" as deal_type,
        "Notes For Invoicing" as notes_for_invoicing,
        "Tableau Order" as tableau_order,
        "Snowflake Order" as snowflake_order,
        "Fivetran Order" as fivetran_order,
        "Invoicing" as invoicing,
        "Close Date" as close_date,
        "Last Activity Date" as last_activity_date,
        "Deal Description" as deal_description,
        "Deal Pipeline" as deal_pipeline,
        "Current Stage" as current_stage,
        "Deal Entity" as deal_entity,
        upper("Deal Name") as deal_name_uppercase
    from rpt_dim_deal
),

dim_deal_to_fact_deal as (
    select
        clean_1.*,
        rpt_fact_deal_detail."Deal Detail HK" as deal_detail_hk,
        rpt_fact_deal_detail."Deal Detail Create Date" as deal_detail_create_date,
        rpt_fact_deal_detail."Deal HK" as deal_hk_1,
        rpt_fact_deal_detail."Customer HK" as customer_hk,
        rpt_fact_deal_detail."Owner HK" as owner_hk,
        rpt_fact_deal_detail."Quantity" as quantity,
        rpt_fact_deal_detail."Bill Rate" as bill_rate,
        rpt_fact_deal_detail."Deal Detail Amount" as deal_detail_amount,
        rpt_fact_deal_detail."Deal Detail Amount (EUR)" as deal_detail_amount_eur,
        rpt_fact_deal_detail."Deal Detail Amount (GBP)" as deal_detail_amount_gbp,
        rpt_fact_deal_detail."Deal Detail Discount" as deal_detail_discount,
        rpt_fact_deal_detail."Deal Detail Discount (EUR)" as deal_detail_discount_eur,
        rpt_fact_deal_detail."Deal Detail Discount (GBP)" as deal_detail_discount_gbp,
        rpt_fact_deal_detail."Deal Detail Discount Percentage" as deal_detail_discount_percentage,
        rpt_fact_deal_detail."Deal Detail Price" as deal_detail_price,
        rpt_fact_deal_detail."Deal Detail Price (EUR)" as deal_detail_price_eur,
        rpt_fact_deal_detail."Deal Detail Price (GBP)" as deal_detail_price_gbp,
        rpt_fact_deal_detail."Deal Detail Cost" as deal_detail_cost,
        rpt_fact_deal_detail."Deal Detail Cost (EUR)" as deal_detail_cost_eur,
        rpt_fact_deal_detail."Deal Detail Cost (GBP)" as deal_detail_cost_gbp,
        rpt_fact_deal_detail."Deal Detail Margin" as deal_detail_margin,
        rpt_fact_deal_detail."Deal Detail Margin (EUR)" as deal_detail_margin_eur,
        rpt_fact_deal_detail."Deal Detail Margin (GBP)" as deal_detail_margin_gbp,
        rpt_fact_deal_detail."Hours" as hours
    from clean_1
    inner join rpt_fact_deal_detail
        on clean_1.deal_hk = rpt_fact_deal_detail."Deal HK"
),

add_deal_detail as (
    select
        dim_deal_to_fact_deal.*,
        rpt_dim_deal_detail."Deal Detail HK" as deal_detail_hk_1,
        rpt_dim_deal_detail."Deal Detail ID" as deal_detail_id,
        rpt_dim_deal_detail."Deal Details" as deal_details,
        rpt_dim_deal_detail."Deal Detail Description" as deal_detail_description,
        rpt_dim_deal_detail."Currency" as currency,
        rpt_dim_deal_detail."Product Description" as product_description,
        rpt_dim_deal_detail."Category" as category,
        rpt_dim_deal_detail."Sub Category" as sub_category,
        rpt_dim_deal_detail."Vendor" as vendor,
        rpt_dim_deal_detail."Product" as product,
        rpt_dim_deal_detail."Additional Information" as additional_information,
        rpt_dim_deal_detail."Domain" as domain
    from dim_deal_to_fact_deal
    inner join rpt_dim_deal_detail
        on dim_deal_to_fact_deal.deal_detail_hk = rpt_dim_deal_detail."Deal Detail HK"
),

final as (
    select
        deal_hk,
        deal_id,
        deal_name,
        deal_currency_code,
        deal_type,
        notes_for_invoicing,
        tableau_order,
        snowflake_order,
        fivetran_order,
        invoicing,
        close_date,
        last_activity_date,
        deal_description,
        deal_pipeline,
        current_stage,
        deal_entity,
        deal_name_uppercase,
        deal_detail_hk,
        deal_detail_create_date,
        deal_hk_1,
        customer_hk,
        owner_hk,
        quantity,
        bill_rate,
        deal_detail_amount,
        deal_detail_amount_eur,
        deal_detail_amount_gbp,
        deal_detail_discount,
        deal_detail_discount_eur,
        deal_detail_discount_gbp,
        deal_detail_discount_percentage,
        deal_detail_price,
        deal_detail_price_eur,
        deal_detail_price_gbp,
        deal_detail_cost,
        deal_detail_cost_eur,
        deal_detail_cost_gbp,
        deal_detail_margin,
        deal_detail_margin_eur,
        deal_detail_margin_gbp,
        hours,
        deal_detail_hk_1,
        deal_detail_id,
        deal_details,
        deal_detail_description,
        currency,
        product_description,
        category,
        sub_category,
        vendor,
        product,
        additional_information,
        domain
    from add_deal_detail
)

select * from final