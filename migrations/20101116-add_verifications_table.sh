#!/bin/bash

# moved verification fields to new table.
# future proof events.id & verifications.id

commands() {
cat <<SQL
  begin;
  create table verifications (
    id bigserial,
    project_id integer,
    rank integer not null default 0,
    message text,
    created_at timestamp not null
  );
 
  alter table verifications
    add constraint verifications_pkey primary key (id),
    add constraint verifications_project_fk foreign key (project_id) references projects(id);

  create index index_verifications_verified on verifications (project_id, rank);

  alter table projects
    drop column botrank,
    drop column notification,
    drop column last_checked_at;

  alter table events alter column id type bigint;
  commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
