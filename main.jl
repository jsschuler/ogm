###############################################################################################################################
#                      Overlapping Generations Model                                                                          #
#                      John S. Schuler                                                                                        #
#                      May 2025                                                                                               #
#                                                                                                                             #
#  Runs in two modes and writes results to results/demand_<timestamp>.csv                                                     #
#                                                                                                                             #
#  Mode "correlated"  (independentDraws=false):                                                                               #
#    k tokens of a security share one payoff draw; portfolio variance ∝ k²                                                   #
#  Mode "independent" (independentDraws=true):                                                                                #
#    each token is drawn independently; portfolio variance ∝ k                                                                #
#                                                                                                                             #
#  For each (seed, mode) pair the code runs a Walrasian tâtonnement to find                                                  #
#  equilibrium prices at which aggregate security demand equals supply.                                                       #
#  Prices are integer throughout; floor price = 1 consumption token.                                                         #
#  Equilibrium prices and allocations are recorded.                                                                           #
###############################################################################################################################

using Distributions
using Random
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
const SEC_SUPPLY     = 20      # tokens of each security available
const AGENT_COUNT    = 20
const CONS_ENDOW     = 200     # consumption tokens each agent starts with
const N_SEEDS        = 10

# tâtonnement settings (integer prices throughout)
const TAT_LAMBDA     = 0.10   # fractional step size for price adjustment
const TAT_MAX_ITER   = 500    # max iterations per equilibrium search
const TAT_TOL        = 0.05   # convergence: max |excess| / supply per security

# ── results directory ──────────────────────────────────────────────────────────
mkpath("results")
timestamp   = Dates.format(now(), "yyyymmdd_HHMMSS")
demand_path = joinpath("results", "demand_$(timestamp).csv")
equil_path  = joinpath("results", "equilibrium_$(timestamp).csv")

demand_rows = DataFrame(
    seed          = Int[],
    mode          = String[],
    agent_idx     = Int[],
    cons          = Int[],
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
    equil_price   = Int[],
    total_demand  = Int[],
    supply        = Int[],
    excess        = Int[],
    tat_iters     = Int[],
    converged     = Bool[],
    max_rel_excess = Float64[],
)

# ── tâtonnement ────────────────────────────────────────────────────────────────
# Integer-native: prices are always Int64, floor = 1.
# Corner solution (price == 1, excess <= 0) counts as converged for that security.
# Float prices are used internally for smooth gradient steps; demandFunc always
# receives rounded integer prices.  Reported equilibrium prices are integers.
# Corner solution: price==1 with excess supply is valid (security trades at floor).
function tatonnement(mod::Model, init_prices::Dict{Security,Int64}, independentDraws::Bool)
    float_prices = Dict{Security,Float64}(sec => Float64(p) for (sec, p) in init_prices)
    n_iters   = 0
    converged = false

    for iter in 1:TAT_MAX_ITER
        n_iters = iter

        int_prices = Dict{Security,Int64}(sec => max(1, round(Int, p))
                                          for (sec, p) in float_prices)

        # aggregate demand across all agents
        total_demand = Dict{Security,Int64}()
        for agt in mod.agents
            demanded = demandFunc(mod, agt, int_prices, independentDraws)
            for (sec, k) in demanded.securities
                total_demand[sec] = get(total_demand, sec, 0) + k
            end
        end

        # check convergence
        all_cleared = true
        for sec in mod.securities
            d  = get(total_demand, sec, 0)
            s  = mod.supply[sec]
            ip = int_prices[sec]
            rel_excess = abs(d - s) / max(s, 1)
            corner_ok  = ip == 1 && d <= s
            market_ok  = rel_excess <= TAT_TOL
            if !market_ok && !corner_ok
                all_cleared = false
            end
        end

        if all_cleared
            converged = true
            break
        end

        # smooth float price update; clamp normalised excess to [-1,1] so prices
        # move by at most exp(±TAT_LAMBDA) per step, preventing overflow
        for sec in mod.securities
            d = get(total_demand, sec, 0)
            s = mod.supply[sec]
            norm_excess = clamp(Float64(d - s) / max(s, 1), -1.0, 1.0)
            float_prices[sec] = max(0.5, float_prices[sec] * exp(TAT_LAMBDA * norm_excess))
        end
    end

    final_prices = Dict{Security,Int64}(sec => max(1, round(Int, p))
                                        for (sec, p) in float_prices)
    # compute max relative excess at final prices for diagnostics
    final_demand = Dict{Security,Int64}()
    for agt in mod.agents
        for (sec, k) in demandFunc(mod, agt, final_prices, independentDraws).securities
            final_demand[sec] = get(final_demand, sec, 0) + k
        end
    end
    max_rel = maximum(
        let d = get(final_demand, sec, 0), s = mod.supply[sec], ip = final_prices[sec]
            (ip == 1 && d <= s) ? 0.0 : abs(d - s) / max(s, 1)
        end
        for sec in mod.securities)
    return final_prices, final_demand, n_iters, converged, max_rel
end

# ── main sweep ─────────────────────────────────────────────────────────────────
t0 = time()

for seed in 1:N_SEEDS
    Random.seed!(seed)

    mu_vec    = rand(Uniform(MIN_MU, MAX_MU), N_SECURITIES)
    dist_list = Distribution[Gamma(mu_vec[i] / THETA_SLOPE, THETA_SLOPE) for i in 1:N_SECURITIES]

    mod = modelGen("seed_$(seed)", AGENT_COUNT, dist_list,
                   fill(SEC_SUPPLY, N_SECURITIES), CONS_ENDOW)

    # initial prices drawn from Uniform(1, 10), integer
    Random.seed!(seed * 100_000)
    init_prices = Dict{Security,Int64}(sec => rand(1:10) for sec in mod.securities)

    for mode_flag in (false, true)
        mode_str = mode_flag ? "independent" : "correlated"

        prices, total_demand, tat_iters, converged, max_rel =
            tatonnement(mod, init_prices, mode_flag)

        util_func = utilGen(mod, mode_flag)

        # agent portfolios at equilibrium prices (demand already computed inside tatonnement)
        agent_portfolios = Vector{Portfolio}(undef, length(mod.agents))
        for (i, agt) in enumerate(mod.agents)
            agent_portfolios[i] = demandFunc(mod, agt, prices, mode_flag)
        end

        for sec in mod.securities
            d = get(total_demand, sec, 0)
            push!(equil_rows, (
                seed, mode_str, sec.idx,
                mean(sec.distribution), var(sec.distribution),
                prices[sec],
                d, mod.supply[sec], d - mod.supply[sec],
                tat_iters, converged, max_rel,
            ))
        end

        for (i, agt) in enumerate(mod.agents)
            p    = agent_portfolios[i]
            secs = sum(values(p.securities); init=0)
            util = util_func(p)
            push!(demand_rows, (
                seed, mode_str, agt.idx,
                p.cons, secs, length(p.securities), util, tat_iters, converged,
            ))
        end
    end

    if seed % 100 == 0
        elapsed = round(time() - t0; digits=1)
        remain  = round((time() - t0) / seed * (N_SEEDS - seed); digits=0)
        println("seed $(seed)/$(N_SEEDS) — $(elapsed)s elapsed, ~$(remain)s remaining")
        flush(stdout)
        CSV.write(demand_path, demand_rows)
        CSV.write(equil_path,  equil_rows)
    end
end

CSV.write(demand_path, demand_rows)
CSV.write(equil_path,  equil_rows)
total = round(time() - t0; digits=1)
println("\nDone. demand: $(nrow(demand_rows)) rows, equilibrium: $(nrow(equil_rows)) rows, $(total)s")
