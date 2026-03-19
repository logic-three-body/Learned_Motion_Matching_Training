# Hardware Benchmark Summary

| Scenario | case-03 (s) | case-04 (s) | case-05 (s) | Total (s) |
|---|---:|---:|---:|---:|
| CPU baseline | 18.683 | 131.112 | 47.578 | 197.373 |
| Single GPU tuned | 18.341 | 32.038 | 22.140 | 72.519 |
| Dual GPU tuned (04/05 parallel) | 18.341 | - | - | 53.100 |

- Recommendation: use Dual GPU tuned profile for best wall-clock under this machine.
