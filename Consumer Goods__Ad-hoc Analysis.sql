/* Q1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region. */
SELECT
    DISTINCT market 
FROM  dim_customer
WHERE region='APAC' AND customer="Atliq Exclusive";


/* Q2. What is the percentage of unique product increase in 2021 vs. 2020? 
       The final output contains these fields, 
		- unique_products_2020 
            	- unique_products_2021 
            	- percentage_chg 
*/
WITH up20 as (
	    SELECT 
	        COUNT(DISTINCT product_code) as unique_products_2020
	    FROM fact_sales_monthly 
	    WHERE fiscal_year=2020),
     up21 as (
	    SELECT 
		COUNT(DISTINCT product_code) as unique_products_2021
	    FROM fact_sales_monthly 
	    WHERE fiscal_year=2021)

SELECT 
    up20.unique_products_2020,
    up21.unique_products_2021,
    ROUND((up21.unique_products_2021 - up20.unique_products_2020) / up20.unique_products_2020 * 100, 2) as percentage_change
FROM up20
CROSS JOIN up21;

   
/* Q3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
       The final output contains 2 fields, 
		- segment 
                - product_count 
*/
SELECT 
    segment,
    COUNT(DISTINCT product_code) as product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


/* Q4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
       The final output contains these fields, 
		- segment 
            	- product_count_2020 
            	- product_count_2021 
            	- difference 
*/
WITH UniqueProducts as (
        SELECT
	    p.segment,
            COUNT(DISTINCT CASE when s.fiscal_year = 2020 then s.product_code END) as unique_products_2020,
            COUNT(DISTINCT CASE when s.fiscal_year = 2021 then s.product_code END) as unique_products_2021
        FROM fact_sales_monthly s
        JOIN dim_product p 
	    ON s.product_code = p.product_code
        GROUP BY p.segment)

SELECT 
    segment,
    unique_products_2020,
    unique_products_2021,
    unique_products_2021 - unique_products_2020 as difference
FROM UniqueProducts
ORDER BY difference DESC;
    
    
/* Q5. Get the products that have the highest and lowest manufacturing costs. 
       The final output should contain these fields, 
		- product_code 
            	- product 
            	- manufacturing_cost 
*/
SELECT 
    m.product_code, 
    p.product, 
    m.manufacturing_cost
FROM fact_manufacturing_cost m
JOIN dim_product p 
    ON m.product_code = p.product_code
WHERE 
    manufacturing_cost = (SELECT min(manufacturing_cost) FROM fact_manufacturing_cost) or 
    manufacturing_cost = (SELECT max(manufacturing_cost) FROM fact_manufacturing_cost);


/* Q6. Generate a report which contains the top 5 customers who received an average high 
       pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
       The final output contains these fields,
		- customer_code
		- customer
		- average_discount_percentage 
*/ 
SELECT 
    c.customer_code,
    c.customer, 
    ROUND(AVG(pre_invoice_discount_pct),4) as average_discount_percentage
FROM fact_pre_invoice_deductions d
JOIN dim_customer c
    ON d.customer_code = c.customer_code
WHERE 
    c.market = "India" AND fiscal_year = "2021"
GROUP BY c.customer_code, c.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;


/* Q7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
       This analysis helps to get an idea of low and high-performing months and take strategic decisions.
       The final report contains these columns:
		- Month
		- Year
		- Gross sales Amount 
*/
WITH temp_table as (
	SELECT 
	    MONTH(s.date) as month_number,
            MONTHNAME(s.date) month,
	    YEAR(s.date) as year,
	    ROUND(SUM(s.sold_quantity * g.gross_price), 2) as gross_sales_amount
	FROM fact_sales_monthly s
	JOIN fact_gross_price g
	    ON s.product_code = g.product_code and
	       s.fiscal_year = g.fiscal_year
	JOIN dim_customer c 
	    ON s.customer_code = c.customer_code
	WHERE 
	    customer="Atliq exclusive"
	GROUP BY month, year, month_number
	ORDER BY year, month_number)
	
SELECT 
    month, 
    year, 
    gross_sales_amount
FROM temp_table;


/* Q8. In which quarter of 2020, got the maximum total_sold_quantity? 
       The final output contains these fields sorted by the total_sold_quantity,
		- Quarter
		- total_sold_quantity 
*/
WITH temp_table as (
	SELECT 
	    date,
            MONTH(DATE_ADD(date, INTERVAL 4 MONTH)) as period, 
            fiscal_year,
            sold_quantity 
	FROM fact_sales_monthly)
	
SELECT 
    CASE 
	when period/3 <= 1 then "Q1"
	when period/3 <= 2 and period/3 > 1 then "Q2"
	when period/3 <=3 and period/3 > 2 then "Q3"
	when period/3 <=4 and period/3 > 3 then "Q4" 
    END quarter,
    ROUND(SUM(sold_quantity)/1000000,2) as total_sold_quanity_in_mln 
FROM temp_table
WHERE fiscal_year = 2020
GROUP BY quarter
ORDER BY total_sold_quanity_in_mln DESC;


/* Q9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
       The final output contains these fields, 
		- channel 
                - gross_sales_mln 
                - percentage 
*/
WITH temp_table AS (
	SELECT 
	    c.channel,
            SUM(s.sold_quantity * g.gross_price) as total_sales
	FROM fact_sales_monthly s 
	JOIN fact_gross_price g 
	    ON s.product_code = g.product_code and
	       s.fiscal_year = g.fiscal_year
	JOIN dim_customer c 
	    ON s.customer_code = c.customer_code
	WHERE s.fiscal_year= 2021
	GROUP BY c.channel
	ORDER BY total_sales DESC)
	
SELECT 
  channel,
  ROUND(total_sales/1000000, 2) as gross_sales_in_mln,
  ROUND(total_sales/( SUM(total_sales) OVER() )*100, 2) as percentage_contribution
FROM temp_table;


/* Q10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
        The final output contains these fields, 
		- division 
                - product_code 
                - product 
                - total_sold_quantity 
                - rank_order 
*/
WITH temp_table as (
	SELECT 
	    p.division, 
            s.product_code, 
            CONCAT(p.product," (",p.variant,")") as product, 
            SUM(s.sold_quantity) as total_sold_quantity,
	    DENSE_RANK() OVER(PARTITION BY p.division ORDER BY SUM(s.sold_quantity) DESC) as rank_order
	FROM fact_sales_monthly s
	JOIN dim_product p
	    ON s.product_code = p.product_code
	WHERE fiscal_year = 2021
	GROUP BY division, s.product_code, product)
	
SELECT * FROM temp_table
WHERE rank_order <= 3;
