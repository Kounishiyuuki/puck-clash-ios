# Codex Workflow

## Default Rules

- Inspect the repository before editing.
- Keep scope narrow and tied to the user request.
- Prefer small, reviewable diffs.
- Preserve the existing architecture and naming conventions.
- Do not rewrite broad areas unless explicitly requested.
- Do not touch unrelated files.
- Do not add dependencies unless the task clearly requires them and the user agrees.

## Project Guardrails

- Do not add online networking unless explicitly requested.
- Do not add server code unless explicitly requested.
- Do not add Firebase, authentication, database, ranking, ads, analytics, or monetization.
- Do not move game rules into SpriteKit.
- Keep `GameCore` pure Swift where possible.

## Xcode Project Safety

- Do not hand-edit the Xcode project file unless necessary and safe.
- Prefer Xcode file-system-synchronized folders when already present.
- If no Xcode project exists, do not generate a fake `.xcodeproj` manually.

## Validation

- Run the smallest relevant command set.
- Use `xcodebuild -list` when checking project visibility.
- Avoid long or destructive commands unless explicitly requested.
