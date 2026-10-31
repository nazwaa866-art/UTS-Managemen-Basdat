-- =============================================================================
-- 02_schema_salam.sql  -  Soal no.3 (skema + tabel) dan hak akses soal no.4
-- Catatan: nama skema ditulis tanpa tanda kutip, jadi PostgreSQL menyimpannya
-- sebagai huruf kecil: salam  (SALAM = salam).
-- =============================================================================
\echo '>>> [02] Membuat skema SALAM, tabel, trigger audit, view, dan hak akses'

-- Skema dimiliki data_engineer -> dia bebas CREATE / ALTER / DROP isinya
CREATE SCHEMA salam AUTHORIZATION data_engineer;
COMMENT ON SCHEMA salam IS 'Skema UTS Manajemen Basis Data';

-- ---- Hak akses ----------------------------------------------------------------
GRANT USAGE ON SCHEMA salam TO backend_dev, bi_dev;

-- Hak default untuk objek BARU yang dibuat di masa depan, supaya "semua table"
-- selalu tercakup (bukan hanya tabel yang ada hari ini).
-- (a) objek yang dibuat data_engineer
ALTER DEFAULT PRIVILEGES FOR ROLE data_engineer IN SCHEMA salam
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO backend_dev;
ALTER DEFAULT PRIVILEGES FOR ROLE data_engineer IN SCHEMA salam
    GRANT SELECT ON TABLES TO bi_dev;
ALTER DEFAULT PRIVILEGES FOR ROLE data_engineer IN SCHEMA salam
    GRANT USAGE, SELECT ON SEQUENCES TO backend_dev;
-- (b) objek yang dibuat superuser (user yang menjalankan skrip ini)
ALTER DEFAULT PRIVILEGES IN SCHEMA salam
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO backend_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA salam
    GRANT SELECT ON TABLES TO bi_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA salam
    GRANT USAGE, SELECT ON SEQUENCES TO backend_dev;

-- Mulai dari sini semua objek dibuat sebagai data_engineer (otomatis jadi pemiliknya)
SET ROLE data_engineer;

-- ---- Tabel mahasiswas -----------------------------------------------------------
CREATE TABLE salam.mahasiswas (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    nim         VARCHAR(15)   NOT NULL,
    nama        VARCHAR(100)  NOT NULL,
    email       VARCHAR(100)  NOT NULL,
    jurusan     VARCHAR(50)   NOT NULL DEFAULT 'Informatika',
    angkatan    SMALLINT      NOT NULL,
    ipk         NUMERIC(3,2)  NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- PRIMARY KEY
    CONSTRAINT pk_mahasiswas          PRIMARY KEY (id),
    -- UNIQUE
    CONSTRAINT uq_mahasiswas_nim      UNIQUE (nim),
    CONSTRAINT uq_mahasiswas_email    UNIQUE (email),
    -- CHECK
    CONSTRAINT ck_mahasiswas_ipk      CHECK (ipk BETWEEN 0 AND 4),
    CONSTRAINT ck_mahasiswas_angkatan CHECK (angkatan BETWEEN 2000 AND 2100),
    CONSTRAINT ck_mahasiswas_nim      CHECK (nim ~ '^[0-9]{8,15}$'),
    CONSTRAINT ck_mahasiswas_email    CHECK (email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')
);
COMMENT ON TABLE salam.mahasiswas IS 'Data mahasiswa (UTS MBD)';

-- Data awal -> GANTI / TAMBAHKAN dengan data milik kamu sendiri agar berbeda dari mahasiswa lain
INSERT INTO salam.mahasiswas (nim, nama, email, angkatan, ipk) VALUES
    ('20240001', 'Andi Pratama',   'andi.pratama@contoh.ac.id',   2024, 3.45),
    ('20240002', 'Budi Santoso',   'budi.santoso@contoh.ac.id',   2024, 3.10),
    ('20250001', 'Citra Lestari',  'citra.lestari@contoh.ac.id',  2025, 3.80),
    ('20250002', 'Dewi Anggraini', 'dewi.anggraini@contoh.ac.id', 2025, 3.25),
    ('20260001', 'Eko Wijaya',     'eko.wijaya@contoh.ac.id',     2026, 3.60);

-- ---- Fitur pembeda 1: audit log otomatis (trigger) ------------------------------
CREATE TABLE salam.audit_log (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    waktu      TIMESTAMPTZ NOT NULL DEFAULT now(),
    tabel      TEXT        NOT NULL,
    operasi    TEXT        NOT NULL CHECK (operasi IN ('INSERT', 'UPDATE', 'DELETE')),
    oleh       TEXT        NOT NULL DEFAULT current_user,   -- user database yang melakukan
    data_lama  JSONB,
    data_baru  JSONB
);
COMMENT ON TABLE salam.audit_log IS 'Jejak INSERT/UPDATE/DELETE pada mahasiswas (diisi trigger)';

CREATE FUNCTION salam.fn_audit_mahasiswas() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO salam.audit_log (tabel, operasi, data_baru)
        VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO salam.audit_log (tabel, operasi, data_lama, data_baru)
        VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        INSERT INTO salam.audit_log (tabel, operasi, data_lama)
        VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$;

CREATE TRIGGER trg_audit_mahasiswas
    AFTER INSERT OR UPDATE OR DELETE ON salam.mahasiswas
    FOR EACH ROW EXECUTE FUNCTION salam.fn_audit_mahasiswas();

-- ---- Fitur pembeda 2: view ringkasan per angkatan (untuk bi_dev) -----------------
CREATE VIEW salam.v_ringkasan_angkatan AS
SELECT angkatan,
       COUNT(*)           AS jumlah_mahasiswa,
       ROUND(AVG(ipk), 2) AS rata_rata_ipk,
       MAX(ipk)           AS ipk_tertinggi
FROM salam.mahasiswas
GROUP BY angkatan
ORDER BY angkatan;

RESET ROLE;

-- Pengaman: pastikan hak tercakup untuk semua objek yang sudah ada sekarang
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA salam TO backend_dev;
GRANT SELECT ON ALL TABLES IN SCHEMA salam TO bi_dev;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA salam TO backend_dev;

\echo '>>> [02] Selesai'
