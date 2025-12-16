@enum AgentType::UInt8 I=1 B=2 H=3 S=4

@inline function sign_self(t::AgentType)::Float64
    t === I && return 1.0
    t === B && return 1.0
    t === H && return -1.0
    return -1.0 # S
end

@inline function sign_other(t::AgentType)::Float64
    t === I && return 1.0
    t === B && return -1.0
    t === H && return 1.0
    return -1.0 # S
end

@inline function parse_agent_type(x)::AgentType
    x isa AgentType && return x
    s = uppercase(String(x))
    s == "I" && return I
    s == "B" && return B
    s == "H" && return H
    s == "S" && return S
    error("Unknown agent type: $(repr(x)). Expected one of I,B,H,S.")
end



