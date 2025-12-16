## Results Summary — v3: actor sampling weighted by leverage

v3 change (recommended “power position” mechanism):

Instead of sampling the actor uniformly, we sample the actor with probability:

\[
P(\text{actor}=i) \propto L_i^{\gamma}
\]

This makes leverage enter the dynamics **twice**:
- as an impact multiplier (v2): \((\Delta u_i,\Delta u_j) \leftarrow (L_i^\alpha \Delta u_i,\; L_i^\alpha \Delta u_j)\)
- as an interaction-rate multiplier (v3): high-leverage agents act more frequently

Implementation notes:
- leverage \(L_i\) is fixed per run (sampled once at initialization)
- actor sampling uses an **Alias table** for O(1) draws from fixed weights
- when `gamma = 0` or leverage is disabled, actor sampling reduces to uniform (v1/v2 behavior)

### Example configs

- v3 + independent leverage:
  - `experiments/exp_010_v3_actorWeighted_levInd/config.yaml`
- v3 + S-biased leverage:
  - `experiments/exp_011_v3_actorWeighted_levS/config.yaml`

Run:

```bash
julia --project scripts/run_experiment.jl experiments/exp_010_v3_actorWeighted_levInd/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_011_v3_actorWeighted_levS/config.yaml
```


