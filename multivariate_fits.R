### Calibrations

load("~/Desktop/fits.Rdata"); ls(); dim(Fits)

colnames(newFits) <- colnames(Fits) <- colnames(Y)
color <- apply(Y,1,which.max)

i <- sample(1:nrow(Y),10000)

plot(Fits[i,'in'] ~ Fits[i,'for'],col=color[i])

plot(newFits[i,'with'] ~ newFits[i,'of'],col=color[i])

pairs(Fits[i,],col=color[i])

cor(Fits[,'with'],newFits[,'of']) # negative, by construction
sum(Fits[,'with']*newFits[,'of'])/nrow(Fits)

prep <- 'in'   # of in for to on with

plot(newFits[i,prep] ~ Fits[i,prep])
abline(a=0,b=1,col='gray')

par(mfrow=c(1,2))

	plot(Y[i,prep] ~ Fits[i, prep])
	ss <- smooth.spline(Fits[,prep],Y[,prep], df=7)
	lines(ss,col='red'); 
	abline(a=0,b=1,col='gray',lty=1)

	plot(Y[i,prep] ~ newFits[i, prep])
	ss <- smooth.spline(Fits[, prep],Y[, prep], df=7)
	lines(ss,col='red'); 
	abline(a=0,b=1,col='gray',lty=1)
	
reset()
