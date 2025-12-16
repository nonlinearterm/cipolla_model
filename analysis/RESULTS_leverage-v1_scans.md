## Leverage v2: scans over \(p_S\) and \(N\)

This note records the 1D scans under two leverage settings:

- **Independent leverage**: leverage distribution independent of type
- **S-biased leverage**: type-biased leverage with higher leverage for S (`type_bias.S = 3.0`)

Four scan experiment folders:

- `experiments/exp_006_levInd_scan_pS/` (scan `p_S`)
- `experiments/exp_007_levS_scan_pS/` (scan `p_S`)
- `experiments/exp_008_levInd_scan_N/` (scan `N`)
- `experiments/exp_009_levS_scan_N/` (scan `N`)

Each scan uses `replicates=5` seeds per parameter point and writes:
- `results_scan.csv` (mean/std summary per point)
- `results_scan_long.csv` (per-seed rows)
- `scan_plot.png` (mean curve + std error bars + per-seed thin lines)

### Reproduce

```bash
julia --project scripts/run_experiment.jl experiments/exp_006_levInd_scan_pS/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_007_levS_scan_pS/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_008_levInd_scan_N/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_009_levS_scan_N/config.yaml

julia --project scripts/plot_scan.jl experiments/exp_006_levInd_scan_pS/results_scan.csv experiments/exp_006_levInd_scan_pS/scan_plot.png
julia --project scripts/plot_scan.jl experiments/exp_007_levS_scan_pS/results_scan.csv experiments/exp_007_levS_scan_pS/scan_plot.png
julia --project scripts/plot_scan.jl experiments/exp_008_levInd_scan_N/results_scan.csv experiments/exp_008_levInd_scan_N/scan_plot.png
julia --project scripts/plot_scan.jl experiments/exp_009_levS_scan_N/results_scan.csv experiments/exp_009_levS_scan_N/scan_plot.png
```


