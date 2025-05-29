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
    # variances are additive but scalars require squaring
    sigmaSum = 0.0
    for sec in mod.securities
        sigmaSum += var(sec.distribution) * (sec.tokenCount)^2
    end
    # return reciprocal as this is the precision  
    return (length(mod.agents)^2) / sigmaSum  
end