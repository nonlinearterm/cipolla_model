## v4: absorbing/bankruptcy state (phase-transition-friendly)

v4 adds a single nonlinearity to v3:

### Bankruptcy / absorbing state

If `bankruptcy_threshold` is finite, an agent becomes **inactive** once:

\[
u_i < \theta_{\text{bankrupt}}
\]

Inactive agents are removed from interactions:
- cannot be selected as actor
- cannot be selected as target

The run records:
- `metrics.collapsed` (true if active population drops below 2 before `T_steps`)
- `metrics.collapse_step` (first step where active < 2; 0 means no early collapse)
- `metrics.active_final`

### Minimal phase diagram (example)

`experiments/exp_016_v4_phase_pS_gamma_levS/` runs a cheap grid:
- \(p_S\) × \(\gamma\) (actor selection weight exponent)
- with leverage mode = `type_biased` (S has higher leverage)
- outputs:
  - `grid_summary.csv` (per-cell collapse probability)
  - `phase_collapse.png` (heatmap)

Reproduce:

```bash
julia --project scripts/run_grid_scan.jl experiments/exp_016_v4_phase_pS_gamma_levS/config.yaml
julia --project scripts/plot_phase_heatmap.jl experiments/exp_016_v4_phase_pS_gamma_levS/grid_summary.csv experiments/exp_016_v4_phase_pS_gamma_levS/phase_collapse.png
```


