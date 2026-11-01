#!/usr/bin/env python3
"""Check production target dependencies and prevent infrastructure leaking into inner layers."""
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
package = root / "Packages/TodoKit"
expected = {
    "TodoDomain": set(),
    "TodoApplication": {"TodoDomain"},
    "TodoData": {"TodoDomain"},
    "TodoPresentation": {"TodoApplication", "TodoDomain"},
}
frameworks = {
    "TodoDomain": {"Foundation"},
    "TodoApplication": {"Foundation"},
    "TodoData": {"Foundation", "Security"},
    "TodoPresentation": {"Foundation", "Observation", "SwiftUI"},
}
manifest = json.loads(subprocess.check_output(
    ["swift", "package", "--package-path", str(package), "dump-package"], text=True
))
failures = []
for target in manifest["targets"]:
    name = target["name"]
    if name not in expected:
        continue
    actual = set()
    for dependency in target["dependencies"]:
        for kind, value in dependency.items():
            if kind not in {"byName", "target"}:
                failures.append(f"{name}: unexpected dependency {dependency}")
            actual.add(value[0])
    if actual != expected[name]:
        failures.append(f"{name}: expected dependencies {sorted(expected[name])}, found {sorted(actual)}")
    for source in (package / "Sources" / name).rglob("*.swift"):
        text = source.read_text()
        imports = set(re.findall(r"^\s*(?:public |internal |private |@testable )?import\s+(\w+)", text, re.M))
        for module in imports - expected[name] - frameworks[name]:
            failures.append(f"{source.relative_to(root)}: forbidden import {module}")
        if name == "TodoDomain" and re.search(r"\b(?:Codable|Encodable|Decodable|SessionTokens|messageKey|titleKey)\b", text):
            failures.append(f"{source.relative_to(root)}: serialization, tokens or presentation text in Domain")
        if name == "TodoPresentation" and re.search(r"\b(?:AuthRepository|TodoRepository|APIClient|URLSession|KeychainTokenStore|SessionTokens)\b", text):
            failures.append(f"{source.relative_to(root)}: Presentation must use Use Cases")
if failures:
    raise SystemExit("\n".join(failures))
print("Architecture OK: Domain <- Application <- Presentation; Data -> Domain; no infrastructure in ViewModels.")
