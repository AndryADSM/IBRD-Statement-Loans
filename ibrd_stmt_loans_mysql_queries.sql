-- ibrd_stmt_loans_mysql_queries

USE ibrd_stmt_loans;

SELECT *
FROM import_data;

-- Latest End of Period
SELECT MAX(end_of_period) AS max_eop FROM loans;

-- Number of Years
SELECT COUNT(DISTINCT(YEAR(board_approval_date))) AS n_years
FROM dates
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- ------------------------------------------------
-- KPIs
-- ------------------------------------------------

-- 1. Total Loans

SELECT COUNT(loan_number) AS total_loans
FROM loans
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- Change Per Year
WITH year_counts AS (
	SELECT 
		year(board_approval_date) AS year_approval,
		COUNT(loan_number) AS metric
	FROM dates
    WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
	GROUP BY year_approval
)
SELECT 
	year_approval,
	metric AS total_loans,
	LAG(metric) OVER (ORDER BY year_approval) AS previous_month,
	ROUND(metric - LAG(metric) OVER (ORDER BY year_approval), 4) AS abs_change,
	ROUND(
		CAST((metric - LAG(metric) OVER (ORDER BY year_approval)) AS FLOAT)
		/ 
		LAG(metric) OVER (ORDER BY year_approval),
		4) AS pct_change
FROM year_counts
ORDER BY year_approval;

-- 2. Total Commitment

SELECT SUM(original_principal_amount) AS total_commitment
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 3. Total Cancelled
SELECT SUM(cancelled_amount) AS total_cancelled
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 4. Total Disbursed

SELECT SUM(disbursed_amount) AS total_disbursed
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 5. Total Undisbursed

SELECT SUM(undisbursed_amount) AS total_undisbursed
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 6. Total Repaid

SELECT SUM(m.repaid_to_ibrd + t.repaid_third_party) AS total_repaid
FROM
	money AS m
		JOIN
	thirdparty AS t ON (m.end_of_period, m.loan_number) = (t.end_of_period, t.loan_number)
WHERE m.end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 7. Total Due

-- borrowers_obligation = due_to_ibrd + due_third_party + exchange_adjustment

SELECT SUM(m.borrowers_obligation) AS total_due
FROM
	money AS m
		JOIN
	thirdparty AS t ON (m.end_of_period, m.loan_number) = (t.end_of_period, t.loan_number)
WHERE m.end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 8. Average Commitment (Original Principal Amount)

SELECT ROUND(AVG(original_principal_amount), 2) AS avg_orig_p_amount
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 9. Average Interest Rate (0's not included)

SELECT ROUND(AVG(interest_rate), 4) AS avg_int_rate
FROM money
WHERE
	end_of_period = (SELECT MAX(end_of_period) FROM loans)
    AND interest_rate != 0;

-- 10. Distinct Projects

SELECT COUNT(DISTINCT(project_id)) AS count_projects
FROM loans
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- 11. Pct Due

SELECT
	ROUND(SUM(borrowers_obligation)
		/ SUM(disbursed_amount), 4) AS pct_due
FROM money
WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans);

-- ------------------------------------------------
-- Loans - Charts
-- ------------------------------------------------

-- Loans Approved by Year (Line Chart)

SELECT 
    YEAR(d.board_approval_date) AS year_approval,
    COUNT(l.loan_number) AS total_loans
FROM
	loans AS l
		JOIN
	dates AS d ON (l.end_of_period, l.loan_number) = (d.end_of_period, d.loan_number)
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY year_approval
ORDER BY year_approval;

-- Loans by Type (Donut Chart)

SELECT
	l.loan_type,
	COUNT(l.loan_number) AS count_loans,
	COUNT(l.loan_number) / MAX(tl.total_loans) AS pct_of_total
FROM
	loans AS l,
    (SELECT COUNT(loan_number) AS total_loans 
		FROM loans
        WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
        ) AS tl
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY l.loan_type
ORDER BY count_loans DESC;

-- Loans by Status (Group)

SELECT
    CASE
        WHEN l.loan_status
			IN ('Fully Repaid', 'Fully Cancelled', 'Fully Transferred', 'Terminated')
        THEN 'Finished'
        ELSE 'Ongoing'
		END AS status_group,
	COUNT(l.loan_number) AS count_loans,
	COUNT(l.loan_number) / MAX(tl.total_loans) AS pct_of_total
FROM
	loans AS l,
    (SELECT COUNT(loan_number) AS total_loans
		FROM loans
        WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
        ) AS tl
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY status_group
ORDER BY count_loans DESC;

-- Loans by Status (Bar Chart)

SELECT
	loan_status,
	COUNT(l.loan_number) AS count_loans,
	COUNT(l.loan_number) / MAX(tl.total_loans) AS pct_of_total
FROM
	loans AS l,
    (SELECT COUNT(loan_number) AS total_loans
		FROM loans
        WHERE end_of_period = (SELECT MAX(end_of_period) FROM loans)
        ) AS tl
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY l.loan_status
ORDER BY count_loans DESC;

-- ** DEL
-- Cumulative Disbursed and Due by Year of Approval (Area Chart)

SELECT
	YEAR(d.board_approval_date) AS year_approval,
	SUM(m.disbursed_amount) AS total_disbursed,
	SUM(SUM(m.disbursed_amount))
		OVER (ORDER BY YEAR(d.board_approval_date)) AS cumulative_disbursed,
	SUM(m.due_to_ibrd + t.due_third_party) AS total_due,
    SUM(SUM(m.due_to_ibrd + t.due_third_party))
		OVER (ORDER BY YEAR(d.board_approval_date)) AS cumulative_due
FROM
	loans AS l
		JOIN
	dates AS d ON (l.end_of_period, l.loan_number) = (d.end_of_period, d.loan_number)
		JOIN
	money AS m ON (l.end_of_period, l.loan_number) = (m.end_of_period, m.loan_number)
		JOIN
	thirdparty AS t ON (l.end_of_period, l.loan_number) = (t.end_of_period, t.loan_number)
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY year_approval
ORDER BY year_approval;

-- ------------------------------------------------
-- Countries - Charts
-- ------------------------------------------------

-- Loans by Country (Map and Bar Chart)

SELECT
	c.country,
    c.country_code,
    COUNT(l.loan_number) AS total_loans
FROM
	loans AS l
		JOIN
	countries AS c ON l.country_code = c.country_code
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY c.country_code
ORDER BY total_loans DESC;

-- ** DEL
-- Amount Held By Country (Bar Chart)

SELECT
	c.country,
	c.country_code,
    SUM(m.loans_held) AS amount_held
FROM
	loans AS l
		JOIN
	countries AS c ON l.country_code = c.country_code
		JOIN
    money AS m ON (l.end_of_period, l.loan_number) = (m.end_of_period, m.loan_number)
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY c.country_code
ORDER BY amount_held DESC;

-- Total Repaid and Due by Region (Stacked Bar Chart)

SELECT
	c.region,
    SUM(m.disbursed_amount) AS total_disbursed,
	SUM(m.repaid_to_ibrd + t.repaid_third_party) AS total_repaid,
	SUM(m.borrowers_obligation) AS total_due,
	ROUND(SUM(m.borrowers_obligation) / SUM(m.disbursed_amount), 4) AS pct_due
FROM
	loans AS l
		JOIN
	countries AS c ON l.country_code = c.country_code
		JOIN
    money AS m ON (l.end_of_period, l.loan_number) = (m.end_of_period, m.loan_number)
		JOIN
	thirdparty AS t ON (l.end_of_period, l.loan_number) = (t.end_of_period, t.loan_number)
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY c.region
ORDER BY total_disbursed DESC;

-- Distinct Countries Given Loans per Year (Area Chart)

SELECT
	YEAR(d.board_approval_date) AS year_approval,
    COUNT(DISTINCT(l.country_code)) AS distinct_countries
FROM
	loans AS l
		JOIN
	dates AS d ON (l.end_of_period, l.loan_number) = (d.end_of_period, d.loan_number)
WHERE l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
GROUP BY year_approval
ORDER BY year_approval;

-- ------------------------------------------------
-- Details - Tables
-- ------------------------------------------------

-- Loans Approved Last 3 Months

SELECT
	l.loan_number,
    l.country_code,
    l.loan_status,
    l.loan_type,
    m.original_principal_amount,
    m.interest_rate,
    d.board_approval_date,
    d.first_repayment_date,
    d.agreement_signing_date,
    d.effective_date_most_recent
FROM
	loans AS l
		JOIN
	money AS m ON (l.end_of_period, l.loan_number) = (m.end_of_period, m.loan_number)
		JOIN
	thirdparty AS t ON (l.end_of_period, l.loan_number) = (t.end_of_period, t.loan_number)
		JOIN
	dates AS d ON (l.end_of_period, l.loan_number) = (d.end_of_period, d.loan_number)
WHERE
	l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
	AND d.board_approval_date
		BETWEEN DATE_ADD((SELECT MAX(end_of_period) FROM loans), INTERVAL -3 MONTH)
		AND (SELECT MAX(end_of_period) FROM loans)
ORDER BY d.board_approval_date DESC;

-- Disbursements of Last Months

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
	money AS m ON (l.end_of_period, l.loan_number) = (m.end_of_period, m.loan_number)
		JOIN
	thirdparty AS t ON (l.end_of_period, l.loan_number) = (t.end_of_period, t.loan_number)
		JOIN
	dates AS d ON (l.end_of_period, l.loan_number) = (d.end_of_period, d.loan_number)
WHERE
	l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
	AND d.last_disbursement_date
		BETWEEN DATE_ADD((SELECT MAX(end_of_period) FROM loans), INTERVAL -1 MONTH)
		AND (SELECT MAX(end_of_period) FROM loans)
ORDER BY d.last_disbursement_date DESC;

-- Last Repayments of Next 3 Months

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
	money AS m ON (l.end_of_period, l.loan_number) = (m.end_of_period, m.loan_number)
		JOIN
	thirdparty AS t ON (l.end_of_period, l.loan_number) = (t.end_of_period, t.loan_number)
		JOIN
	dates AS d ON (l.end_of_period, l.loan_number) = (d.end_of_period, d.loan_number)
WHERE
	l.end_of_period = (SELECT MAX(end_of_period) FROM loans)
	AND d.last_repayment_date 
		BETWEEN (SELECT MAX(end_of_period) FROM loans)
		AND DATE_ADD((SELECT MAX(end_of_period) FROM loans), INTERVAL 3 MONTH)
ORDER BY d.last_repayment_date;

-- END
-- ---