#!/bin/sh
# Dijalankan otomatis oleh image postgres SATU KALI, saat volume data masih kosong.
# Tugasnya: menjalankan skrip SQL dan menyuntikkan password 3 user dari environment
# (yang berasal dari .env) sebagai variabel psql -> password tidak pernah ditulis di file SQL.
set -e

psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
     -v backend_pw="$BACKEND_DEV_PASSWORD" \
     -v bi_pw="$BI_DEV_PASSWORD" \
     -v de_pw="$DATA_ENGINEER_PASSWORD" \
     -f /sql/01_roles.sql \
     -f /sql/02_schema_salam.sql
