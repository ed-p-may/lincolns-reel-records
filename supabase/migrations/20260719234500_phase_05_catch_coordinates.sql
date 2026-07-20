alter table public.catches
    add column latitude double precision,
    add column longitude double precision,
    add constraint catches_coordinate_pair_valid check (
        num_nonnulls(latitude, longitude) in (0, 2)
    ),
    add constraint catches_latitude_valid check (
        latitude is null or (
            latitude between -90 and 90
            and latitude <> 'NaN'::double precision
            and latitude <> 'Infinity'::double precision
            and latitude <> '-Infinity'::double precision
        )
    ),
    add constraint catches_longitude_valid check (
        longitude is null or (
            longitude between -180 and 180
            and longitude <> 'NaN'::double precision
            and longitude <> 'Infinity'::double precision
            and longitude <> '-Infinity'::double precision
        )
    );
