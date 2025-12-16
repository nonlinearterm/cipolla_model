# Cipolla ABM (Julia) — project skeleton

This repository is structured to keep **code in git** and manage **numerical experiment versions via parameters + directories + metadata**.
Do **not** try to version raw simulation outputs with git.

## Structure

```
cipolla_model/
├── src/                    # Julia source (model/sim/measures) — tracked by git
├── experiments/            # One folder per experiment “worldline”
│   ├── exp_001_baseline/
│   │   ├── config.yaml     # experiment DNA (tracked)
│   │   └── summary.json    # small metrics for analysis (tracked)
│   ├── exp_002_scan_pS/
│   │   ├── config.yaml
│   │   └── summary.json
│   └── ...                 # large results files are ignored by .gitignore
├── notebooks/              # optional notebooks / exploratory analysis
├── analysis/               # optional scripted analysis outputs
├── Project.toml            # Julia project (tracked)
└── .gitignore
```

## Experiment versioning rule

- Each **model assumption / algorithm change** = one git commit.
- Each **experiment run** = one `experiments/exp_xxx_*` directory with:
  - `config.yaml` (parameters, random seed, model version tag/commit)
  - `summary.json` (aggregated metrics you’ll use for phase diagrams)
  - large artifacts (time series, arrays, snapshots) **ignored by git**

## Minimal ABM (v1) runner

Run a single experiment:

```bash
cd /root/playground/cipolla_model
julia --project scripts/run_experiment.jl experiments/exp_001_baseline/config.yaml
```

Outputs (in the same experiment directory by default):
- `summary.json`: small metrics + metadata (tracked)
- `results_W.csv`: time series of total resource W(t) (ignored by git)

Run a scan over `p_S`:

```bash
julia --project scripts/run_experiment.jl experiments/exp_002_scan_pS/config.yaml
```

Outputs:
- `summary.json`: includes `scan_results` (tracked)
- `results_scan.csv`: table for phase diagrams (ignored by git)
- `results_W_pS_*.csv`: W(t) per scan point (ignored by git)

Run a scan over `N`:

```bash
julia --project scripts/run_experiment.jl experiments/exp_003_scan_N/config.yaml
```

## Visualize t vs W(t)

```bash
julia --project scripts/plot_W.jl experiments/exp_001_baseline/results_W.csv
```

This saves `W_timeseries.png` next to the input CSV (by default).

## Visualize scan results (p_S / N)

```bash
julia --project scripts/plot_scan.jl experiments/exp_002_scan_pS/results_scan.csv
julia --project scripts/plot_scan.jl experiments/exp_003_scan_N/results_scan.csv
```

This saves `scan_plot.png` next to each input CSV (by default).

## Results summary

See `RESULTS.md` for the current v1 findings and how to reproduce.


