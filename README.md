# usdc-nest

A [nuthatch](https://github.com/nuthatch-org/nuthatch) nest: **Circle's USDC on Ethereum mainnet**.

Every transfer, approval, mint, burn and blacklisting of USDC, decoded into SQL tables on your own
machine, with views for hourly volume and for Circle's issuance.

One binary, one config file, no Postgres, no Docker, no API key.

## What it indexes

**Chain:** `mainnet`. **1 contract**, **17 tables**.

| alias | contract | address | from block |
|---|---|---|---|
| `usdc` | USDC (FiatToken proxy) | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6,082,465 |

## Verified

Measured on 2026-11-17 with nuthatch 5.22.0 on an 18-core M5 Pro, against the two keyless public
endpoints in `nuthatch.toml`.

- `nuthatch dev --dir . --backfill 7200 --poll-interval 2s`, the last day of blocks, caught up to the
  tip at block 26,436,671 with **698,795 events in 3 m 20 s** (3,490 events a second). That is
  about 80 transfers a block.
- A second run from a clean directory a quarter of an hour later took 13 m 27 s for
  707,143 events: both endpoints were answering 429 by then, 181 times in its log, and nuthatch
  waited each one out.
  Its peak RSS was 321 MB. Disk after it: 33 MB of sealed segments, 23 MB of hot store.
- **Checked against `totalSupply`.** Between blocks 26,429,525 and 26,436,700 the `issuance` view
  holds 5,038 mints and 3,517 burns, a net of 290,670,481.609838 USDC. `totalSupply()` by
  `eth_call` on dRPC's public endpoint, which this nest does not use, rose by exactly
  290,670,481.609838 between blocks 26,429,524 and 26,436,700, to 44,490,049,919.150292. The first
  run's range agreed to the unit as well.
- The one `Blacklisted` event in the window, account `0xb4981dac90b74af27e1580a876975791b905cf2f`
  at block 26,430,074, reads `isBlacklisted = true` by `eth_call`.
- A restart was back at the tip in under a second. The queries below answered in under a quarter of
  a second.

## What it does not do

- **Full history is not attempted here.** About 80 transfers a block across 20 million blocks is a
  job for your own archive node. Pass it with `--rpc` and drop `--backfill`.
- **USDC's implementation has changed.** The current FiatToken was deployed at block 18,921,498;
  events before it may use an earlier ABI, and `init` warns about it. A full-history nest should add
  the earlier ABI as a second contract entry at the same address. A recent range is not affected.
- **No balances or supply.** A bounded backfill sees only movements, so there is no holder table;
  `issuance` gives the change in supply across a range, not the supply itself.
- **Amounts are raw units.** USDC has 6 decimals; divide by 1e6.

## Run it

```sh
nuthatch init --from https://github.com/nuthatch-org/usdc-nest
cd usdc-nest
nuthatch dev --dir . --backfill 7200 --poll-interval 2s
```

## Views

- `transfers_hourly`: transfers and `value_raw` per hour. `hour` is the unix time the hour starts.
- `issuance`: one row per `Mint` or `Burn`, with `kind`, `actor` (the minter or burner) and
  `amount_raw`, negative for a burn, so its sum over a range is the change in `totalSupply`.

```sql
-- Circle's mints and burns over a block range; the net is the change in totalSupply
SELECT kind, count(*) AS events, sum(amount_raw) / 1e6 AS usdc
FROM issuance WHERE block_number BETWEEN 26429525 AND 26436700 GROUP BY kind;
```

```
 kind | events | usdc
------+--------+------------------
 mint | 5038   | 984538794.171498
 burn | 3517   | -693868312.56166
```

```sql
-- the minters that minted the most in the window
SELECT actor AS minter, count(*) AS mints, sum(amount_raw) / 1e6 AS usdc
FROM issuance WHERE kind = 'mint' GROUP BY actor ORDER BY usdc DESC LIMIT 3;
```

```
 minter                                     | mints | usdc
--------------------------------------------+-------+------------------
 0x5b6122c109b78c6755486966148c1d70a50a47d7 | 178   | 787010573.408459
 0xfd78ee919681417d192449715b2594ab58f5d002 | 3835  | 143997190.338199
 0xc4922d64a24675e16e1586e3e3aa56c06fabe907 | 601   | 47148009.749737
```

```sql
-- hourly volume
SELECT hour, transfers, value_raw / 1e6 AS usdc FROM transfers_hourly ORDER BY hour DESC LIMIT 3;
```

`from` and `to` are reserved words in SQL, so quote them.
