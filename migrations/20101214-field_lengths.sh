#!/bin/bash

# update field lengths/types on some tables.

commands() {
cat <<SQL
  begin;
  alter table features alter column url type text;
  alter table comments alter column detail type text;
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
