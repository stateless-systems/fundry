#!/bin/bash

# Update fundry.projects table with new verification fields.

commands() {
cat <<SQL
  begin;
  alter table projects add column botrank integer not null default 0,
                       add column notification text,
                       add column last_checked_at timestamp;
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
