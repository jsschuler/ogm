################################################################################
#                 Geometric vs Arithmetic Mean                                 #
#                                                                              #
#                                                                              #
################################################################################
library(ggplot2)
# in R, gamma uses the shape, rate parameterization so lambda rather than theta

# set theta slope 
theta=2.0
mu <- seq(1,100,1)
sigmaSq <- theta*mu

alpha <- mu / theta

aMean <- c()
gMean <- c()
# now, let's calculate the ratio
for (i in 1:length(mu)){
  rgamma(1000000,alpha[i],1/theta) -> X
  c(aMean,mean(X)) -> aMean
  c(gMean,exp(mean(log(X)))) -> gMean
}

ggplot() + geom_line(aes(x=aMean,y=gMean))

ggplot() + geom_line(aes(x=mu,y=(gMean/aMean)),color="blue") + geom_line(aes(x=mu,y=sigmaSq/mu),color="red")
