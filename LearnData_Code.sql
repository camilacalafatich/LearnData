# 1. Create the new database in MYSQL

CREATE SCHEMA learndata;

# 2. Create the customers table to store information about our customers.

CREATE TABLE dim_customers (
    id_customer int,
    customer_creation_date DATE,
    first_name varchar(100),
    last_name varchar(100),
    email_customer varchar(100),
    phone_customer varchar(100),
    customer_region varchar(100),
    customer_country varchar(100),
    customer_postal_code varchar(100),
    customer_address varchar(255),
    PRIMARY KEY (id_customer)
);

# 3. Create the products table to store information about the courses we sell.

CREATE TABLE dim_product (
  id_product int ,
  product_sku int,
  product_name varchar(100),
  product_published BOOLEAN ,
  product_inventory varchar(100),
  product_normal_price INT ,
  product_category varchar(100),
  PRIMARY KEY (product_sku)
);

# 4. Create the orders table to store all our sales.

CREATE TABLE fac_orders (
  order_id INT,
  product_sku INT,
  order_status VARCHAR(50),
  order_date DATE,
  id_customer INT,
  payment_type VARCHAR(50),
  order_cost INT,
  order_discount_amount decimal(10,0),
  order_total_amount INT,
  order_quantity INT,
  coupon_code VARCHAR(100),
  PRIMARY KEY (order_id),
  FOREIGN KEY (id_customer) REFERENCES dim_customers (id_customer),
  FOREIGN KEY (product_sku) REFERENCES dim_product (product_sku)
);

# 5. Create the stripe payments table that we receive.

CREATE TABLE fac_stripe_payments (
  payment_id VARCHAR(50),
  payment_date datetime(6),
  order_id int,
  payment_amount int,
  payment_currency VARCHAR(5),
  payment_fee decimal(10,2),
  payment_net decimal(10,2),
  payment_type VARCHAR(50),
  PRIMARY KEY (payment_id),
  FOREIGN KEY (order_id) REFERENCES fac_orders (order_id)
);

# 6. Insert clean data and the desired columns into our new table.

INSERT INTO learndata.dim_product
SELECT
id as id_product,
sku as product_sku,
name as product_name,
published as product_published,
inventory as product_inventory,
normal_price as product_normal_price,
categories as product_category
FROM learndata_raw.raw_woocommerce_products;

# 7. Insert clean data and the desired columns into our new table.

INSERT INTO learndata.dim_customers
SELECT 
id as id_customer,
DATE(STR_TO_DATE(date_created,"%d/%m/%Y %H:%i:%s")) as customer_creation_date,
JSON_VALUE(billing,'$[0].first_name') AS first_name,
JSON_VALUE(billing,'$[0].last_name') AS last_name,
JSON_VALUE(billing,'$[0].email') AS email_customer,
JSON_VALUE(billing,'$[0].phone') AS phone_customer,
JSON_VALUE(billing,'$[0].Region') AS customer_region,
JSON_VALUE(billing,'$[0].country') AS customer_country,
JSON_VALUE(billing,'$[0].postcode') AS customer_postal_code,
JSON_VALUE(billing,'$[0].address_1') AS customer_address
FROM learndata_raw.raw_woocommerce_customers;

# 8. Insert clean data and the desired columns into our new table.

INSERT INTO learndata.fac_orders
SELECT
	order_number as order_id,
	CASE WHEN p.product_sku IS NULL THEN 3 ELSE p.product_sku END as product_sku,
	order_status as order_status,
	DATE(order_date) as order_date,
	`customer id` AS id_customer,
	CASE WHEN payment_method_title LIKE '%Stripe%' THEN 'Stripe' ELSE 'Card' END AS payment_type,
	item_cost AS order_cost,
	cart_discount_amount AS order_discount_amount, 
	order_total AS order_total_amount,
	quantity AS order_quantity,
	item_coupon AS coupon_code
FROM learndata_raw.raw_woocommerce_orders w
LEFT JOIN learndata.dim_product p on p.product_name = w.item_name;

# 9. Insert clean data and the desired columns into our new table.
INSERT INTO learndata.fac_stripe_payments

SELECT
	id as payment_id,
	TIMESTAMP(created) AS payment_date,
	RIGHT(description,5) as order_id,
	amount as payment_amount,
	currency as payment_currency,
	CAST(REPLACE(fee,',','.') AS DECIMAL(10,2)) as payment_fee,
	CAST(REPLACE(net,',','.') AS DECIMAL(10,2)) as payment_net,
	type as payment_type
FROM learndata_raw.raw_stripe_payments;