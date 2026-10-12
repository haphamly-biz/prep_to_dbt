-- dbt model generated from Tableau Prep flow

{{ config(materialized='view') }}

select * from {{ ref('l02_planning_detailed') }}