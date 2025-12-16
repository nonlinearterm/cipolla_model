## Results Summary — Minimal ABM (v1) (`minimal-v1`)

This document summarizes the current results for **Minimal ABM v1** (git tag: `minimal-v1`).
The v1 model includes only:

- **Type heterogeneity**: agents are fixed types \(T_i \in \{I,B,H,S\}\)
- **Well-mixed interactions**: random ordered pairs \(i \to j\)
- **Stochastic payoffs**:
  - amplitude \(a \sim \mathrm{Exponential}(A)\)
  - noise \(\epsilon_i,\epsilon_j \sim \mathcal{N}(0,\sigma^2)\)

No topology, learning, promotion, leverage, bankruptcy constraints, etc.

### Order parameter: \(m_W\)

Define total resource:

\[
W(t) = \sum_i u_i(t)
\]

In simulation we record `W_series` and estimate long-run drift per step by:

- `m_W = mean(diff(W_series))`

### Analytical expectation in v1 (sanity check)

In a single interaction with action amplitude \(a\) and zero-mean noise:

- **I (Intelligent)**: \(\mathbb{E}[\Delta W] = +2A\)
- **S (Stupid)**: \(\mathbb{E}[\Delta W] = -2A\)
- **B (Bandit)**, **H (Helpless)**: \(\mathbb{E}[\Delta W] = 0\)

Since the actor is sampled uniformly from the population each step:

\[
\mathbb{E}[m_W] = 2A\,(p_I - p_S)
\]

So the v1 “regime change” is fundamentally a **linear sign flip** at \(p_I=p_S\).

### Scan 1: \(p_S\) (`experiments/exp_002_scan_pS`)

Setup:
- \(p_S \in [0,0.5]\) sampled on **51** evenly spaced points
- **replicates = 5** seeds per point
- \(I/B/H\) shares are taken from `p_types_base` and renormalized to \(1-p_S\)

Expectation (when `p_types_base` is roughly equal across I/B/H):
- \(p_I \approx (1-p_S)/3\)
- threshold \(p_S^\* \approx 0.25\)

Observed:
- `m_W_mean` crosses 0 near \(p_S \approx 0.25\), with uncertainty captured by the error bars
- auxiliary degradation trends with increasing \(p_S\): `final_mean_u_mean` decreases and becomes negative in the bleeding regime

Artifacts:
- summary table (mean/std): `experiments/exp_002_scan_pS/results_scan.csv`
- per-seed rows: `experiments/exp_002_scan_pS/results_scan_long.csv`
- plot: `experiments/exp_002_scan_pS/scan_plot.png`

### Scan 2: \(N\) (`experiments/exp_003_scan_N`)

Setup:
- \(N \in [100,5000]\) sampled on **17** log-spaced points
- **replicates = 5** seeds per point
- fixed `p_types`: I/B/H/S = 0.25 each

Expectation:
- since \(p_I=p_S\), \(\mathbb{E}[m_W]=0\) (independent of \(N\))

Observed:
- `m_W_mean` stays near 0 with noticeable finite-sample variation at small \(N\)
- variability decreases with larger \(N\) / averaging across seeds

Artifacts:
- summary table (mean/std): `experiments/exp_003_scan_N/results_scan.csv`
- per-seed rows: `experiments/exp_003_scan_N/results_scan_long.csv`
- plot: `experiments/exp_003_scan_N/scan_plot.png`

### How to reproduce (recommended)

Run scans:

```bash
julia --project scripts/run_experiment.jl experiments/exp_002_scan_pS/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_003_scan_N/config.yaml
```

Plot:

```bash
julia --project scripts/plot_scan.jl experiments/exp_002_scan_pS/results_scan.csv
julia --project scripts/plot_scan.jl experiments/exp_003_scan_N/results_scan.csv
```


