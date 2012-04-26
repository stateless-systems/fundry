#!/bin/bash

# Add index to token column.

commands() {
cat <<SQL
  begin;
  create index subscriptions_token_idx on subscriptions(token);
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
