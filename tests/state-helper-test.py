#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "libexec" / "omatabs-state"


def assert_true(cond, msg):
    if not cond:
        print("fail - " + msg, file=sys.stderr)
        raise SystemExit(1)
    print("ok - " + msg)


def run_helper(home: Path, args: list[str], stdin: bytes | None = None, timeout: float = 3.0):
    env = os.environ.copy()
    env["HOME"] = str(home)
    env.pop("XDG_STATE_HOME", None)
    return subprocess.run(
        [sys.executable, str(HELPER), *args],
        input=stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        timeout=timeout,
        check=False,
    )


def state_dir(home: Path) -> Path:
    return home / ".local" / "state" / "omarchy"


def test_load_seeds(home: Path):
    result = run_helper(home, ["load"])
    assert_true(result.returncode == 0, "load succeeds on a fresh home")
    data = json.loads(result.stdout.decode())
    assert_true(data["notes"][0]["id"] == "omatabs-welcome", "fresh load seeds the welcome note")


def test_round_trip(home: Path):
    payload = {
        "version": 1,
        "edge": "left",
        "notes": [{"id": "n1", "title": "Hi", "body": "hello **there**", "color": "mint"}],
    }
    saved = run_helper(home, ["save"], json.dumps(payload).encode())
    assert_true(saved.returncode == 0, "save succeeds")
    loaded = run_helper(home, ["load"])
    data = json.loads(loaded.stdout.decode())
    assert_true(data["edge"] == "left" and data["notes"][0]["body"].startswith("hello"), "save round-trips notes")
    path = state_dir(home) / "omatabs.json"
    assert_true(path.is_file() and not path.is_symlink(), "state file is a regular file")
    assert_true(stat.S_IMODE(path.stat().st_mode) & 0o077 == 0, "state file is mode 0600")


def test_rejects_html_and_images(home: Path):
    payload = {
        "notes": [{
            "id": "n1",
            "title": "t",
            "body": '<img src="https://evil.example/a.png"> ![x](https://evil.example/a.png) [ok](https://example.com) [bad](javascript:alert(1))',
        }]
    }
    saved = run_helper(home, ["save"], json.dumps(payload).encode())
    body = json.loads(saved.stdout.decode())["notes"][0]["body"]
    assert_true("<img" not in body and "![x]" not in body, "helper strips HTML and images")
    assert_true("https://example.com" in body and "javascript:" not in body, "helper keeps http links only")


def test_symlink_is_not_followed(home: Path):
    target = home / "outside.json"
    target.write_text('{"notes":[{"id":"secret","title":"no","body":"leak"}]}', encoding="utf-8")
    omarchy = state_dir(home)
    omarchy.mkdir(parents=True, exist_ok=True)
    os.chmod(home, 0o700)
    for path in (home / ".local", home / ".local" / "state", omarchy):
        os.chmod(path, 0o700)
    link = omarchy / "omatabs.json"
    link.symlink_to(target)
    loaded = run_helper(home, ["load"])
    data = json.loads(loaded.stdout.decode())
    ids = [note["id"] for note in data.get("notes", [])]
    assert_true("secret" not in ids, "symlinked state is not followed")
    assert_true(target.read_text(encoding="utf-8").find("secret") != -1, "symlink target is left intact")


def test_fifo_does_not_block(home: Path):
    omarchy = state_dir(home)
    omarchy.mkdir(parents=True, exist_ok=True)
    os.chmod(home, 0o700)
    for path in (home / ".local", home / ".local" / "state", omarchy):
        os.chmod(path, 0o700)
    fifo = omarchy / "omatabs.json"
    os.mkfifo(fifo, 0o600)
    loaded = run_helper(home, ["load"], timeout=2.5)
    assert_true(loaded.returncode == 0, "FIFO state does not block load")
    data = json.loads(loaded.stdout.decode())
    assert_true(isinstance(data.get("notes"), list), "FIFO state is quarantined and replaced with empty/seed JSON")


def test_oversize_is_quarantined(home: Path):
    omarchy = state_dir(home)
    omarchy.mkdir(parents=True, exist_ok=True)
    os.chmod(home, 0o700)
    for path in (home / ".local", home / ".local" / "state", omarchy):
        os.chmod(path, 0o700)
    huge = omarchy / "omatabs.json"
    huge.write_bytes(b"{" + b"x" * (256 * 1024 + 10))
    loaded = run_helper(home, ["load"])
    assert_true(loaded.returncode == 0, "oversized state does not crash load")
    quarantined = list(omarchy.glob("omatabs.json.corrupt.*"))
    assert_true(len(quarantined) == 1, "oversized state is quarantined")


def test_legacy_migration(home: Path):
    omarchy = state_dir(home)
    omarchy.mkdir(parents=True, exist_ok=True)
    os.chmod(home, 0o700)
    for path in (home / ".local", home / ".local" / "state", omarchy):
        os.chmod(path, 0o700)
    legacy = omarchy / "edge-notes.json"
    legacy.write_text(json.dumps({"edge": "left", "seeded": True, "notes": [{"id": "old", "title": "Old", "body": "note"}]}), encoding="utf-8")
    loaded = run_helper(home, ["load"])
    data = json.loads(loaded.stdout.decode())
    assert_true(data["notes"][0]["id"] == "old", "legacy edge-notes.json is migrated")
    assert_true((omarchy / "omatabs.json").is_file(), "migration writes omatabs.json")


def main():
    with tempfile.TemporaryDirectory() as raw:
        home = Path(raw)
        os.chmod(home, 0o700)
        test_load_seeds(home)
    with tempfile.TemporaryDirectory() as raw:
        home = Path(raw)
        os.chmod(home, 0o700)
        test_round_trip(home)
        test_rejects_html_and_images(home)
    with tempfile.TemporaryDirectory() as raw:
        home = Path(raw)
        os.chmod(home, 0o700)
        test_symlink_is_not_followed(home)
    with tempfile.TemporaryDirectory() as raw:
        home = Path(raw)
        os.chmod(home, 0o700)
        test_fifo_does_not_block(home)
    with tempfile.TemporaryDirectory() as raw:
        home = Path(raw)
        os.chmod(home, 0o700)
        test_oversize_is_quarantined(home)
    with tempfile.TemporaryDirectory() as raw:
        home = Path(raw)
        os.chmod(home, 0o700)
        test_legacy_migration(home)
    print("all helper tests passed")


if __name__ == "__main__":
    main()
