function genSecurity(mod::Model, distribution::Distribution, supply::Int64)
    newSec = Security(length(mod.securities) + 1, distribution)
    push!(mod.securities, newSec)
    mod.supply[newSec] = supply
    return newSec
end

function genAgent(mod::Model, cons::Int64)
    newAgent = Agent(length(mod.agents) + 1,
                     Portfolio(cons, Dict{Security,Int64}()),
                     Float64[])
    push!(mod.agents, newAgent)
    return newAgent
end

function modelGen(key::String, agentCount::Int64, distList::Array{Distribution},
                  secSupply::Array{Int64}, consEndow::Int64)
    mod = Model(key, Set{Security}(), Dict{Security,Int64}(), Agent[])
    for j in eachindex(distList)
        genSecurity(mod, distList[j], secSupply[j])
    end
    for _ in 1:agentCount
        genAgent(mod, consEndow)
    end
    return mod
end

# --- utility factory ---
#
# Utility = log(c) + E[log(W)] where W is the portfolio payoff in consumption tokens.
# E[log(W)] is approximated via the delta method:
#   E[log(W)] ≈ log(μ_W) − σ²_W / (2 · μ²_W)
#
# Two variance modes for σ²_W:
#   independentDraws=false (correlated): k tokens of the same security share
#     one draw, so σ²_W contribution = k² · Var
#   independentDraws=true  (independent): each token drawn separately,
#     so σ²_W contribution = k · Var

function utilGen(mod::Model, independentDraws::Bool=false)

    function finUtility(p::Portfolio)
        c = Float64(p.cons)
        (c <= 0.0 || isempty(p.securities)) && return -Inf

        mu_W = sum(Float64(k) * mean(sec.distribution)
                   for (sec, k) in p.securities; init=0.0)
        mu_W <= 0.0 && return -Inf

        var_W = if independentDraws
            sum(Float64(k) * var(sec.distribution)
                for (sec, k) in p.securities; init=0.0)
        else
            sum(Float64(k)^2 * var(sec.distribution)
                for (sec, k) in p.securities; init=0.0)
        end

        e_log_W = log(mu_W) - var_W / (2.0 * mu_W^2)
        return log(c) + e_log_W
    end

    return finUtility
end

# --- demand via greedy marginal-utility optimisation ---

function demandFunc(mod::Model, agt::Agent, priceVec::Dict{Security,Int64},
                    independentDraws::Bool=false)
    utilFunc = utilGen(mod, independentDraws)

    # liquidate all holdings into a consumption budget
    budget = agt.portfolio.cons +
             sum(k * priceVec[sec] for (sec, k) in agt.portfolio.securities; init=0)

    # start fully in consumption; greedily swap to highest-MU security token
    holdings = Dict{Security,Int64}()
    cons = budget

    better = true
    while better
        currUtil = utilFunc(Portfolio(cons, holdings))
        bestSec  = nothing
        bestUtil = -Inf

        for sec in mod.securities
            cons < priceVec[sec] && continue
            # temporarily add one token of sec to evaluate marginal utility
            old_k = get(holdings, sec, 0)
            holdings[sec] = old_k + 1
            newU = utilFunc(Portfolio(cons - priceVec[sec], holdings))
            if newU > bestUtil
                bestUtil = newU
                bestSec  = sec
            end
            # restore
            if old_k == 0
                delete!(holdings, sec)
            else
                holdings[sec] = old_k
            end
        end

        if bestSec === nothing || bestUtil <= currUtil
            better = false
        else
            cons -= priceVec[bestSec]
            holdings[bestSec] = get(holdings, bestSec, 0) + 1
        end
    end

    return Portfolio(cons, holdings)
end
