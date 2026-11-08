#!/usr/bin/env python3
"""Write a timestamp when a physical input device emits an event.

This never records key codes, button numbers, or text — only "a human touched
an input device at TIME". It skips the ydotool virtual device so the agent's
own synthetic input does not count as human activity.

Run as root (reads /dev/input); see setup-humanwatch.sh.
"""

from __future__ import annotations

import argparse
import glob
import os
import select
import struct
import sys
import time
from pathlib import Path

# struct input_event: struct timeval + __u16 type + __u16 code + __s32 value.
# timeval is two longs; use the platform's long width.
_LONG = "l" if struct.calcsize("l") == 8 else "i"
EVENT = struct.Struct(f"{_LONG}{_LONG}HHi")
IGNORED = ("ydotoold", "uinput")

EV_KEY, EV_REL, EV_ABS = 1, 2, 3


def device_name(path: str) -> str:
    event = Path(path).name
    try:
        return Path(f"/sys/class/input/{event}/device/name").read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def scan(fds: dict[str, int]) -> None:
    for path in sorted(glob.glob("/dev/input/event*")):
        if path in fds:
            continue
        name = device_name(path)
        if not name or any(token in name.lower() for token in IGNORED):
            continue
        try:
            fds[path] = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue


def write_stamp(runtime_dir: Path, uid: int) -> None:
    target = runtime_dir / f"human-{uid}"
    tmp = target.with_name(target.name + ".tmp")
    try:
        tmp.write_text(f"{time.time():.3f}\n", encoding="utf-8")
        os.chmod(tmp, 0o644)
        os.replace(tmp, target)
    except OSError:
        pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--runtime-dir", default="/run/pc-control")
    parser.add_argument("--uid", type=int, default=os.getuid())
    parser.add_argument("--scan-interval", type=float, default=2.0)
    parser.add_argument("--write-interval", type=float, default=0.05)
    args = parser.parse_args()

    runtime = Path(args.runtime_dir)
    try:
        runtime.mkdir(parents=True, exist_ok=True)
        os.chmod(runtime, 0o755)
    except OSError as exc:
        print(f"humanwatch: cannot create {runtime}: {exc}", file=sys.stderr)
        return 1

    fds: dict[str, int] = {}
    last_write = 0.0
    next_scan = 0.0

    while True:
        now = time.monotonic()
        if now >= next_scan:
            scan(fds)
            next_scan = now + args.scan_interval
        try:
            ready, _, _ = select.select(list(fds.values()), [], [], 1.0)
        except OSError:
            ready = []
        for fd in ready:
            try:
                data = os.read(fd, EVENT.size * 64)
            except OSError:
                data = b""
            if not data:
                for path, candidate in list(fds.items()):
                    if candidate == fd:
                        fds.pop(path, None)
                try:
                    os.close(fd)
                except OSError:
                    pass
                continue
            for offset in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, event_type, _, _ = EVENT.unpack_from(data, offset)
                if event_type in (EV_KEY, EV_REL, EV_ABS):
                    moment = time.time()
                    if moment - last_write >= args.write_interval:
                        write_stamp(runtime, args.uid)
                        last_write = moment
                    break


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
