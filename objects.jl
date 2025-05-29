

mutable struct Security
    idx::Int64
    distribution::Distribution
    tokenCount::Int64
end

struct token
    idx::Int64
    security::Security
end


struct consumption
    idx::Int64
end

struct agent
    idx::Int64
    tokens::Union{Vector{token},Nothing}
    consumption::Union{Vector{consumption},Nothing}
end

mutable struct Model
    key::String
    securities::Vector{Security}
    allTokens::Vector{token}
    agents::Vector{agent}
end