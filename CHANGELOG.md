# Changelog

## Phase 3 — Contract 1.2

- Follow-up: wandering shades now patrol toward lanterns, and pursuit remains active out to 24 m to remove the previous 12–18 m dead zone.

### Breaking changes

- Nights now last 240/270/300 seconds. Victory is evaluated only at dawn and requires 60% of lamps lit (rounded up).
- Lanterns have 100 fuel, lose 1/sec, can be refueled, and need five motes to relight after going out. Weak lanterns no longer protect against shades.
- Mote value is 5 points; dawn awards 50 plus remaining fuel per lit lamp and 50 per remaining flame. The time-left bonus is removed.
- Carry capacity grows from 10 by two per successful lighting, up to 20.
- Headless snapshots and events add fuel state, capacity, shade targets, `refuel`, `fuel_drain`, and `lantern_out`. The `all_lanterns` win reason is replaced with `dawn_survived`.

### Added

- Persisted colorblind mode with alternate shade outline and danger styling.
- Fuel bars and low-fuel blinking in the game view.
- Scenarios for refueling, relighting, and shade fuel drain.
