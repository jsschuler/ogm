# let's write functions that generate the basic objects 

# generate a security object. It has only a random variable. It will be used to generate tokens.
function genSecurity(mod::Model,distribution::Distribution)
    newSec=Security(length(mod.securities)+1, distribution, 0)
    push!(mod.securities,newSec)
    return newSec
end
# this function generates a token for a security. It increments the token count for the security and returns a new token object.
function genToken(mod::Model, security::Security)
    security.tokenCount += 1
    tok=Token(security.tokenCount, security)
    return tok
end

# generate an agent object. It has no tokens or consumption at the beginning.

function genAgent(mod::Model)
    newAgent = Agent(length(mod.agents) + 1, nothing)
    push!(mod.agents, newAgent)
    return newAgent
end

function genConsumption()

end
# finally generate a model object. It has a key, a vector of securities, a vector of all tokens, and a vector of agents.

function modelGen(key::String, agentCount::Int64, distList::Array{Distribution},tokenCount::Array{Int64})
    mod=Model(key, Set{Security}(), Set{Tradeable}(),Agent[])
    for j in 1:length(distList)
        currSec=genSecurity(mod, distList[j])
        for i in 1:tokenCount[j]
            push!(mod.allTradeables,genToken(mod, currSec))
        end
    end
    for i in 1:agentCount
        genAgent(mod)
    end
    return mod
end 

# now, let's write functions that simulate the entire portfolio of securities for the whole model.
# the expected mean of mean of the portfolio in each time period times the number of tokens and divided by the number of agents 
# is the normalizaton factor we use for both consumption and the expected future consumption in each time period. 
# Recall that these are independent. 
# we also simulate the distribution of the portfolio over all future time periods times the number of tokens and divided by the number of agents.
# now we want two versions of this. In one version, the actual payout from a token in each period is the same  
# in the other, the payout of each token is an independent draw from the distribution of the portfolio.
# in the former case, the model can be interpreted as a representative agent model.

# calculate normalization factors 

function calcNormMu(mod::Model)
    muSum = 0.0
    for sec in mod.securities
        muSum += mean(sec.distribution) * sec.tokenCount
    end
    return muSum / length(mod.agents)
end

function calcNormPrecis(mod::Model)
    # now the agents are interested in the precision of their vector of future consumption. 
    # this is tractable analytically, so we can just calculate it.
    global periods

    # now we have period numbers of independent draws from the portfolio.
    # as these are independent, the variance is additive. 
    varianceVec=[]
    for sec in mod.securities
        push!(varianceVec,sec.tokenCount*periods*var(sec.distribution))
    end
    # again variances are addive so 
    totVar=sum(varianceVec)
    # this is the variance of the portfolio over all future time periods.
    # for further normalization, we multiply it by the number of tokens and divide by the number of agents.
    # but since we are interested in the precision, we take the inverse of the variance.

    return length(mod.agents)/ totVar 
  
end

# now we have normalization factors to calculate a utility function 
# now our goal is to calculate a demand function where the consumption unit is the numeraire.
# each token has a price in this numerarire. 

# we need a few helper functions first

function expectation(tok::Token)
    denom=tok.security.tokenCount
    mu=mean(tok.security)
    return mu/denom
end
# we need to generate utility functions
function utilGen(mod::Model,agt::Agent)




# we need the cloning functions

function clone(tok::Token)
    return SimToken(tok.idx,tok.security)
end

function clone(cons::Consumption)
    return SimConsumption(cons.idx)
end

function clone(tok::SimToken)
    return SimToken(tok.idx,tok.security)
end

function clone(cons::SimConsumption)
    return SimConsumption(cons.idx)
end

function clone(tokenSet::Set{Tradeable})
    return Set{Tradeable}(clone.(tokenSet))
end

function clone(tokenSet::Set{SimCoin})
    return Set{SimCoin}(clone.(tokenSet))
end

# now we need a function to remove k consumption tokens
function removeConsumption(k::Int64,tokenSet::Set{SimCoin})
    n=0
    deletionSet::Set{SimCoin}=Set{SimCoin}()
    for tok in tokenSet
        if typeof(tok)==Consumption && n < k
            push!(deletionSet,tok)
            n=n+1
        end
    end
    return setdiff(tokenSet,deletionSet)
end

function removeConsumption(k::Int64,tokenSet::Set{SimConsumption})
    n=0
    deletionSet::Set{SimCoin}=Set{SimCoin}()
    for tok in tokenSet
        if typeof(tok)==Consumption && n < k
            push!(deletionSet,tok)
            n=n+1
        end
    end
    return setdiff(tokenSet,deletionSet)
end

function removeConsumption(k::Int64,tokenSet::Set{SimToken})
    n=0
    deletionSet::Set{SimCoin}=Set{SimCoin}()
    for tok in tokenSet
        if typeof(tok)==Consumption && n < k
            push!(deletionSet,tok)
            n=n+1
        end
    end
    return setdiff(tokenSet,deletionSet)
end


function addToken(tokenSet::Set{SimCoin},security::Security)
    typeCnt::Int64=0
    for tok in filter(x-> x.tok==security,filter(y-> typeof(y)==Security,collect(tokenSet)))
        typeCnt=typCnt+1
    end
    
    push!(tokenSet,SimToken(typeCnt,security))
    return tokenSet
end

#function addToken(tokenSet::Set{SimConsumption},security::Security)
#    typeCnt::Int64=0
#    for tok in filter(x-> x.tok==security,collect(tokenSet))
#        typeCnt=typCnt+1
#    end
#    
#    push!(tokenSet,Token(typeCnt,security))
#    return tokenSet
#end

function addToken(tokenSet::Set{SimToken},security::Security)
    typeCnt::Int64=0
    for tok in filter(x-> x.tok==security,collect(tokenSet))
        typeCnt=typCnt+1
    end
    
    push!(tokenSet,Token(typeCnt,security))
    return tokenSet
end
# given a price vector, calculate demand for each security 
function demandFunc(mod::Model,agt::Agent,priceVec::Dict{Security,Int64})
    # this function calculates the demand for each security given a price vector.
    # we assume that the price vector is in terms of the numeraire.
    # we also assume that the utility function is concave in consumption and linear in future consumption.
    # we will use a monte carlo optimization to find the demand function.
    utilFunc = utilGen(mod)
    # now calculate the budget from the price vector
    budget::Int64=0
    for tok in agt.tokens
        if typeof(tok)==Consumption
            budget=budget + 1
        else
            budget=budget+priceVec[tok.security]
        end
    end
    # now, we move consumption to the highest marginal utility token step by step 
    # until utility stops rising
    tempTokenSet=Set{SimCoin}()
    for k in 1:budget
        push!(tempTokenSet,SimConsumption(k))
    end
    better=true
    while better
        # get  current utility
        currUtil=utilFunc(tempTokenSet)
        println("Current Utility")
        println(currUtil)
        # now, loop over the securities we could buy
        bestSecurity::Union{Security,Nothing}=nothing
        bestNewUtil=-Inf
        for sec in mod.securities
            # Can we afford one token?
            if budget >= priceVec[sec]
                currTokenSet=clone(tempTokenSet)
                currTokenSet=removeConsumption(priceVec[sec],currTokenSet)
                currTokenSet=addToken(currTokenSet,sec)
                # now, calculate the utility of the new token set
                newU=utilFunc(currTokenSet)
                println("New Util After ",string(params(sec.distribution)))
                println(newU)
                # now, we replace the best Security and the best new Util only if they are both
                # better than new U and better than the old
                if newU > currUtil 
                    println("Switching")
                    bestNewUtil=newU
                    bestSecurity=sec
                    println("Best Security")
                    println(bestSecurity)
                end
            end
        end
        # now, if the best utility trade is lower utility than the current, halt the loop
        if bestNewUtil < currUtil
            better=false
        end
        if better
            # now that we have the highest marginal utility security, actually change the agent's token set
            tempTokenSet=removeConsumption(priceVec[bestSecurity],tempTokenSet)
            tempTokenSet=addToken(tempTokenSet,bestSecurity)
            budget=budget-priceVec[bestSecurity]
        end
        # now if the budget is less than the price of any security, halt the loop
        allPrices=Int64[]
        println(priceVec)
        println(typeof(priceVec))
        for sec in keys(priceVec)
            println(sec)
            push!(allPrices,priceVec[sec])
        end
        if minimum(allPrices) > budget
            better=false
        end
    end
    # now return the demanded token set
    return tempTokenSet
end

# we need a reporting function
function report(x::SimConsumption)
    return typeof(x)
end

function report(x::SimToken)
    return (mean(x.security.distribution),var(x.security.distribution))
end

function report(x::Set)
    return(countmap(report.(collect(x))))
end