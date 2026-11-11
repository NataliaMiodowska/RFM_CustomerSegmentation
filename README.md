# RFM Customer Segmentation

Customer segmentation based on RFM (Recency, Frequency, Monetary) analysis of retail transactions, implemented in SQL (PostgreSQL) and Python.

**Status:** in progress – data quality assessment and data cleaning completed, RFM metrics calculated, RFM scoring and customer segmentation completed, Python analysis and recommendations next.

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
| `sql/5_scoring.sql` | Assigning Recency, Frequency and Monetary scores (1–5) per customer (table `scoring`) and a check of the group sizes |
| `sql/6_customer_segments.sql` | Mapping of the scores to seven segments (tables `segments` and `scoring_and_segments`), segment averages of R, F, M and the business summary per segment (table `business_summary`) |
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

## RFM scoring

Each customer from `rfm_metrics` gets three scores from 1 to 5 (`sql/5_scoring.sql`, table `scoring`), calculated separately for Recency, Frequency and Monetary with `NTILE(5)`, i.e. into five groups of (almost) equal size.

| Metric | Sort order in `NTILE` | Score 5 means |
|---|---|---|
| Recency | descending | most recent customers |
| Frequency | ascending | most frequent customers |
| Monetary | ascending | highest net value |

**Assumptions**

- Score 5 is the best group in every dimension, a higher score is better.
- Customers with the same metric value can fall into different groups (`NTILE` splits ties), so `customer_id` is added as a second sort key to make the result repeatable.

**Validation**

- The group sizes are the same for all three metrics: 5,832 customers split into two groups of 1,167 and three groups of 1,166 (about 20% each). The result was identical after re-running the script with the tie-breaker.

## Customer segments

Customers are assigned to seven segments with a `CASE` expression (`sql/6_customer_segments.sql`, table `segments`). The table `scoring_and_segments` combines the segment with the scores and metrics from `scoring` (one row per customer, 5,832 customers) and is the input for the analysis in Python. The rules use the Recency score (R) and the sum of the Frequency and Monetary scores (FM = F + M, range 2–10), so the segments are based on how recently a customer bought (R) and on their overall value (F and M together). Scores: 5 = best.

| Segment | Rule | Description |
|---|---|---|
| Top Customers | R 4–5 and FM 9–10 | Bought recently, often and for a high value |
| Loyal | R 4 and FM 5–8; R 5 and FM 8; R 3 and FM 8–10 | Regular customers of good value, not always the most recent |
| Promising | R 5 and FM 5–7; R 4 and FM 2–4 | Recent customers of medium or lower value |
| Recent Occasional | R 5 and FM 2–4 | Bought recently, but rarely and for a low value |
| Need Attention | R 3 and FM 2–7; R 2 and FM 5–7 | Medium activity and value, moving away |
| Immediate Attention | R 1–2 and FM 8–10 | High past value, no recent purchase |
| Lost | R 1–2 and FM 2–4; R 1 and FM 5–7 | Long time since the last purchase, low or medium value |

**Assumptions**

- The rules do not overlap and cover all 25 combinations of R and FM; no customer is left unassigned (5,832 customers in total).
- `Recent Occasional` is not named "New Customers" on purpose: the scores do not show whether the first purchase was recent, so the segment includes both new customers and occasional buyers who happened to purchase recently.
- The Top Customers rule was tightened from FM 8–10 to FM 9–10, because the first version covered 1,296 customers (22.2%), which is too many for a top segment. Customers with FM = 8 moved to Loyal.
- The 20 customers with Monetary <= 0 are not in `rfm_metrics` and therefore have no segment; percentages below are calculated on the 5,832 segmented customers.

### Segment profile

Average values per customer, calculated from `rfm_metrics`.

| Segment | Avg Recency (days) | Avg Frequency | Avg Monetary |
|---|---:|---:|---:|
| Top Customers | 17.76 | 20.05 | 10,757.94 |
| Loyal | 56.14 | 6.26 | 2,351.17 |
| Immediate Attention | 336.63 | 8.74 | 3,795.74 |
| Need Attention | 179.34 | 2.78 | 774.73 |
| Lost | 465.94 | 1.48 | 412.47 |
| Promising | 21.30 | 2.63 | 678.30 |
| Recent Occasional | 9.97 | 1.50 | 292.18 |

### Business summary

The summary is stored in the table `business_summary`, one row per segment. Revenue is net of cancellations (`quantity * unit_price` over all lines of the segment's customers). Average order value is the segment's revenue divided by the number of its regular invoices (invoices starting with "C" are not counted), the same definition of an order as in Frequency.

| Segment | Customers | % of customers | Revenue | % of revenue | Avg order value |
|---|---:|---:|---:|---:|---:|
| Top Customers | 1,005 | 17.23 | 10,811,728.76 | 66.08 | 536.54 |
| Loyal | 1,114 | 19.10 | 2,619,205.43 | 16.01 | 375.51 |
| Immediate Attention | 251 | 4.30 | 952,730.68 | 5.82 | 434.24 |
| Need Attention | 1,170 | 20.06 | 906,433.05 | 5.54 | 278.39 |
| Lost | 1,647 | 28.24 | 679,331.63 | 4.15 | 278.87 |
| Promising | 526 | 9.02 | 356,786.25 | 2.18 | 257.98 |
| Recent Occasional | 119 | 2.04 | 34,768.88 | 0.21 | 195.33 |
| **Total** | **5,832** | **100.00** | **16,360,984.68** | **100.00** | |
