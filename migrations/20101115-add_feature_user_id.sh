#!/bin/bash

# Add user_id to features

commands() {
cat <<SQL
  begin;
  alter table features
    add column user_id integer,
    add constraint features_user_fk foreign key (user_id) references users(id);
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
