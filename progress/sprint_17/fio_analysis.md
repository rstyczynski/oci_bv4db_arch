# Sprint 17 FIO Phase Analysis

## fio Jobs

### data-8k
- Read IOPS: `13200.06`
- Read MiB/s: `103.13`
- Write IOPS: `5664.11`
- Write MiB/s: `44.25`

### data-8k
- Read IOPS: `13212.1`
- Read MiB/s: `103.22`
- Write IOPS: `5647.24`
- Write MiB/s: `44.12`

### data-8k
- Read IOPS: `13218.53`
- Read MiB/s: `103.27`
- Write IOPS: `5654.88`
- Write MiB/s: `44.18`

### data-8k
- Read IOPS: `13213.91`
- Read MiB/s: `103.23`
- Write IOPS: `5647.62`
- Write MiB/s: `44.12`

### redo
- Read IOPS: `0.0`
- Read MiB/s: `0.0`
- Write IOPS: `706.29`
- Write MiB/s: `2.76`

### fra-1m
- Read IOPS: `23.68`
- Read MiB/s: `23.74`
- Write IOPS: `23.09`
- Write MiB/s: `23.14`

## Guest iostat

- `sdn` avg read `0.00 MiB/s`, avg write `25.54 MiB/s`, avg util `44.95%`
- `sdg` avg read `0.00 MiB/s`, avg write `143.38 MiB/s`, avg util `39.20%`
- `dm-4` avg read `0.00 MiB/s`, avg write `286.78 MiB/s`, avg util `39.07%`
- `dm-3` avg read `0.00 MiB/s`, avg write `143.38 MiB/s`, avg util `38.86%`
- `sdb` avg read `0.00 MiB/s`, avg write `143.40 MiB/s`, avg util `38.67%`
- `dm-2` avg read `0.00 MiB/s`, avg write `143.40 MiB/s`, avg util `38.12%`
- `sda` avg read `0.42 MiB/s`, avg write `1.35 MiB/s`, avg util `8.42%`
- `dm-0` avg read `0.41 MiB/s`, avg write `1.32 MiB/s`, avg util `8.38%`
- `dm-5` avg read `0.00 MiB/s`, avg write `9.51 MiB/s`, avg util `1.59%`
- `sdl` avg read `0.00 MiB/s`, avg write `4.76 MiB/s`, avg util `1.51%`
- `sdm` avg read `0.00 MiB/s`, avg write `4.75 MiB/s`, avg util `1.50%`
- `dm-1` avg read `0.00 MiB/s`, avg write `0.02 MiB/s`, avg util `0.04%`
- `sdi` avg read `0.00 MiB/s`, avg write `0.00 MiB/s`, avg util `0.02%`
- `sdd` avg read `0.00 MiB/s`, avg write `0.00 MiB/s`, avg util `0.02%`
- `sdc` avg read `0.00 MiB/s`, avg write `0.00 MiB/s`, avg util `0.01%`

## Interpretation

- This phase validates the Oracle-style fio profile on the multi-volume benchmark topology.
- Guest iostat shows which devices absorbed the fio load during the benchmark window.
- OCI metrics for the same window are archived separately and can be compared with this guest-side evidence.
