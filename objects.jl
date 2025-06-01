

mutable struct Security
    idx::Int64
    distribution::Distribution
    tokenCount::Int64
end

abstract type Tradable end

struct Token <: Tradable
    idx::Int64
    security::Security
end

struct Consumption <: Tradable
    idx::Int64
end

struct Agent
    idx::Int64
    tokens::Union{Set{Tradable},Nothing}
end

mutable struct Model
    key::String
    securities::Set{Security}
    allTradeables::Set{Tradable}
    agents::Vector{Agent}
end

# we need tokens for the simulated agents
abstract type SimCoin end

struct SimToken <: SimCoin
    idx::Int64
    security::Security
end

struct SimConsumption <: SimCoin
    idx::Int64
end