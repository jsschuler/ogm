

mutable struct Security
    idx::Int64
    distribution::Distribution
    tokenCount::Int64
end

struct Token
    idx::Int64
    security::Security
end


struct Consumption
    idx::Int64
end

struct Agent
    idx::Int64
    tokens::Union{Set{Token},Nothing}
    consumption::Union{Set{Consumption},Nothing}
end

mutable struct Model
    key::String
    securities::Set{Security}
    allTokens::Set{Token}
    agents::Vector{Agent}
end