###############################################################################################################################
#                      Overlapping Generations Model                                                                          #
#                      John S. Schuler                                                                                        #
#                      May 2025                                                                                               #
#                                                                                                                             #
#  Runs in two modes and writes results to results/demand_<timestamp>.csv                                                     #
#                                                                                                                             #
#  Mode "correlated"  (independentDraws=false):                                                                               #
#    k tokens of a security share one payoff draw; portfolio variance ∝ k²/n²                                                #
#  Mode "independent" (independentDraws=true):                                                                                #
#    each token is drawn independently; portfolio variance ∝ k/n²                                                            #
#                                                                                                                             #
#  For each (seed, mode) pair the code runs a Walrasian tâtonnement to find                                                  #
#  equilibrium prices at which aggregate security demand equals supply.                                                       #
#  Equilibrium prices and allocations are recorded.                                                                           #
###############################################################################################################################

using Distributions
using Random
using StatsBase
using CSV
using DataFrames
using Dates

include("objects.jl")
include("functions.jl")
import Distributions: sample

# ── model hyper-parameters ─────────────────────────────────────────────────────
const MIN_MU         = 1.0
const MAX_MU         = 10.0
const THETA_SLOPE    = 1.0
const N_SECURITIES   = 20
const TOKENS_EACH    = 15
const AGENT_COUNT    = 20
const N_SEEDS        = 30000  # independent parameter draws
const MAX_PRICE_INIT = 10     # initial prices drawn from Uniform(1, MAX_PRICE_INIT)

# tâtonnement settings
const TAT_LAMBDA     = 0.05   # step size for price adjustment
const TAT_MAX_ITER   = 200    # max iterations per equilibrium search
const TAT_TOL        = 0.05   # convergence: max |excess_demand| / supply

# ── results directory ──────────────────────────────────────────────────────────
mkpath("results")
timestamp   = Dates.format(now(), "yyyymmdd_HHMMSS")
demand_path = joinpath("results", "demand_$(timestamp).csv")
equil_path  = joinpath("results", "equilibrium_$(timestamp).csv")

demand_rows = DataFrame(
    seed          = Int[],
    mode          = String[],
    agent_idx     = Int[],
    cons_count    = Int[],
    sec_count     = Int[],
    n_sec_types   = Int[],
    utility       = Float64[],
    tat_iters     = Int[],
    converged     = Bool[],
)

equil_rows = DataFrame(
    seed          = Int[],
    mode          = String[],
    sec_idx       = Int[],
    sec_mean      = Float64[],
    sec_var       = Float64[],
    equil_price   = Float64[],
    total_demand  = Int[],
    supply        = Int[],
    excess        = Int[],
    tat_iters     = Int[],
    converged     = Bool[],
)

# ── helpers ────────────────────────────────────────────────────────────────────

# Count how many SimToken of each security are in a demanded set
function sec_demand(demanded::Set{SimCoin})
    counts = Dict{Int64, Int64}()
    for tok in demanded
        typeof(tok) == SimToken || continue
        idx = tok.security.idx
        counts[idx] = get(counts, idx, 0) + 1
    end
    return counts
end

# Find equilibrium prices via Walrasian tâtonnement.
# Returns (prices::Dict, n_iters::Int, converged::Bool)
function tatonnement(mod::Model, init_prices::Dict{Security,Float64}, independentDraws::Bool)
    prices = copy(init_prices)
    supply = Dict{Security,Int64}(sec => sec.tokenCount for sec in mod.securities)
    n_iters = 0
    converged = false

    for iter in 1:TAT_MAX_ITER
        n_iters = iter

        # compute integer prices for demandFunc (floor, minimum 1)
        int_prices = Dict{Security,Int64}(sec => max(1, floor(Int64, prices[sec]))
                                          for sec in mod.securities)

        # aggregate demand across all agents
        total_demand = Dict{Int64,Int64}()   # sec.idx => token count demanded
        for agt in mod.agents
            demanded = demandFunc(mod, agt, int_prices, independentDraws)
            for (idx, cnt) in sec_demand(demanded)
                total_demand[idx] = get(total_demand, idx, 0) + cnt
            end
        end

        # compute excess demand and check convergence
        max_rel_excess = 0.0
        for sec in mod.securities
            d  = get(total_demand, sec.idx, 0)
            s  = supply[sec]
            rel = abs(d - s) / max(s, 1)
            max_rel_excess = max(max_rel_excess, rel)
        end

        if max_rel_excess <= TAT_TOL
            converged = true
            break
        end

        # price adjustment: raise price for over-demanded, lower for under-demanded
        for sec in mod.securities
            d = get(total_demand, sec.idx, 0)
            s = supply[sec]
            prices[sec] = max(0.5, prices[sec] * exp(TAT_LAMBDA * (d - s) / max(s, 1)))
        end
    end

    # final integer prices
    final_prices = Dict{Security,Int64}(sec => max(1, floor(Int64, prices[sec]))
                                        for sec in mod.securities)
    return final_prices, prices, n_iters, converged
end

# ── main sweep ─────────────────────────────────────────────────────────────────
t0 = time()

for seed in 1:N_SEEDS
    Random.seed!(seed)

    mu_vec    = rand(Uniform(MIN_MU, MAX_MU), N_SECURITIES)
    dist_list = Distribution[Gamma(mu_vec[i], THETA_SLOPE * mu_vec[i]) for i in 1:N_SECURITIES]

    mod = modelGen("seed_$(seed)", AGENT_COUNT, dist_list, fill(TOKENS_EACH, N_SECURITIES))

    # distribute tokens round-robin across agents
    token_list = shuffle(collect(mod.allTradeables))
    for (i, agt) in enumerate(mod.agents)
        agt.tokens = Set{Tradeable}(token_list[i:AGENT_COUNT:end])
    end

    # initial prices: same starting point for both modes
    Random.seed!(seed * 100_000)
    init_prices_f = Dict{Security,Float64}(
        sec => Float64(rand(1:MAX_PRICE_INIT)) for sec in mod.securities)

    for mode_flag in (false, true)
        mode_str = mode_flag ? "independent" : "correlated"

        int_prices, cont_prices, tat_iters, converged =
            tatonnement(mod, init_prices_f, mode_flag)

        util_func = utilGen(mod, mode_flag)

        # record per-security equilibrium stats
        final_demand = Dict{Int64,Int64}()
        for agt in mod.agents
            demanded = demandFunc(mod, agt, int_prices, mode_flag)
            for (idx, cnt) in sec_demand(demanded)
                final_demand[idx] = get(final_demand, idx, 0) + cnt
            end
        end
        for sec in mod.securities
            push!(equil_rows, (
                seed, mode_str, sec.idx,
                mean(sec.distribution), var(sec.distribution),
                cont_prices[sec],
                get(final_demand, sec.idx, 0), TOKENS_EACH,
                get(final_demand, sec.idx, 0) - TOKENS_EACH,
                tat_iters, converged,
            ))
        end

        # record per-agent demand
        for agt in mod.agents
            demanded = demandFunc(mod, agt, int_prices, mode_flag)
            cons   = count(tok -> typeof(tok) == SimConsumption, collect(demanded))
            secs   = count(tok -> typeof(tok) == SimToken,        collect(demanded))
            types  = length(unique(tok.security.idx
                                   for tok in demanded if typeof(tok) == SimToken))
            util   = util_func(demanded)
            push!(demand_rows, (seed, mode_str, agt.idx,
                                cons, secs, types, util, tat_iters, converged))
        end
    end

    if seed % 100 == 0
        elapsed = round(time() - t0; digits=1)
        remain  = round((time()-t0)/seed * (N_SEEDS-seed); digits=0)
        println("seed $(seed)/$(N_SEEDS) — $(elapsed)s elapsed, ~$(remain)s remaining")
        flush(stdout)
        CSV.write(demand_path, demand_rows)
        CSV.write(equil_path,  equil_rows)
    end
end

CSV.write(demand_path, demand_rows)
CSV.write(equil_path,  equil_rows)
total = round(time()-t0; digits=1)
println("\nDone. demand: $(nrow(demand_rows)) rows, equilibrium: $(nrow(equil_rows)) rows, $(total)s")
