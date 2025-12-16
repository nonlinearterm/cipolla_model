## Results Summary — Leverage ABM (v2) (`leverage-v1`)

This document summarizes the first leverage extension (v2).

### What changed vs v1

Each agent has a leverage \(L_i \ge 1\). In each step, an ordered pair \(i \to j\) is drawn and the v1 deltas are computed:

- \(\Delta u_i = s_{\text{self}}(T_i)\,a + \epsilon_i\)
- \(\Delta u_j = s_{\text{other}}(T_i)\,a + \epsilon_j\)

Then both deltas are **scaled by the actor’s leverage**:

\[
(\Delta u_i, \Delta u_j) \leftarrow (L_i^{\alpha}\Delta u_i,\; L_i^{\alpha}\Delta u_j)
\]

Leverage sampling (v2):
- base: \(L = l_{\min}\cdot \exp(Z)\), where \(Z \sim \mathcal{N}(\mu,\sigma_L^2)\)
- mode:
  - `independent`: \(L\) independent of type
  - `type_biased`: multiply by `type_bias[T_i]` (e.g. make S more likely to have high leverage)

### Quick sanity check outcome

With equal type shares (I/B/H/S = 0.25 each), v1 has \(\mathbb{E}[m_W]=0\).
In v2:
- if leverage is independent, the drift remains near 0 (up to sampling noise)
- if S is biased toward higher leverage, the system can enter a strong bleeding regime even at small \(p_S\)

### Repro configs

- Independent leverage:
  - `experiments/exp_004_leverage_independent/config.yaml`
- Stupid-biased leverage:
  - `experiments/exp_005_leverage_S_high/config.yaml`

Run:

```bash
julia --project scripts/run_experiment.jl experiments/exp_004_leverage_independent/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_005_leverage_S_high/config.yaml
```

Compare key fields in `summary.json`:
- `metrics.m_W`, `metrics.final_mean_u`, `metrics.phi_u_lt_threshold`
- `meta.leverage` (records alpha/dist/mode/bias)


