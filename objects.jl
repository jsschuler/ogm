

mutable struct Security
    idx::Int64
    distribution::Distribution
    tokenCount::Int64
end

abstract type Tradeable end

struct Token <: Tradeable
    idx::Int64
    security::Security
end

struct Consumption <: Tradeable
    idx::Int64
end

mutable struct Agent
    idx::Int64
    tokens::Union{Set{Tradeable},Nothing}
end

mutable struct Model
    key::String
    securities::Set{Security}
    allTradeables::Set{Tradeable}
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