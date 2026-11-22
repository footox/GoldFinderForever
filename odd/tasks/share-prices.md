# share-prices

Objective: near-real-time auction prices shared between friends who run the addon, entirely inside the game (addon messages), with no external server or PC client.
Branch: feat/share-prices (from main) | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Request: "si yo escaneo la subasta y quiero que esos datos recientes se envien a otro amigo que ya tenga addon" (user, 2026-11-22), widened to: "lo que queremos es "tener los precios en tiempo real" con ayuda del addon de los demas. En especial, si alguien postea algo que estas buscando y entre los amigos va y revisa subasta, el cliete puedo leer ese dato." (user, 2026-11-22).
- S2 Transport: `adapters/comms.lua` wraps `C_ChatInfo.RegisterAddonMessagePrefix`, `C_ChatInfo.SendAddonMessage` and the `CHAT_MSG_ADDON` event with `pcall` and nil-safe fallbacks. Verified against the WoW Forever (Camelot) API catalog (all three exist; also `BN_CHAT_MSG_ADDON` for Battle.net friends). Not verified, to test in game: delivery to friends outside the guild and the party (whisper or a private channel) and the real send throttle.
- S3 Protocol: `core/share.lua`, pure and offline-testable. Versioned text messages, chunks under 255 bytes. `V1|PRICE|itemId|unitPrice|seenAt` announces a price that this client just saw (a live check from the Post button, a scan, or a search); `V1|ASK|itemId|since` asks the group whether anyone has a price newer than `since`; `V1|ANS|itemId|unitPrice|seenAt` answers an ASK. Several items can share one message. The prefix and version are fixed from day one.
- S4 Validation and abuse limits: the receiver checks every field (numeric ids, price within a sane range, `seenAt` not in the future and not older than a day), drops anything malformed, caps the messages and the stored items per sender per minute, and ignores senders that are not in the player's trust list (S7).
- S5 Same economy: a price is only used when it was seen on the same realm and faction as the receiver. The realm tag is read from the client; in Forever the name may be empty, so verify what identifies the economy before relying on it. Prices come from the existing reads (live check, Auctionator), and are never written into Auctionator's database.
- S6 Storage and use: received prices go to `GoldFinderDB.shared[itemId] = { price, seenAt, from }`, keeping the newest per item. `Decide()` and the Post button use a shared price only when it is newer than the local one (scan or live check), and show where it came from ("price seen by <name> 3 min ago"). Old shared entries expire.
- S7 Who and consent: opt-in. The player chooses the channel(s) to share on (guild, party, a private channel with a name and password, or a list of friends) and who to trust. Nothing is sent or stored until the option is turned on. Only item, price and time are sent: nothing personal. All text goes through `GF.L` (enUS + esES).
- S8 Verification: offline tests for building and parsing messages, chunking, validation against malformed and hostile input, expiry and "newest wins"; then an in-game test with two clients (the player and one friend) following `odd/validation/`.
- S9 Watch alerts: "eso puede mandarme una alerta si algun objeto que postean" (user, 2026-11-22). A friend who turns on "announce my posts" sends `V1|POST|itemId|unitPrice|qty|postedAt` when they post through GoldFinder (object, price and quantity are known there). A receiver compares it with their watch list (the materials missing in the Shopping tab, the GoldFinder lists, or items marked by hand) and, on a match, prints a chat line with the price and age and plays a sound. The alert is about what was posted, not about what still exists: it always shows the age. Limits: a per-item cooldown and a maximum number of alerts per minute; the announcing is opt-in and off by default, and the same trust list and validation as S4 apply. Posts made with other addons are out of scope for the first version.

## Tasks

- [ ] T1 (S3,S4) `core/share.lua` + tests (build, parse, validate, limits) | route: inline | commit: -
- [ ] T2 (S2) `adapters/comms.lua`: prefix, send with throttling, receive | route: inline | commit: -
- [ ] T3 (S5,S6) shared price store, expiry and `Decide()` / Post button integration | route: inline | commit: -
- [ ] T4 (S7) options (opt-in, channels, trust list), status line and locale strings | route: inline | commit: -
- [ ] T5 (S9) watch alerts: watch list, `POST` announce and match, cooldown, sound | route: inline | commit: -
- [ ] T6 (S8) two-client in-game validation checklist | route: inline | commit: -

Phases: T1+T2 give announce and receive with a debug command; T3 makes the data used; T4 exposes the options. Each phase is tested with a friend before the next.

Risk: item 3 (a new contract between clients: the message format, versioned from day one), item 2 (messages from other players are untrusted input) and item 6 for the in-game parts.

## Log

- L1 (2026-11-22, user): "Duda, si yo escaneo la subasta y quiero que esos datos recientes se envien a otro amigo que ya tenga addon."
- L2 (2026-11-22, user): "Hay que dejarla como feature." -> registered as its own feature.
- L3 (2026-11-22, user): "Ah dentro del juego si se puede??" -> confirmed against the Forever API catalog; the design stays inside the game, no PC client.
- L4 (2026-11-22, user): "Sí, actualiza la especificación" -> S1-S8 rewritten around announce + ask + shared store with provenance. An external server or PC client is out of scope; no usable external price source exists today (wowauctions.net has no API or stated licence).
- L5 (2026-11-22, user): "Ah super y eso puede mandarme una alerta si algun objeto que postean" -> added S9 (watch alerts) and T5; the validation task is now T6.
