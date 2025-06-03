function utilGen(mod::Model)
    # calculate the normalization factors
    norm1=calcNormMu(mod::Model)
    norm2=calcNormPrecis(mod::Model)

    function util(consumption::Float64, expectedConsumption::Float64, precision::Float64)
        # utility function is concave in consumption and linear in future consumption
        return log((1+consumption) / norm1) + log((1+expectedConsumption) / norm1) + log(precision / norm2)
    end
    function tokenConsumption(tokenSet::Set{Tradeable})
        consCount::Int64=0
        for tok in tokenSet
            if typeof(tok)==Consumption
                consCount=consCount+1
            end
        end
        return conCount
    end
    function tokenExpectation(tokenSet::Set{Tradeable})
        mu::Float64=0.0
        for tok in tokenSet
            if typeof(tok) != Consumption
                mu=mu+mean(tok.security)
            end
        end
        return mu
    end
    function tokenPrecision(tokenSet::Set{Tradeable})
        variance::Float64=0.0
        for tok in tokenSet
            if typeof(tok) != Consumption
                variance=variance+var(tok)
            end
        end
        if variance ==0.0
            return -Inf
        else
            return 1/variance
        end
    end

    function utility(tokenSet::Set{Tradeable})
        return util(tokenConsumption(tokenSet),
                    tokenExpectation(tokenSet),
                    tokenPrecision(tokenSet))

    end
    # Now we need the simulation versions
    function tokenConsumption(tokenSet::Set{SimCoin})
        consCount::Int64=0
        for tok in tokenSet
            if typeof(tok)==SimConsumption
                consCount=consCount+1
            end
        end
        return consCount
    end
    function tokenExpectation(tokenSet::Set{SimCoin})
        mu::Float64=0.0
        for tok in tokenSet
            if typeof(tok) != SimConsumption
                mu=mu+mean(tok.security.distribution)
            end
        end
        return mu
    end
    function tokenPrecision(tokenSet::Set{SimCoin})
        variance::Float64=0.0
        for tok in tokenSet
            if typeof(tok) != SimConsumption
                variance=variance+var(tok.security.distribution)
            end
        end
        if variance ==0.0
            return -Inf
        else
            return 1/variance
        end
    end

    function finUtility(tokenSet::Set{SimCoin})
        println("Utility Components")
        println(tokenConsumption(tokenSet))
        println(tokenExpectation(tokenSet))
        println(tokenPrecision(tokenSet))
        cons=tokenConsumption(tokenSet)
        exp=tokenExpectation(tokenSet)
        precis=tokenPrecision(tokenSet)

        if cons <= 0.0
            return -Inf
        elseif exp <= 0.0
            return -Inf
        elseif precis <= 0.0
            return -Inf
        else return util(tokenConsumption(tokenSet)/norm1,
                    tokenExpectation(tokenSet)/norm1,
                    tokenPrecision(tokenSet)/norm2)
        end
    end
    
end
