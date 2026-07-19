alter table public.catches
    add column weight double precision,
    add column length double precision,
    add column location text,
    add column lure_text text,
    add column rod_reel text,
    add column notes text,
    add column released boolean not null default true,
    add column deleted_at timestamptz,
    add column version bigint not null default 1,
    add constraint catches_weight_valid check (
        weight is null or (
            weight >= 0
            and weight <> 'NaN'::double precision
            and weight <> 'Infinity'::double precision
        )
    ),
    add constraint catches_length_valid check (
        length is null or (
            length >= 0
            and length <> 'NaN'::double precision
            and length <> 'Infinity'::double precision
        )
    ),
    add constraint catches_location_valid check (
        location is null or (location = btrim(location) and char_length(location) between 1 and 160)
    ),
    add constraint catches_lure_text_valid check (
        lure_text is null or (lure_text = btrim(lure_text) and char_length(lure_text) between 1 and 160)
    ),
    add constraint catches_rod_reel_valid check (
        rod_reel is null or (rod_reel = btrim(rod_reel) and char_length(rod_reel) between 1 and 240)
    ),
    add constraint catches_notes_valid check (
        notes is null or (notes = btrim(notes) and char_length(notes) between 1 and 10000)
    ),
    add constraint catches_version_valid check (version > 0);

create index catches_owner_updated_at_idx
    on public.catches (owner_id, updated_at desc);

create index catches_owner_deleted_at_idx
    on public.catches (owner_id, deleted_at)
    where deleted_at is not null;
