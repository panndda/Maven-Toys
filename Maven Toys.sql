
--create a view to join the required tables
CREATE VIEW toys AS (
    SELECT
        *
    FROM
        sales AS s
    LEFT JOIN products AS p 
	USING (product_id)
    LEFT JOIN stores AS st 
	USING (store_id)
    LEFT JOIN inventory AS i 
	USING (store_id, product_id));


--NO. 1a (Product category with highest profit)
SELECT
    product_category,
    SUM((product_price - product_cost) * units) AS profit
FROM
    toys
GROUP BY
    1
ORDER BY
    2 DESC;



--1b(Is this the same across all store locations?)
WITH product_profit AS (
    SELECT
        store_location,
        product_category,
        SUM((product_price - product_cost) * units) AS profit
    FROM
        toys
    GROUP BY
        1,2
    ORDER BY
        1,3 DESC
),
product_rank AS (
    SELECT
        store_location,
        product_category,
        profit,
        ROW_NUMBER() OVER (PARTITION BY store_location ORDER BY profit DESC) AS ranks
    FROM
        product_profit
)
SELECT
    store_location,
    product_category,
    profit
FROM
    product_rank
WHERE
    ranks = 1;



--2a alt (how much money is tied up in inventory at the toy stores?)
WITH cost_of_inventory AS (
    SELECT
        store_name,
        s.store_id,
        product_name,
        stock_on_hand * product_cost AS inventory_cost
    FROM
        inventory AS i
    LEFT JOIN stores AS s 
	ON i.store_id = s.store_id
    LEFT JOIN products AS p 
	ON i.product_id = p.product_id
)
SELECT
    store_id,
    store_name,
    SUM(inventory_cost) AS total_inventory
FROM
    cost_of_inventory
GROUP BY
    1,2
ORDER BY
    3



--2b. How long will the stocks last?
WITH daily_sale AS (
    SELECT
        date,
        store_id,
        SUM(units) AS daily_sale
    FROM
        sales
    GROUP BY
        1,2
    ORDER BY
        1,2
),
stocks AS (
    SELECT
        store_id,
        SUM(stock_on_hand) AS stock_remaining
    FROM
        inventory
    GROUP BY
        1
    ORDER BY
        1
),
avg_daily_sale AS (
    SELECT
        store_id,
        AVG(daily_sale) AS avg_daily_sale
    FROM
        daily_sale
    GROUP BY
        1
    ORDER BY
        1
)
SELECT
    store_id,
    store_name,
    CONCAT(ROUND(stock_remaining / avg_daily_sale), ' days') AS days
FROM
    avg_daily_sale
LEFT JOIN stocks 
USING (store_id)
LEFT JOIN stores 
USING (store_id)
ORDER BY
    ROUND(stock_remaining / avg_daily_sale);



--NO. 3(Are sales been lost at certain locations due to out of stock products?)
SELECT
    s.store_location,
    s.store_name,
    p.product_name,
    i.stock_on_hand
FROM
    inventory AS i
LEFT JOIN stores AS s 
ON s.store_id = i.store_id
LEFT JOIN products AS p 
ON p.product_id = i.product_id
WHERE
    i.stock_on_hand = 0;



--Which store location has the highest revenue contribution to the total sales?
SELECT
    store_location,
    SUM(product_price * units) AS revenue,
    CONCAT(ROUND((SUM(product_price * units) / 
               (SELECT
                    SUM(product_price * units)
                FROM sales AS s
            	LEFT JOIN products AS p 
				ON s.product_id = p.product_id)) * 100, 2), '%') AS revenue_contribution 
FROM
    sales AS s
LEFT JOIN stores AS st 
ON s.store_id = st.store_id
LEFT JOIN products AS p 
ON s.product_id = p.product_id
GROUP BY
    1
ORDER BY
    2 DESC;



--What is the average number of units sold per week for each product through the years?
SELECT
    year,
    product_id,
    product_name,
    ROUND(AVG(units))
FROM (
    SELECT
        product_id,
        EXTRACT(year FROM date) AS year,
        EXTRACT(week FROM date) AS week,
        SUM(units) AS units
    FROM
        sales
    GROUP BY
        1,2,3
    ORDER BY
        1,2,3) AS a
LEFT JOIN products 
USING (product_id)
GROUP BY
    2,3,1;



--Which store has the highest inventory turnover rate (units sold / stock on hand) in the inventory table?
WITH unit_sold AS (
    SELECT
        store_id,
        SUM(units) AS unit
    FROM
        sales AS s
    GROUP BY
        1
),
stock AS (
    SELECT
        store_id,
        SUM(stock_on_hand) AS stock
    FROM
        inventory
    GROUP BY
        1
)
SELECT
    u.store_id,
    st.store_name,
    (unit / stock) AS turnover
FROM
    unit_sold AS u
JOIN stock AS s 
ON u.store_id = s.store_id
JOIN stores AS st 
ON u.store_id = st.store_id
ORDER BY
	3 DESC;
	


--Top 5 selling Products by units
SELECT
    product_name,
    SUM(units) AS units_sold
FROM
    products
JOIN sales 
USING (product_id)
GROUP BY
    1
ORDER BY
    2 DESC
LIMIT 5;



--Which product categories have shown the highest growth in sales revenue over the past year?
SELECT
    product_category,
    SUM(product_price * units) FILTER (WHERE EXTRACT(year FROM date) = 2017) AS revenue_2017,
    SUM(product_price * units) FILTER (WHERE EXTRACT(year FROM date) = 2018) AS revenue_2018,
    CONCAT(ROUND(((SUM(product_price * units) FILTER (WHERE EXTRACT(year FROM date) = 2018) - 
	SUM(product_price * units) FILTER (WHERE EXTRACT(year FROM date) = 2017)) / 
	SUM(product_price * units) FILTER (WHERE EXTRACT(year FROM date) = 2017)) * 100, 2), '%') AS revenue_growth
FROM
    toys
GROUP BY
    1
ORDER BY 
	(SUM(product_price * units) FILTER (WHERE EXTRACT(year FROM date) = 2018) - 
	SUM(product_price * units) FILTER (WHERE EXTRACT(year FROM date) = 2017)) / 
	SUM(product_price * units) FILTER (WHERE EXTRACT(year FROM date) = 2017) DESC;

