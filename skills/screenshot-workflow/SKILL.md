---
name: screenshot-workflow
description: Deterministic workflow for opening a URL, taking screenshots via the browser tool, and sending them back via the message tool.
user-invocable: true
metadata: {"openclaw":{"emoji":"📸","requires":{"config":["browser.enabled"]}}}
---

# Screenshot Workflow (Deterministic)

Use this workflow whenever the user requests a screenshot ("screenshot", "take a screenshot", "截图", "截个图") and provides a URL.

## Inputs
- A URL that may be:
  - full (https://...)
  - starts with www
  - bare domain (example.com)

## Workflow (must follow)

### Step 1 — Normalize URL
- If the URL does not start with http/https, prepend `https://`.
- Call the normalized URL `TARGET_URL`.

### Step 2 — Open page
- Use the `browser` tool to open `TARGET_URL`.
- If redirected, treat the final landing URL as `FINAL_URL`.

### Step 3 — Screenshot
- Use the `browser` tool to capture a screenshot (prefer full-page).
- If full-page capture fails or is unsupported:
  - capture viewport screenshot
  - optionally scroll and capture up to 3 total images

### Step 4 — Send back to user
- Use the `message` tool to send:
  - Text: `Screenshot captured: <FINAL_URL>`
  - Attach 1–3 screenshot images

## Required failure handling
- If open/connect fails:
  - retry once (optionally check browser status first)
  - if still failing, report the concrete reason (CDP unreachable, browser not configured, attach required, permissions/sandbox)
- If the site requires login/CAPTCHA/human verification:
  - stop automation
  - inform the user manual interaction is required
  - do NOT fabricate results

## Tool-call budget
- Max 8 tool calls total.
