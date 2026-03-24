SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'PayTalk_db' AND pid <> pg_backend_pid();
DROP DATABASE "PayTalk_db";
