#!/usr/bin/env bash
# render_swingbench_report_html.sh — render Swingbench XML/log artifacts into a standalone HTML dashboard

set -euo pipefail

RESULTS_XML="${1:?usage: render_swingbench_report_html.sh <results.xml> <charbench.log> <results_db.json> <output.html>}"
CHARBENCH_LOG="${2:?usage: render_swingbench_report_html.sh <results.xml> <charbench.log> <results_db.json> <output.html>}"
RESULTS_DB_JSON="${3:-}"
OUTPUT_HTML="${4:?usage: render_swingbench_report_html.sh <results.xml> <charbench.log> <results_db.json> <output.html>}"

python3 - "$RESULTS_XML" "$CHARBENCH_LOG" "$RESULTS_DB_JSON" "$OUTPUT_HTML" <<'PY'
import html
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

results_xml = Path(sys.argv[1])
charbench_log = Path(sys.argv[2])
results_db_json = Path(sys.argv[3]) if sys.argv[3] else None
output_html = Path(sys.argv[4])

ns = {"sb": "http://www.dominicgiles.com/swingbench/results"}
root = ET.parse(results_xml).getroot()

def text(tag, default="n/a"):
    node = root.find(f".//sb:{tag}", ns)
    return node.text if node is not None and node.text is not None else default

overview = {
    "Benchmark Name": text("BenchmarkName"),
    "Time Of Run": text("TimeOfRun"),
    "Run Time": text("TotalRunTime"),
    "Users": text("NumberOfUsers"),
    "Completed Transactions": text("TotalCompletedTransactions"),
    "Failed Transactions": text("TotalFailedTransactions"),
    "Average TPS": text("AverageTransactionsPerSecond"),
    "Maximum Transaction Rate": text("MaximumTransactionRate"),
}

transaction_rows = []
for elem in root.findall(".//sb:TransactionResults/sb:Result", ns):
    transaction_rows.append({
        "name": elem.attrib.get("id", "unknown"),
        "count": elem.findtext("sb:TransactionCount", default="0", namespaces=ns),
        "failed": elem.findtext("sb:FailedTransactionCount", default="0", namespaces=ns),
        "avg_response": elem.findtext("sb:AverageResponse", default="0", namespaces=ns),
        "p90": elem.findtext("sb:NinetiethPercentile", default="0", namespaces=ns),
        "max_response": elem.findtext("sb:MaximumResponse", default="0", namespaces=ns),
    })

log_lines = charbench_log.read_text(errors="ignore").splitlines()
series = []
metric_re = re.compile(r"^(\d{2}:\d{2}:\d{2})\s+\[(\d+)/(\d+)\]\s+(\d+)\s+(\d+)\s+(\d+)")
for line in log_lines:
    m = metric_re.match(line.strip())
    if not m:
        continue
    t, active, total, tpm, tps, errs = m.groups()
    series.append({
        "time": t,
        "active": int(active),
        "total": int(total),
        "tpm": int(tpm),
        "tps": int(tps),
        "errors": int(errs),
    })

db_json_preview = ""
if results_db_json and results_db_json.exists():
    raw = results_db_json.read_text(errors="ignore").strip()
    try:
        parsed = json.loads(raw)
        db_json_preview = json.dumps(parsed, indent=2)[:4000]
    except Exception:
        db_json_preview = raw[:4000]

def build_svg(points, value_key, stroke, title):
    if not points:
        return "<p>No runtime series available.</p>"
    width, height = 720, 220
    pad_left, pad_right, pad_top, pad_bottom = 52, 24, 20, 32
    usable_w = width - pad_left - pad_right
    usable_h = height - pad_top - pad_bottom
    values = [p[value_key] for p in points]
    max_val = max(values) if max(values) > 0 else 1
    coords = []
    for i, val in enumerate(values):
        x = pad_left + (usable_w * i / max(1, len(values) - 1))
        y = pad_top + usable_h - (usable_h * (val / max_val))
        coords.append((x, y))
    poly = " ".join(f"{x:.2f},{y:.2f}" for x, y in coords)
    y_ticks = []
    for idx in range(5):
        ratio = idx / 4
        y = pad_top + usable_h - usable_h * ratio
        label = int(max_val * ratio)
        y_ticks.append((y, label))
    x_labels = []
    step = max(1, len(points) // 6)
    for i in range(0, len(points), step):
        x = pad_left + (usable_w * i / max(1, len(points) - 1))
        x_labels.append((x, points[i]["time"]))
    if x_labels[-1][1] != points[-1]["time"]:
        x_labels.append((pad_left + usable_w, points[-1]["time"]))
    out = [f'<svg viewBox="0 0 {width} {height}" class="metric-chart" role="img" aria-label="{html.escape(title)}">']
    out.append(f'<rect x="0" y="0" width="{width}" height="{height}" rx="18" fill="#fffaf2"/>')
    for y, label in y_ticks:
        out.append(f'<line x1="{pad_left}" y1="{y:.2f}" x2="{width-pad_right}" y2="{y:.2f}" stroke="#eadfcd" stroke-width="1"/>')
        out.append(f'<text x="{pad_left-8}" y="{y+4:.2f}" text-anchor="end" font-size="11" fill="#7a6a55">{label}</text>')
    out.append(f'<polyline fill="none" stroke="{stroke}" stroke-width="3" points="{poly}"/>')
    for x, y in coords[::max(1, len(coords)//18)]:
        out.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="2.8" fill="{stroke}"/>')
    for x, label in x_labels:
        out.append(f'<text x="{x:.2f}" y="{height-10}" text-anchor="middle" font-size="11" fill="#7a6a55">{html.escape(label)}</text>')
    out.append("</svg>")
    return "".join(out)

summary_cards = "".join(
    f'<article class="stat-card"><h3>{html.escape(k)}</h3><p>{html.escape(v)}</p></article>'
    for k, v in overview.items()
)

transaction_table = "".join(
    "<tr>"
    f"<td>{html.escape(row['name'])}</td>"
    f"<td>{html.escape(row['count'])}</td>"
    f"<td>{html.escape(row['failed'])}</td>"
    f"<td>{html.escape(row['avg_response'])}</td>"
    f"<td>{html.escape(row['p90'])}</td>"
    f"<td>{html.escape(row['max_response'])}</td>"
    "</tr>"
    for row in transaction_rows
)

html_doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sprint 15 Swingbench Report</title>
  <style>
    :root {{
      --bg: #f6efe3;
      --panel: #fffaf2;
      --ink: #201911;
      --muted: #6f604f;
      --line: #dccdb8;
      --accent: #9c4f21;
      --accent-2: #1e6f68;
      --accent-3: #7a1f36;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: Georgia, "Iowan Old Style", serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, #fff7ea 0, #fff7ea 18%, transparent 19%) 0 0/180px 180px,
        linear-gradient(180deg, #f8f1e7 0%, #f1e7d8 100%);
    }}
    main {{ max-width: 1180px; margin: 0 auto; padding: 40px 24px 72px; }}
    .hero {{
      background: linear-gradient(135deg, rgba(156,79,33,.94), rgba(59,33,13,.96));
      color: #fff7ec;
      border-radius: 28px;
      padding: 28px 30px;
      box-shadow: 0 18px 50px rgba(67, 34, 11, 0.18);
    }}
    .eyebrow {{ margin: 0; letter-spacing: .18em; text-transform: uppercase; font-size: 12px; opacity: .84; }}
    h1 {{ margin: 10px 0 8px; font-size: clamp(34px, 5vw, 58px); line-height: 1; }}
    .hero p:last-child {{ max-width: 760px; color: rgba(255,247,236,.88); }}
    .toc, .panel {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 22px;
      padding: 24px;
      margin-top: 24px;
      box-shadow: 0 10px 30px rgba(70, 46, 22, 0.08);
    }}
    .toc ul {{ margin: 8px 0 0; padding-left: 18px; }}
    .toc a {{ color: var(--accent); text-decoration: none; }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 14px;
      margin-top: 18px;
    }}
    .stat-card {{
      border: 1px solid var(--line);
      border-radius: 18px;
      background: #fffdf8;
      padding: 16px 18px;
    }}
    .stat-card h3 {{ margin: 0 0 6px; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }}
    .stat-card p {{ margin: 0; font-size: 24px; font-weight: 700; }}
    h2 {{ margin: 0 0 14px; font-size: 28px; }}
    .section-kicker {{ margin: 0 0 18px; color: var(--muted); }}
    .chart-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 18px;
    }}
    .metric-chart {{ width: 100%; height: auto; display: block; }}
    table {{ width: 100%; border-collapse: collapse; font-size: 14px; }}
    th, td {{ text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }}
    th {{ color: var(--muted); font-size: 12px; letter-spacing: .08em; text-transform: uppercase; }}
    .artifact-list li {{ margin: 8px 0; }}
    code, pre {{ font-family: "SFMono-Regular", Menlo, Consolas, monospace; }}
    pre {{
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      background: #201911;
      color: #f7f2e8;
      border-radius: 18px;
      padding: 18px;
      font-size: 12px;
      line-height: 1.45;
    }}
    details.class-section {{
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 14px 16px;
      background: #fffdf8;
    }}
    details.class-section summary {{ cursor: pointer; font-weight: 700; }}
  </style>
</head>
<body>
  <main>
    <section class="hero">
      <p class="eyebrow">Swingbench Results</p>
      <h1>Sprint 15 Swingbench Benchmark Dashboard</h1>
      <p>Standalone HTML presentation for the archived Sprint 15 Swingbench result set. This report summarizes benchmark outcome, transaction mix, and runtime behavior from the saved XML, CLI log, and exported database JSON.</p>
    </section>

    <section class="toc">
      <h2>Table of Contents</h2>
      <ul>
        <li><a href="#overview">Overview</a></li>
        <li><a href="#runtime">Runtime Charts</a></li>
        <li><a href="#transactions">Transaction Mix</a></li>
        <li><a href="#artifacts">Artifacts</a></li>
        <li><a href="#json">Benchmark JSON</a></li>
      </ul>
    </section>

    <section id="overview" class="panel">
      <h2>Overview</h2>
      <p class="section-kicker">High-level benchmark outcome extracted from the archived Swingbench XML result file.</p>
      <div class="stats">{summary_cards}</div>
    </section>

    <section id="runtime" class="panel">
      <h2>Runtime Charts</h2>
      <p class="section-kicker">Per-sample throughput captured from the `charbench` console stream.</p>
      <div class="chart-grid">
        <article>
          <h3>TPS Over Time</h3>
          {build_svg(series, "tps", "#9c4f21", "TPS over time")}
        </article>
        <article>
          <h3>TPM Over Time</h3>
          {build_svg(series, "tpm", "#1e6f68", "TPM over time")}
        </article>
      </div>
    </section>

    <section id="transactions" class="panel">
      <h2>Transaction Mix</h2>
      <p class="section-kicker">Per-transaction totals and response times from the Swingbench XML result set.</p>
      <details class="class-section" open>
        <summary>Per-Transaction Breakdown</summary>
        <table>
          <thead>
            <tr>
              <th>Transaction</th>
              <th>Count</th>
              <th>Failed</th>
              <th>Avg Response</th>
              <th>P90</th>
              <th>Max Response</th>
            </tr>
          </thead>
          <tbody>
            {transaction_table}
          </tbody>
        </table>
      </details>
    </section>

    <section id="artifacts" class="panel">
      <h2>Artifacts</h2>
      <ul class="artifact-list">
        <li><code>{html.escape(str(results_xml.name))}</code> — raw Swingbench XML results</li>
        <li><code>{html.escape(str(charbench_log.name))}</code> — `charbench` execution log with runtime samples</li>
        <li><code>{html.escape(str(results_db_json.name if results_db_json else "n/a"))}</code> — latest `BENCHMARK_RESULTS` export from the database</li>
      </ul>
    </section>

    <section id="json" class="panel">
      <h2>Benchmark JSON</h2>
      <p class="section-kicker">Preview of the exported `BENCHMARK_RESULTS` JSON payload.</p>
      <pre>{html.escape(db_json_preview or "No BENCHMARK_RESULTS JSON preview available.")}</pre>
    </section>
  </main>
</body>
</html>
"""

output_html.write_text(html_doc)
PY
