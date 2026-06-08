function genSecurity(mod::Model, distribution::Distribution)
    newSec = Security(length(mod.securities)+1, distribution, 0)
    push!(mod.securities, newSec)
    return newSec
end

function genToken(mod::Model, security::Security)
    security.tokenCount += 1
    tok = Token(security.tokenCount, security)
    return tok
end

# alpha initialised to empty; utility weights are not yet used
function genAgent(mod::Model)
    newAgent = Agent(length(mod.agents) + 1, nothing, Float64[])
    push!(mod.agents, newAgent)
    return newAgent
end

function modelGen(key::String, agentCount::Int64, distList::Array{Distribution}, tokenCount::Array{Int64})
    mod = Model(key, Set{Security}(), Set{Tradeable}(), Agent[])
    for j in 1:length(distList)
        currSec = genSecurity(mod, distList[j])
        for i in 1:tokenCount[j]
            push!(mod.allTradeables, genToken(mod, currSec))
        end
    end
    for i in 1:agentCount
        genAgent(mod)
    end
    return mod
end

# total expected payoff if one held every token of every security
function calcNormMu(mod::Model)
    total = 0.0
    for sec in mod.securities
        total += mean(sec.distribution)
    end
    return total
end

# precision of a portfolio that holds exactly one token of every security (independent draws)
function calcNormPrecis(mod::Model)
    totalVar = 0.0
    for sec in mod.securities
        totalVar += var(sec.distribution) / sec.tokenCount
    end
    totalVar == 0.0 && return Inf
    return 1.0 / totalVar
end

# --- cloning (Tradeable -> SimCoin for simulation) ---

function clone(tok::Token)
    return SimToken(tok.idx, tok.security)
end

function clone(cons::Consumption)
    return SimConsumption(cons.idx)
end

function clone(tok::SimToken)
    return SimToken(tok.idx, tok.security)
end

function clone(cons::SimConsumption)
    return SimConsumption(cons.idx)
end

function clone(tokenSet::Set{Tradeable})
    return Set{SimCoin}(clone.(collect(tokenSet)))
end

function clone(tokenSet::Set{SimCoin})
    return Set{SimCoin}(clone.(collect(tokenSet)))
end

# --- token-set mutation helpers ---

function removeConsumption(k::Int64, tokenSet::Set{SimCoin})
    n = 0
    toDelete = Set{SimCoin}()
    for tok in tokenSet
        if typeof(tok) == SimConsumption && n < k
            push!(toDelete, tok)
            n += 1
        end
    end
    return setdiff(tokenSet, toDelete)
end

function addToken(tokenSet::Set{SimCoin}, security::Security)
    typeCnt = count(tok -> typeof(tok) == SimToken && tok.security === security, collect(tokenSet))
    push!(tokenSet, SimToken(typeCnt + 1, security))
    return tokenSet
end

# --- utility factory ---
#
# Two modes differ in how portfolio variance is computed:
#   independentDraws=false (correlated): tokens of the same security share one draw,
#     so holding k of n tokens scales variance as (k/n)^2 * Var
#   independentDraws=true (independent): each token is drawn separately,
#     so holding k tokens scales variance as k * (1/n)^2 * Var = k/n^2 * Var

function utilGen(mod::Model, independentDraws::Bool=false)
    norm1 = calcNormMu(mod)
    norm2 = calcNormPrecis(mod)

    function tokenConsumption(tokenSet::Set{SimCoin})
        Float64(count(tok -> typeof(tok) == SimConsumption, collect(tokenSet)))
    end

    function tokenExpectation(tokenSet::Set{SimCoin})
        mu = 0.0
        for tok in tokenSet
            if typeof(tok) == SimToken
                mu += mean(tok.security.distribution) / tok.security.tokenCount
            end
        end
        return mu
    end

    function tokenPrecision(tokenSet::Set{SimCoin})
        variance = 0.0
        if independentDraws
            for tok in tokenSet
                if typeof(tok) == SimToken
                    n = tok.security.tokenCount
                    variance += var(tok.security.distribution) / (n * n)
                end
            end
        else
            # group by security, then apply correlated-draw formula
            secCounts = Dict{Int64, Tuple{Security,Int64}}()
            for tok in tokenSet
                if typeof(tok) == SimToken
                    idx = tok.security.idx
                    if haskey(secCounts, idx)
                        sec, cnt = secCounts[idx]
                        secCounts[idx] = (sec, cnt + 1)
                    else
                        secCounts[idx] = (tok.security, 1)
                    end
                end
            end
            for (_, (sec, k)) in secCounts
                fraction = k / sec.tokenCount
                variance += fraction * fraction * var(sec.distribution)
            end
        end
        variance <= 0.0 && return -Inf
        return 1.0 / variance
    end

    function finUtility(tokenSet::Set{SimCoin})
        c = tokenConsumption(tokenSet)
        e = tokenExpectation(tokenSet)
        p = tokenPrecision(tokenSet)
        (c <= 0.0 || e <= 0.0 || p <= 0.0) && return -Inf
        return log(c / norm1) + log(e / norm1) + log(p / norm2)
    end

    return finUtility
end

# --- demand via greedy marginal-utility optimisation ---

function demandFunc(mod::Model, agt::Agent, priceVec::Dict{Security,Int64}, independentDraws::Bool=false)
    utilFunc = utilGen(mod, independentDraws)

    # liquidate current holdings into numeraire budget
    budget = 0
    for tok in agt.tokens
        if typeof(tok) == Consumption
            budget += 1
        else
            budget += priceVec[tok.security]
        end
    end

    # start fully in consumption; greedily swap to highest-MU security token
    tempSet = Set{SimCoin}(SimConsumption(k) for k in 1:budget)
    allPrices = [priceVec[sec] for sec in mod.securities]

    better = true
    while better && minimum(allPrices) <= budget
        currUtil = utilFunc(tempSet)
        bestSec  = nothing
        bestUtil = -Inf

        for sec in mod.securities
            budget < priceVec[sec] && continue
            candidate = removeConsumption(priceVec[sec], clone(tempSet))
            candidate = addToken(candidate, sec)
            newU = utilFunc(candidate)
            if newU > bestUtil
                bestUtil = newU
                bestSec  = sec
            end
        end

        if bestSec === nothing || bestUtil <= currUtil
            better = false
        else
            tempSet = removeConsumption(priceVec[bestSec], tempSet)
            tempSet = addToken(tempSet, bestSec)
            budget -= priceVec[bestSec]
        end
    end

    return tempSet
end

# --- reporting ---

function report(x::SimConsumption)
    return :consumption
end

function report(x::SimToken)
    return (mean=mean(x.security.distribution), var=var(x.security.distribution))
end

function report(x::Set)
    return countmap(report.(collect(x)))
end
