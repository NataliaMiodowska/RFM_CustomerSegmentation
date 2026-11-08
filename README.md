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
| InvoiceNo | 6-digit invoice number; a "C" prefix marks a cancellation | Nominal | Length 6 or 7; most 7-character values start with "C"; 6 records start with "A" |
| StockCode | 5-digit product code | Nominal | Length 1–9 and 12; 1715 records are not 5 characters long, many of them non-product codes (e.g. gift, bank charges, amazon fee, test, adjust); some codes are 5 digits plus a letter |
| Description | Product name | Nominal | 5699 unique values, 4382 NULL, mixed letter case |
| Quantity | Number of units per transaction | Numeric | 22950 values below 0; 3457 of them are not cancellations |
| InvoiceDate | Date and time of the transaction | Numeric | Range 2009–2011 |
| UnitPrice | Price per unit in GBP | Numeric | 5 negative values (invoices starting with "A", "adjust bad debt"); 6202 values equal to 0 |
| CustomerID | 5-digit customer number | Nominal | 243007 NULL; remaining values stored as numbers with one decimal place |
| Country | Customer's country | Nominal | 42 unique countries plus "Unspecified"; "EIRE" is used for Ireland |

Other observations: 32907 rows are duplicates (each record repeated 2–20 times); NULL values occur only in `Description` and `CustomerID`.

## Planned data cleaning

| Issue | Planned treatment |
|---|---|
| `CustomerID` is NULL | Exclude (RFM is calculated per customer) |
| Technical records (adjustments, fees, bank charges, tests) | Exclude |
| `UnitPrice` <= 0 | Exclude |
| Negative `Quantity` that is not a cancellation | Exclude |
| Duplicated rows | Remove duplicates |
| `CustomerID` stored with a decimal part | Convert to integer |
| `Description`, `Country` inconsistencies | Standardise |

The raw table `retail_data` is left unchanged; the cleaned data will be stored separately.
