###############################################################################################################################
#                      Overlapping Generations Model                                                                          #
#                      John S. Schuler                                                                                        #
#                      May 2025                                                                                               #
#                                                                                                                             #
###############################################################################################################################

using Distributions 
using Random
using StatsBase
# now, this is an overlapping generations model
# agents live for 50 periods
# there are three arguments to the agent's utility function:
# 1. consumption in the current period
# 2. expected future consumption 
# 3. precision of future consumption

include("objects.jl")
include("functions.jl")
import Distributions: sample
# generate a model with five agents 
# set theta paramter as slope for relationship between mean and variance of the gamma distributions
# steeper theta means we get greater variance to get higher mean 
# for simplicity, let theta slope be 1.0
minMu=1.0
maxMu=10.0
thetaSlope=1.0
initSecurities=5
agentCount=5
periods=50
independentDraws=false
Random.seed!(12345)
muVec=rand(Uniform(minMu, maxMu),5)
sigmaVec=thetaSlope .* muVec
distList=Distribution[]
for i in 1:length(muVec)
    push!(distList, Gamma(muVec[i], sigmaVec[i]))
end

tstMod=modelGen("test", 5, distList,[10, 10, 10, 10, 10])

# now test the normalization factors
normMu=calcNormMu(tstMod)
println("Normalization factor for mean: ", normMu)
normPrecis=calcNormPrecis(tstMod)
println("Normalization factor for precision: ", normPrecis)

# now, let's test a utility 
utilFunc=utilGen(tstMod)
# now, set an endowment. We can use the expected value of the portfolio per agent  
# which is actually the normalization factor for the mean.
endowment=normMu
# divide the endowments randomly and evenly among agents
agt=tstMod.agents[1]
agt.tokens=Set(sample(collect(tstMod.allTradeables),floor(Int64,length(tstMod.allTradeables)/agentCount),replace=false))

println(agt.tokens)
priceDict::Dict{Security,Int64}=Dict{Security,Int64}()
for sec in tstMod.securities
    priceDict[sec]=sample(collect(1:500),1)[1]
end
println(priceDict)
demanded=demandFunc(tstMod,agt,priceDict)
println(report(demanded))