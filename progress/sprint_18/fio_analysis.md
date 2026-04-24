# Sprint 18 FIO Phase Analysis

## fio Jobs

### data-8k
- Read IOPS: `7263.82`
- Read MiB/s: `56.75`
- Write IOPS: `3113.42`
- Write MiB/s: `24.32`

### data-8k
- Read IOPS: `7265.85`
- Read MiB/s: `56.76`
- Write IOPS: `3113.14`
- Write MiB/s: `24.32`

### data-8k
- Read IOPS: `7267.24`
- Read MiB/s: `56.78`
- Write IOPS: `3112.07`
- Write MiB/s: `24.31`

### data-8k
- Read IOPS: `7270.29`
- Read MiB/s: `56.8`
- Write IOPS: `3110.16`
- Write MiB/s: `24.3`

### redo
- Read IOPS: `0.0`
- Read MiB/s: `0.0`
- Write IOPS: `688.74`
- Write MiB/s: `2.69`

### fra-1m
- Read IOPS: `11.94`
- Read MiB/s: `11.94`
- Write IOPS: `11.62`
- Write MiB/s: `11.62`

## Guest iostat

- `dm-4` avg read `415.49 MiB/s`, avg write `178.26 MiB/s`, avg util `99.26%`
- `sdb` avg read `207.72 MiB/s`, avg write `89.15 MiB/s`, avg util `99.26%`
- `sdg` avg read `207.76 MiB/s`, avg write `89.11 MiB/s`, avg util `99.25%`
- `dm-2` avg read `207.72 MiB/s`, avg write `89.15 MiB/s`, avg util `99.25%`
- `dm-3` avg read `207.76 MiB/s`, avg write `89.11 MiB/s`, avg util `99.25%`
- `dm-5` avg read `0.00 MiB/s`, avg write `16.04 MiB/s`, avg util `99.22%`
- `sdn` avg read `20.27 MiB/s`, avg write `26.29 MiB/s`, avg util `99.17%`
- `sdm` avg read `0.00 MiB/s`, avg write `8.02 MiB/s`, avg util `78.67%`
- `sdl` avg read `0.00 MiB/s`, avg write `8.02 MiB/s`, avg util `78.17%`
- `sda` avg read `0.00 MiB/s`, avg write `0.73 MiB/s`, avg util `1.15%`
- `dm-0` avg read `0.00 MiB/s`, avg write `0.72 MiB/s`, avg util `0.73%`
- `dm-1` avg read `0.00 MiB/s`, avg write `0.03 MiB/s`, avg util `0.02%`
- `sde` avg read `0.00 MiB/s`, avg write `0.00 MiB/s`, avg util `0.01%`
- `sdh` avg read `0.00 MiB/s`, avg write `0.00 MiB/s`, avg util `0.01%`
- `sdk` avg read `0.00 MiB/s`, avg write `0.00 MiB/s`, avg util `0.01%`

## Interpretation

- This phase validates the Oracle-style fio profile on the multi-volume benchmark topology.
- Guest iostat shows which devices absorbed the fio load during the benchmark window.
- OCI metrics for the same window are archived separately and can be compared with this guest-side evidence.
