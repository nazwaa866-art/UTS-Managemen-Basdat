-- =============================================================================
-- 12_transaksi_pembeda.sql  -  Fitur / aktivitas / transaksi PEMBEDA (catatan soal)
-- Dijalankan sebagai backend_dev (lewat SET ROLE) supaya jejaknya tercatat atas nama
-- backend_dev di salam.audit_log.
--   docker exec -i postgres_NAMA psql -U postgres -d db_uts_mbd -a -f /sql/12_transaksi_pembeda.sql
-- >>> HIGHLIGHT bagian ini di laporan PDF <<<
-- =============================================================================
\set ON_ERROR_STOP off
SET ROLE backend_dev;

\echo ''
\echo '=== A. Transaksi COMMIT : dua data masuk sekaligus ==='
BEGIN;
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269101', 'Transaksi Satu', 'trx1@contoh.ac.id', 2026, 3.20);
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269102', 'Transaksi Dua',  'trx2@contoh.ac.id', 2026, 3.40);
COMMIT;
SELECT nim, nama FROM salam.mahasiswas WHERE nim LIKE '2026910%' ORDER BY nim;

\echo ''
\echo '=== B. Transaksi ROLLBACK : DELETE massal dibatalkan, data kembali utuh ==='
SELECT count(*) AS jumlah_sebelum FROM salam.mahasiswas;
BEGIN;
DELETE FROM salam.mahasiswas;
SELECT count(*) AS jumlah_di_dalam_transaksi FROM salam.mahasiswas;
ROLLBACK;
SELECT count(*) AS jumlah_setelah_rollback FROM salam.mahasiswas;

\echo ''
\echo '=== C. SAVEPOINT : satu langkah gagal, langkah lain tetap di-COMMIT ==='
BEGIN;
UPDATE salam.mahasiswas SET ipk = 3.90 WHERE nim = '20269101';
SAVEPOINT sp_aman;
\echo '--- langkah ini sengaja melanggar CHECK ipk (akan ERROR):'
UPDATE salam.mahasiswas SET ipk = 9.99 WHERE nim = '20269102';
ROLLBACK TO SAVEPOINT sp_aman;
UPDATE salam.mahasiswas SET ipk = 3.75 WHERE nim = '20269102';
COMMIT;
SELECT nim, nama, ipk FROM salam.mahasiswas WHERE nim LIKE '2026910%' ORDER BY nim;

\echo ''
\echo '=== D. Jejak otomatis di audit_log (trigger) : catat siapa, kapan, apa ==='
\echo '    (transaksi B yang di-ROLLBACK tidak meninggalkan jejak)'
SELECT id, to_char(waktu, 'HH24:MI:SS') AS jam, operasi, oleh,
       COALESCE(data_baru->>'nim', data_lama->>'nim') AS nim,
       data_lama->>'ipk' AS ipk_lama, data_baru->>'ipk' AS ipk_baru
FROM salam.audit_log ORDER BY id;

\echo ''
\echo '=== E. View ringkasan per angkatan (analisis) ==='
SELECT * FROM salam.v_ringkasan_angkatan;

\echo ''
\echo '=== F. Rapikan data uji transaksi ==='
DELETE FROM salam.mahasiswas WHERE nim LIKE '2026910%';
SELECT count(*) AS jumlah_akhir FROM salam.mahasiswas;

RESET ROLE;
