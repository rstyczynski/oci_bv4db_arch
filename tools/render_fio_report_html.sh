#!/usr/bin/env bash
# render_fio_report_html.sh — render fio + iostat artifacts into a standalone HTML dashboard

set -euo pipefail

FIO_JSON="${1:?usage: render_fio_report_html.sh <fio.json> <iostat.json> <output.html> [title]}"
IOSTAT_JSON="${2:?usage: render_fio_report_html.sh <fio.json> <iostat.json> <output.html> [title]}"
OUTPUT_HTML="${3:?usage: render_fio_report_html.sh <fio.json> <iostat.json> <output.html> [title]}"
REPORT_TITLE="${4:-Sprint 17 FIO Report}"

python3 - "$FIO_JSON" "$IOSTAT_JSON" "$OUTPUT_HTML" "$REPORT_TITLE" <<'PY'
import html
import json
import math
import sys
from pathlib import Path

fio_json = Path(sys.argv[1])
iostat_json = Path(sys.argv[2])
output_html = Path(sys.argv[3])
report_title = sys.argv[4]

with fio_json.open("r", encoding="utf-8") as handle:
    fio = json.load(handle)
with iostat_json.open("r", encoding="utf-8") as handle:
    iostat = json.load(handle)

jobs = fio.get("jobs", [])
global_opts = fio.get("global options", {})

def ns_to_ms(value):
    return round((value or 0) / 1_000_000, 2)

job_rows = []
for job in jobs:
    read = job.get("read", {})
    write = job.get("write", {})
    job_rows.append({
        "name": job.get("jobname", "unknown"),
        "read_iops": round(read.get("iops", 0), 2),
        "read_bw_mib": round(read.get("bw", 0) / 1024, 2),
        "read_lat_ms": ns_to_ms(read.get("lat_ns", {}).get("mean", 0)),
        "write_iops": round(write.get("iops", 0), 2),
        "write_bw_mib": round(write.get("bw", 0) / 1024, 2),
        "write_lat_ms": ns_to_ms(write.get("lat_ns", {}).get("mean", 0)),
    })

stats = (((iostat.get("sysstat") or {}).get("hosts") or [{}])[0].get("statistics") or [])
disk_samples = {}
for snap in stats:
    for disk in snap.get("disk", []):
        name = disk.get("disk_device", "unknown")
        disk_samples.setdefault(name, []).append({
            "read_mib": float(disk.get("rMB/s", 0.0)),
            "write_mib": float(disk.get("wMB/s", 0.0)),
            "util": float(disk.get("util", 0.0)),
        })

disk_rows = []
for name, samples in disk_samples.items():
    if not samples:
        continue
    disk_rows.append({
        "name": name,
        "avg_read_mib": round(sum(s["read_mib"] for s in samples) / len(samples), 2),
        "avg_write_mib": round(sum(s["write_mib"] for s in samples) / len(samples), 2),
        "avg_util": round(sum(s["util"] for s in samples) / len(samples), 2),
        "max_util": round(max(s["util"] for s in samples), 2),
    })
disk_rows.sort(key=lambda row: (row["avg_util"], row["avg_read_mib"] + row["avg_write_mib"]), reverse=True)

runtime = global_opts.get("runtime", "n/a")
ramp_time = global_opts.get("ramp_time", "n/a")
ioengine = global_opts.get("ioengine", "n/a")

total_read_iops = round(sum(row["read_iops"] for row in job_rows), 2)
total_write_iops = round(sum(row["write_iops"] for row in job_rows), 2)
total_read_bw = round(sum(row["read_bw_mib"] for row in job_rows), 2)
total_write_bw = round(sum(row["write_bw_mib"] for row in job_rows), 2)

def svg_chart(rows, key, stroke, label):
    if not rows:
        return "<p>No iostat samples available.</p>"
    width, height = 720, 220
    pad_left, pad_right, pad_top, pad_bottom = 48, 24, 20, 32
    usable_w = width - pad_left - pad_right
    usable_h = height - pad_top - pad_bottom
    values = [row[key] for row in rows]
    max_val = max(values) if max(values) > 0 else 1.0
    coords = []
    for i, row in enumerate(rows):
        x = pad_left + usable_w * i / max(1, len(rows) - 1)
        y = pad_top + usable_h - usable_h * (row[key] / max_val)
        coords.append((x, y))
    poly = " ".join(f"{x:.2f},{y:.2f}" for x, y in coords)
    ticks = []
    for idx in range(5):
        ratio = idx / 4
        y = pad_top + usable_h - usable_h * ratio
        value = max_val * ratio
        ticks.append(f'<line x1="{pad_left}" y1="{y:.2f}" x2="{width-pad_right}" y2="{y:.2f}" stroke="#ddd5c6" stroke-width="1"/>')
        ticks.append(f'<text x="{pad_left-8}" y="{y+4:.2f}" text-anchor="end" font-size="11" fill="#6b5d4e">{value:.1f}</text>')
    return f"""
<svg viewBox="0 0 {width} {height}" class="metric-chart" role="img" aria-label="{html.escape(label)}">
  <rect x="0" y="0" width="{width}" height="{height}" rx="18" fill="#fffdf8"/>
  {''.join(ticks)}
  <polyline fill="none" stroke="{stroke}" stroke-width="3" points="{poly}"/>
</svg>
"""

top_disk = disk_rows[0]["name"] if disk_rows else "n/a"
top_series = disk_samples.get(top_disk, [])

job_table = "".join(
    "<tr>"
    f"<td>{html.escape(row['name'])}</td>"
    f"<td>{row['read_iops']}</td>"
    f"<td>{row['read_bw_mib']}</td>"
    f"<td>{row['read_lat_ms']}</td>"
    f"<td>{row['write_iops']}</td>"
    f"<td>{row['write_bw_mib']}</td>"
    f"<td>{row['write_lat_ms']}</td>"
    "</tr>"
    for row in job_rows
)

disk_table = "".join(
    "<tr>"
    f"<td>{html.escape(row['name'])}</td>"
    f"<td>{row['avg_read_mib']}</td>"
    f"<td>{row['avg_write_mib']}</td>"
    f"<td>{row['avg_util']}</td>"
    f"<td>{row['max_util']}</td>"
    "</tr>"
    for row in disk_rows[:18]
)

html_doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(report_title)}</title>
  <style>
    :root {{
      --bg: #f7f0e7;
      --panel: #fffaf3;
      --ink: #22170f;
      --muted: #6f6152;
      --line: #ddcfbe;
      --accent: #8a4f15;
      --accent2: #236f83;
      --accent3: #7c2439;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: Georgia, "Iowan Old Style", serif;
      color: var(--ink);
      background: linear-gradient(180deg, #fbf6ef 0%, #f0e4d3 100%);
    }}
    main {{ max-width: 1180px; margin: 0 auto; padding: 40px 24px 72px; }}
    .hero {{
      background: linear-gradient(135deg, rgba(138,79,21,.96), rgba(52,30,10,.96));
      color: #fff7ee;
      border-radius: 28px;
      padding: 28px 30px;
      box-shadow: 0 18px 50px rgba(67,34,11,.18);
    }}
    .eyebrow {{ margin: 0; letter-spacing: .18em; text-transform: uppercase; font-size: 12px; opacity: .84; }}
    h1 {{ margin: 10px 0 8px; font-size: clamp(34px, 5vw, 58px); line-height: 1; }}
    .toc, .panel {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 22px;
      padding: 24px;
      margin-top: 24px;
      box-shadow: 0 10px 30px rgba(70,46,22,.08);
    }}
    .toc ul {{ margin: 8px 0 0; padding-left: 18px; }}
    .toc a {{ color: var(--accent); text-decoration: none; }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 14px;
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
  </style>
</head>
<body>
  <main>
    <section class="hero">
      <p class="eyebrow">FIO Results</p>
      <h1>{html.escape(report_title)}</h1>
      <p>Standalone HTML presentation for the archived Oracle-style fio phase, combining fio per-job results with guest iostat device observations.</p>
    </section>

    <section class="toc">
      <h2>Table of Contents</h2>
      <ul>
        <li><a href="#overview">Overview</a></li>
        <li><a href="#jobs">fio Jobs</a></li>
        <li><a href="#devices">Device Activity</a></li>
        <li><a href="#runtime">Top Device Charts</a></li>
      </ul>
    </section>

    <section id="overview" class="panel">
      <h2>Overview</h2>
      <p class="section-kicker">High-level fio context and aggregated throughput from the archived result set.</p>
      <div class="stats">
        <article class="stat-card"><h3>Runtime</h3><p>{html.escape(str(runtime))} s</p></article>
        <article class="stat-card"><h3>Ramp Time</h3><p>{html.escape(str(ramp_time))} s</p></article>
        <article class="stat-card"><h3>IO Engine</h3><p>{html.escape(str(ioengine))}</p></article>
        <article class="stat-card"><h3>Total Read IOPS</h3><p>{total_read_iops}</p></article>
        <article class="stat-card"><h3>Total Write IOPS</h3><p>{total_write_iops}</p></article>
        <article class="stat-card"><h3>Total Read MiB/s</h3><p>{total_read_bw}</p></article>
        <article class="stat-card"><h3>Total Write MiB/s</h3><p>{total_write_bw}</p></article>
        <article class="stat-card"><h3>Most Active Device</h3><p>{html.escape(top_disk)}</p></article>
      </div>
    </section>

    <section id="jobs" class="panel">
      <h2>fio Jobs</h2>
      <p class="section-kicker">Per-job fio throughput and latency extracted from the JSON output.</p>
      <table>
        <thead>
          <tr>
            <th>Job</th>
            <th>Read IOPS</th>
            <th>Read MiB/s</th>
            <th>Read Lat ms</th>
            <th>Write IOPS</th>
            <th>Write MiB/s</th>
            <th>Write Lat ms</th>
          </tr>
        </thead>
        <tbody>
          {job_table}
        </tbody>
      </table>
    </section>

    <section id="devices" class="panel">
      <h2>Device Activity</h2>
      <p class="section-kicker">Guest iostat averages used to confirm device-level behavior during the fio phase.</p>
      <table>
        <thead>
          <tr>
            <th>Device</th>
            <th>Avg Read MiB/s</th>
            <th>Avg Write MiB/s</th>
            <th>Avg Util %</th>
            <th>Max Util %</th>
          </tr>
        </thead>
        <tbody>
          {disk_table}
        </tbody>
      </table>
    </section>

    <section id="runtime" class="panel">
      <h2>Top Device Charts</h2>
      <p class="section-kicker">Runtime samples for the most active device seen in guest iostat.</p>
      <div class="chart-grid">
        <article>
          <h3>{html.escape(top_disk)} Read MiB/s</h3>
          {svg_chart(top_series, "read_mib", "#8a4f15", f"{top_disk} read throughput")}
        </article>
        <article>
          <h3>{html.escape(top_disk)} Write MiB/s</h3>
          {svg_chart(top_series, "write_mib", "#236f83", f"{top_disk} write throughput")}
        </article>
        <article>
          <h3>{html.escape(top_disk)} Util %</h3>
          {svg_chart(top_series, "util", "#7c2439", f"{top_disk} utilization")}
        </article>
      </div>
    </section>
  </main>
</body>
</html>
"""

output_html.write_text(html_doc, encoding="utf-8")
PY
