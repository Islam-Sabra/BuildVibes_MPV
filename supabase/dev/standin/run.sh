#!/bin/bash
# usage: run.sh <repo dir>   rebuilds db "bv" from scratch, applies all migrations, runs every test file
R=$1; S=$(dirname "$0")
su postgres -c "psql -q -c 'drop database if exists bv' -c 'create database bv'" >/dev/null
su postgres -c "psql -q -v ON_ERROR_STOP=1 -d bv -f $S/shim.sql" >/dev/null || exit 1
su postgres -c "psql -q -d bv -c 'alter database bv set search_path = \"\$user\", public, extensions'"
for f in "$R"/supabase/migrations/*.sql; do
  out=$(su postgres -c "psql -q -v ON_ERROR_STOP=1 -d bv -f $f" 2>&1) || { echo "MIGRATION FAIL $f"; echo "$out" | tail -5; exit 1; }
done
echo "migrations ok"
total=0; fails=0
for t in "$R"/supabase/tests/*.sql; do
  out=$(su postgres -c "psql -X -d bv -f $t" 2>&1)
  ok=$(echo "$out" | grep -cE '^ *ok [0-9]')
  nok=$(echo "$out" | grep -cE '^ *not ok')
  plan=$(echo "$out" | grep -oE '^ *1\.\.[0-9]+' | head -1 | grep -oE '[0-9]+$')
  err=$(echo "$out" | grep -E 'ERROR|Looks like' | head -3)
  total=$((total+ok)); [ "$nok" -gt 0 -o "$ok" != "$plan" ] && fails=$((fails+1))
  printf "%-40s plan=%s ok=%s notok=%s %s\n" "$(basename $t)" "$plan" "$ok" "$nok" "$err"
done
echo "TOTAL ok=$total files_failing=$fails"
