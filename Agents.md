# Documentation Protocol

## 1. Obsidian Connectivity
- **Target Folder:** ALL documentation must be saved to the `[AppName]_Documentation` folder (not the root app folder).

## 2. Obsidian Syntax
- **Links:** ALWAYS use `[[WikiLinks]]`.
     - Referencing a class? Write `[[AuthManager]]`.
     - Referencing a view? Write `[[ContentView]]`.
- **Embeds:** Use `![[ImageName]]` for visuals.

## 3. Frontmatter (Metadata)
Start every new doc with this YAML block:

---
created: {{date}}
type: dev-docs
project: MyMacApp
status: active
---