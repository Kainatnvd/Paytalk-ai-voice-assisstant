-- Migration Script: Applying pgcrypto to existing columns
-- Run this directly in PostgreSQL after running init_full_db.py

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Encrypt User Phone Numbers
ALTER TABLE users ADD COLUMN phone_number_enc BYTEA;
UPDATE users SET phone_number_enc = pgp_sym_encrypt(phone_number, current_setting('app.aes_key'));
ALTER TABLE users DROP COLUMN phone_number;
ALTER TABLE users RENAME COLUMN phone_number_enc TO phone_number;

-- 2. Encrypt Transaction Amounts and Accounts
ALTER TABLE transactions ADD COLUMN recipient_account_enc BYTEA;
ALTER TABLE transactions ADD COLUMN amount_enc BYTEA;

UPDATE transactions SET 
    recipient_account_enc = pgp_sym_encrypt(recipient_account, current_setting('app.aes_key')),
    amount_enc = pgp_sym_encrypt(amount::text, current_setting('app.aes_key'));

ALTER TABLE transactions DROP COLUMN recipient_account;
ALTER TABLE transactions DROP COLUMN amount;

ALTER TABLE transactions RENAME COLUMN recipient_account_enc TO recipient_account;
ALTER TABLE transactions RENAME COLUMN amount_enc TO amount;

-- Note: Once applied, your application code (SQLAlchemy) must use func.pgp_sym_decrypt()
-- in its SELECT statements and func.pgp_sym_encrypt() in its INSERT/UPDATE statements.
