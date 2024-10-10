-- ibrd_stmt_loans_mssql_queries

-- Queries for MSSQLServer

-- Queries to get insights from the ibrd_stmt_loans database
-- and check data obtained in dashboards

USE ibrd_stmt_loans;

-- Latest End of Period

SELECT MAX(end_of_period) AS latest_eop FROM loans;

-- Number of Years

SELECT COUNT(DISTINCT(YEAR(board_approval_date))) AS n_years
FROM dates
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- To apply filters place in the WHERE clause lines like these:

-- YEAR(board_approval_date) BETWEEN 2004 AND 2024
-- region = 'Latin america and caribbean'
-- country = 'Ecuador'
-- loan_status IN ('Signed', 'Effective', 'Repaying')
-- loan_type IN ('FSL', 'SCL')

-- ------------------------------------------------
-- KPIs
-- ------------------------------------------------

-- 1. Total Commitment

SELECT SUM(original_principal_amount) AS total_commitment
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 2. Total Cancelled

SELECT SUM(cancelled_amount) AS total_cancelled
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 3. Total Disbursed

SELECT SUM(disbursed_amount) AS total_disbursed
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 4. Total Undisbursed

SELECT SUM(undisbursed_amount) AS total_undisbursed
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 5. Total Repaid

SELECT SUM(m.repaid_to_ibrd + t.repaid_third_party) AS total_repaid
FROM
	money AS m
		JOIN
	thirdparty AS t ON m.end_of_period = t.end_of_period AND m.loan_number = t.loan_number
WHERE m.end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 6. Total Due

-- borrowers_obligation = due_to_ibrd + due_third_party + exchange_adjustment

SELECT SUM(borrowers_obligation) AS total_due
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 7. Distinct Projects

SELECT COUNT(DISTINCT(project_id)) AS count_projects
FROM loans
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 8. Pct Due

SELECT
	ROUND(SUM(borrowers_obligation)
		/ SUM(disbursed_amount), 4) AS pct_due
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 9. Average Commitment (Original Principal Amount)

SELECT ROUND(AVG(original_principal_amount), 2) AS avg_orig_p_amount
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 10. Average Interest Rate (0's not included)

SELECT ROUND(AVG(interest_rate), 4) AS avg_int_rate
FROM money
WHERE
	end_of_period = (SELECT MAX(end_of_period) FROM loans)
    AND interest_rate != 0;

-- ------------------------------------------------
-- Loans
-- ------------------------------------------------

-- 1a. Total Loans

SELECT COUNT(loan_number) AS total_loans
FROM loans
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 1b. Total Loans YTD

SELECT COUNT(loan_number) AS total_loans
FROM dates
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
	AND YEAR(board_approval_date) = (SELECT MAX(YEAR(board_approval_date)) FROM dates);

-- 1c. Total Loans PYTD

SELECT COUNT(loan_number) AS total_loans
FROM dates
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
	AND YEAR(board_approval_date) = (SELECT MAX(YEAR(board_approval_date)) - 1 FROM dates);

-- 1d. Change Per Year

WITH year_counts AS (
	SELECT 
		year(board_approval_date) AS year_approval,
		COUNT(loan_number) AS metric
	FROM dates
    WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
	GROUP BY year(board_approval_date)
)
SELECT 
	year_approval,
	metric AS total_loans,
	LAG(metric) OVER (ORDER BY year_approval) AS previous_year,
	metric - LAG(metric) OVER (ORDER BY year_approval) AS abs_change,
	ROUND(
		CAST((metric - LAG(metric) OVER (ORDER BY year_approval)) AS FLOAT)
		/ 
		LAG(metric) OVER (ORDER BY year_approval),
		4) AS pct_change
FROM year_counts
ORDER BY year_approval;

-- 2. Loans Approved per Year, with Running Total (Line Chart)

SELECT 
    YEAR(board_approval_date) AS year_approval,
    COUNT(loan_number) AS total_loans,
    SUM(COUNT(loan_number))
		OVER (ORDER BY YEAR(board_approval_date)) AS running_total
FROM dates
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY YEAR(board_approval_date)
ORDER BY YEAR(board_approval_date);

-- 3. Loans by Type (Donut Chart)

SELECT
	l.loan_type,
	COUNT(l.loan_number) AS count_loans,
	ROUND(CAST(COUNT(l.loan_number) AS FLOAT) / MAX(tl.total_loans), 4) AS pct_of_total
FROM
	loans AS l,
    (SELECT COUNT(loan_number) AS total_loans 
		FROM loans
        WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
        ) AS tl
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY l.loan_type
ORDER BY count_loans DESC;

-- 4a. Loans by Status (Group) (Donut Chart)

SELECT
    CASE
        WHEN l.loan_status
			IN ('Fully Repaid', 'Fully Cancelled', 'Fully Transferred', 'Terminated')
        THEN 'Finished'
        ELSE 'Ongoing'
		END AS status_group,
	COUNT(l.loan_number) AS count_loans,
	ROUND(CAST(COUNT(l.loan_number) AS FLOAT) / MAX(tl.total_loans), 4) AS pct_of_total
FROM
	loans AS l,
    (SELECT COUNT(loan_number) AS total_loans
		FROM loans
        WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
        ) AS tl
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY
	CASE
        WHEN l.loan_status
			IN ('Fully Repaid', 'Fully Cancelled', 'Fully Transferred', 'Terminated')
        THEN 'Finished'
        ELSE 'Ongoing'
		END
ORDER BY count_loans DESC;

-- 4b. Loans by Status (Bar Chart)

SELECT
	loan_status,
	COUNT(l.loan_number) AS count_loans,
	ROUND(CAST(COUNT(l.loan_number) AS FLOAT) / MAX(tl.total_loans), 4) AS pct_of_total
FROM
	loans AS l,
    (SELECT COUNT(loan_number) AS total_loans
		FROM loans
        WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
        ) AS tl
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY l.loan_status
ORDER BY count_loans DESC;

-- ------------------------------------------------
-- Countries
-- ------------------------------------------------

-- 1. Loans by Country (Map and Bar Chart)

SELECT
	c.country,
    c.country_code,
    COUNT(l.loan_number) AS total_loans
FROM
	loans AS l
		JOIN
	countries AS c ON l.country_code = c.country_code
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY c.country_code, c.country
ORDER BY total_loans DESC;

-- 2. Distinct Countries Given Loans per Year (Area Chart)

SELECT
	YEAR(d.board_approval_date) AS year_approval,
    COUNT(DISTINCT(l.country_code)) AS distinct_countries
FROM
	loans AS l
		JOIN
	dates AS d ON l.end_of_period = d.end_of_period AND l.loan_number = d.loan_number
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY YEAR(d.board_approval_date)
ORDER BY year_approval;

-- 3a. Total Repaid and Due by Region (Stacked Bar Chart)

SELECT
	c.region,
    SUM(m.disbursed_amount) AS total_disbursed,
	SUM(m.repaid_to_ibrd + t.repaid_third_party) AS total_repaid,
	SUM(m.borrowers_obligation) AS total_due,
	ROUND(CAST(SUM(m.borrowers_obligation) AS FLOAT)
		/ CASE WHEN SUM(m.disbursed_amount) = 0 THEN 1 ELSE SUM(m.disbursed_amount) END
		, 4) AS pct_due
FROM
	loans AS l
		JOIN
	countries AS c ON l.country_code = c.country_code
		JOIN
    money AS m ON l.end_of_period = m.end_of_period AND l.loan_number = m.loan_number
		JOIN
	thirdparty AS t ON l.end_of_period = t.end_of_period AND l.loan_number = t.loan_number
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY c.region
ORDER BY total_disbursed DESC;

-- 3b. Total Repaid and Due by Country (Stacked Bar Chart)

SELECT
	c.country,
	c.country_code,
    SUM(m.disbursed_amount) AS total_disbursed,
	SUM(m.repaid_to_ibrd + t.repaid_third_party) AS total_repaid,
	SUM(m.borrowers_obligation) AS total_due,
	ROUND(CAST(SUM(m.borrowers_obligation) AS FLOAT)
		/ CASE WHEN SUM(m.disbursed_amount) = 0 THEN 1 ELSE SUM(m.disbursed_amount) END
		, 4) AS pct_due
FROM
	loans AS l
		JOIN
	countries AS c ON l.country_code = c.country_code
		JOIN
    money AS m ON l.end_of_period = m.end_of_period AND l.loan_number = m.loan_number
		JOIN
	thirdparty AS t ON l.end_of_period = t.end_of_period AND l.loan_number = t.loan_number
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY c.country, c.country_code
ORDER BY total_disbursed DESC;

-- ------------------------------------------------
-- Details
-- ------------------------------------------------

-- 1. Loans Approved Last 3 Months (Table)

SELECT
	l.loan_number,
    l.country_code,
    l.loan_status,
    l.loan_type,
    p.project_name,
    m.original_principal_amount,
    m.interest_rate,
    d.board_approval_date,
    d.first_repayment_date,
    d.agreement_signing_date,
    d.effective_date_most_recent
FROM
	loans AS l
		JOIN
	money AS m ON l.end_of_period = m.end_of_period AND l.loan_number = m.loan_number
		JOIN
	thirdparty AS t ON l.end_of_period = t.end_of_period AND l.loan_number = t.loan_number
		JOIN
	dates AS d ON l.end_of_period = d.end_of_period AND l.loan_number = d.loan_number
		JOIN
	projects AS p ON l.project_id = p.project_id
WHERE
	l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
	AND d.board_approval_date
		BETWEEN DATEADD(MONTH, -3, (SELECT MAX(end_of_period) FROM loans))
		AND (SELECT MAX(end_of_period) FROM loans)
ORDER BY
	d.board_approval_date DESC,
	l.loan_number DESC;

-- 2. Disbursements Last Months (Table)

SELECT
	l.loan_number,
    l.country_code,
    l.loan_status,
    l.loan_type,
    m.disbursed_amount,
    d.last_disbursement_date
FROM
	loans AS l
		JOIN
	money AS m ON l.end_of_period = m.end_of_period AND l.loan_number = m.loan_number
		JOIN
	thirdparty AS t ON l.end_of_period = t.end_of_period AND l.loan_number = t.loan_number
		JOIN
	dates AS d ON l.end_of_period = d.end_of_period AND l.loan_number = d.loan_number
WHERE
	l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
	AND d.last_disbursement_date
		BETWEEN DATEADD(MONTH, -1, (SELECT MAX(end_of_period) FROM loans))
		AND (SELECT MAX(end_of_period) FROM loans)
ORDER BY
	d.last_disbursement_date DESC,
	l.loan_number DESC;

-- 3. Last Repayments Next 3 Months (Table)

SELECT
	l.loan_number,
    l.country_code,
    l.loan_status,
    l.loan_type,
    m.due_to_ibrd + t.due_third_party AS total_due,
    d.last_repayment_date
FROM
	loans AS l
		JOIN
	money AS m ON l.end_of_period = m.end_of_period AND l.loan_number = m.loan_number
		JOIN
	thirdparty AS t ON l.end_of_period = t.end_of_period AND l.loan_number = t.loan_number
		JOIN
	dates AS d ON l.end_of_period = d.end_of_period AND l.loan_number = d.loan_number
WHERE
	l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
	AND d.last_repayment_date 
		BETWEEN (SELECT MAX(end_of_period) FROM loans)
		AND DATEADD(MONTH, 3, (SELECT MAX(end_of_period) FROM loans))
ORDER BY
	d.last_repayment_date ASC,
	l.loan_number ASC;

-- END
-- ---