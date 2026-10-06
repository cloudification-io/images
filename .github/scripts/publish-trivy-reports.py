#!/usr/bin/env python3

import argparse
import json
import re
import shutil
from dataclasses import dataclass
from datetime import datetime
from html import escape
from pathlib import Path


TIMESTAMP_SUFFIX = re.compile(r"-\d{14}$")


def tag_prefix(tag: str) -> str:
    return TIMESTAMP_SUFFIX.sub("", tag)


@dataclass(frozen=True)
class ReportMetadata:
    image: str
    tag: str
    digest: str
    image_reference: str
    generated_at: str
    report: str
    source_directory: Path
    critical_vulnerabilities: int


PAGE_STYLE = """
body {
    margin: 0;
    padding: 24px;
    background: #f6f8fa;
}

.card-list {
    list-style: none;
    padding: 0;
    margin: 0;
}

.card {
    background: white;
    border: 1px solid #d8dee4;
    border-radius: 6px;
    padding: 14px 18px;

    width: fit-content;
    min-width: 330px;
}

.card + .card {
    margin-top: 10px;
}

.card a {
    text-decoration: none;
    color: #0969da;
    font-weight: 600;
}

.card a:hover {
    text-decoration: underline;
}

.report-time {
    display: block;
    margin-top: 4px;
    color: #656d76;
    font-size: 90%;
}

.back-link {
    display: inline-block;
    margin-bottom: 20px;
}

.critical-badge {
    margin-left: 12px;
    padding: 2px 6px;
    border-radius: 4px;
    background: #cf222e;
    color: white;
    font-size: 80%;
    font-weight: 600;
}
"""


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
        "--live-tags",
        type=Path,
        help="File with one 'image tag-prefix' pair per line; report groups not listed are removed.",
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
    if not isinstance(raw_metadata, dict):
        raise ValueError(
            f"Metadata file {metadata_file} must contain a JSON object"
        )

    required_fields = {
        "image",
        "tag",
        "digest",
        "image_reference",
        "generated_at",
        "report",
        "critical_vulnerabilities",
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
        critical_vulnerabilities=raw_metadata["critical_vulnerabilities"],
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


def load_live_tags(live_tags_file: Path) -> set[tuple[str, str]]:
    live: set[tuple[str, str]] = set()
    for line in live_tags_file.read_text(encoding="utf-8").splitlines():
        if line.strip():
            image, prefix = line.split(maxsplit=1)
            live.add((image, prefix))
    if not live:
        raise ValueError(f"No live tags found in {live_tags_file}")
    return live


def cleanup_old_reports(
    site_directory: Path,
    keep: int,
    live_tags: set[tuple[str, str]] | None,
) -> None:
    reports_directory = site_directory / "reports"

    if not reports_directory.exists():
        return

    for image_directory in reports_directory.iterdir():
        if not image_directory.is_dir():
            continue

        for prefix, reports in group_reports_by_prefix(image_directory).items():
            if live_tags is not None and (image_directory.name, prefix) not in live_tags:
                stale = reports
                print(f"Removed reports of {image_directory.name}:{prefix}, no longer built")
            else:
                stale = reports[:-keep]
            for report in stale:
                shutil.rmtree(report.source_directory)
                print(f"Removed old report: {report.source_directory}")

        if not any(directory.is_dir() for directory in image_directory.iterdir()):
            shutil.rmtree(image_directory)
            print(f"Removed empty image directory: {image_directory}")


def group_reports_by_prefix(
    image_directory: Path,
) -> dict[str, list[ReportMetadata]]:
    """Reports of one image keyed by tag prefix (tag minus timestamp), oldest first."""
    groups: dict[str, list[ReportMetadata]] = {}

    for report_directory in image_directory.iterdir():
        if not report_directory.is_dir():
            continue
        report = load_report_metadata(report_directory)
        groups.setdefault(tag_prefix(report.tag), []).append(report)

    for reports in groups.values():
        reports.sort(
            key=lambda report: datetime.fromisoformat(report.generated_at),
        )

    return dict(sorted(groups.items()))


def get_latest_reports(image_directory: Path) -> dict[str, ReportMetadata]:
    groups = group_reports_by_prefix(image_directory)

    if not groups:
        raise ValueError(
            f"No reports found for image: {image_directory.name}"
        )

    return {prefix: reports[-1] for prefix, reports in groups.items()}


def generate_image_indexes(site_directory: Path) -> None:
    reports_directory = site_directory / "reports"

    if not reports_directory.exists():
        return

    for image_directory in sorted(reports_directory.iterdir()):
        if not image_directory.is_dir():
            continue

        report_entries: list[ReportMetadata] = []

        for report_directory in image_directory.iterdir():
            if not report_directory.is_dir():
                continue

            report_entries.append(
                load_report_metadata(report_directory)
            )

        report_entries.sort(
            key=lambda report: datetime.fromisoformat(report.generated_at),
            reverse=True,
        )

        report_links = "\n".join(
            (
                '        <li class="card">'
                f'<a href="{escape(report.tag)}/">'
                f"{escape(report.tag)}"
                "</a>"
                f'<span class="report-time">'
                f'{datetime.fromisoformat(report.generated_at).strftime("%b %d, %Y • %H:%M UTC")}'
                "</span>"
                "</li>"
            )
            for report in report_entries
        )

        page = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>{PAGE_STYLE}</style>
    <title>Trivy reports for {escape(image_directory.name)}</title>
</head>
<body>
    <h1>Trivy reports for {escape(image_directory.name)}</h1>
      <a class="back-link" href="../../">
          ← Back to all images
      </a>
    <ul class="card-list">
    {report_links}
    </ul>
</body>
</html>
"""

        index_file = image_directory / "index.html"
        index_file.write_text(page, encoding="utf-8")

        print(f"Generated image index: {index_file}")


def generate_root_index(site_directory: Path) -> None:
    reports_directory = site_directory / "reports"

    if not reports_directory.exists():
        return

    image_directories = sorted(
        directory
        for directory in reports_directory.iterdir()
        if directory.is_dir()
    )

    image_links_entries: list[str] = []

    for image_directory in image_directories:
        critical_badges = "".join(
            '<span class="critical-badge">'
            f"{escape(prefix)}: Critical {report.critical_vulnerabilities}"
            "</span>"
            for prefix, report in get_latest_reports(image_directory).items()
            if report.critical_vulnerabilities > 0
        )

        image_links_entries.append(
            '<li class="card">'
            f'<a href="reports/{escape(image_directory.name)}/">'
            f"{escape(image_directory.name)}"
            "</a>"
            f"{critical_badges}"
            "</li>"
        )

    image_links = "\n".join(image_links_entries)

    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>{PAGE_STYLE}</style>
    <title>Trivy vulnerability reports</title>
</head>
<body>
    <h1>Trivy vulnerability reports</h1>
    <ul class="card-list">
    {image_links}
    </ul>
</body>
</html>
"""

    index_file = site_directory / "index.html"
    index_file.write_text(page, encoding="utf-8")

    print(f"Generated root index: {index_file}")


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

    try:
        live_tags = load_live_tags(args.live_tags) if args.live_tags else None
    except (OSError, ValueError) as error:
        raise SystemExit(str(error)) from error

    cleanup_old_reports(
        site_directory=args.site_dir,
        keep=args.keep,
        live_tags=live_tags,
    )

    generate_image_indexes(
        site_directory=args.site_dir,
    )

    generate_root_index(
        site_directory=args.site_dir,
    )


if __name__ == "__main__":
    main()
