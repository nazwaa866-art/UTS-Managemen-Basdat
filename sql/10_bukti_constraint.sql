-- =============================================================================
-- 10_bukti_constraint.sql  -  Soal no.3 : membuktikan constraint bekerja
-- Jalankan sebagai superuser. Setiap pelanggaran HARUS menghasilkan ERROR
-- (itulah buktinya), sedangkan data yang valid HARUS berhasil.
--   docker exec -i postgres_NAMA psql -U postgres -d db_uts_mbd -a -f /sql/10_bukti_constraint.sql
-- =============================================================================
\set ON_ERROR_STOP off

\echo ''
\echo '=== 0. Daftar constraint pada salam.mahasiswas ==='
SELECT conname                    AS nama_constraint,
       CASE contype WHEN 'p' THEN 'PRIMARY KEY'
                    WHEN 'u' THEN 'UNIQUE'
                    WHEN 'c' THEN 'CHECK'
                    ELSE contype::text END AS tipe,
       pg_get_constraintdef(oid)  AS definisi
FROM pg_constraint
WHERE conrelid = 'salam.mahasiswas'::regclass
ORDER BY contype DESC, conname;

\echo ''
\echo '=== 1. Data VALID -> harus BERHASIL (INSERT 0 1) ==='
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269999', 'Mahasiswa Uji', 'uji@contoh.ac.id', 2026, 3.50);

\echo ''
\echo '=== 2. PRIMARY KEY : id duplikat -> harus ERROR (pk_mahasiswas) ==='
INSERT INTO salam.mahasiswas (id, nim, nama, email, angkatan, ipk)
OVERRIDING SYSTEM VALUE
VALUES (1, '20269998', 'Id Kembar', 'idkembar@contoh.ac.id', 2026, 3.00);

\echo ''
\echo '=== 3. UNIQUE : NIM duplikat -> harus ERROR (uq_mahasiswas_nim) ==='
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269999', 'NIM Kembar', 'nimkembar@contoh.ac.id', 2026, 3.00);

\echo ''
\echo '=== 4. UNIQUE : email duplikat -> harus ERROR (uq_mahasiswas_email) ==='
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269997', 'Email Kembar', 'uji@contoh.ac.id', 2026, 3.00);

\echo ''
\echo '=== 5. CHECK : IPK 4.50 (di luar 0-4) -> harus ERROR (ck_mahasiswas_ipk) ==='
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269996', 'IPK Ngawur', 'ipk@contoh.ac.id', 2026, 4.50);

\echo ''
\echo '=== 6. CHECK : angkatan 1999 -> harus ERROR (ck_mahasiswas_angkatan) ==='
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269995', 'Angkatan Lama', 'lama@contoh.ac.id', 1999, 3.00);

\echo ''
\echo '=== 7. CHECK : NIM bukan angka -> harus ERROR (ck_mahasiswas_nim) ==='
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('ABCDEFGH', 'NIM Huruf', 'huruf@contoh.ac.id', 2026, 3.00);

\echo ''
\echo '=== 8. CHECK : format email salah -> harus ERROR (ck_mahasiswas_email) ==='
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269994', 'Email Salah', 'bukan-email', 2026, 3.00);

\echo ''
\echo '=== 9. NOT NULL : nama kosong -> harus ERROR ==='
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk)
VALUES ('20269993', NULL, 'null@contoh.ac.id', 2026, 3.00);

\echo ''
\echo '=== 10. Rapikan data uji & lihat hasil akhir (hanya 5 data awal tersisa) ==='
DELETE FROM salam.mahasiswas WHERE nim = '20269999';
SELECT id, nim, nama, email, angkatan, ipk FROM salam.mahasiswas ORDER BY id;
