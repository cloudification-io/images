#!/usr/bin/env python3

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def parse_arguments() -> argparse.Namespace:
    """
    Read command-line arguments passed from the GitHub Actions workflow.
    """
    parser = argparse.ArgumentParser(
        description="Create metadata.json for a generated Trivy HTML report."
    )

    parser.add_argument(
        "--report-dir",
        required=True,
        type=Path,
        help="Directory containing the generated Trivy index.html file.",
    )
    parser.add_argument(
        "--image",
        required=True,
        help="Container image name, for example: nova.",
    )
    parser.add_argument(
        "--tag",
        required=True,
        help="Exact timestamped image tag.",
    )
    parser.add_argument(
        "--digest",
        required=True,
        help="Published image digest, including the sha256: prefix.",
    )
    parser.add_argument(
        "--image-reference",
        required=True,
        help="Immutable image reference in registry/image@sha256:digest format.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_arguments()

    report_dir: Path = args.report_dir
    report_file = report_dir / "index.html"
    trivy_json_file = report_dir / "report.json"
    metadata_file = report_dir / "metadata.json"

    if not report_dir.is_dir():
        raise SystemExit(f"Report directory does not exist: {report_dir}")

    if not report_file.is_file():
        raise SystemExit(f"Trivy report does not exist: {report_file}")

    if not trivy_json_file.is_file():
        raise SystemExit(f"Trivy JSON report does not exist: {trivy_json_file}")

    if not args.digest.startswith("sha256:"):
        raise SystemExit(
            f"Unexpected image digest format: {args.digest}. "
            "Expected a value beginning with 'sha256:'."
        )

    trivy_report = json.loads(trivy_json_file.read_text(encoding="utf-8"))

    critical_count = sum(
        1
        for result in trivy_report.get("Results", [])
        for vulnerability in result.get("Vulnerabilities") or []
        if vulnerability.get("Severity") == "CRITICAL"
    )

    metadata: dict[str, str | int] = {
        "image": args.image,
        "tag": args.tag,
        "digest": args.digest,
        "image_reference": args.image_reference,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "report": report_file.name,
        "critical_vulnerabilities": critical_count,
    }

    metadata_file.write_text(
        json.dumps(metadata, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Created Trivy metadata: {metadata_file}")


if __name__ == "__main__":
    main()
