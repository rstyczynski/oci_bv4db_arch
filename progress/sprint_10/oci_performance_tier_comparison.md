# Sprint 10 OCI Performance Tier Comparison

## Scope

Sprint 10 keeps the Sprint 9 Oracle fio workload unchanged and varies only:

- OCI block volume performance tier
- single-volume versus separated-volume topology
- compute sizing required to realize the target tier

The separated-volume runs use the same tier for `DATA`, `REDO`, and `FRA` volumes so the tier signal stays clean.

## Compute Sizing Used

| OCI tier | Topology | Compute |
| ------ | ------ | ------ |
| Lower Cost | single-volume | `VM.Standard.E5.Flex`, `2 OCPUs`, `16 GB` |
| Balanced | single-volume | `VM.Standard.E5.Flex`, `8 OCPUs`, `32 GB` |
| Balanced | multi-volume | `VM.Standard.E5.Flex`, `8 OCPUs`, `32 GB` |
| Higher Performance | single-volume | `VM.Standard.E5.Flex`, `8 OCPUs`, `32 GB` |
| Higher Performance | multi-volume | `VM.Standard.E5.Flex`, `8 OCPUs`, `32 GB` |
| UHP reference | single-volume | Sprint 9 reference: `VM.Standard.E5.Flex`, `40 OCPUs`, `64 GB` |
| UHP reference | multi-volume | Sprint 9 reference: `VM.Standard.E5.Flex`, `40 OCPUs`, `64 GB` |

## Measured Logical-Volume Results

| Tier | Topology | DATA | REDO | FRA |
| ------ | ------ | ------ | ------ | ------ |
| Lower Cost | single-volume | `754` read IOPS / `5.89 MiB/s` read; `324` write IOPS / `2.53 MiB/s` write | `4` write IOPS / `0.02 MiB/s` | `13` read IOPS / `12.88 MiB/s` read; `12` write IOPS / `12.39 MiB/s` write |
| Balanced | single-volume | `6395` read IOPS / `49.96 MiB/s` read; `2742` write IOPS / `21.43 MiB/s` write | `36` write IOPS / `0.14 MiB/s` | `105` read IOPS / `104.77 MiB/s` read; `104` write IOPS / `104.30 MiB/s` write |
| Balanced | multi-volume | `16780` read IOPS / `131.09 MiB/s` read; `7187` write IOPS / `56.15 MiB/s` write | `827` write IOPS / `3.23 MiB/s` | `24` read IOPS / `23.57 MiB/s` read; `23` write IOPS / `23.31 MiB/s` write |
| Higher Performance | single-volume | `9893` read IOPS / `77.29 MiB/s` read; `4241` write IOPS / `33.13 MiB/s` write | `60` write IOPS / `0.23 MiB/s` | `120` read IOPS / `120.00 MiB/s` read; `120` write IOPS / `120.00 MiB/s` write |
| Higher Performance | multi-volume | `20979` read IOPS / `163.90 MiB/s` read; `8984` write IOPS / `70.19 MiB/s` write | `769` write IOPS / `3.00 MiB/s` | `29` read IOPS / `29.37 MiB/s` read; `29` write IOPS / `29.22 MiB/s` write |
| UHP reference | single-volume | `18606` read IOPS / `145.36 MiB/s` read; `7969` write IOPS / `62.26 MiB/s` write | `131` write IOPS / `0.51 MiB/s` | `120` read IOPS / `120.00 MiB/s` read; `120` write IOPS / `120.00 MiB/s` write |
| UHP reference | multi-volume | `55137` read IOPS / `430.76 MiB/s` read; `23622` write IOPS / `184.55 MiB/s` write | `791` write IOPS / `3.09 MiB/s` | `24` read IOPS / `23.57 MiB/s` read; `23` write IOPS / `23.31 MiB/s` write |

## Interpretation

- Lower Cost single-volume is a valid Oracle-style reference point, but it is far too weak for serious concurrent database workload.
- Balanced and Higher Performance single-volume runs improve `DATA` and `REDO`, but they still keep `DATA`, `REDO`, and `FRA` on one contention domain.
- Balanced and Higher Performance multi-volume runs keep `REDO` materially stronger than their single-volume counterparts because `REDO` no longer competes with the `FRA` stream on one underlying device.
- `FRA` is intentionally rate-like in the multi-volume layout. The lower `FRA` MB/s in multi-volume runs is not a failure signal; it shows that `FRA` is isolated instead of consuming the same device bandwidth needed by `DATA` and `REDO`.
- The redo job is intentionally synchronous (`iodepth=1`, `fdatasync=1`, `4k` writes), so redo should be judged by sync write rate and latency sensitivity, not by large throughput numbers.
- The Sprint 9 UHP reference remains much stronger than Sprint 10 Balanced and Higher Performance results, but that reference also uses much larger compute (`40 OCPUs`). That is consistent with OCI guidance that realized block volume performance depends on instance-side capacity as well as the volume tier itself.

## Practical Conclusion

- `Lower Cost` is acceptable only as a minimal Oracle starting point.
- `Balanced single-volume` is the first plausible simplicity-oriented production layout.
- `Balanced multi-volume` is the first layout in this repository that combines production-style Oracle domain separation with reasonable `DATA` and `REDO` behavior.
- `Higher Performance multi-volume` is the strongest Sprint 10 layout and the best non-UHP Oracle layout proven in this repository so far.
- `UHP multi-volume` remains the top-end reference when the goal is maximum Oracle headroom on OCI block volumes.
