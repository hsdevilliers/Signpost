"""Dev-machine paths, read from tools/dev.local.json (gitignored; copy tools/dev.local.example.json).

    {"wowDir": "C:\\\\Program Files (x86)\\\\World of Warcraft", "flavorDir": "_classic_beta_", "account": "<WOW_ACCOUNT>"}

`account` is the folder under WTF\\Account (it appears after the first login). Left as the placeholder, the only
account folder present is used.
"""

from __future__ import annotations

import json
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = TOOLS_DIR.parent
DEFAULT_CONFIG = TOOLS_DIR / "dev.local.json"
PLACEHOLDER_ACCOUNT = "<WOW_ACCOUNT>"


class ConfigError(RuntimeError):
    pass


def load_config(path: Path | None = None) -> dict[str, str]:
    path = path or DEFAULT_CONFIG
    if not path.exists():
        raise ConfigError(f"{path} not found: copy tools/dev.local.example.json to it and fill in the paths")
    config = json.loads(path.read_text(encoding="utf-8"))
    for key in ("wowDir", "flavorDir"):
        if not config.get(key):
            raise ConfigError(f"{path}: '{key}' is missing")
    return config


def flavor_dir(config: dict[str, str]) -> Path:
    return Path(config["wowDir"]) / config["flavorDir"]


def addons_dir(config: dict[str, str]) -> Path:
    return flavor_dir(config) / "Interface" / "AddOns"


def account_dir(config: dict[str, str]) -> Path:
    root = flavor_dir(config) / "WTF" / "Account"
    account = config.get("account")
    if account and account != PLACEHOLDER_ACCOUNT:
        path = root / account
        if not path.is_dir():
            raise ConfigError(f"account folder {path} does not exist")
        return path
    if not root.is_dir():
        raise ConfigError(f"{root} does not exist yet: log in to the game once so the client creates it")
    accounts = sorted(p for p in root.iterdir() if p.is_dir() and p.name != "SavedVariables")
    if len(accounts) == 1:
        return accounts[0]
    if not accounts:
        raise ConfigError(f"no account folders under {root}: log in to the game once")
    names = ", ".join(p.name for p in accounts)
    raise ConfigError(f"several accounts under {root}; set 'account' in dev.local.json to one of: {names}")
