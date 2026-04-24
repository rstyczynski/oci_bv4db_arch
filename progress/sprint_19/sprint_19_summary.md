# Sprint 19 Summary

## Verdict

### FAILED

Sprint 19 produced meaningful improvements to correlation analysis and reporting, but the sprint objective of producing **trustworthy cross-layer conclusions across Sprint 17 and Sprint 18** is not met because the Sprint 17 Swingbench evidence is structurally invalid (database I/O placement defect) and short-run correlation can be misleading without sufficient overlapping samples.

## What failed (root causes)

- **Sprint 17 Swingbench invalid evidence**: database workload I/O is dominated by boot volume rather than the intended DATA/REDO/FRA block volumes, so topology correlation conclusions are not acceptable.
- **Short-run correlation pitfalls**: with small overlap counts, Pearson r can appear perfect (|r| close to 1.00) without being meaningful; correlation outputs must always be interpreted with overlap `n`.

## What was delivered (still valuable)

- Topology-aware correlation variables (`boot/data/redo/fra`) and per-resource aggregation (e.g., `data1+data2 -> data`).
- Better time alignment logic and lag-aware iostat↔OCI correlation.
- Swingbench TPS is joined as a time series for correlation.
- Synthetic FIO time series fallback when only fio summary artifacts exist.
- Report guardrails: correlation overlap `n` is surfaced and low-`n` warnings reduce misleading conclusions.

## Conclusions for future sprints

- **Fail fast on DB placement**: add/require explicit placement validation artifacts before running Swingbench (prove datafiles/redo/FRA are on `/u02` `/u03` `/u04`).
- **Use benchmark-quality durations**: prefer 900s+ windows so OCI Monitoring 1-minute metrics produce enough overlap for correlations.
- **Treat overlap count as first-class evidence**: correlations with `n < 10` must not be used for decisions.
- **Implement real FIO time series**: add fio per-interval logging ingestion so `fio_*_mbps` is measured, not synthetic.
