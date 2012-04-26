#!/bin/bash

# Add client_ip fields to tables where needed.

commands() {
cat <<SQL
  begin;
  alter table donations add column client_ip text;
  alter table pledges   add column client_ip text;
  alter table payments  add column client_ip text;
  alter table users     add column client_ip text, add column last_login_at timestamp;
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
