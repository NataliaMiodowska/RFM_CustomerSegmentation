# RFM Customer Segmentation

Customer segmentation based on RFM (Recency, Frequency, Monetary) analysis of retail transactions, implemented in SQL (PostgreSQL) and Python.

**Status:** in progress – data quality assessment and data cleaning completed, RFM metrics calculated, scoring and segmentation next.

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
| `sql/3_data_cleaning.sql` | Data cleaning (staging views `retail_clean_stage1`–`8`, final table `retail_clean`) |
| `sql/4_rfm_metrics.sql` | Calculation of Recency, Frequency and Monetary per customer (table `rfm_metrics`) and validation checks |
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

## Data cleaning

The raw table `retail_data` is left unchanged; the cleaned data is stored separately as `retail_clean` (`sql/3_data_cleaning.sql`). Each step is a separate view (`retail_clean_stage1`–`8`), the final table is built from the last one.

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

Cancellations (invoices starting with "C") are kept in the cleaned data; how they enter Recency, Frequency and Monetary is described in the RFM metrics section.

### Result of the cleaning

| Step | Rows | Customers |
|---|---:|---:|
| Raw data (`retail_data`) | 1,067,371 | 5,942 |
| After standardisation (`CustomerID`, `StockCode`) | 1,067,371 | 5,942 |
| After excluding NULL `CustomerID`, `UnitPrice` <= 0 and negative `Quantity` outside cancellations | 824,293 | 5,939 |
| After keeping product `StockCode` only | 820,565 | 5,875 |
| After removing identical rows | 794,163 | 5,875 |
| After excluding customers with cancellations only | 794,076 | 5,852 |
| **Final `retail_clean`** (after standardising `Description`, `Country`, `InvoiceDate` and removing 4 rows that became identical) | **794,072** | **5,852** |

`retail_clean` contains 43,851 invoices; it has no NULL `Description` or `Country`.

Of the 90 customers excluded in total, 61 had cancellations only; the remaining 29 had no rows left after the row-level filters. Checks on the final table: no customer with cancellations only, no identical rows, one country per customer, one timestamp per invoice, one description per `StockCode`, no `UnitPrice` <= 0, no negative `Quantity` outside cancellations, only product `StockCode` values, no `EIRE`.

## RFM metrics

The metrics are calculated from `retail_clean` (`sql/4_rfm_metrics.sql`), one row per `customer_id` (table `rfm_metrics`). The input stays at the level of invoice lines; the aggregation to customer level is the core of this stage.

| Metric | Definition |
|---|---|
| Recency | Days between the customer's latest invoice date in `retail_clean` and the reference date (lower = more recent) |
| Frequency | Number of distinct regular invoices (invoices starting with "C" are not counted) |
| Monetary | Sum of `quantity * unit_price` over all of the customer's lines, i.e. net of cancellations |

**Assumptions**

- Reference date: 2011-12-10, the day after the last transaction in `retail_clean` (2011-12-09). It is fixed because the analysed period (2009-2011) is closed.
- A cancellation is not a purchase, so it does not increase Frequency; it reduces Monetary because a returned product reduces the customer's real value.
- Recency uses the latest invoice date including cancellations, as the last contact with the customer.
- Customers with Monetary <= 0 (net value of zero or below, e.g. a purchase fully cancelled) are excluded from RFM: 20 of 5,852 customers. The final `rfm_metrics` table contains 5,832 customers.

**Validation**

- One row per customer (no duplicated `customer_id`).
- Before the exclusion: no invalid Recency or Frequency, 20 customers with Monetary <= 0. After the exclusion: 5,832 customers and no NULL or invalid values in any of the three metrics.
- Before the exclusion, the total of Monetary equals the total value of all lines in `retail_clean` (16,359,435.22). After the exclusion the totals are compared on the same customers (those in `rfm_metrics`) and are equal (16,360,984.68).
- Manual check of selected customers against their invoice lines (e.g. customer 12346: 3 regular invoices, Frequency = 3; one purchase and its full cancellation offset each other).
