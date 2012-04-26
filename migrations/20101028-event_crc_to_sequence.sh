#!/bin/bash

# Update fundry.events so the id is now a sequence.

commands() {
  # I'm no shell wizard, this can probably be written better.
  create_sql=$(pg_dump fundry --schema-only -O -t events | sed -e s/events/new_events/g | sed -e s/id\ character\ varying\(11\)/id\ bigserial/)
  cat <<SQL
    begin;

    create table new_events (
        id bigserial,
        type character varying(50) NOT NULL,
        user_id integer,
        project_id integer,
        feature_id integer,
        detail text NOT NULL,
        created_at timestamp without time zone NOT NULL
    );

    insert into new_events(type, user_id, project_id, feature_id, detail, created_at)
      select type, user_id, project_id, feature_id, detail, created_at from events order by created_at asc;

    drop table events;

    alter table new_events rename to events;

    create index index_events_type on events using btree (type);
    create index index_events_user_id on events using btree (user_id);
    create index index_events_feature_id on events using btree (feature_id);
    create index index_events_project_id on events using btree (project_id);

    alter table events
      add constraint events_pkey primary key (id),
      add constraint events_feature_fk foreign key (feature_id) references features(id),
      add constraint events_project_fk foreign key (project_id) references projects(id),
      add constraint events_user_fk foreign key (user_id) references users(id);

    commit;
SQL
}

commands | psql --set ON_ERROR_STOP= fundry
exit $?
