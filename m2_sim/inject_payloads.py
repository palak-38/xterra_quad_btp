#!/usr/bin/env python3
"""
inject_payloads.py — Inject payload bodies into m2_metal.xml from payload_config.yaml.

Usage:
    python3 inject_payloads.py [--xml XML_PATH] [--config CONFIG_PATH]

Defaults (relative to m2_sim root, auto-detected from this file's location):
    --xml    src/robots/m2_metal_description/mujoco/m2_metal.xml
    --config config/payload_config.yaml

The script replaces everything between the <!-- PAYLOAD_INJECT_HERE --> marker and
the line after it with freshly-generated <body> elements — one per payload entry.
Running it again is safe (idempotent): it clears the old injected bodies first.

Run this script before launching the simulator whenever payload_config.yaml changes.
"""

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
M2_SIM_ROOT = SCRIPT_DIR  # script lives at the root of m2_sim/

DEFAULT_XML = M2_SIM_ROOT / "src/robots/m2_metal_description/mujoco/m2_metal.xml"

DEFAULT_CONFIG = M2_SIM_ROOT / "config/payload_config.yaml"

# Unique anchor comment that must already exist in the XML (never removed).
ANCHOR = "<!-- PAYLOAD_INJECT_HERE -->"
# Header comment lines that follow the anchor (regenerated each run).
HEADER_PATTERN = re.compile(r"\s*<!-- Payload bodies are injected.*?-->.*?(?=\n)", re.DOTALL)

# ---------------------------------------------------------------------------
# XML generation helpers
# ---------------------------------------------------------------------------

def _fmt(values, fmt=".6g"):
    """Format a list of floats as a space-separated string."""
    return " ".join(format(v, fmt) for v in values)


def build_payload_xml(payload: dict, indent: str = "      ") -> str:
    """
    Return the XML string for one payload body.

    Expected payload keys: name, mass, pos, inertia, size, rgba
    """
    name = payload["name"]
    mass = float(payload["mass"])
    pos = [float(v) for v in payload["pos"]]
    inertia = [float(v) for v in payload["inertia"]]
    size = [float(v) for v in payload["size"]]
    rgba = [float(v) for v in payload["rgba"]]

    lines = [
        f'{indent}<body name="{name}" pos="{_fmt(pos)}">',
        f'{indent}  <inertial pos="0 0 0" mass="{mass:.6g}" diaginertia="{_fmt(inertia)}"/>',
        f'{indent}  <!-- visual geom: rendered in viewer, no collision -->',
        f'{indent}  <geom name="{name}_visual" type="box" size="{_fmt(size)}"',
        f'{indent}        rgba="{_fmt(rgba)}" contype="0" conaffinity="0" group="1" density="0"/>',
        f'{indent}  <!-- collision geom: participates in contact, hidden in viewer -->',
        f'{indent}  <geom name="{name}_collision" type="box" size="{_fmt(size)}"',
        f'{indent}        contype="1" conaffinity="1" group="3" density="0"/>',
        f'{indent}</body>',
    ]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Injection logic
# ---------------------------------------------------------------------------

def inject(xml_path: Path, config_path: Path) -> None:
    xml_text = xml_path.read_text()

    if ANCHOR not in xml_text:
        sys.exit(
            f"ERROR: Anchor '{ANCHOR}' not found in {xml_path}.\n"
            "Make sure the XML contains the placeholder comment."
        )

    # Load payload config
    with open(config_path) as f:
        config = yaml.safe_load(f)

    payloads = config.get("payloads") or []
    active = [p for p in payloads if not str(p.get("name", "")).startswith("#")]

    # Split on the anchor line; keep everything before and after.
    # We need to remove any previously-injected bodies between the anchor
    # comment block and the first leg body (FL_hip_link).
    #
    # Strategy: replace the region from ANCHOR up to (but not including)
    # the first '<body name="FL_hip_link"' with a fresh block.
    anchor_idx = xml_text.index(ANCHOR)
    # Find next leg body start after the anchor
    leg_start_pattern = '<body name="FL_hip_link"'
    leg_idx = xml_text.index(leg_start_pattern, anchor_idx)

    before = xml_text[:anchor_idx]
    after = xml_text[leg_idx:]

    # Build replacement block
    block_lines = [ANCHOR]
    block_lines.append(
        "      <!-- Payload bodies injected by inject_payloads.py — do not edit manually -->"
    )

    if active:
        for p in active:
            block_lines.append(build_payload_xml(p))
            print(f"  + Injected payload: {p['name']}  mass={p['mass']} kg  pos={p['pos']}")
    else:
        block_lines.append("      <!-- (no payloads configured) -->")
        print("  No active payloads — placeholder left empty.")

    block_lines.append("")  # blank line before leg bodies
    injection = "\n".join(block_lines) + "\n      "

    new_xml = before + injection + after

    xml_path.write_text(new_xml)
    print(f"\nUpdated: {xml_path}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--xml", type=Path, default=DEFAULT_XML,
                        help=f"Path to m2_metal.xml (default: {DEFAULT_XML})")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG,
                        help=f"Path to payload_config.yaml (default: {DEFAULT_CONFIG})")
    args = parser.parse_args()

    if not args.xml.exists():
        sys.exit(f"ERROR: XML file not found: {args.xml}")
    if not args.config.exists():
        sys.exit(f"ERROR: Config file not found: {args.config}")

    print(f"XML:    {args.xml}")
    print(f"Config: {args.config}")
    inject(args.xml, args.config)


if __name__ == "__main__":
    main()
