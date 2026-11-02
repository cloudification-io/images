"""Install the pins of one override file into this interpreter's environment.

name==version is for packages the upstream constraints freeze: equal is skipped,
older than installed fails the build so the pin gets dropped. name>=version is for
packages the base image upgrades on its own, such as pip: anything at or above
stays. A package that is not installed is left alone. Only pure-Python wheels
belong in the pin files; anything that needs a compiler goes through the
venv_builder stage.
"""

import argparse
import re
import subprocess
import sys
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path

try:
    from packaging.version import Version
except ImportError:
    from pip._vendor.packaging.version import Version

PIN = re.compile(r"([A-Za-z0-9._-]+)(==|>=)(\S+)")


def read_pins(path: Path) -> list[tuple[str, str, str]]:
    pins = []
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        pin = PIN.fullmatch(line)
        if not pin:
            sys.exit(f"overrides: '{line}' in {path.name} is not name==version or name>=version")
        pins.append(pin.groups())
    return pins


def uv(*args: str) -> None:
    subprocess.run(["uv", "pip", *args, "--python", sys.executable], check=True)


def main() -> None:
    sys.stdout.reconfigure(line_buffering=True)
    parser = argparse.ArgumentParser()
    parser.add_argument("pin_file", type=Path)
    parser.add_argument("--break-system-packages", action="store_true")
    args = parser.parse_args()

    if not args.pin_file.is_file():
        print(f"overrides: no {args.pin_file.name}, nothing to apply")
        return
    pins = read_pins(args.pin_file)
    if not pins:
        print(f"overrides: {args.pin_file.name} has no pins")
        return
    print(f"overrides: {args.pin_file.name} -> {sys.executable}")

    install_flags = ["--break-system-packages"] if args.break_system_packages else []
    for name, op, wanted in pins:
        try:
            installed = version(name)
        except PackageNotFoundError:
            print(f"overrides: {name} is not installed, skipping")
            continue
        have, want = Version(installed), Version(wanted)
        if have == want or (op == ">=" and have > want):
            print(f"overrides: {name} {installed} already satisfies {op}{wanted}")
            continue
        if have > want:
            sys.exit(
                f"overrides: {name}=={wanted} is older than the installed {installed}; "
                f"drop it from {args.pin_file.name}"
            )
        print(f"overrides: {name} {installed} -> {wanted}")
        uv("install", "--no-cache", "--no-deps", *install_flags, f"{name}=={wanted}")

    uv("check")


if __name__ == "__main__":
    main()
