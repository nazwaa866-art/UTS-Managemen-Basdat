-- =============================================================================
-- 11_bukti_roles.sql  -  Soal no.4 : membuktikan aturan hak akses bekerja
-- Jalankan sebagai superuser; skrip berpindah identitas dengan SET ROLE
-- (hak akses diperiksa terhadap role aktif). Baris bertanda "HARUS BERHASIL"
-- tidak boleh ERROR, baris "HARUS GAGAL" harus menampilkan "permission denied".
--   docker exec -i postgres_NAMA psql -U postgres -d db_uts_mbd -a -f /sql/11_bukti_roles.sql
-- Pembuktian login langsung per user ada di README.md (bagian 6).
-- =============================================================================
\set ON_ERROR_STOP off

\echo ''
\echo '=== 0. Matriks hak akses (ringkasan) ==='
SELECT r.rolname                                              AS role,
       has_table_privilege(r.rolname, 'salam.mahasiswas', 'SELECT') AS sel,
       has_table_privilege(r.rolname, 'salam.mahasiswas', 'INSERT') AS ins,
       has_table_privilege(r.rolname, 'salam.mahasiswas', 'UPDATE') AS upd,
       has_table_privilege(r.rolname, 'salam.mahasiswas', 'DELETE') AS del,
       has_schema_privilege(r.rolname, 'salam', 'CREATE')           AS create_objek,
       pg_has_role(r.rolname, n.nspowner, 'USAGE')                  AS pemilik_skema_alter_drop
FROM (VALUES ('backend_dev'), ('bi_dev'), ('data_engineer')) AS r(rolname)
CROSS JOIN (SELECT nspowner FROM pg_namespace WHERE nspname = 'salam') AS n;

-- ============================================================================
\echo ''
\echo '########## A. backend_dev  (CRUD semua tabel, tanpa DDL) ##########'
SET ROLE backend_dev;
SELECT current_user AS aktif_sebagai;

\echo '--- CREATE (INSERT)  : HARUS BERHASIL'
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269001', 'Uji Backend', 'uji.backend@contoh.ac.id', 2026, 3.10);
\echo '--- READ (SELECT)    : HARUS BERHASIL'
SELECT id, nim, nama, ipk FROM salam.mahasiswas WHERE nim = '20269001';
\echo '--- UPDATE           : HARUS BERHASIL'
UPDATE salam.mahasiswas SET ipk = 3.55 WHERE nim = '20269001';
\echo '--- DELETE           : HARUS BERHASIL'
DELETE FROM salam.mahasiswas WHERE nim = '20269001';
\echo '--- CREATE TABLE     : HARUS GAGAL'
CREATE TABLE salam.tabel_ilegal (id int);
\echo '--- ALTER TABLE      : HARUS GAGAL'
ALTER TABLE salam.mahasiswas ADD COLUMN catatan text;
\echo '--- DROP TABLE       : HARUS GAGAL'
DROP TABLE salam.audit_log;
\echo '--- TRUNCATE         : HARUS GAGAL'
TRUNCATE salam.mahasiswas;
RESET ROLE;

-- ============================================================================
\echo ''
\echo '########## B. bi_dev  (hanya SELECT tabel & view) ##########'
SET ROLE bi_dev;
SELECT current_user AS aktif_sebagai;

\echo '--- SELECT tabel     : HARUS BERHASIL'
SELECT id, nim, nama, ipk FROM salam.mahasiswas ORDER BY id;
\echo '--- SELECT view      : HARUS BERHASIL'
SELECT * FROM salam.v_ringkasan_angkatan;
\echo '--- SELECT audit_log : HARUS BERHASIL'
SELECT count(*) AS jumlah_baris_audit FROM salam.audit_log;
\echo '--- INSERT           : HARUS GAGAL'
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269002', 'Uji BI', 'uji.bi@contoh.ac.id', 2026, 3.00);
\echo '--- UPDATE           : HARUS GAGAL'
UPDATE salam.mahasiswas SET ipk = 4.00 WHERE nim = '20240001';
\echo '--- DELETE           : HARUS GAGAL'
DELETE FROM salam.mahasiswas WHERE nim = '20240001';
\echo '--- CREATE TABLE     : HARUS GAGAL'
CREATE TABLE salam.tabel_ilegal_bi (id int);
RESET ROLE;

-- ============================================================================
\echo ''
\echo '########## C. data_engineer  (CREATE / MODIFY / DROP semua objek + CRUD) ##########'
SET ROLE data_engineer;
SELECT current_user AS aktif_sebagai;

\echo '--- CREATE TABLE     : HARUS BERHASIL'
CREATE TABLE salam.uji_data_engineer (id serial PRIMARY KEY, catatan text);
\echo '--- ALTER (MODIFY)   : HARUS BERHASIL'
ALTER TABLE salam.uji_data_engineer ADD COLUMN dibuat_pada timestamptz DEFAULT now();
\echo '--- CREATE VIEW      : HARUS BERHASIL'
CREATE VIEW salam.v_uji_data_engineer AS SELECT id, catatan FROM salam.uji_data_engineer;
\echo '--- CRUD pada tabel  : HARUS BERHASIL'
INSERT INTO salam.uji_data_engineer (catatan) VALUES ('dibuat oleh data_engineer');
SELECT id, catatan FROM salam.uji_data_engineer;
UPDATE salam.uji_data_engineer SET catatan = 'diubah oleh data_engineer' WHERE id = 1;
SELECT id, catatan FROM salam.uji_data_engineer;
RESET ROLE;

\echo ''
\echo '--- Tabel BARU buatan data_engineer otomatis bisa di-CRUD backend_dev'
SET ROLE backend_dev;
INSERT INTO salam.uji_data_engineer (catatan) VALUES ('ditambah backend_dev');
SELECT id, catatan FROM salam.uji_data_engineer ORDER BY id;
RESET ROLE;

\echo '--- ...dan otomatis hanya bisa di-SELECT bi_dev'
SET ROLE bi_dev;
SELECT id, catatan FROM salam.uji_data_engineer ORDER BY id;
INSERT INTO salam.uji_data_engineer (catatan) VALUES ('coba tulis bi_dev');
RESET ROLE;

\echo ''
\echo '--- data_engineer DROP view & tabel uji : HARUS BERHASIL'
SET ROLE data_engineer;
DROP VIEW  salam.v_uji_data_engineer;
DROP TABLE salam.uji_data_engineer;
SELECT count(*) AS sisa_tabel_uji FROM information_schema.tables
WHERE table_schema = 'salam' AND table_name LIKE 'uji_%';
RESET ROLE;

\echo ''
\echo '=== Selesai: lihat juga jejak siapa yang melakukan perubahan (audit_log) ==='
SELECT id, operasi, oleh, COALESCE(data_baru->>'nim', data_lama->>'nim') AS nim
FROM salam.audit_log ORDER BY id;
