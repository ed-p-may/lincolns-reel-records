alter table public.catches
    add column bookmarked boolean not null default false;

create index catches_owner_bookmarked_idx
    on public.catches (owner_id, caught_at desc)
    where bookmarked and deleted_at is null;
