module CipollaModel

include("types.jl")
include("params.jl")
include("alias.jl")
include("simulate.jl")
include("measures.jl")
include("config.jl")

export AgentType, I, B, H, S
export ModelParams, SimulationResult
export simulate, measure_summary, load_config, params_from_config
export utc_timestamp

end # module


