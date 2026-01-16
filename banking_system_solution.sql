-- =========================================================
-- ADVANCED SQL PRACTICE FILE (BANKING DATABASE)
-- Level: Moderate → Ultra Difficult | Industry-Oriented
-- Assume MySQL 8+
-- =========================================================


-- =========================================================
-- 🟦 SECTION 1 — Aggregates, GROUP BY, HAVING, WHERE, ORDER BY (25)
-- =========================================================

-- 10. Find accounts that have zero transactions.

SELECT
    a.account_id
FROM accounts a
LEFT JOIN transactions t
    ON a.account_id = t.account_id
WHERE t.transaction_id IS NULL;


-- 11. Compute the average transaction size per transaction_type.

SELECT
    t.transaction_type,
    AVG(ABS(t.amount)) AS avg_transaction_size
FROM transactions t
GROUP BY t.transaction_type
ORDER BY avg_transaction_size DESC;


-- 12. Identify customers who have accounts in more than one branch.

SELECT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    COUNT(DISTINCT a.branch_id) AS branch_count
FROM customer_accounts ca
JOIN customers c ON c.customer_id = ca.customer_id
JOIN accounts a ON a.account_id = ca.account_id
GROUP BY ca.customer_id, c.first_name, c.last_name
HAVING COUNT(DISTINCT a.branch_id) > 1
ORDER BY branch_count DESC;


-- 13. Find branches with the highest average account age.

SELECT
    b.branch_id,
    b.name AS branch_name,
    AVG(DATEDIFF(CURDATE(), a.opened_date)) AS avg_account_age_days
FROM branches b
JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.name
ORDER BY avg_account_age_days DESC;


-- 14. For each loan_type, calculate average interest_rate and principal_amount.

SELECT
    l.loan_type,
    AVG(l.interest_rate) AS avg_interest_rate,
    AVG(l.principal_amount) AS avg_principal_amount
FROM loans l
GROUP BY l.loan_type
ORDER BY avg_principal_amount DESC;


-- 15. Find customers who have paid more than ₹500 in total fees.

SELECT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    SUM(f.amount) AS total_fees_paid
FROM fees f
JOIN customer_accounts ca ON ca.account_id = f.account_id
JOIN customers c ON c.customer_id = ca.customer_id
GROUP BY ca.customer_id, c.first_name, c.last_name
HAVING SUM(f.amount) > 500
ORDER BY total_fees_paid DESC;


-- 16. Identify the top 5 busiest branches by transaction count.

SELECT
    b.branch_id,
    b.name AS branch_name,
    COUNT(*) AS transaction_count
FROM branches b
JOIN accounts a ON a.branch_id = b.branch_id
JOIN transactions t ON t.account_id = a.account_id
GROUP BY b.branch_id, b.name
ORDER BY transaction_count DESC
LIMIT 5;


-- 17. Calculate the percentage of frozen accounts.

SELECT
    ROUND(
        100 * SUM(CASE WHEN LOWER(a.status) = 'frozen' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS frozen_percentage
FROM accounts a;


-- 18. Find accounts with negative net balance (ledger-based).

SELECT
    t.account_id,
    SUM(t.amount) AS net_ledger_balance
FROM transactions t
GROUP BY t.account_id
HAVING SUM(t.amount) < 0
ORDER BY net_ledger_balance ASC;


-- 19. Identify customers whose latest transaction is older than 2 years.

SELECT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    MAX(t.transaction_date) AS latest_transaction_date
FROM customers c
JOIN customer_accounts ca ON ca.customer_id = c.customer_id
JOIN transactions t ON t.account_id = ca.account_id
GROUP BY ca.customer_id, c.first_name, c.last_name
HAVING MAX(t.transaction_date) < DATE_SUB(CURDATE(), INTERVAL 2 YEAR);


-- 20. Compute median transaction amount per account (MySQL workaround).

WITH ranked AS (
    SELECT
        account_id,
        amount,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY amount) AS rn,
        COUNT(*) OVER (PARTITION BY account_id) AS cnt
    FROM transactions
),
picked AS (
    SELECT
        account_id,
        amount
    FROM ranked
    WHERE rn IN (FLOOR((cnt + 1) / 2), FLOOR((cnt + 2) / 2))
)
SELECT
    account_id,
    AVG(amount) AS median_transaction_amount
FROM picked
GROUP BY account_id;


-- 21. Find employees who have never created a transaction.

SELECT
    e.employee_id,
    e.branch_id
FROM employees e
LEFT JOIN transactions t
    ON t.created_by_employee_id = e.employee_id
WHERE t.transaction_id IS NULL;


-- 22. Identify branches where average withdrawal > average deposit.

SELECT
    b.branch_id,
    b.name AS branch_name,
    AVG(CASE WHEN LOWER(t.transaction_type) = 'withdrawal' THEN ABS(t.amount) END) AS avg_withdrawal,
    AVG(CASE WHEN LOWER(t.transaction_type) = 'deposit' THEN t.amount END) AS avg_deposit
FROM branches b
JOIN accounts a ON a.branch_id = b.branch_id
JOIN transactions t ON t.account_id = a.account_id
GROUP BY b.branch_id, b.name
HAVING AVG(CASE WHEN LOWER(t.transaction_type) = 'withdrawal' THEN ABS(t.amount) END)
     > AVG(CASE WHEN LOWER(t.transaction_type) = 'deposit' THEN t.amount END);


-- 23. Count joint accounts vs single-owner accounts.

WITH owners AS (
    SELECT
        account_id,
        COUNT(DISTINCT customer_id) AS owner_count
    FROM customer_accounts
    GROUP BY account_id
)
SELECT
    SUM(CASE WHEN owner_count = 1 THEN 1 ELSE 0 END) AS single_owner_accounts,
    SUM(CASE WHEN owner_count > 1 THEN 1 ELSE 0 END) AS joint_accounts
FROM owners;


-- 24. Find customers whose average transaction amount > overall average.

WITH cust_avg AS (
    SELECT
        ca.customer_id,
        AVG(ABS(t.amount)) AS avg_txn
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id
),
overall AS (
    SELECT AVG(ABS(amount)) AS overall_avg
    FROM transactions
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    ca.avg_txn
FROM cust_avg ca
JOIN overall o
JOIN customers c ON c.customer_id = ca.customer_id
WHERE ca.avg_txn > o.overall_avg
ORDER BY ca.avg_txn DESC;


-- 25. Rank transaction_types by total monetary impact.

SELECT
    t.transaction_type,
    SUM(t.amount) AS total_impact
FROM transactions t
GROUP BY t.transaction_type
ORDER BY total_impact DESC;



-- =========================================================
-- 🟦 SECTION 2 — Advanced JOINs & Self-JOINs (30)
-- =========================================================

-- 26. List customers with their total number of accounts and total transactions.

WITH acc AS (
    SELECT
        customer_id,
        COUNT(DISTINCT account_id) AS total_accounts
    FROM customer_accounts
    GROUP BY customer_id
),
tx AS (
    SELECT
        ca.customer_id,
        COUNT(DISTINCT t.transaction_id) AS total_transactions
    FROM customer_accounts ca
    LEFT JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    COALESCE(a.total_accounts, 0) AS total_accounts,
    COALESCE(t.total_transactions, 0) AS total_transactions
FROM customers c
LEFT JOIN acc a ON a.customer_id = c.customer_id
LEFT JOIN tx t ON t.customer_id = c.customer_id
ORDER BY total_transactions DESC, total_accounts DESC;


-- 27. Find customers who share at least one joint account.

SELECT DISTINCT
    ca1.customer_id AS customer_1,
    ca2.customer_id AS customer_2,
    ca1.account_id
FROM customer_accounts ca1
JOIN customer_accounts ca2
    ON ca1.account_id = ca2.account_id
   AND ca1.customer_id < ca2.customer_id;


-- 28. Identify accounts with multiple owners and list all owners.

SELECT
    ca.account_id,
    GROUP_CONCAT(
        DISTINCT CONCAT_WS(' ', c.first_name, c.last_name)
        ORDER BY c.customer_id
        SEPARATOR ', '
    ) AS owners,
    COUNT(DISTINCT ca.customer_id) AS owner_count
FROM customer_accounts ca
JOIN customers c ON c.customer_id = ca.customer_id
GROUP BY ca.account_id
HAVING COUNT(DISTINCT ca.customer_id) > 1
ORDER BY owner_count DESC;


-- 29. Find transfers where from_account and to_account belong to the same customer.

SELECT
    tr.transfer_id,
    tr.from_account_id,
    tr.to_account_id,
    tr.amount
FROM transfers tr
JOIN customer_accounts ca1 ON ca1.account_id = tr.from_account_id
JOIN customer_accounts ca2 ON ca2.account_id = tr.to_account_id
WHERE ca1.customer_id = ca2.customer_id;


-- 30. Find customers who have both a loan and a savings account.

SELECT DISTINCT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name
FROM customers c
JOIN loans l ON l.customer_id = c.customer_id
JOIN customer_accounts ca ON ca.customer_id = c.customer_id
JOIN accounts a ON a.account_id = ca.account_id
WHERE LOWER(a.account_type) = 'savings';


-- 31. Identify customers who have cards on inactive accounts.

SELECT DISTINCT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    a.account_id,
    a.status AS account_status,
    cd.card_id,
    cd.status AS card_status
FROM cards cd
JOIN accounts a ON a.account_id = cd.account_id
JOIN customer_accounts ca ON ca.account_id = a.account_id
JOIN customers c ON c.customer_id = ca.customer_id
WHERE LOWER(a.status) <> 'active';


-- 32. Find branches where employees manage accounts but never transactions.

-- meaning: branch has employees AND accounts, but 0 transactions ever in branch
SELECT
    b.branch_id,
    b.name AS branch_name
FROM branches b
JOIN employees e ON e.branch_id = b.branch_id
JOIN accounts a ON a.branch_id = b.branch_id
LEFT JOIN transactions t ON t.account_id = a.account_id
GROUP BY b.branch_id, b.name
HAVING COUNT(DISTINCT e.employee_id) > 0
   AND COUNT(DISTINCT a.account_id) > 0
   AND COUNT(DISTINCT t.transaction_id) = 0;


-- 33. Self-join transactions to find same-day multiple withdrawals per account.

SELECT DISTINCT
    t1.account_id,
    DATE(t1.transaction_date) AS txn_day
FROM transactions t1
JOIN transactions t2
    ON t1.account_id = t2.account_id
   AND DATE(t1.transaction_date) = DATE(t2.transaction_date)
   AND t1.transaction_id < t2.transaction_id
WHERE LOWER(t1.transaction_type) = 'withdrawal'
  AND LOWER(t2.transaction_type) = 'withdrawal';


-- 34. Find customers whose accounts exist in branches where they don’t reside (city mismatch).

SELECT DISTINCT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    c.city AS customer_city,
    b.city AS branch_city,
    a.account_id
FROM customers c
JOIN customer_accounts ca ON ca.customer_id = c.customer_id
JOIN accounts a ON a.account_id = ca.account_id
JOIN branches b ON b.branch_id = a.branch_id
WHERE LOWER(c.city) <> LOWER(b.city);


-- 35. Identify accounts that received transfers but never initiated one.

SELECT
    a.account_id
FROM accounts a
JOIN transfers tr_in
    ON tr_in.to_account_id = a.account_id
LEFT JOIN transfers tr_out
    ON tr_out.from_account_id = a.account_id
WHERE tr_out.transfer_id IS NULL
GROUP BY a.account_id;


-- 36. Find customers whose largest transaction was a withdrawal.

WITH cust_tx AS (
    SELECT
        ca.customer_id,
        t.transaction_id,
        t.transaction_type,
        ABS(t.amount) AS amt,
        ROW_NUMBER() OVER (
            PARTITION BY ca.customer_id
            ORDER BY ABS(t.amount) DESC, t.transaction_date DESC
        ) AS rn
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name
FROM cust_tx x
JOIN customers c ON c.customer_id = x.customer_id
WHERE x.rn = 1
  AND LOWER(x.transaction_type) = 'withdrawal';


-- 37. List accounts with fees but no transactions in the same month.

SELECT
    f.account_id,
    DATE_FORMAT(f.fee_date, '%Y-%m') AS fee_month
FROM fees f
LEFT JOIN transactions t
    ON t.account_id = f.account_id
   AND DATE_FORMAT(t.transaction_date, '%Y-%m') = DATE_FORMAT(f.fee_date, '%Y-%m')
WHERE t.transaction_id IS NULL
GROUP BY f.account_id, fee_month;


-- 38. Join loans and transactions to find accounts making payments before loan start_date.

SELECT
    l.loan_id,
    l.account_id,
    t.transaction_id,
    t.transaction_date,
    t.amount
FROM loans l
JOIN transactions t
    ON t.account_id = l.account_id
WHERE LOWER(t.transaction_type) IN ('loan_payment', 'repayment', 'emi')
  AND t.transaction_date < l.start_date;


-- 39. Identify customers who have cards linked to multiple accounts.

SELECT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    cd.card_id,
    COUNT(DISTINCT cd.account_id) AS linked_accounts
FROM cards cd
JOIN customer_accounts ca ON ca.account_id = cd.account_id
JOIN customers c ON c.customer_id = ca.customer_id
GROUP BY ca.customer_id, c.first_name, c.last_name, cd.card_id
HAVING COUNT(DISTINCT cd.account_id) > 1;


-- 40. Find branches with higher loan default rate than overall average.

WITH br AS (
    SELECT
        a.branch_id,
        AVG(CASE WHEN l.default_flag = 1 OR LOWER(l.status) = 'default' THEN 1 ELSE 0 END) AS br_default_rate
    FROM loans l
    JOIN accounts a ON a.account_id = l.account_id
    GROUP BY a.branch_id
),
ov AS (
    SELECT
        AVG(CASE WHEN default_flag = 1 OR LOWER(status) = 'default' THEN 1 ELSE 0 END) AS overall_default_rate
    FROM loans
)
SELECT
    b.branch_id,
    b.name AS branch_name,
    br.br_default_rate
FROM br
JOIN ov
JOIN branches b ON b.branch_id = br.branch_id
WHERE br.br_default_rate > ov.overall_default_rate
ORDER BY br.br_default_rate DESC;


-- 41. Find accounts where employee-created transactions > system-created transactions.

SELECT
    t.account_id
FROM transactions t
GROUP BY t.account_id
HAVING
    SUM(CASE WHEN t.created_by_employee_id IS NOT NULL THEN 1 ELSE 0 END)
    >
    SUM(CASE WHEN t.created_by_employee_id IS NULL THEN 1 ELSE 0 END);


-- 42. Identify customers who became joint owners after account opening.

SELECT DISTINCT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    ca.account_id,
    ca.ownership_start_date,
    a.opened_date
FROM customer_accounts ca
JOIN accounts a ON a.account_id = ca.account_id
JOIN customers c ON c.customer_id = ca.customer_id
WHERE ca.ownership_start_date > a.opened_date;


-- 43. Self-join accounts to find customers with multiple accounts opened on the same day.

SELECT DISTINCT
    ca1.customer_id,
    ca1.account_id AS account_1,
    ca2.account_id AS account_2,
    a1.opened_date
FROM customer_accounts ca1
JOIN customer_accounts ca2
    ON ca1.customer_id = ca2.customer_id
   AND ca1.account_id < ca2.account_id
JOIN accounts a1 ON a1.account_id = ca1.account_id
JOIN accounts a2 ON a2.account_id = ca2.account_id
WHERE a1.opened_date = a2.opened_date;


-- 44. Find employees who handled transactions for accounts outside their branch.

SELECT DISTINCT
    e.employee_id,
    e.branch_id AS employee_branch,
    a.branch_id AS account_branch,
    t.transaction_id
FROM employees e
JOIN transactions t ON t.created_by_employee_id = e.employee_id
JOIN accounts a ON a.account_id = t.account_id
WHERE e.branch_id <> a.branch_id;


-- 45. Identify customers whose account count > branch average.

WITH cust_counts AS (
    SELECT
        ca.customer_id,
        a.branch_id,
        COUNT(DISTINCT ca.account_id) AS acc_count
    FROM customer_accounts ca
    JOIN accounts a ON a.account_id = ca.account_id
    GROUP BY ca.customer_id, a.branch_id
),
br_avg AS (
    SELECT
        branch_id,
        AVG(acc_count) AS avg_acc_per_customer
    FROM cust_counts
    GROUP BY branch_id
)
SELECT
    cc.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    cc.branch_id,
    cc.acc_count,
    ba.avg_acc_per_customer
FROM cust_counts cc
JOIN br_avg ba ON ba.branch_id = cc.branch_id
JOIN customers c ON c.customer_id = cc.customer_id
WHERE cc.acc_count > ba.avg_acc_per_customer
ORDER BY cc.acc_count DESC;


-- 46. Find customers whose accounts never had INTEREST transactions.

SELECT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name
FROM customer_accounts ca
JOIN customers c ON c.customer_id = ca.customer_id
LEFT JOIN transactions t
    ON t.account_id = ca.account_id
   AND LOWER(t.transaction_type) = 'interest'
GROUP BY ca.customer_id, c.first_name, c.last_name
HAVING COUNT(t.transaction_id) = 0;


-- 47. Detect transfers where transaction_date ≠ initiated_at date.

SELECT
    transfer_id,
    from_account_id,
    to_account_id,
    transaction_date,
    initiated_at
FROM transfers
WHERE DATE(transaction_date) <> DATE(initiated_at);


-- 48. Find customers linked to multiple cards of different types.

SELECT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    COUNT(DISTINCT cd.card_type) AS distinct_card_types
FROM cards cd
JOIN customer_accounts ca ON ca.account_id = cd.account_id
JOIN customers c ON c.customer_id = ca.customer_id
GROUP BY ca.customer_id, c.first_name, c.last_name
HAVING COUNT(DISTINCT cd.card_type) > 1
ORDER BY distinct_card_types DESC;


-- 49. Identify branches where average transaction amount is declining month-over-month.

WITH m AS (
    SELECT
        a.branch_id,
        DATE_FORMAT(t.transaction_date, '%Y-%m') AS ym,
        AVG(ABS(t.amount)) AS avg_amt
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY a.branch_id, ym
),
x AS (
    SELECT
        branch_id,
        ym,
        avg_amt,
        LAG(avg_amt) OVER (PARTITION BY branch_id ORDER BY ym) AS prev_avg
    FROM m
)
SELECT DISTINCT
    b.branch_id,
    b.name AS branch_name
FROM x
JOIN branches b ON b.branch_id = x.branch_id
WHERE prev_avg IS NOT NULL
  AND avg_amt < prev_avg;


-- 50. Join fees, transactions, accounts to find fees without any nearby transaction.

-- nearby = within ±3 days of fee_date
SELECT
    f.fee_id,
    f.account_id,
    f.amount,
    f.fee_date
FROM fees f
LEFT JOIN transactions t
    ON t.account_id = f.account_id
   AND t.transaction_date BETWEEN DATE_SUB(f.fee_date, INTERVAL 3 DAY)
                             AND DATE_ADD(f.fee_date, INTERVAL 3 DAY)
WHERE t.transaction_id IS NULL;


-- 51. Find customers whose first transaction happened before account opened_date.

SELECT DISTINCT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    ca.account_id
FROM customer_accounts ca
JOIN customers c ON c.customer_id = ca.customer_id
JOIN accounts a ON a.account_id = ca.account_id
JOIN transactions t ON t.account_id = a.account_id
GROUP BY ca.customer_id, c.first_name, c.last_name, ca.account_id, a.opened_date
HAVING MIN(t.transaction_date) < a.opened_date;


-- 52. Detect accounts that received transfers from more than 10 unique accounts.

SELECT
    tr.to_account_id AS account_id,
    COUNT(DISTINCT tr.from_account_id) AS unique_senders
FROM transfers tr
GROUP BY tr.to_account_id
HAVING COUNT(DISTINCT tr.from_account_id) > 10
ORDER BY unique_senders DESC;


-- 53. Identify customers whose loan account has no repayment transactions.

SELECT DISTINCT
    l.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    l.loan_id,
    l.account_id
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id
LEFT JOIN transactions t
    ON t.account_id = l.account_id
   AND LOWER(t.transaction_type) IN ('loan_payment','repayment','emi')
WHERE t.transaction_id IS NULL;


-- 54. Find branches where employees > accounts ratio is highest.

SELECT
    b.branch_id,
    b.name AS branch_name,
    COUNT(DISTINCT e.employee_id) / NULLIF(COUNT(DISTINCT a.account_id), 0) AS emp_to_account_ratio
FROM branches b
LEFT JOIN employees e ON e.branch_id = b.branch_id
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.name
ORDER BY emp_to_account_ratio DESC;


-- 55. List customers who share a joint account but never transacted on it themselves.

WITH joint AS (
    SELECT account_id
    FROM customer_accounts
    GROUP BY account_id
    HAVING COUNT(DISTINCT customer_id) > 1
)
SELECT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    ca.account_id
FROM customer_accounts ca
JOIN joint j ON j.account_id = ca.account_id
JOIN customers c ON c.customer_id = ca.customer_id
LEFT JOIN transactions t
    ON t.account_id = ca.account_id
   AND EXISTS (
       SELECT 1
       FROM customer_accounts ca2
       WHERE ca2.account_id = t.account_id
         AND ca2.customer_id = ca.customer_id
   )
WHERE t.transaction_id IS NULL;



-- =========================================================
-- 🟦 SECTION 3 — Subqueries (10)
-- =========================================================

-- 56. Find customers whose total transaction amount > average customer total.

WITH cust_tot AS (
    SELECT
        ca.customer_id,
        SUM(t.amount) AS total_amt
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id
),
avg_tot AS (
    SELECT AVG(total_amt) AS avg_total
    FROM cust_tot
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    ct.total_amt
FROM cust_tot ct
JOIN avg_tot at
JOIN customers c ON c.customer_id = ct.customer_id
WHERE ct.total_amt > at.avg_total
ORDER BY ct.total_amt DESC;


-- 57. Identify accounts whose largest transaction > 2× account average.

SELECT
    account_id
FROM (
    SELECT
        account_id,
        MAX(ABS(amount)) AS max_amt,
        AVG(ABS(amount)) AS avg_amt
    FROM transactions
    GROUP BY account_id
) x
WHERE x.max_amt > 2 * x.avg_amt;


-- 58. Find branches whose total deposits exceed every other branch.

WITH br_dep AS (
    SELECT
        a.branch_id,
        SUM(t.amount) AS total_deposits
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    WHERE LOWER(t.transaction_type) = 'deposit'
    GROUP BY a.branch_id
)
SELECT
    b.branch_id,
    b.name AS branch_name,
    d.total_deposits
FROM br_dep d
JOIN branches b ON b.branch_id = d.branch_id
WHERE d.total_deposits = (SELECT MAX(total_deposits) FROM br_dep);


-- 59. Find customers whose latest transaction is their largest ever.

WITH cust_tx AS (
    SELECT
        ca.customer_id,
        t.transaction_date,
        ABS(t.amount) AS amt
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
),
latest AS (
    SELECT customer_id, MAX(transaction_date) AS latest_dt
    FROM cust_tx
    GROUP BY customer_id
),
largest AS (
    SELECT customer_id, MAX(amt) AS largest_amt
    FROM cust_tx
    GROUP BY customer_id
),
latest_amt AS (
    SELECT
        ct.customer_id,
        ct.amt
    FROM cust_tx ct
    JOIN latest l
      ON l.customer_id = ct.customer_id
     AND l.latest_dt = ct.transaction_date
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name
FROM latest_amt la
JOIN largest lg ON lg.customer_id = la.customer_id
JOIN customers c ON c.customer_id = la.customer_id
WHERE la.amt = lg.largest_amt;


-- 60. Identify accounts with more fees than the average account.

WITH fee_cnt AS (
    SELECT
        account_id,
        COUNT(*) AS fee_count
    FROM fees
    GROUP BY account_id
),
avg_fee AS (
    SELECT AVG(fee_count) AS avg_fee_count
    FROM fee_cnt
)
SELECT
    fc.account_id,
    fc.fee_count
FROM fee_cnt fc
JOIN avg_fee af
WHERE fc.fee_count > af.avg_fee_count
ORDER BY fc.fee_count DESC;


-- 61. Find customers whose transaction count is in the top 5%.

WITH cust_cnt AS (
    SELECT
        ca.customer_id,
        COUNT(*) AS txn_count
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id
),
ranked AS (
    SELECT
        customer_id,
        txn_count,
        NTILE(20) OVER (ORDER BY txn_count DESC) AS top_bucket
    FROM cust_cnt
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    r.txn_count
FROM ranked r
JOIN customers c ON c.customer_id = r.customer_id
WHERE r.top_bucket = 1
ORDER BY r.txn_count DESC;


-- 62. Identify loans where interest_rate > average for same loan_type.

SELECT
    l.loan_id,
    l.loan_type,
    l.interest_rate
FROM loans l
WHERE l.interest_rate >
(
    SELECT AVG(l2.interest_rate)
    FROM loans l2
    WHERE l2.loan_type = l.loan_type
);


-- 63. Find customers whose account balance < branch average balance.

WITH cust_bal AS (
    SELECT
        ca.customer_id,
        a.branch_id,
        SUM(a.current_balance) AS cust_balance
    FROM customer_accounts ca
    JOIN accounts a ON a.account_id = ca.account_id
    GROUP BY ca.customer_id, a.branch_id
),
br_avg AS (
    SELECT
        branch_id,
        AVG(cust_balance) AS avg_customer_balance
    FROM cust_bal
    GROUP BY branch_id
)
SELECT
    cb.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    cb.branch_id,
    cb.cust_balance,
    ba.avg_customer_balance
FROM cust_bal cb
JOIN br_avg ba ON ba.branch_id = cb.branch_id
JOIN customers c ON c.customer_id = cb.customer_id
WHERE cb.cust_balance < ba.avg_customer_balance;


-- 64. Find accounts whose last transaction was a withdrawal AND amount > account avg.

WITH last_tx AS (
    SELECT
        t.*,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY transaction_date DESC, transaction_id DESC) AS rn
    FROM transactions t
),
avg_tx AS (
    SELECT
        account_id,
        AVG(ABS(amount)) AS avg_amt
    FROM transactions
    GROUP BY account_id
)
SELECT
    l.account_id
FROM last_tx l
JOIN avg_tx a ON a.account_id = l.account_id
WHERE l.rn = 1
  AND LOWER(l.transaction_type) = 'withdrawal'
  AND ABS(l.amount) > a.avg_amt;


-- 65. Identify customers who own the single most active account.

WITH acc_act AS (
    SELECT
        account_id,
        COUNT(*) AS txn_count
    FROM transactions
    GROUP BY account_id
),
top_acc AS (
    SELECT account_id
    FROM acc_act
    ORDER BY txn_count DESC
    LIMIT 1
)
SELECT DISTINCT
    ca.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    ca.account_id
FROM customer_accounts ca
JOIN top_acc ta ON ta.account_id = ca.account_id
JOIN customers c ON c.customer_id = ca.customer_id;



-- =========================================================
-- 🟦 SECTION 4 — Window Functions (25)
-- =========================================================

-- 66. Rank customers by total transaction value.

WITH cust_tot AS (
    SELECT
        ca.customer_id,
        SUM(t.amount) AS total_value
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    ct.total_value,
    DENSE_RANK() OVER (ORDER BY ct.total_value DESC) AS rank_no
FROM cust_tot ct
JOIN customers c ON c.customer_id = ct.customer_id;


-- 67. Calculate running balance per account ordered by transaction_date.

SELECT
    t.account_id,
    t.transaction_date,
    t.transaction_id,
    t.amount,
    SUM(t.amount) OVER (
        PARTITION BY t.account_id
        ORDER BY t.transaction_date, t.transaction_id
    ) AS running_balance
FROM transactions t
ORDER BY t.account_id, t.transaction_date, t.transaction_id;


-- 68. Rank transactions per account by absolute amount.

SELECT
    t.*,
    DENSE_RANK() OVER (
        PARTITION BY t.account_id
        ORDER BY ABS(t.amount) DESC
    ) AS txn_rank
FROM transactions t;


-- 69. Find the top transaction per customer.

WITH cust_tx AS (
    SELECT
        ca.customer_id,
        t.transaction_id,
        t.transaction_date,
        t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY ca.customer_id
            ORDER BY ABS(t.amount) DESC, t.transaction_date DESC
        ) AS rn
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    ct.transaction_id,
    ct.transaction_date,
    ct.amount
FROM cust_tx ct
JOIN customers c ON c.customer_id = ct.customer_id
WHERE ct.rn = 1;


-- 70. Compute month-over-month transaction growth per account.

WITH m AS (
    SELECT
        account_id,
        DATE_FORMAT(transaction_date, '%Y-%m') AS ym,
        SUM(ABS(amount)) AS total_amt
    FROM transactions
    GROUP BY account_id, ym
),
x AS (
    SELECT
        account_id,
        ym,
        total_amt,
        LAG(total_amt) OVER (PARTITION BY account_id ORDER BY ym) AS prev_amt
    FROM m
)
SELECT
    account_id,
    ym,
    total_amt,
    prev_amt,
    ROUND(100 * (total_amt - prev_amt) / NULLIF(prev_amt, 0), 2) AS mom_growth_pct
FROM x
ORDER BY account_id, ym;


-- 71. Identify customers whose activity declines 3 months in a row.

WITH m AS (
    SELECT
        ca.customer_id,
        DATE_FORMAT(t.transaction_date, '%Y-%m') AS ym,
        COUNT(*) AS txn_count
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id, ym
),
x AS (
    SELECT
        customer_id,
        ym,
        txn_count,
        LAG(txn_count, 1) OVER (PARTITION BY customer_id ORDER BY ym) AS p1,
        LAG(txn_count, 2) OVER (PARTITION BY customer_id ORDER BY ym) AS p2,
        LAG(txn_count, 3) OVER (PARTITION BY customer_id ORDER BY ym) AS p3
    FROM m
)
SELECT DISTINCT
    customer_id
FROM x
WHERE p3 IS NOT NULL
  AND p3 > p2 AND p2 > p1 AND p1 > txn_count;


-- 72. Rank branches by loan default rate.

WITH br AS (
    SELECT
        a.branch_id,
        AVG(CASE WHEN l.default_flag = 1 OR LOWER(l.status) = 'default' THEN 1 ELSE 0 END) AS default_rate
    FROM loans l
    JOIN accounts a ON a.account_id = l.account_id
    GROUP BY a.branch_id
)
SELECT
    b.branch_id,
    b.name AS branch_name,
    br.default_rate,
    DENSE_RANK() OVER (ORDER BY br.default_rate DESC) AS rank_no
FROM br
JOIN branches b ON b.branch_id = br.branch_id;


-- 73. Calculate cumulative deposits vs withdrawals per account.

SELECT
    t.account_id,
    t.transaction_date,
    t.transaction_id,
    SUM(CASE WHEN LOWER(t.transaction_type) = 'deposit' THEN t.amount ELSE 0 END)
        OVER (PARTITION BY t.account_id ORDER BY t.transaction_date, t.transaction_id) AS cum_deposit,
    SUM(CASE WHEN LOWER(t.transaction_type) = 'withdrawal' THEN ABS(t.amount) ELSE 0 END)
        OVER (PARTITION BY t.account_id ORDER BY t.transaction_date, t.transaction_id) AS cum_withdrawal
FROM transactions t
ORDER BY t.account_id, t.transaction_date, t.transaction_id;


-- 74. Find accounts where current balance < previous month balance.

WITH m AS (
    SELECT
        account_id,
        DATE_FORMAT(transaction_date, '%Y-%m') AS ym,
        SUM(amount) AS net_change
    FROM transactions
    GROUP BY account_id, ym
),
rb AS (
    SELECT
        account_id,
        ym,
        SUM(net_change) OVER (PARTITION BY account_id ORDER BY ym) AS month_end_balance
    FROM m
),
x AS (
    SELECT
        account_id,
        ym,
        month_end_balance,
        LAG(month_end_balance) OVER (PARTITION BY account_id ORDER BY ym) AS prev_balance
    FROM rb
)
SELECT
    account_id,
    ym,
    month_end_balance,
    prev_balance
FROM x
WHERE prev_balance IS NOT NULL
  AND month_end_balance < prev_balance;


-- 75. Rank customers within each branch by total balance.

WITH cust_bal AS (
    SELECT
        ca.customer_id,
        a.branch_id,
        SUM(a.current_balance) AS total_balance
    FROM customer_accounts ca
    JOIN accounts a ON a.account_id = ca.account_id
    GROUP BY ca.customer_id, a.branch_id
)
SELECT
    cb.branch_id,
    cb.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    cb.total_balance,
    DENSE_RANK() OVER (PARTITION BY cb.branch_id ORDER BY cb.total_balance DESC) AS branch_rank
FROM cust_bal cb
JOIN customers c ON c.customer_id = cb.customer_id
ORDER BY cb.branch_id, branch_rank;


-- 76. Identify transactions that are outliers (> 95th percentile).

WITH x AS (
    SELECT
        t.*,
        PERCENT_RANK() OVER (ORDER BY ABS(amount)) AS pr
    FROM transactions t
)
SELECT *
FROM x
WHERE pr >= 0.95;


-- 77. Calculate rolling 3-month transaction average per account.

WITH m AS (
    SELECT
        account_id,
        STR_TO_DATE(CONCAT(DATE_FORMAT(transaction_date, '%Y-%m'), '-01'), '%Y-%m-%d') AS month_start,
        SUM(ABS(amount)) AS month_total
    FROM transactions
    GROUP BY account_id, month_start
)
SELECT
    account_id,
    DATE_FORMAT(month_start, '%Y-%m') AS ym,
    month_total,
    AVG(month_total) OVER (
        PARTITION BY account_id
        ORDER BY month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3m_avg
FROM m
ORDER BY account_id, month_start;


-- 78. Find customers whose latest transaction rank = 1 and is withdrawal.

WITH cust_tx AS (
    SELECT
        ca.customer_id,
        t.transaction_type,
        t.transaction_date,
        ROW_NUMBER() OVER (
            PARTITION BY ca.customer_id
            ORDER BY t.transaction_date DESC, t.transaction_id DESC
        ) AS rn
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
)
SELECT DISTINCT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name
FROM cust_tx x
JOIN customers c ON c.customer_id = x.customer_id
WHERE x.rn = 1
  AND LOWER(x.transaction_type) = 'withdrawal';


-- 79. Rank employees by transaction handling volume within branch.

WITH emp_tx AS (
    SELECT
        e.branch_id,
        e.employee_id,
        COUNT(t.transaction_id) AS txn_count
    FROM employees e
LEFT JOIN transactions t ON t.created_by_employee_id = e.employee_id
GROUP BY e.branch_id, e.employee_id
)
SELECT
    branch_id,
    employee_id,
    txn_count,
    DENSE_RANK() OVER (PARTITION BY branch_id ORDER BY txn_count DESC) AS branch_rank
FROM emp_tx
ORDER BY branch_id, branch_rank;


-- 80. Compute time gap between consecutive transactions per account.

WITH x AS (
    SELECT
        t.*,
        LAG(t.transaction_date) OVER (PARTITION BY t.account_id ORDER BY t.transaction_date, t.transaction_id) AS prev_dt
    FROM transactions t
)
SELECT
    account_id,
    transaction_id,
    transaction_date,
    prev_dt,
    TIMESTAMPDIFF(DAY, prev_dt, transaction_date) AS gap_days
FROM x
WHERE prev_dt IS NOT NULL;


-- 81. Identify dormant accounts using window-based inactivity detection.

WITH last_tx AS (
    SELECT
        account_id,
        MAX(transaction_date) AS last_transaction_date
    FROM transactions
    GROUP BY account_id
)
SELECT
    a.account_id,
    lt.last_transaction_date
FROM accounts a
LEFT JOIN last_tx lt ON lt.account_id = a.account_id
WHERE lt.last_transaction_date IS NULL
   OR lt.last_transaction_date < DATE_SUB(CURDATE(), INTERVAL 12 MONTH);


-- 82. Rank loan accounts by remaining term length.

SELECT
    l.loan_id,
    l.account_id,
    l.end_date,
    DATEDIFF(l.end_date, CURDATE()) AS remaining_days,
    DENSE_RANK() OVER (ORDER BY DATEDIFF(l.end_date, CURDATE()) DESC) AS rank_no
FROM loans l
WHERE l.end_date IS NOT NULL;


-- 83. Calculate percent contribution of each account to customer balance.

WITH cb AS (
    SELECT
        ca.customer_id,
        ca.account_id,
        a.current_balance
    FROM customer_accounts ca
    JOIN accounts a ON a.account_id = ca.account_id
),
tot AS (
    SELECT
        customer_id,
        SUM(current_balance) AS total_balance
    FROM cb
    GROUP BY customer_id
)
SELECT
    cb.customer_id,
    cb.account_id,
    cb.current_balance,
    ROUND(100 * cb.current_balance / NULLIF(t.total_balance, 0), 2) AS pct_contribution
FROM cb
JOIN tot t ON t.customer_id = cb.customer_id
ORDER BY cb.customer_id, pct_contribution DESC;


-- 84. Identify customers whose account count ranks in top 10%.

WITH cc AS (
    SELECT
        customer_id,
        COUNT(DISTINCT account_id) AS acc_count
    FROM customer_accounts
    GROUP BY customer_id
),
ranked AS (
    SELECT
        customer_id,
        acc_count,
        NTILE(10) OVER (ORDER BY acc_count DESC) AS bucket
    FROM cc
)
SELECT
    r.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    r.acc_count
FROM ranked r
JOIN customers c ON c.customer_id = r.customer_id
WHERE r.bucket = 1
ORDER BY r.acc_count DESC;


-- 85. Detect sudden spikes: transactions > 3× rolling average.

WITH x AS (
    SELECT
        t.*,
        AVG(ABS(amount)) OVER (
            PARTITION BY account_id
            ORDER BY transaction_date, transaction_id
            ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING
        ) AS rolling_avg
    FROM transactions t
)
SELECT *
FROM x
WHERE rolling_avg IS NOT NULL
  AND ABS(amount) > 3 * rolling_avg;


-- 86. Rank cards per customer by usage proxy (transaction count).

WITH card_usage AS (
    SELECT
        ca.customer_id,
        cd.card_id,
        COUNT(t.transaction_id) AS txn_count
    FROM cards cd
    JOIN customer_accounts ca ON ca.account_id = cd.account_id
    LEFT JOIN transactions t ON t.account_id = cd.account_id
    GROUP BY ca.customer_id, cd.card_id
)
SELECT
    customer_id,
    card_id,
    txn_count,
    DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY txn_count DESC) AS usage_rank
FROM card_usage
ORDER BY customer_id, usage_rank;


-- 87. Find branches with consistently increasing transaction volume.

WITH m AS (
    SELECT
        a.branch_id,
        DATE_FORMAT(t.transaction_date, '%Y-%m') AS ym,
        COUNT(*) AS txn_count
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY a.branch_id, ym
),
x AS (
    SELECT
        branch_id,
        ym,
        txn_count,
        LAG(txn_count) OVER (PARTITION BY branch_id ORDER BY ym) AS prev_cnt
    FROM m
)
SELECT DISTINCT branch_id
FROM x
GROUP BY branch_id
HAVING SUM(CASE WHEN prev_cnt IS NOT NULL AND txn_count > prev_cnt THEN 1 ELSE 0 END) >= 3;


-- 88. Identify customers whose largest transaction is within last 10% of timeline.

WITH ct AS (
    SELECT
        ca.customer_id,
        t.transaction_date,
        ABS(t.amount) AS amt,
        ROW_NUMBER() OVER (PARTITION BY ca.customer_id ORDER BY t.transaction_date) AS rn_time,
        COUNT(*) OVER (PARTITION BY ca.customer_id) AS total_txn
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
),
largest AS (
    SELECT
        customer_id,
        MAX(amt) AS max_amt
    FROM ct
    GROUP BY customer_id
)
SELECT DISTINCT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name
FROM ct
JOIN largest l ON l.customer_id = ct.customer_id AND l.max_amt = ct.amt
JOIN customers c ON c.customer_id = ct.customer_id
WHERE ct.rn_time >= CEIL(0.9 * ct.total_txn);


-- 89. Rank accounts by volatility (stddev over time).

SELECT
    account_id,
    STDDEV_POP(amount) AS volatility,
    DENSE_RANK() OVER (ORDER BY STDDEV_POP(amount) DESC) AS volatility_rank
FROM transactions
GROUP BY account_id;


-- 90. Identify customers whose activity percentile dropped month-over-month.

WITH m AS (
    SELECT
        ca.customer_id,
        DATE_FORMAT(t.transaction_date, '%Y-%m') AS ym,
        COUNT(*) AS txn_count
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id, ym
),
p AS (
    SELECT
        customer_id,
        ym,
        txn_count,
        PERCENT_RANK() OVER (PARTITION BY ym ORDER BY txn_count) AS pr
    FROM m
),
x AS (
    SELECT
        customer_id,
        ym,
        pr,
        LAG(pr) OVER (PARTITION BY customer_id ORDER BY ym) AS prev_pr
    FROM p
)
SELECT DISTINCT customer_id
FROM x
WHERE prev_pr IS NOT NULL
  AND pr < prev_pr;



-- =========================================================
-- 🟦 SECTION 5 — CTEs (10)
-- =========================================================

-- 91. Using a CTE, calculate account balances and then filter negative ones.

WITH bal AS (
    SELECT
        account_id,
        SUM(amount) AS ledger_balance
    FROM transactions
    GROUP BY account_id
)
SELECT *
FROM bal
WHERE ledger_balance < 0
ORDER BY ledger_balance ASC;


-- 92. Build a CTE to compute monthly customer activity, then find drop-offs.

WITH m AS (
    SELECT
        ca.customer_id,
        DATE_FORMAT(t.transaction_date, '%Y-%m') AS ym,
        COUNT(*) AS txn_count
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id, ym
),
x AS (
    SELECT
        customer_id,
        ym,
        txn_count,
        LAG(txn_count) OVER (PARTITION BY customer_id ORDER BY ym) AS prev_cnt
    FROM m
)
SELECT
    customer_id,
    ym,
    prev_cnt,
    txn_count
FROM x
WHERE prev_cnt IS NOT NULL
  AND txn_count < 0.5 * prev_cnt
ORDER BY customer_id, ym;


-- 93. Use recursive CTE to generate a calendar table for missing months.

WITH RECURSIVE cal AS (
    SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 24 MONTH), '%Y-%m-01') AS month_start
    UNION ALL
    SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
    FROM cal
    WHERE month_start < DATE_FORMAT(CURDATE(), '%Y-%m-01')
)
SELECT
    DATE_FORMAT(month_start, '%Y-%m') AS ym
FROM cal;


-- 94. Build a CTE pipeline to find high-risk accounts (fees + overdrafts).

WITH fee_sum AS (
    SELECT account_id, SUM(amount) AS total_fees
    FROM fees
    GROUP BY account_id
),
overdrafts AS (
    SELECT account_id, COUNT(*) AS overdraft_count
    FROM transactions
    WHERE LOWER(transaction_type) = 'withdrawal'
      AND amount < 0
    GROUP BY account_id
),
risk AS (
    SELECT
        a.account_id,
        COALESCE(f.total_fees, 0) AS total_fees,
        COALESCE(o.overdraft_count, 0) AS overdraft_count,
        (COALESCE(f.total_fees, 0) + 200 * COALESCE(o.overdraft_count, 0)) AS risk_score
    FROM accounts a
    LEFT JOIN fee_sum f ON f.account_id = a.account_id
    LEFT JOIN overdrafts o ON o.account_id = a.account_id
)
SELECT *
FROM risk
WHERE risk_score >= 500
ORDER BY risk_score DESC;


-- 95. Compute customer lifetime value using layered CTEs.

WITH cust_tx AS (
    SELECT
        ca.customer_id,
        SUM(CASE WHEN LOWER(t.transaction_type) = 'deposit' THEN t.amount ELSE 0 END) AS total_deposit,
        SUM(CASE WHEN LOWER(t.transaction_type) = 'withdrawal' THEN ABS(t.amount) ELSE 0 END) AS total_withdrawal
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id
),
cust_fee AS (
    SELECT
        ca.customer_id,
        SUM(f.amount) AS total_fees
    FROM customer_accounts ca
    JOIN fees f ON f.account_id = ca.account_id
    GROUP BY ca.customer_id
),
clv AS (
    SELECT
        tx.customer_id,
        (tx.total_deposit - tx.total_withdrawal) + COALESCE(cf.total_fees, 0) AS lifetime_value
    FROM cust_tx tx
    LEFT JOIN cust_fee cf ON cf.customer_id = tx.customer_id
)
SELECT
    c.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    clv.lifetime_value
FROM clv
JOIN customers c ON c.customer_id = clv.customer_id
ORDER BY clv.lifetime_value DESC;


-- 96. Identify branches with abnormal transaction behavior using CTEs.

WITH br_stats AS (
    SELECT
        a.branch_id,
        AVG(ABS(t.amount)) AS avg_amt,
        STDDEV_POP(ABS(t.amount)) AS std_amt
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY a.branch_id
),
overall AS (
    SELECT AVG(avg_amt) AS overall_avg
    FROM br_stats
)
SELECT
    b.branch_id,
    b.name AS branch_name,
    s.avg_amt,
    s.std_amt
FROM br_stats s
JOIN overall o
JOIN branches b ON b.branch_id = s.branch_id
WHERE s.avg_amt > 2 * o.overall_avg
ORDER BY s.avg_amt DESC;


-- 97. Use CTEs to compare customer behavior before and after first loan.

WITH first_loan AS (
    SELECT customer_id, MIN(start_date) AS first_loan_date
    FROM loans
    GROUP BY customer_id
),
tx AS (
    SELECT
        ca.customer_id,
        t.transaction_date,
        ABS(t.amount) AS amt
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
),
summary AS (
    SELECT
        fl.customer_id,
        AVG(CASE WHEN tx.transaction_date < fl.first_loan_date THEN tx.amt END) AS avg_before_loan,
        AVG(CASE WHEN tx.transaction_date >= fl.first_loan_date THEN tx.amt END) AS avg_after_loan
    FROM first_loan fl
    LEFT JOIN tx ON tx.customer_id = fl.customer_id
    GROUP BY fl.customer_id
)
SELECT
    s.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    s.avg_before_loan,
    s.avg_after_loan
FROM summary s
JOIN customers c ON c.customer_id = s.customer_id;


-- 98. Build a CTE to rank customers, then filter top 5% only.

WITH cust_value AS (
    SELECT
        ca.customer_id,
        SUM(ABS(t.amount)) AS total_abs_amount
    FROM customer_accounts ca
    JOIN transactions t ON t.account_id = ca.account_id
    GROUP BY ca.customer_id
),
ranked AS (
    SELECT
        customer_id,
        total_abs_amount,
        NTILE(20) OVER (ORDER BY total_abs_amount DESC) AS bucket
    FROM cust_value
)
SELECT
    r.customer_id,
    CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
    r.total_abs_amount
FROM ranked r
JOIN customers c ON c.customer_id = r.customer_id
WHERE r.bucket = 1
ORDER BY r.total_abs_amount DESC;


-- 99. Compute rolling averages using CTEs instead of window functions.

WITH m AS (
    SELECT
        account_id,
        STR_TO_DATE(CONCAT(DATE_FORMAT(transaction_date, '%Y-%m'), '-01'), '%Y-%m-%d') AS month_start,
        SUM(ABS(amount)) AS month_total
    FROM transactions
    GROUP BY account_id, month_start
),
roll AS (
    SELECT
        m1.account_id,
        m1.month_start,
        (SELECT AVG(m2.month_total)
         FROM m m2
         WHERE m2.account_id = m1.account_id
           AND m2.month_start BETWEEN DATE_SUB(m1.month_start, INTERVAL 2 MONTH) AND m1.month_start
        ) AS rolling_3m_avg
    FROM m m1
)
SELECT
    account_id,
    DATE_FORMAT(month_start, '%Y-%m') AS ym,
    rolling_3m_avg
FROM roll
ORDER BY account_id, month_start;


-- 100. Use multiple CTEs to detect potential money laundering patterns (rapid transfers).

-- pattern: rapid in-out transfers in short window (same day / 1 day) with high count
WITH out_tr AS (
    SELECT
        from_account_id AS account_id,
        DATE(transaction_date) AS d,
        COUNT(*) AS out_cnt,
        SUM(amount) AS out_amt
    FROM transfers
    GROUP BY from_account_id, DATE(transaction_date)
),
in_tr AS (
    SELECT
        to_account_id AS account_id,
        DATE(transaction_date) AS d,
        COUNT(*) AS in_cnt,
        SUM(amount) AS in_amt
    FROM transfers
    GROUP BY to_account_id, DATE(transaction_date)
),
combo AS (
    SELECT
        COALESCE(o.account_id, i.account_id) AS account_id,
        COALESCE(o.d, i.d) AS d,
        COALESCE(i.in_cnt, 0) AS in_cnt,
        COALESCE(o.out_cnt, 0) AS out_cnt,
        COALESCE(i.in_amt, 0) AS in_amt,
        COALESCE(o.out_amt, 0) AS out_amt
    FROM out_tr o
    LEFT JOIN in_tr i
        ON i.account_id = o.account_id AND i.d = o.d
    UNION ALL
    SELECT
        i.account_id,
        i.d,
        i.in_cnt,
        0,
        i.in_amt,
        0
    FROM in_tr i
    LEFT JOIN out_tr o
        ON o.account_id = i.account_id AND o.d = i.d
    WHERE o.account_id IS NULL
)
SELECT *
FROM combo
WHERE in_cnt >= 5
  AND out_cnt >= 5
  AND ABS(in_amt - out_amt) <= 0.1 * GREATEST(in_amt, out_amt)
ORDER BY (in_cnt + out_cnt) DESC, d DESC;


-- ======================== END OF FILE ========================
