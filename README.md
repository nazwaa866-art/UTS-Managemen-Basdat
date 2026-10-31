# UTS Manajemen Basis Data — PostgreSQL + pgAdmin4 dengan Docker Compose

Proyek 1 / UTS MBD (semester V). Menjalankan PostgreSQL 15 dan pgAdmin4 dalam kontainer,
membuat skema `salam`, tabel `mahasiswas` berikut constraint-nya, serta 3 user dengan hak akses berbeda.

## Struktur proyek

```
uts-mbd/
├── docker-compose.yml        # 2 service: postgres & pgadmin (tanpa hardcode kredensial)
├── .env                      # RAHASIA: username/password, NAMA, NIM3  (tidak di-push)
├── .env.example              # contoh isi .env (aman di-push)
├── .gitignore / .gitattributes
├── initdb/
│   └── 00_init.sh            # jalan otomatis saat pertama kali: menjalankan 01 & 02, menyuntik password dari .env
├── sql/
│   ├── 01_roles.sql          # soal 4  : membuat backend_dev, bi_dev, data_engineer
│   ├── 02_schema_salam.sql   # soal 3+4: skema salam, tabel mahasiswas, trigger audit, view, GRANT
│   ├── 10_bukti_constraint.sql   # bukti soal 3
│   ├── 11_bukti_roles.sql        # bukti soal 4
│   └── 12_transaksi_pembeda.sql  # fitur/transaksi pembeda
└── pgadmin/servers.json      # server PostgreSQL otomatis terdaftar di pgAdmin
```

## 0. Sesuaikan identitas (WAJIB, 2 baris saja)

Buka `.env`, ganti:

```
NAMA=nama      # nama panggilan, huruf kecil tanpa spasi  -> postgres_nama, pgadmin_nama
NIM3=123       # 3 digit terakhir NIM -> PostgreSQL di port 22123, pgAdmin di port 44123
```

Nama kontainer dan nomor port di `docker-compose.yml` otomatis mengikuti dua nilai ini.

## 1. Jalankan (Docker Desktop harus sudah menyala)

```bash
docker compose up -d
docker compose ps          # tunggu postgres berstatus "healthy"
docker compose logs postgres | tail -30     # lihat ">>> [01] ..." dan ">>> [02] Selesai"
```

Skrip di `initdb/` hanya berjalan **sekali**, saat volume data masih kosong. Untuk mengulang dari nol:

```bash
docker compose down -v     # -v menghapus volume (SEMUA data hilang)
docker compose up -d
```

## 2. Bukti PostgreSQL bisa diakses dari internal dan eksternal Docker

| Jalur | Alat | Alamat | Keterangan |
|---|---|---|---|
| Internal Docker | pgAdmin4 (kontainer) | `http://localhost:44XXX` | koneksi memakai host `postgres`, port `5432` (antar-kontainer lewat jaringan `mbd_net_<NAMA>`) |
| Eksternal Docker | DBeaver (di laptop) | `localhost : 22XXX` | lewat port yang dipublikasikan ke host |

**pgAdmin4:** buka `http://localhost:44XXX`, login dengan `PGADMIN_DEFAULT_EMAIL` / `PGADMIN_DEFAULT_PASSWORD` dari `.env`.
Server **PostgreSQL UTS MBD** sudah terdaftar; klik dua kali, isi password `ifunggul`.
Buka *Query Tool* lalu jalankan `SELECT * FROM salam.mahasiswas;`.

**DBeaver:** New Database Connection → PostgreSQL → Host `localhost`, Port `22XXX`,
Database `db_uts_mbd`, Username `postgres`, Password `ifunggul` → Test Connection → Finish.

## 3. Bukti constraint (soal 3)

```bash
docker exec -i postgres_NAMA psql -U postgres -d db_uts_mbd -a -f /sql/10_bukti_constraint.sql
```

Hasil yang diharapkan: data valid berhasil, sedangkan pelanggaran PRIMARY KEY, UNIQUE (nim, email),
CHECK (ipk, angkatan, format nim, format email), dan NOT NULL masing-masing menghasilkan `ERROR`.
(Loncatan nomor `id` setelah INSERT yang gagal itu normal: sequence tetap bertambah.)

## 4. Bukti hak akses user (soal 4)

```bash
docker exec -i postgres_NAMA psql -U postgres -d db_uts_mbd -a -f /sql/11_bukti_roles.sql
```

| User | Boleh | Ditolak |
|---|---|---|
| `backend_dev` | INSERT / SELECT / UPDATE / DELETE semua tabel | CREATE, ALTER, DROP, TRUNCATE |
| `bi_dev` | SELECT semua tabel & view | INSERT, UPDATE, DELETE, CREATE |
| `data_engineer` | CREATE, ALTER, DROP semua objek + CRUD semua tabel | — |

Cara kerjanya: `data_engineer` dijadikan **pemilik** skema `salam` (hak ALTER/DROP di PostgreSQL
hanya milik owner), sedangkan `ALTER DEFAULT PRIVILEGES` memastikan tabel yang dibuat belakangan
otomatis bisa di-CRUD `backend_dev` dan di-SELECT `bi_dev`.

**Login langsung per user (opsional, lebih meyakinkan):** buat 3 koneksi baru di DBeaver
(`localhost:22XXX`, database `db_uts_mbd`, password dari `.env`) lalu coba perintah yang diizinkan dan ditolak.
Lewat terminal, gunakan `-h postgres` agar password benar-benar diperiksa:

```bash
docker exec -e PGPASSWORD=bi_Dev_2026 postgres_NAMA psql -h postgres -U bi_dev -d db_uts_mbd -c "DELETE FROM mahasiswas;"
# -> ERROR: permission denied for table mahasiswas
```

## 5. Fitur / transaksi pembeda (highlight di laporan)

```bash
docker exec -i postgres_NAMA psql -U postgres -d db_uts_mbd -a -f /sql/12_transaksi_pembeda.sql
```

- **Audit log otomatis** (`salam.audit_log` + trigger) mencatat siapa, kapan, dan data lama/baru tiap INSERT/UPDATE/DELETE.
- **Transaksi:** COMMIT, ROLLBACK total (DELETE massal dibatalkan), dan SAVEPOINT (satu langkah gagal, sisanya tetap tersimpan).
- **View** `salam.v_ringkasan_angkatan` untuk analisis BI.
- **Healthcheck** + `depends_on: service_healthy`, **jaringan khusus**, dan **server pgAdmin terdaftar otomatis**.
- Tambahan yang disarankan agar berbeda dari mahasiswa lain: ganti 5 data awal di `sql/02_schema_salam.sql`
  dengan data milikmu, tambah satu kolom/tabel sendiri, lalu jalankan `docker compose down -v && docker compose up -d`.

## 6. Push ke GitHub / GitLab (soal 5)

Buat repositori kosong di GitHub, lalu:

```bash
git init
git add .
git status                  # PASTIKAN .env TIDAK muncul (hanya .env.example)
git commit -m "UTS MBD: PostgreSQL + pgAdmin4 dengan Docker Compose"
git branch -M main
git remote add origin https://github.com/USERNAME/uts-mbd-NAMA.git
git push -u origin main
```

## 7. Checklist screenshot untuk laporan PDF

1. Isi `.env` (boleh sensor password) dan `docker-compose.yml`
2. `docker compose up -d`, `docker compose ps` (healthy), serta tampilan Docker Desktop (Containers + Volumes)
3. pgAdmin4: login, server terhubung, hasil `SELECT * FROM salam.mahasiswas`
4. DBeaver: pengaturan koneksi, Test Connection sukses, hasil query
5. Output `10_bukti_constraint.sql` (tabel constraint + tiap ERROR)
6. Output `11_bukti_roles.sql` (matriks hak akses + berhasil/ditolak per user)
7. Output `12_transaksi_pembeda.sql` (di-highlight)
8. Halaman repositori GitHub (tanpa `.env`) beserta URL-nya

Kumpulkan **PDF + URL GitHub** ke LMS minggu 08, paling lambat **1 November 2026 pukul 23.00**.

## Troubleshooting

- *port is already allocated* → ganti `NIM3`, atau hentikan program yang memakai port itu.
- *variable is not set* saat `docker compose up` → ada isian `.env` yang kosong.
- Skrip init tidak jalan / user tidak ada → volume lama masih ada; jalankan `docker compose down -v`.
- Di Windows, jika `00_init.sh` error `\r: command not found` → ubah line ending file menjadi LF (`.gitattributes` sudah mengatur ini untuk repo).
