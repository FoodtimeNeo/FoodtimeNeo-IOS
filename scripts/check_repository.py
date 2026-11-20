"""Validate repository handoff records; this is not an iOS build or business test."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SHA = re.compile(r"[0-9a-f]{40}")
STATES = {"not-started", "in-progress", "implemented", "verified", "blocked", "approved-equivalent"}
REPOSITORIES = {
    "android": "FoodtimeNeo/FoodtimeNeo-Android",
    "backend": "FoodtimeNeo/FoodtimeNeo-Backend",
    "web": "FoodtimeNeo/FoodtimeNeo-Web",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def local_file(value):
    require(isinstance(value, str) and bool(value), "Empty file reference")
    path = (ROOT / value).resolve()
    require(path.is_relative_to(ROOT) and path.is_file(), f"Missing or outside file: {value}")
    return path


def validate(record):
    require(record.get("schemaVersion") == 1, "Unsupported coverage schema")
    for key, repository in REPOSITORIES.items():
        reference = record["reference"][key]
        require(reference["repository"] == repository, f"Unexpected source: {key}")
        require(reference["branch"] == "main" and SHA.fullmatch(reference["commit"]), f"Invalid main reference: {key}")
    android = record["reference"]["android"]
    require(android["integrationBranch"] == "dev" and SHA.fullmatch(android["integrationCommit"]), "Invalid Android dev reference")
    approved = {}
    for decision in record["approvedPlatformDifferences"]:
        require(decision.get("decisionReference"), "Platform equivalent requires an approval reference")
        for identity in decision["coverageIds"]:
            require(identity not in approved, f"Duplicate platform approval: {identity}")
            approved[identity] = decision
    rows = record["coverage"]
    require(bool(rows), "Coverage cannot be empty")
    identities = set()
    routes = {"main": set(), "dev": set(), "union": set()}
    code_extensions = {".swift", ".m", ".mm", ".h", ".dart", ".ts", ".tsx", ".js", ".jsx", ".storyboard", ".xib"}
    for row in rows:
        identity = row["id"]
        require(isinstance(identity, str) and identity and identity not in identities, f"Duplicate or empty coverage ID: {identity}")
        identities.add(identity)
        require(bool(row["title"]) and row["status"] in STATES, f"Invalid coverage status: {identity}")
        require(row["availability"] in {"released", "integration-only"}, f"Invalid availability: {identity}")
        if row["kind"] == "route":
            route = row["androidRoute"]
            require(identity == "route:" + route and route not in routes["union"], f"Duplicate route: {route}")
            routes["union"].add(route)
            branches = row["androidBranches"]
            require(branches and len(branches) == len(set(branches)) and set(branches) <= {"main", "dev"}, f"Invalid route branch: {route}")
            for branch in branches:
                routes[branch].add(route)
            sources = [row["androidSource"]]
        else:
            require(row["kind"] == "capability" and identity.startswith("capability:"), f"Invalid coverage kind: {identity}")
            sources = row["androidSources"]
        require(bool(sources), f"Source missing: {identity}")
        for source in sources:
            expected = android["commit"] if source["branch"] == "main" else android["integrationCommit"]
            require(source["branch"] in {"main", "dev"} and source["commit"] == expected, f"Source revision mismatch: {identity}")
            require(source["path"].startswith("app/src/") and ".." not in Path(source["path"]).parts, f"Invalid Android path: {identity}")
        require(isinstance(row["iosPaths"], list) and isinstance(row["evidence"], list), f"Invalid evidence fields: {identity}")
        for path in row["iosPaths"]:
            local_file(path)
        for evidence in row["evidence"]:
            require(isinstance(evidence, str) and evidence, f"Empty evidence: {identity}")
            if not evidence.startswith("https://"):
                local_file(evidence)
        if row["status"] in {"verified", "approved-equivalent"}:
            require(row["iosPaths"] and row["evidence"], f"Implementation and evidence required: {identity}")
            require(any(Path(path).suffix in code_extensions for path in row["iosPaths"]), f"Documentation alone is not implementation: {identity}")
        if row["status"] == "blocked":
            require(bool(row.get("notes", "").strip()), f"Blocked reason missing: {identity}")
        if row["status"] == "approved-equivalent":
            require(identity in approved, f"User-approved equivalent missing: {identity}")
    require(set(approved) <= identities, "Approval refers to unknown coverage")
    for branch, values in routes.items():
        require(len(values) == record["registeredRouteCounts"][branch], f"Route count mismatch: {branch}")
    reviewed = record["lastReviewedAndroidCommit"]
    aligned = record["lastFullyAlignedAndroidCommit"]
    require(reviewed is None or reviewed == android["commit"], "Review marker must identify current main target")
    if aligned is not None:
        require(aligned == reviewed == android["commit"], "Full alignment must identify the reviewed main target")
        require(all(row["status"] in {"verified", "approved-equivalent"} for row in rows), "Cannot declare full alignment with unfinished coverage")
    return routes


def check_links():
    for markdown in ROOT.rglob("*.md"):
        if ".git" in markdown.parts:
            continue
        for target in re.findall(r"\]\(([^)]+)\)", markdown.read_text(encoding="utf-8")):
            if urlsplit(target).scheme or target.startswith("#"):
                continue
            path = (markdown.parent / unquote(target.split("#", 1)[0])).resolve()
            require(path.is_relative_to(ROOT) and path.exists(), f"Broken local link: {markdown.relative_to(ROOT)} -> {target}")


def check_pr():
    head, base, title = (os.environ.get(key, "") for key in ("HEAD_REF", "BASE_REF", "PR_TITLE"))
    if not any((head, base, title)):
        return
    work = r"(?:feature|fix|hotfix)/[a-z0-9]+(?:-[a-z0-9]+)*"
    require((base == "dev" and re.fullmatch(work, head)) or (base == "main" and (head == "dev" or re.fullmatch(r"hotfix/[a-z0-9]+(?:-[a-z0-9]+)*", head))), "Invalid PR branch flow")
    require(len(title) <= 72 and re.fullmatch(r"(?:feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(?:\([a-z0-9-]+\))?!?: .+", title), "PR title must use Conventional Commits within 72 characters")


def check_upstream(record, strict_dev):
    command = ["git", "ls-remote", "https://github.com/FoodtimeNeo/FoodtimeNeo-Android.git", "refs/heads/main", "refs/heads/dev"]
    result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=40)
    refs = {}
    for line in result.stdout.splitlines():
        commit, reference = line.split()
        require(SHA.fullmatch(commit), "Invalid upstream response")
        refs[reference] = commit
    android = record["reference"]["android"]
    require({"refs/heads/main", "refs/heads/dev"} <= refs.keys(), "Cannot verify upstream refs")
    require(refs["refs/heads/main"] == android["commit"], "Android main changed: review all commits and update the parity target; changing SHA alone is not implementation")
    if refs["refs/heads/dev"] != android["integrationCommit"]:
        message = f"Android dev changed to {refs['refs/heads/dev']}; review new integration work"
        require(not strict_dev, message)
        print("NOTICE: " + message)


def check_android_sources(record, folder, routes):
    android = record["reference"]["android"]
    for branch, commit in (("main", android["commit"]), ("dev", android["integrationCommit"])):
        path = "app/src/main/java/cn/edu/bjtu/foodtime/presentation/MainActivity.java"
        source = subprocess.check_output(["git", "-C", str(folder), "show", commit + ":" + path], text=True, encoding="utf-8")
        registered = set(re.findall(r'screens\.put\("([^\"]+)"', source))
        require(registered == routes[branch], f"Android {branch} registered routes differ from coverage")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", action="store_true")
    parser.add_argument("--strict-dev", action="store_true")
    parser.add_argument("--android-repo", type=Path)
    args = parser.parse_args()
    for file in ("README.md", "AGENTS.md", "docs/HANDOFF-PROMPT.md", "docs/ANDROID-PARITY.md", "docs/ARCHITECTURE.md", "docs/IOS-DECISIONS.md", "docs/SYNC-PROCESS.md"):
        local_file(file)
    record = json.loads(local_file("docs/parity/coverage.json").read_text(encoding="utf-8"))
    routes = validate(record)
    check_links()
    check_pr()
    if args.android_repo:
        check_android_sources(record, args.android_repo, routes)
    if args.upstream or args.strict_dev:
        check_upstream(record, args.strict_dev)
    verified = sum(row["status"] in {"verified", "approved-equivalent"} for row in record["coverage"])
    print(f"Repository records valid: {len(record['coverage'])} targets, {verified} marked verified/equivalent. iOS build and business verification NOT performed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print(f"Repository check failed: {error}", file=sys.stderr)
        sys.exit(1)
