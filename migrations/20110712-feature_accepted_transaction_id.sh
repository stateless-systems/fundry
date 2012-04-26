#!/bin/bash

commands() {
cat <<SQL
  begin;
  alter table feature_acceptances
    add column transfer_id integer references transfers(id);
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?

