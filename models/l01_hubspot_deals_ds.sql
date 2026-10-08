-- Tableau Prep flow: L00 - Hubspot Deals
-- Flow LUID: 2bcf5f5a-f0a3-4de7-adf2-abaacaa9c3b1
-- Output data source: L01 - HubSpot Deals DS
-- Created by Autom8 on 2026-10-08

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
    "Deal Detail HK" as deal_detail_hk,
    "Deal Detail Create Date" as deal_detail_create_date,
    "Deal HK" as deal_hk_1,
    "Customer HK" as customer_hk,
    "Owner HK" as owner_hk,
    "Quantity" as quantity,
    "Bill Rate" as bill_rate,
    "Deal Detail Amount" as deal_detail_amount,
    "Deal Detail Amount (EUR)" as deal_detail_amount_eur,
    "Deal Detail Amount (GBP)" as deal_detail_amount_gbp,
    "Deal Detail Discount" as deal_detail_discount,
    "Deal Detail Discount (EUR)" as deal_detail_discount_eur,
    "Deal Detail Discount (GBP)" as deal_detail_discount_gbp,
    "Deal Detail Discount Percentage" as deal_detail_discount_percentage,
    "Deal Detail Price" as deal_detail_price,
    "Deal Detail Price (EUR)" as deal_detail_price_eur,
    "Deal Detail Price (GBP)" as deal_detail_price_gbp,
    "Deal Detail Cost" as deal_detail_cost,
    "Deal Detail Cost (EUR)" as deal_detail_cost_eur,
    "Deal Detail Cost (GBP)" as deal_detail_cost_gbp,
    "Deal Detail Margin" as deal_detail_margin,
    "Deal Detail Margin (EUR)" as deal_detail_margin_eur,
    "Deal Detail Margin (GBP)" as deal_detail_margin_gbp,
    "Hours" as hours
  from clean_1
  inner join rpt_fact_deal_detail
    on clean_1.deal_hk = rpt_fact_deal_detail."Deal HK"
),

add_deal_detail as (
  select
    dim_deal_to_fact_deal.*,
    "Deal Detail HK" as deal_detail_hk_1,
    "Deal Detail ID" as deal_detail_id,
    "Deal Details" as deal_details,
    "Deal Detail Description" as deal_detail_description,
    "Currency" as currency,
    "Product Description" as product_description,
    "Category" as category,
    "Sub Category" as sub_category,
    "Vendor" as vendor,
    "Product" as product,
    "Additional Information" as additional_information,
    "Domain" as domain
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