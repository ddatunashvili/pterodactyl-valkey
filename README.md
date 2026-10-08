# pterodactyl-valkey

[Valkey](https://valkey.io) 9 — the BSD-licensed Redis fork — packaged for Pterodactyl.

- Image: `ghcr.io/ddatunashvili/pterodactyl-valkey:9`, built and boot-tested in CI on every push to `main`.
- Egg: `egg-valkey.json`.

## How it runs

- Runs as uid 988 (Wings' default user); all data in the server volume under `data/` (AOF + RDB snapshots).
- Listens on the server's primary allocation. Refuses to start without `VALKEY_PASSWORD`.
- `maxmemory` is 80% of the container's memory limit; the policy is `VALKEY_EVICTION_POLICY` (default `noeviction`).
- The config (which holds the password) is generated on each start in `/tmp`, mode 600, outside the volume.
- `DEBUG` and `MODULE` commands are disabled.
- Panel console lines run as Valkey commands, e.g. `INFO memory`.

## Connect

```
valkey-cli -h <node-ip> -p <port> -a <password>
redis://:<password>@<node-ip>:<port>
```

Any Redis client works.
