
mutable struct Security
    idx::Int64
    distribution::Distribution
end

struct Portfolio
    cons::Int64
    securities::Dict{Security, Int64}
end

mutable struct Agent
    idx::Int64
    portfolio::Portfolio
    alpha::Array{Float64}
end

mutable struct Model
    key::String
    securities::Set{Security}
    supply::Dict{Security, Int64}
    agents::Vector{Agent}
end
