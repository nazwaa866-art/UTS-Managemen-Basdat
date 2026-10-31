-- =============================================================================
-- 01_roles.sql  -  Soal no.4 : membuat 3 user baru
-- Dijalankan oleh superuser lewat initdb/00_init.sh
-- Password TIDAK ditulis di sini: dibaca dari variabel psql (:'backend_pw' dst)
-- yang diisi dari file .env.
-- =============================================================================
\echo '>>> [01] Membuat role / user'

-- backend_dev : aplikasi backend -> CRUD semua tabel
CREATE ROLE backend_dev LOGIN PASSWORD :'backend_pw'
    NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- bi_dev : analis BI -> hanya SELECT semua tabel/view
CREATE ROLE bi_dev LOGIN PASSWORD :'bi_pw'
    NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- data_engineer : CREATE / MODIFY (ALTER) / DROP semua objek + CRUD semua tabel
-- (hak ALTER & DROP di PostgreSQL hanya dimiliki OWNER objek, jadi di 02_schema_salam.sql
--  role ini dijadikan pemilik skema SALAM beserta isinya)
CREATE ROLE data_engineer LOGIN PASSWORD :'de_pw'
    NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Hanya skema milik kita yang boleh dipakai membuat objek.
-- (Di PostgreSQL <= 14 skema public bisa di-CREATE oleh siapa saja; ini menutupnya.)
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Kemudahan: user otomatis memakai skema salam tanpa harus menulis "salam." terus
ALTER ROLE backend_dev   SET search_path = salam, public;
ALTER ROLE bi_dev        SET search_path = salam, public;
ALTER ROLE data_engineer SET search_path = salam, public;
