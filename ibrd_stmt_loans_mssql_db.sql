-- ibrd_stmt_loans_mssql_db

-- Creation of relational database
-- Stored procedures
-- Importing data

-- DROP DATABASE IF EXISTS ibrd_stmt_loans;

CREATE DATABASE ibrd_stmt_loans;

USE ibrd_stmt_loans;

-- Creation of Relational Database (RDB)

-- Tables

DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS money;
DROP TABLE IF EXISTS dates;
DROP TABLE IF EXISTS thirdparty;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS countries;

CREATE TABLE loans (
    end_of_period			DATE 		 NOT NULL,
	loan_number				VARCHAR(10)  NOT NULL,
	borrower				VARCHAR(100) NULL,
	project_id				VARCHAR(10)  NOT NULL,
	country_code			VARCHAR(2)   NOT NULL,
	guarantor_country_code 	VARCHAR(2)   NULL,
	loan_type				VARCHAR(5)   NULL,
	loan_status				VARCHAR(50)  NULL,
PRIMARY KEY (loan_number, end_of_period)
);

CREATE TABLE money (
    end_of_period				DATE 		  NOT NULL,
	loan_number					VARCHAR(10)   NOT NULL,
	currency_of_commitment		VARCHAR(50)   NULL,
	interest_rate				DECIMAL(7,6)  NULL,
	original_principal_amount	DECIMAL(12,2) NULL,
	cancelled_amount			DECIMAL(12,2) NULL,
	undisbursed_amount			DECIMAL(12,2) NULL,
	disbursed_amount			DECIMAL(12,2) NOT NULL,
	repaid_to_ibrd				DECIMAL(12,2) NULL,
	due_to_ibrd					DECIMAL(12,2) NULL,
	exchange_adjustment			DECIMAL(12,2) NULL,
	borrowers_obligation		DECIMAL(12,2) NULL,
	loans_held					DECIMAL(12,2) NULL,
PRIMARY KEY (loan_number, end_of_period)
);

CREATE TABLE dates (
    end_of_period				DATE NOT NULL,
	loan_number					VARCHAR(10) NOT NULL,
	board_approval_date			DATE NOT NULL,
	agreement_signing_date		DATE NULL,
	first_repayment_date		DATE NULL,
	last_repayment_date			DATE NULL,
	effective_date_most_recent	DATE NULL,
	closed_date_most_recent		DATE NULL,
	last_disbursement_date		DATE NULL,
PRIMARY KEY (loan_number, end_of_period)
);

CREATE TABLE thirdparty (
    end_of_period		DATE 		  NOT NULL,
	loan_number			VARCHAR(10)	  NOT NULL,
	sold_third_party	DECIMAL(12,2) NULL,
	repaid_third_party	DECIMAL(12,2) NULL,
	due_third_party		DECIMAL(12,2) NULL,
PRIMARY KEY (loan_number, end_of_period)
);

CREATE TABLE projects (
	project_id		VARCHAR(10),
	project_name	VARCHAR(100) NULL,
PRIMARY KEY (project_id)
);

CREATE TABLE countries (
	country_code	VARCHAR(2),
	country			VARCHAR(50) NULL,
	region			VARCHAR(50) NULL,
	is_guarantor	BIT			NULL DEFAULT 0,
PRIMARY KEY (country_code)
);

-- Foreign keys

ALTER TABLE loans
	ADD CONSTRAINT fk_loans_money
    FOREIGN KEY (loan_number, end_of_period)
    REFERENCES money (loan_number, end_of_period)
	ON DELETE NO ACTION
	ON UPDATE NO ACTION;
  
ALTER TABLE loans
	ADD CONSTRAINT fk_loans_dates
    FOREIGN KEY (loan_number, end_of_period)
    REFERENCES dates (loan_number, end_of_period)
	ON DELETE NO ACTION
	ON UPDATE NO ACTION;
    
ALTER TABLE loans
	ADD CONSTRAINT fk_loans_thirdparty
    FOREIGN KEY (loan_number, end_of_period)
    REFERENCES thirdparty (loan_number, end_of_period)
	ON DELETE NO ACTION
	ON UPDATE NO ACTION;
    
ALTER TABLE loans
	ADD CONSTRAINT fk_loans_projects
    FOREIGN KEY (project_id)
    REFERENCES projects (project_id)
	ON DELETE NO ACTION
	ON UPDATE NO ACTION;
 
ALTER TABLE loans
	ADD CONSTRAINT fk_loans_countries
    FOREIGN KEY (country_code)
    REFERENCES countries (country_code)
	ON DELETE NO ACTION
	ON UPDATE NO ACTION;

ALTER TABLE loans
	ADD CONSTRAINT fk_loans_countries_g
    FOREIGN KEY (guarantor_country_code)
    REFERENCES countries (country_code)
	ON DELETE NO ACTION
	ON UPDATE NO ACTION;

-- Create table for importing data, either from a csv
-- or Python (table is also created there)

CREATE TABLE import_data (
    end_of_period 				DATE,
	loan_number 				VARCHAR(10),
	region 						VARCHAR(50),
	country_code 				VARCHAR(2),
	country 					VARCHAR(50),
	borrower 					VARCHAR(100),
	guarantor_country_code 		VARCHAR(2),
	guarantor 					VARCHAR(50),
	loan_type 					VARCHAR(5),
	loan_status 				VARCHAR(50),
	interest_rate 				DECIMAL(7, 6),
	currency_of_commitment 		VARCHAR(50),
	project_id 					VARCHAR(10),
	project_name 				VARCHAR(100),
	original_principal_amount 	DECIMAL(12, 2),
	cancelled_amount 			DECIMAL(12, 2),
	undisbursed_amount 			DECIMAL(12, 2),
	disbursed_amount 			DECIMAL(12, 2),
	repaid_to_ibrd 				DECIMAL(12, 2),
	due_to_ibrd 				DECIMAL(12, 2),
	exchange_adjustment 		DECIMAL(12, 2),
	borrowers_obligation 		DECIMAL(12, 2),
	sold_third_party 			DECIMAL(12, 2),
	repaid_third_party 			DECIMAL(12, 2),
	due_third_party 			DECIMAL(12, 2),
	loans_held 					DECIMAL(12, 2),
	first_repayment_date 		DATE,
	last_repayment_date 		DATE,
	agreement_signing_date 		DATE,
	board_approval_date 		DATE,
	effective_date_most_recent	DATE,
	closed_date_most_recent 	DATE,
	last_disbursement_date 		DATE
);

-- Stored procedure to distribute (INSERT) the data into the relational db

DROP PROCEDURE IF EXISTS insert_import_data;

CREATE PROCEDURE insert_import_data AS
BEGIN
	INSERT INTO money (
		end_of_period,
		loan_number,
		currency_of_commitment,
		interest_rate,
		original_principal_amount,
		cancelled_amount,	
		undisbursed_amount,
		disbursed_amount,
		repaid_to_ibrd,
		due_to_ibrd,
		exchange_adjustment,
		borrowers_obligation,
		loans_held
	)
	SELECT
		end_of_period,
		loan_number,
		currency_of_commitment,
		interest_rate,
		original_principal_amount,
		cancelled_amount,	
		undisbursed_amount,
		disbursed_amount,
		repaid_to_ibrd,
		due_to_ibrd,
		exchange_adjustment,
		borrowers_obligation,
		loans_held
	FROM import_data;

	INSERT INTO dates (
		end_of_period,
		loan_number,
		board_approval_date,
		agreement_signing_date,
		first_repayment_date,
		last_repayment_date,
		effective_date_most_recent,
		closed_date_most_recent,
		last_disbursement_date
	)
	SELECT
		end_of_period,
		loan_number,
		board_approval_date,
		agreement_signing_date,
		first_repayment_date,
		last_repayment_date,
		effective_date_most_recent,
		closed_date_most_recent,
		last_disbursement_date
	FROM import_data;

	INSERT INTO thirdparty (
		end_of_period,
		loan_number,
		sold_third_party,
		repaid_third_party,
		due_third_party
	)
	SELECT
		end_of_period,
		loan_number,
		sold_third_party,
		repaid_third_party,
		due_third_party
	FROM import_data;
	
	INSERT INTO projects (
		project_id,
		project_name
	)
	SELECT
		DISTINCT(project_id),
		project_name
	FROM import_data AS imp
	WHERE NOT EXISTS (
		SELECT project_id
        FROM projects AS p
        WHERE p.project_id = imp.project_id
	)
	ORDER BY project_id;

	INSERT INTO countries (
		country_code,
		country,
		region
	)
	SELECT
		DISTINCT(country_code),
		country,
		region
	FROM import_data AS imp
	WHERE NOT EXISTS (
		SELECT country_code
        FROM countries AS c
        WHERE c.country_code = imp.country_code
	);

	INSERT INTO countries (
		country_code,
		country
	)
	SELECT
		DISTINCT(guarantor_country_code),
		guarantor
	FROM import_data AS imp
	WHERE guarantor_country_code IS NOT NULL
	AND NOT EXISTS (
		SELECT country_code
        FROM countries AS c
        WHERE c.country_code = imp.guarantor_country_code
	);

	UPDATE countries
	SET is_guarantor = 1
	WHERE country_code IN 
		(SELECT DISTINCT(guarantor_country_code)
		FROM import_data 
		WHERE guarantor_country_code IS NOT NULL);

	INSERT INTO loans (
		end_of_period,
		loan_number,
		borrower,
		project_id,
		country_code,
		guarantor_country_code,
		loan_type,
		loan_status
	)
	SELECT
		end_of_period,
		loan_number,
		borrower,
		project_id,
		country_code,
		guarantor_country_code,
		loan_type,
		loan_status
	FROM import_data;
END;

-- Importing Data

-- We import the data from the .csv into a single table "temp_import_data"
-- DROP TABLE IF EXISTS temp_import_data;
-- SELECT * FROM temp_import_data;

-- Insert the data into the table "import_data"
-- INSERT INTO import_data SELECT * FROM temp_import_data;
-- DROP TABLE IF EXISTS temp_import_data;

-- or
-- Use Python to import it directly

-- Check the data was imported correctly
SELECT * FROM import_data;

-- Populate the RDB
EXEC insert_import_data;

-- Check tables
SELECT * FROM loans;
SELECT * FROM money;
SELECT * FROM dates;
SELECT * FROM thirdparty;
SELECT * FROM projects;
SELECT * FROM countries;

-- END
-- ---