#!/usr/bin/env python3

import argparse
import json
import shutil
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ReportMetadata:
    image: str
    tag: str
    digest: str
    image_reference: str
    generated_at: str
    report: str
    source_directory: Path


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare Trivy HTML reports for GitHub Pages."
    )
    parser.add_argument(
        "--input-dir",
        required=True,
        type=Path,
        help="Directory containing downloaded Trivy report artifacts.",
    )
    parser.add_argument(
        "--site-dir",
        required=True,
        type=Path,
        help="Directory containing the GitHub Pages site.",
    )
    parser.add_argument(
        "--keep",
        type=int,
        default=10,
        help="Number of reports to keep for each image.",
    )
    return parser.parse_args()


def load_metadata(metadata_file: Path) -> ReportMetadata:
    try:
        raw_metadata = json.loads(metadata_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(
            f"Invalid JSON in metadata file {metadata_file}: {error}"
        ) from error

    required_fields = {
        "image",
        "tag",
        "digest",
        "image_reference",
        "generated_at",
        "report",
    }

    missing_fields = required_fields - raw_metadata.keys()
    if missing_fields:
        missing = ", ".join(sorted(missing_fields))
        raise ValueError(
            f"Metadata file {metadata_file} is missing fields: {missing}"
        )

    report_file = metadata_file.parent / raw_metadata["report"]
    if not report_file.is_file():
        raise ValueError(
            f"Report referenced by {metadata_file} does not exist: {report_file}"
        )

    return ReportMetadata(
        image=raw_metadata["image"],
        tag=raw_metadata["tag"],
        digest=raw_metadata["digest"],
        image_reference=raw_metadata["image_reference"],
        generated_at=raw_metadata["generated_at"],
        report=raw_metadata["report"],
        source_directory=metadata_file.parent,
    )


def discover_reports(input_directory: Path) -> list[ReportMetadata]:
    metadata_files = sorted(input_directory.rglob("metadata.json"))

    if not metadata_files:
        raise ValueError(
            f"No metadata.json files found in {input_directory}"
        )

    return [
        load_metadata(metadata_file)
        for metadata_file in metadata_files
    ]


def copy_reports(
    reports: list[ReportMetadata],
    site_directory: Path,
) -> None:
    reports_directory = site_directory / "reports"
    reports_directory.mkdir(parents=True, exist_ok=True)

    for report in reports:
        destination_directory = (
            reports_directory
            / report.image
            / report.tag
        )
        destination_directory.mkdir(parents=True, exist_ok=True)

        source_report = report.source_directory / report.report
        source_metadata = report.source_directory / "metadata.json"

        shutil.copy2(
            source_report,
            destination_directory / "index.html",
        )
        shutil.copy2(
            source_metadata,
            destination_directory / "metadata.json",
        )

        print(
            f"Copied {report.image}:{report.tag} "
            f"to {destination_directory}"
        )


def load_report_metadata(report_directory: Path) -> ReportMetadata:
    metadata_file = report_directory / "metadata.json"
    return load_metadata(metadata_file)


def cleanup_old_reports(
    site_directory: Path,
    keep: int,
) -> None:
    reports_directory = site_directory / "reports"

    if not reports_directory.exists():
        return

    for image_directory in reports_directory.iterdir():
        if not image_directory.is_dir():
            continue

        report_directories = sorted(
            (
                directory
                for directory in image_directory.iterdir()
                if directory.is_dir()
            ),
            key=lambda directory: load_report_metadata(directory).generated_at,
        )

        if len(report_directories) <= keep:
            continue

        directories_to_remove = report_directories[:-keep]

        for directory in directories_to_remove:
            shutil.rmtree(directory)
            print(f"Removed old report: {directory}")


def main() -> None:
    args = parse_arguments()

    if not args.input_dir.is_dir():
        raise SystemExit(
            f"Input directory does not exist: {args.input_dir}"
        )

    if args.keep < 1:
        raise SystemExit("--keep must be at least 1")

    try:
        reports = discover_reports(args.input_dir)
    except ValueError as error:
        raise SystemExit(str(error)) from error

    print(f"Found {len(reports)} Trivy report(s)")

    for report in reports:
        print(
            f"- {report.image}:{report.tag} "
            f"({report.digest})"
        )

    copy_reports(
        reports=reports,
        site_directory=args.site_dir,
    )

    cleanup_old_reports(
        site_directory=args.site_dir,
        keep=args.keep,
)


if __name__ == "__main__":
    main()
