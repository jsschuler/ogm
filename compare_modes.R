################################################################################
#  Mode Comparison: correlated vs independent draws
#  Compares equilibrium prices, portfolio composition, utility, convergence
################################################################################
library(ggplot2)
library(dplyr)
library(tidyr)

DEMAND_FILE <- "results/demand_20260530_214755.csv"
EQUIL_FILE  <- "results/equilibrium_20260530_214755.csv"
OUT_DIR     <- "results"

demand <- read.csv(DEMAND_FILE)
equil  <- read.csv(EQUIL_FILE)

cat("Demand rows:", nrow(demand), "| Equilibrium rows:", nrow(equil), "\n")
cat("Modes:", paste(unique(demand$mode), collapse=", "), "\n\n")

## ── 1. Convergence ────────────────────────────────────────────────────────────
conv_summary <- demand %>%
  group_by(mode) %>%
  summarise(
    seeds        = n_distinct(seed),
    conv_rate    = mean(converged),
    mean_tat     = mean(tat_iters),
    med_tat      = median(tat_iters),
    .groups = "drop"
  )
cat("=== Convergence by mode ===\n")
print(conv_summary)
cat("\n")

p_conv <- ggplot(demand %>% distinct(seed, mode, tat_iters, converged),
       aes(x=tat_iters, fill=mode)) +
  geom_histogram(bins=50, alpha=0.6, position="identity") +
  facet_wrap(~mode) +
  labs(title="Tatonnement iterations by mode", x="Iterations", y="Seeds") +
  theme_minimal()
ggsave(file.path(OUT_DIR, "conv_iterations.png"), p_conv, width=8, height=4)

## ── 2. Utility ────────────────────────────────────────────────────────────────
util_summary <- demand %>%
  group_by(mode) %>%
  summarise(
    mean_util = mean(utility),
    med_util  = median(utility),
    sd_util   = sd(utility),
    .groups = "drop"
  )
cat("=== Utility by mode ===\n")
print(util_summary)
cat("\n")

p_util <- ggplot(demand, aes(x=utility, fill=mode)) +
  geom_density(alpha=0.5) +
  labs(title="Utility distribution by mode", x="Utility", y="Density") +
  theme_minimal()
ggsave(file.path(OUT_DIR, "utility_dist.png"), p_util, width=7, height=4)

## ── 3. Portfolio composition ──────────────────────────────────────────────────
port_summary <- demand %>%
  group_by(mode) %>%
  summarise(
    mean_cons      = mean(cons_count),
    mean_sec       = mean(sec_count),
    mean_sec_types = mean(n_sec_types),
    .groups = "drop"
  )
cat("=== Portfolio composition by mode ===\n")
print(port_summary)
cat("\n")

p_sec_types <- ggplot(demand, aes(x=n_sec_types, fill=mode)) +
  geom_histogram(bins=21, alpha=0.6, position="identity") +
  facet_wrap(~mode) +
  labs(title="Security type diversity by mode", x="# distinct security types held", y="Agent-seeds") +
  theme_minimal()
ggsave(file.path(OUT_DIR, "sec_type_diversity.png"), p_sec_types, width=8, height=4)

## ── 4. Equilibrium prices ─────────────────────────────────────────────────────
price_summary <- equil %>%
  group_by(mode) %>%
  summarise(
    mean_price  = mean(equil_price),
    med_price   = median(equil_price),
    sd_price    = sd(equil_price),
    .groups = "drop"
  )
cat("=== Equilibrium prices by mode ===\n")
print(price_summary)
cat("\n")

# mean price per security index, by mode
price_by_sec <- equil %>%
  group_by(mode, sec_idx) %>%
  summarise(mean_price = mean(equil_price), .groups="drop")

p_price <- ggplot(price_by_sec, aes(x=sec_idx, y=mean_price, color=mode)) +
  geom_line() + geom_point(size=1) +
  labs(title="Mean equilibrium price by security index and mode",
       x="Security index", y="Mean equilibrium price") +
  theme_minimal()
ggsave(file.path(OUT_DIR, "equil_price_by_sec.png"), p_price, width=8, height=4)

p_price_dist <- ggplot(equil, aes(x=equil_price, fill=mode)) +
  geom_density(alpha=0.5) +
  labs(title="Equilibrium price distribution by mode", x="Price", y="Density") +
  theme_minimal()
ggsave(file.path(OUT_DIR, "equil_price_dist.png"), p_price_dist, width=7, height=4)

## ── 5. Excess demand at convergence ──────────────────────────────────────────
excess_summary <- equil %>%
  group_by(mode) %>%
  summarise(
    mean_excess    = mean(excess),
    mean_abs_excess = mean(abs(excess)),
    .groups = "drop"
  )
cat("=== Excess demand by mode ===\n")
print(excess_summary)
cat("\n")

## ── 6. Price vs security characteristics ─────────────────────────────────────
# Do higher-mean or higher-var securities command higher prices? Does mode change this?
sec_chars <- equil %>%
  group_by(mode, sec_idx) %>%
  summarise(
    mean_price  = mean(equil_price),
    mean_mean   = mean(sec_mean),
    mean_var    = mean(sec_var),
    .groups = "drop"
  )

p_pricevmean <- ggplot(sec_chars, aes(x=mean_mean, y=mean_price, color=mode)) +
  geom_point(alpha=0.6) +
  geom_smooth(method="lm", se=FALSE) +
  labs(title="Equilibrium price vs security mean payoff",
       x="Mean payoff", y="Mean equil price") +
  theme_minimal()
ggsave(file.path(OUT_DIR, "price_vs_mean.png"), p_pricevmean, width=7, height=4)

p_pricevcv <- ggplot(sec_chars, aes(x=mean_var/mean_mean, y=mean_price, color=mode)) +
  geom_point(alpha=0.6) +
  geom_smooth(method="lm", se=FALSE) +
  labs(title="Equilibrium price vs CV of security payoff",
       x="CV (variance/mean)", y="Mean equil price") +
  theme_minimal()
ggsave(file.path(OUT_DIR, "price_vs_cv.png"), p_pricevcv, width=7, height=4)

cat("Plots saved to", OUT_DIR, "\n")
cat("Done.\n")
