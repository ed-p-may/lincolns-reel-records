alter table public.catches
    add column air_temp_f double precision,
    add column sky_condition text,
    add column water_temp_f double precision,
    add column water_clarity text,
    add constraint catches_air_temp_f_finite check (
        air_temp_f is null or air_temp_f not in (
            'NaN'::double precision, 'Infinity'::double precision, '-Infinity'::double precision
        )
    ),
    add constraint catches_water_temp_f_finite check (
        water_temp_f is null or water_temp_f not in (
            'NaN'::double precision, 'Infinity'::double precision, '-Infinity'::double precision
        )
    ),
    add constraint catches_sky_condition_valid check (
        sky_condition is null or sky_condition in (
            'sunny', 'partly_cloudy', 'overcast', 'rain', 'fog', 'clear_night'
        )
    ),
    add constraint catches_water_clarity_valid check (
        water_clarity is null or water_clarity in ('clear', 'stained', 'muddy')
    );
