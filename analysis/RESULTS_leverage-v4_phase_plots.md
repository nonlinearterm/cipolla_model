## v4 phase plots: where collapse probability becomes non-zero

This note adds two lightweight visualizations on top of v4 outputs:

### 1) From the \(p_S \times \gamma\) heatmap grid

Input:
- `experiments/exp_016_v4_phase_pS_gamma_levS/grid_summary.csv`

Outputs:
- `phase_collapse.png` (heatmap of `collapse_prob`)
- `ps_vs_mW_by_gamma.png` (for gammas with any `collapse_prob>0`, plot `p_S` vs `m_W_mean` and mark collapse points)

Script:
- `scripts/plot_ps_vs_mW_by_gamma_from_grid.jl`

### 2) \(N \times p_S\) grid at fixed \(\gamma\)

Input:
- `experiments/exp_017_v4_phase_N_pS_levS_gamma2/grid_summary.csv`

Output:
- `ps_vs_mW_by_N.png` (plot `p_S` vs `m_W_mean` for each N and mark collapse points)

Scripts:
- `scripts/run_grid_scan_N_pS.jl`
- `scripts/plot_N_pS_orderparam.jl`


