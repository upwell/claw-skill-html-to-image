# OpenClaw Skill: HTML to Image (Agent-Browser)

This is a composite skill for OpenClaw that utilizes `agent-browser` to take screenshots of URLs, local HTML files, or raw HTML strings. It features a lightweight, pure Bash architecture.

## Usage

This skill takes the following inputs:
- `source_type`: Must be `url`, `file`, or `code`.
- `source_content`: The target URL, absolute file path, or HTML code block.
- `format`: `png` (default), `jpeg`, or `webp`.
- `width`: Standardizes the viewport (default 1200).
- `full_page`: Boolean to determine if the entire scrollable page should be captured.

## Deployment

To package this skill for OpenClaw:
```bash
./build.sh
```
This will generate `html_to_image_skill.zip`.
