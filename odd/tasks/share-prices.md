# share-prices

Objective: share recent auction scan prices with a friend who also has the addon.
Branch: feature/share-prices (to create from main after the refactor merges) | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Request: "si yo escaneo la subasta y quiero que esos datos recientes se envien a otro amigo que ya tenga addon" (user, 2026-11-22).
- S2 Transport: `adapters/comms.lua` wraps `C_ChatInfo.RegisterAddonMessagePrefix`, `SendAddonMessage` and `CHAT_MSG_ADDON` with `pcall` and nil-safe fallbacks. Verify in the Forever client (the API was checked against the Retail catalog only).
- S3 Protocol: `core/share.lua`, pure and offline-testable. Versioned text messages (`V1|HELLO`, `V1|DATA|scanTime|id:price,...`, `V1|END`), chunks under 255 bytes, rate-limited.
- S4 Validation: the receiver validates every field (numeric ids, price range, scan time not in the future, item cap per session) and discards anything else.
- S5 Scope: send only prices for items the receiver carries (asked via `HELLO`) or changes since the last send. Prices come from the existing Auctionator read, never written into Auctionator's database.
- S6 Storage: received data goes to `GoldFinderDB.shared[sender]` with its scan time; `Decide()` uses it only when newer than the local price and shows "data from X, N min ago".
- S7 Consent and UI: the sender triggers it (`/gf compartir <name>` or a "Share scan" button); the receiver sees an Accept/Ignore prompt. Nothing is stored without acceptance. All text goes through `GF.L` (enUS + esES).
- S8 Verification: offline tests for chunking, assembly and malicious input; in-game test with two clients.

## Tasks

- [ ] T1 (S2,S3,S4) `core/share.lua` + tests | route: inline | commit: -
- [ ] T2 (S2) `adapters/comms.lua` | route: inline | commit: -
- [ ] T3 (S5,S6) shared price store and `Decide()` integration | route: inline | commit: -
- [ ] T4 (S7) command, button, accept prompt, locale strings | route: inline | commit: -

Risk: item 3 (new contract between clients: message format; version it from day one) and item 6 for the UI.

## Log

- L1 (2026-11-22, user): "Duda, si yo escaneo la subasta y quiero que esos datos recientes se envien a otro amigo que ya tenga addon."
- L2 (2026-11-22, user): "Hay que dejarla como feature." -> registered as its own feature, to start after the refactor merges.
