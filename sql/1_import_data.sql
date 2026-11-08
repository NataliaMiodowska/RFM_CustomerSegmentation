DROP TABLE IF EXISTS retail_data;

CREATE TABLE retail_data (
    invoice_no VARCHAR(20),
    stock_code VARCHAR(20),
    description TEXT,
    quantity INTEGER,
    invoice_date TIMESTAMP,
    unit_price NUMERIC,
    customer_id VARCHAR(20),
    country VARCHAR(50)
);
