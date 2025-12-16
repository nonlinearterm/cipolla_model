# 当前结果总结（Minimal ABM v1）

本项目的 v1 仅包含：
- agent 类型异质性（I/B/H/S，类型不可变）
- 完全随机 mixing
- 有序交互对 `i→j`
- 幅度 `a ~ Exponential(A)`，噪声 `ϵ ~ Normal(0, σ^2)`

没有拓扑、学习、晋升、杠杆、破产机制等。

## 1) 关键序参量：m_W

定义：
- 总资源：`W(t) = Σ u_i(t)`
- 序参量（长期漂移率的数值估计）：`m_W = mean(diff(W_series))`

在 v1 中可以直接解析得到期望值：
- I 行动者：`E[ΔW] = +2A`
- S 行动者：`E[ΔW] = -2A`
- B/H 行动者：`E[ΔW] = 0`

因为每步行动者从全体均匀抽样，所以：

**E[m_W] = 2A (p_I - p_S)**

这意味着：v1 的 “regime change” 本质上是 **线性过零**，阈值由 `p_I = p_S` 决定。

## 2) p_S 扫描（exp_002_scan_pS）

配置：
- `p_S` 从 0 到 0.5 的 **51 点**线性采样
- 每个点 **replicates=5**（不同 seed）
- I/B/H 在剩余比例中按 `p_types_base` 归一化分配

理论阈值（当 `p_types_base` 为 I/B/H 等分时）：
- `p_I = (1 - p_S)/3`
- 解 `p_I = p_S` 得到：**p_S* = 0.25**

数值结果表现：
- `m_W_mean` 在 `p_S≈0.25` 附近稳定穿越 0（多 seed 后误差条覆盖过零区间）
- `p_S` 增大时，负漂移区间内 `final_mean_u_mean` 也随之转负（系统性出血）

可视化：
- `experiments/exp_002_scan_pS/scan_plot.png`

## 3) N 扫描（exp_003_scan_N）

配置：
- `N` 在 `[100, 5000]` 的 **17 点**logspace 采样
- 每个点 **replicates=5**
- `p_types` 固定为 I/B/H/S 各 0.25

理论预期：
- 因为 `p_I = p_S`，所以 **E[m_W] = 0**（与 N 无关）

数值结果表现：
- 小 N 时 `m_W_mean` 波动更明显、std 更大（有限样本效应）
- 大 N 时 `m_W_mean` 更接近 0、std 更小（收敛趋势）

可视化：
- `experiments/exp_003_scan_N/scan_plot.png`

## 4) 如何解释“现在的结果”

这套结果最重要的意义是：**验证 v1 的实现正确，并且“增值/出血”两态由 (p_I - p_S) 决定且可重复**。

但也要注意：由于 v1 没有引入任何非线性机制（破产/下限、交互成本、网络拓扑、杠杆放大等），因此更像 **解析线性阈值**，而不是复杂系统里尖锐的临界相变。

## 5) 复现实验（不建议把大结果进 git）

单次实验：

```bash
julia --project scripts/run_experiment.jl experiments/exp_001_baseline/config.yaml
```

扫描：

```bash
julia --project scripts/run_experiment.jl experiments/exp_002_scan_pS/config.yaml
julia --project scripts/run_experiment.jl experiments/exp_003_scan_N/config.yaml
```

绘图：

```bash
julia --project scripts/plot_scan.jl experiments/exp_002_scan_pS/results_scan.csv
julia --project scripts/plot_scan.jl experiments/exp_003_scan_N/results_scan.csv
```


