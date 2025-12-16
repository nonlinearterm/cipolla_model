## v3 scans: \(p_S\) and \(N\) under actor-weighted sampling

These scans use v3 actor selection:

\[
P(\text{actor}=i) \propto L_i^{\gamma}, \quad \gamma=1
\]

We compare the same scans under two leverage modes:
- `levInd`: leverage independent of type
- `levS`: S-biased leverage (`type_bias.S = 3`)

### Scan folders

- `experiments/exp_012_v3_levInd_scan_pS/`
- `experiments/exp_013_v3_levS_scan_pS/`
- `experiments/exp_014_v3_levInd_scan_N/`
- `experiments/exp_015_v3_levS_scan_N/`

Each scan uses `replicates=5` seeds and writes:
- `results_scan.csv` (mean/std per point)
- `results_scan_long.csv` (per-seed rows)
- `scan_plot.png` (mean curve + std error bars + per-seed overlays)

### Reproduce

```bash
julia --project scripts/run_experiment.jl experiments/exp_012_v3_levInd_scan_pS/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_013_v3_levS_scan_pS/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_014_v3_levInd_scan_N/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_015_v3_levS_scan_N/config.yaml

julia --project scripts/plot_scan.jl experiments/exp_012_v3_levInd_scan_pS/results_scan.csv experiments/exp_012_v3_levInd_scan_pS/scan_plot.png
julia --project scripts/plot_scan.jl experiments/exp_013_v3_levS_scan_pS/results_scan.csv experiments/exp_013_v3_levS_scan_pS/scan_plot.png
julia --project scripts/plot_scan.jl experiments/exp_014_v3_levInd_scan_N/results_scan.csv experiments/exp_014_v3_levInd_scan_N/scan_plot.png
julia --project scripts/plot_scan.jl experiments/exp_015_v3_levS_scan_N/results_scan.csv experiments/exp_015_v3_levS_scan_N/scan_plot.png
```


