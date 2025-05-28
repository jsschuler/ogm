###############################################################################################################################
#                      Overlapping Generations Model                                                                          #
#                      John S. Schuler                                                                                        #
#                      May 2025                                                                                               #
#                                                                                                                             #
###############################################################################################################################

using Distributions 


# now, this is an overlapping generations model
# agents live for 50 periods
# there are three arguments to the agent's utility function:
# 1. consumption in the current period
# 2. expected future consumption 
# 3. precision of future consumption