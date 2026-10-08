WITH planning_detailed AS (
    SELECT
        customer_name,
        deal_name,
        deal_id,
        engagement_code,
        engagement_date,
        planning_status,
        product_category,
        product_name,
        shortcode,
        username,
        week_number,
        employee_name,
        employee_email_address,
        employee_team,
        DATE(DATEADD('day', 2, engagement_date)) AS engagement_date_for_match
    FROM {{ ref('l03_planning_detailed_ds') }}
),

birthdays AS (
    SELECT
        anniversary_or_birthday,
        first_name,
        last_name,
        member_type,
        raw_date,
        status,
        LOWER(first_name) || '.' || LOWER(last_name) AS username,
        DATE(DATEADD('year', 26, raw_date)) AS birthday_in_2026
    FROM {{ source('example_content', 'l03_birthdays_ds') }}
),

working_on_birthday AS (
    SELECT
        p.customer_name,
        p.deal_name,
        p.deal_id,
        p.engagement_code,
        p.engagement_date_for_match AS engagement_date,
        p.planning_status,
        p.product_category,
        p.product_name,
        p.shortcode,
        p.username,
        p.week_number,
        p.employee_name,
        p.employee_email_address,
        p.employee_team,
        b.anniversary_or_birthday,
        b.first_name,
        b.last_name,
        b.member_type,
        b.raw_date,
        b.status,
        b.birthday_in_2026
    FROM planning_detailed p
    INNER JOIN birthdays b
        ON p.username = b.username
        AND p.engagement_date_for_match = b.birthday_in_2026
)

SELECT * FROM working_on_birthday