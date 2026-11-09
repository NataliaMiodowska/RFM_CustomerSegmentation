# RFM Customer Segmentation

Customer segmentation based on RFM (Recency, Frequency, Monetary) analysis of retail transactions, implemented in SQL (PostgreSQL) and Python.

**Status:** in progress – data quality assessment completed, data cleaning next.

## Data source and licence

Chen, D. (2012). *Online Retail II* [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5CG6D

Licence: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Changes: the transactions were loaded into PostgreSQL and cleaned in SQL (see `sql/`). The original file is not included in this repository.

## Tools

PostgreSQL (pgAdmin), Python (pandas, SQLAlchemy, plotly), Jupyter Notebook.

## Repository structure

| Path | Content |
|---|---|
| `sql/1_import_data.sql` | Creation of the `retail_data` table |
| `sql/2_data_quality_check.sql` | Data quality checks |
| `notebooks/dataset_preparation.ipynb` | Dataset preparation |

## Data dictionary

| Column | Description (UCI) | Type (UCI) | Observations in the data |
|---|---|---|---|
| InvoiceNo | 6-digit invoice number; a "C" prefix marks a cancellation | Nominal | 53628 unique invoices; length 6 or 7; most 7-character values start with "C"; 6 records start with "A" |
| StockCode | 5-digit product code | Nominal | Length 1–9 and 12; 1715 distinct codes are not 5 characters long. Most are regular products with a letter suffix (e.g. 85123A); 62 are non-product codes (e.g. DOT, POST, AMAZONFEE, BANK CHARGES, ADJUST, TEST, gift vouchers). The same code appears in upper and lower case (e.g. 85123A / 85123a) and some have trailing spaces |
| Description | Product name | Nominal | 5698 unique non-NULL values, 4382 NULL; 213035 rows with leading or trailing spaces, 52708 with double spaces; 5698 variants collapse to 5631 after `UPPER(TRIM())`; a single `StockCode` can have several descriptions, including free-text notes (e.g. "damaged", "found", "amazon") and different product names |
| Quantity | Number of units per transaction | Numeric | Range from -80995 to 80995 (invoice 581483 and the cancellation C581484 for the same product and customer, 12 minutes later); 22950 values below 0, of which 3457 are not cancellations (3393 of those also have `UnitPrice` = 0); 1 cancellation invoice (C496350, "Manual") has a positive value |
| InvoiceDate | Date and time of the transaction | Numeric | Range 2009-12-01 - 2011-12-09; 83 invoices have two timestamps, one minute apart |
| UnitPrice | Price per unit in GBP | Numeric | Range from -53594.36 to 38970.00 (the maximum is `StockCode` M with `Quantity` = -1); 5 negative values (invoices starting with "A", "adjust bad debt"); 6202 values equal to 0 |
| CustomerID | 5-digit customer number | Nominal | 5942 unique customers; 243007 NULL (22.77% of rows); remaining values stored as numbers with one decimal place |
| Country | Customer's country | Nominal | 42 unique countries plus "Unspecified"; "EIRE" is used for Ireland; 13 customers appear with two different countries |

Other observations:

- 32907 groups of fully identical rows; each record appears 2–20 times (67242 rows in total, of which 34335 are surplus copies).
- NULL values occur only in `Description` and `CustomerID`.

### Customer activity

| Activity type | Customers | Share |
|---|---:|---:|
| Regular purchases only | 3,370 | 56.71% |
| Both purchases and cancellations | 2,511 | 42.26% |
| Cancellations only | 61 | 1.03% |
| Total | 5,942 | 100.00% |

## Planned data cleaning

The raw table `retail_data` is left unchanged; the cleaned data will be stored separately as `retail_clean`.

**Standardise**

| Issue | Treatment |
|---|---|
| `CustomerID` stored with a decimal part (e.g. 12345.0) | Convert to integer |
| `StockCode` letter case and trailing spaces | `UPPER(TRIM())` |
| `Description` | `UPPER(TRIM())` and collapse repeated spaces; take the product name as the most frequent description among regular sales |
| `Country` | `EIRE` -> Ireland; for customers with two countries (13) use the country of the latest invoice |
| `InvoiceDate` | For invoices with two timestamps (83) use the later one |

**Exclude**

| Issue | Treatment |
|---|---|
| `CustomerID` is NULL | Exclude (RFM is calculated per customer) |
| Non-product `StockCode` (postage, fees, adjustments, tests, manual entries, gift vouchers) | Exclude; keep only codes matching `^[0-9]{5}[A-Z]{0,2}$` |
| `UnitPrice` <= 0 | Exclude |
| Negative `Quantity` that is not a cancellation | Exclude (3393 of 3457 rows also have `UnitPrice` = 0) |
| Fully identical rows | Keep one copy of each |
| Customers with cancellations only (61) | Exclude |

Cancellations (invoices starting with "C") are kept in the cleaned data; how they enter Recency, Frequency and Monetary is decided in the next stage.
