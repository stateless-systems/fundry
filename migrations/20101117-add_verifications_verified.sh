#!/bin/bash

# damn it, forgot to add verifications.verified :(

commands() {
cat <<SQL
  begin;
  alter table verifications add column verified boolean not null default false;
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
