# Sprint 12 Design

Status: tested

Mode:

- `YOLO`

Scope:

- complete `BV4DB-32` by generating a real HTML metrics report with charts
- keep the existing Markdown report and raw JSON artifacts
- execute a short Oracle-style multi-volume run so metrics cover more than one block volume
- collect compute, block volume, and network metrics through the `operate-*` path

Design choices:

- reuse the working `operate-*` metrics flow from Sprint 11 instead of inventing a second reporting path
- reuse the validated Sprint 10 Balanced multi-volume Oracle profile and shorten the runtime to `300` seconds
- keep the HTML report self-contained with inline CSS and SVG charts so it renders without extra dependencies
- keep formatting metadata in the raw metrics payload so Markdown and HTML stay consistent
- keep the HTML look Oracle/OCI-inspired, but implement the styling as original project CSS rather than copying Oracle site or OCI Console assets
