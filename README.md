# FS25_FabriX

**New gameplay for Farming Simulator 25 productions.**

![Platform](https://img.shields.io/badge/Farming%20Simulator-25-4CAF50)![Version](https://img.shields.io/badge/version-1.0.0.0-blue)![Status](https://img.shields.io/badge/status-released-green)![Multiplayer](https://img.shields.io/badge/multiplayer-supported-4CAF50)![Languages](https://img.shields.io/badge/languages-DE%20%7C%20EN-red)[![Production Revamp](https://img.shields.io/badge/Production%20Revamp-compatible%20with%20limitations-4CAF50)](#compatibility-with-production-revamp)

## About FabriX

FabriX (pronounced like the English word “fabrics” [fæbrɪks]) turns Farming Simulator 25 productions into a management experience. Hire and train employees, plan shifts, upgrade factories and run your business.

## Documentation

- [Deutsche Version](docs/README.de.md)
- [English version](docs/README.en.md)

## License

© 2026 Manuel Milde. All rights reserved.

This mod may not be copied, in whole or in part, into other mods or otherwise published without explicit permission. Official downloads are available only through ModHub. Uploading to other download portals is permitted only as a link to GitHub or ModHub.

## Installation

1. Download the mod ZIP from the official ModHub
2. Copy it to your Farming Simulator 25 mods folder (`Documents/My Games/FarmingSimulator2025/mods`)
3. Enable FabriX when loading your savegame
4. Open the FabriX menu in-game with **K**. You can change the key binding in the game settings

## Compatibility with Production Revamp

![Compatibility](https://img.shields.io/badge/tested%20with-Production%20Revamp%201.0.0.0-4CAF50)![Limitations](https://img.shields.io/badge/limitations-2%20minor-orange)

In my opinion, Production Revamp was very popular with the community in FS22. Judging by the discussions on the GIANTS Forum, a release for FS25 has been eagerly anticipated ever since FS25 was released. I expect that Production Revamp will also be very popular in FS25.
Since FabriX also revolves around productions and modifies and overrides various aspects of the base game, I checked at the end of my development process to see if both mods could be used at the same time and if there are any limitations.
First, the good news: FabriX and Production Revamp are compatible with each other (as far as I've been able to test). Using them simultaneously does not cause the game to crash or result in errors in the logs. However, I cannot guarantee that this is 100% the case! I would appreciate any reports of potential errors or error messages.

### Known limitations

| Feature                        | Status                                                         | Explanation                                                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------------------ | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Transportation costs           | ![Limited](https://img.shields.io/badge/status-limited-orange) | When both mods are used together, FabriX does not charge any transportation costs, so the FabriX entry in the financial overview stays empty. Production Revamp takes over the distribution of goods between productions. This isn't a big deal either, since Production Revamp has its own logic for transportation costs; they're just billed differently and shown under a different entry in the financial overview. |
| Pausing during factory upgrade | ![Limited](https://img.shields.io/badge/status-limited-orange) | When a factory is upgraded, FabriX pauses all its production lines during the renovation. Production Revamp does not allow production lines marked with "autoStart" or "hideFromMenu" in the production XML to be switched off. These lines keep running during the renovation. This only affects productions that use these Production Revamp attributes.                                                               |
