# Vendored libraries

Copied verbatim from upstream (only the files the addon loads). Update by replacing the files and this table.

| Library | Minor | Upstream | Version | License |
|---|---|---|---|---|
| LibStub | 2 | https://github.com/WoWUIDev/Ace3 (`LibStub/`) | tag `Release-r1403` | Public domain (file header) |
| CallbackHandler-1.0 | 8 | https://github.com/WoWUIDev/Ace3 (`CallbackHandler-1.0/`) | tag `Release-r1403` | BSD-style, `CallbackHandler-1.0/LICENSE.txt` (Ace3) |
| HereBeDragons-2.0, HereBeDragons-Pins-2.0 | 35, 17 | https://github.com/Nevcairiel/HereBeDragons | tag `2.18-release` (`HereBeDragons-Migrate.lua` not included) | BSD (`X-License` in upstream TOC) |
| LibDataBroker-1.1 | 4 | https://github.com/tekkub/libdatabroker-1-1 | tag `v1.1.4` | No license statement upstream; embedded by convention |
| LibDBIcon-1.0 | 57 | https://repos.wowace.com/wow/libdbicon-1-0 (SVN) | tag `v12.1.1` | `X-License: All Rights Reserved` (upstream TOC); embedded by convention |

HereBeDragons 2.18 already detects WoW: Forever (`WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`); its TOC and LibDBIcon's
both list interface 16001.
