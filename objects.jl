

mutable struct Security
    idx::Int64
    distribution::Distributions
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
    tokens::Vector{token}
    consumption::Int64
end

mutable struct Model
    key::String

end