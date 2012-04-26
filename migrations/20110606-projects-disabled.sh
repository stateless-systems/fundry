#!/bin/bash

commands() {
cat <<SQL
  begin;
  alter table projects add column disabled_at timestamp;
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
