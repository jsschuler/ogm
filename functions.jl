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
    tok=token(security.tokenCount, security)
    return tok
end

# generate an agent object. It has no tokens or consumption at the beginning.

function genAgent(mod::Model)
    newAgent = agent(length(mod.agents) + 1, nothing, nothing)
    push!(mod.agents, newAgent)
    return newAgent
end

# finally generate a model object. It has a key, a vector of securities, a vector of all tokens, and a vector of agents.

function modelGen(key::String, agentCount::Int64, distList::Array{Distribution},tokenCount::Array{Int64})
    mod=Model(key, Security[], token[],agent[])
    for j in 1:length(distList)
        currSec=genSecurity(mod, distList[j])
        for i in 1:tokenCount[j]
            push!(mod.allTokens,genToken(mod, currSec))
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
    global independentDraws
    global periods
    if !independentDraws
        # now we have period numbers of independent draws from the portfolio.
        # as these are independent, the variance is additive. 
        varianceVec=[]
        for sec in mod.securities
            push!(varianceVec,periods*var(sec.distribution))
        end
        # again variances are addive so 
        totVar=sum(varianceVec)
        # this is the variance of the portfolio over all future time periods.
        # for further normalization, we multiply it by the number of tokens and divide by the number of agents.
        # but since we are interested in the precision, we take the inverse of the variance.
        return (length(mod.allTokens) * totVar) / length(mod.agents)
    else
        # if we have independent draws, we have to take into account that each agent draws independently.
        # This obviates the need to normalize by the number of agents.
        varianceVec=[]
        for sec in mod.securities
            push!(varianceVec,periods*length(mod.agtList)*var(sec.distribution))
        end
        totVar = sum(varianceVec)
        # now we need only normalize by the number of tokens.
        return length(mod.allTokens) / totVar
    end     
end

# now we have normalization factors to calculate a utility function 
# now our goal is to calculate a demand function where the consumption unit is the numeraire.
# each token has a price in this numerarire. 
# now, it is possible that there is not a unique maximum given each price vector.
# But, we can determine this if the monte carlo optimization stabilizes.
# given the use of Gamma distributions and the  fact that variance and expectation are linearly related, there should be a well-defined demand function.

function utilGen(mod::Model)
    # calculate the normalization factors
    norm1=calcNormMu(mod::Model)
    norm2=calcNormPrecis(mod::Model)

    function util(consumption::Float64, expectedConsumption::Float64, precision::Float64)
        # utility function is concave in consumption and linear in future consumption
        return log(consumption / norm1) + log(futureConsumption / norm1) + log(precision / norm2)
    end
    return util
end

# given a price vector, calculate demand for each security 
function demandFunc(mod::Model,porfolio::Set{Tokens},endowment::Set{consumption} ,priceVec::Vector{Float64})
    # this function calculates the demand for each security given a price vector.
    # we assume that the price vector is in terms of the numeraire.
    # we also assume that the utility function is concave in consumption and linear in future consumption.
    # we will use a monte carlo optimization to find the demand function.
    util = utilGen(mod)
    


end