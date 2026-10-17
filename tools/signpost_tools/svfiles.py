"""Locating and loading Signpost's SavedVariables files: the account file (SignpostDB) and one per character
(SignpostCharDB), either in the client's WTF folder (paths from tools/dev.local.json) or in a copied folder."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from . import devconfig
from .savedvars import load_savedvars

FILE_NAME = "Signpost.lua"
ACCOUNT_VAR = "SignpostDB"
CHAR_VAR = "SignpostCharDB"


@dataclass
class SVFile:
    path: Path
    variable: str
    owner: str  # "account" or "Character - Realm"


def find_files(source: Path | None, config_path: Path | None = None) -> list[SVFile]:
    """The account file first (it may not exist yet), then every character file found."""
    if source is None:
        base = devconfig.account_dir(devconfig.load_config(config_path))
        account_file = base / "SavedVariables" / FILE_NAME
    else:
        base = source
        account_file = next(
            (p for p in (source / FILE_NAME, source / "SavedVariables" / FILE_NAME) if p.exists()),
            source / FILE_NAME,
        )
    files = [SVFile(account_file, ACCOUNT_VAR, "account")]
    for path in sorted(base.rglob(FILE_NAME)):
        if path.resolve() == account_file.resolve():
            continue
        parts = path.relative_to(base).parts
        # <Realm>/<Character>/SavedVariables/Signpost.lua (or <Realm>/<Character>/Signpost.lua in a copied folder)
        owner = f"{parts[1]} - {parts[0]}" if len(parts) >= 3 else str(path.parent)
        files.append(SVFile(path, CHAR_VAR, owner))
    return files


def load_db(sv: SVFile) -> dict:
    """The file's table (SignpostDB or SignpostCharDB); {} when the variable is nil or missing."""
    value = load_savedvars(sv.path).get(sv.variable)
    return value if isinstance(value, dict) else {}
