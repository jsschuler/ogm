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

# now, we will explore the statistical properties of the geometric mean of the geometric mean over the arithmetic mean. 
simulate <- function(n,theta,alpha,k,b){
  # n is number of periods
  # k is the number of simulations
  # theta is the Gamma scale parameter and the slope relating mu and sigma squared
  # alpha is, of course, the Gamma shape parameter
  # step 1: draw from Gamma
  matrix(rgamma(n*k,shape=alpha,scale=theta),nrow=n) -> simulationMat
  # now, get the arithmetic mean for each row
  AM <- apply(simulationMat,1,mean)
  geomMean <- function(x){return(exp(mean(log(x))))}
  GM <- apply(simulationMat,1,geomMean) 
  all(GM < AM)
  # now calculate the ratio
  GM/AM -> ratio
  # and caculate the geometric mean of this ratio
  geomMean(ratio) -> dispersion
  return(dispersion)
}
# now, see how this relates to alpha


# now play with theta to check invariance

bondGen <- function(b){
  alphaVec <- seq(0,10,.05)
  disperVec <- c()
  for (alpha in alphaVec){
    disperVec <- c(disperVec,simulate(100,1.0,alpha,10000,b))
    
  }
  
  ggplot() + geom_line(aes(x=alphaVec,y=disperVec),color="red") -> plt  
  return(plt)
}
bondGen(2) -> plt1

# it checks out. The slope does not affect this measure of dispersion

# now, let's see how the number of periods affects it

periodFunc <- function(theta,n){
  alphaVec <- seq(0.05,10,.05)
  disperVec <- c()
  for (alpha in alphaVec){
    disperVec <- c(disperVec,simulate(n,theta,alpha,10000))
    
  }
  
  return(disperVec)
  
}
alphaVec <- seq(0.05,10,.05)
ggplot() + geom_line(aes(x=alphaVec,y=periodFunc(1.0,100)),color="red") +
  geom_line(aes(x=alphaVec,y=periodFunc(1.0,2)),color="blue")

