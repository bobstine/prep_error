### Calibrations

load("~/C/projects/prep_error/fits.Rdata"); ls(); dim(Fits)
prepositions <- colnames(newFits) <- colnames(Fits) <- colnames(Y)

## --- color codes for plots
color <- apply(Y,1,which.max)

## --- select a subset for plots
iPlot <- sample(1:nrow(Y),10000)


## --- plots

plot(Fits[iPlot,'in'] ~ Fits[iPlot,'for'],col=color[iPlot])

plot(newFits[iPlot,'with'] ~ newFits[iPlot,'of'],col=color[iPlot])

pairs(Fits[iPlot,],col=color[iPlot])

## --- correlation, dot product
cor(Fits[,'with'],newFits[,'of']) # negative, by construction
sum(Fits[,'with']*newFits[,'of'])/nrow(Fits)


## --- calibration (looks just as calibrated in both raw and second)

prep <- 'of'   # of in for to on with

plot(newFits[iPlot,prep] ~ Fits[iPlot,prep])
abline(a=0,b=1,col='gray')

par(mfrow=c(1,2))

	plot(Y[iPlot,prep] ~ Fits[iPlot, prep], main=paste("Auction Fit:",prep))
	ss <- smooth.spline(Fits[,prep],Y[,prep], df=7)
	lines(ss,col='red'); 
	abline(a=0,b=1,col='gray',lty=1)

	plot(Y[iPlot,prep] ~ newFits[iPlot, prep])
	ss <- smooth.spline(Fits[, prep],Y[, prep], df=7)
	lines(ss,col='red'); 
	abline(a=0,b=1,col='gray',lty=1)
	
reset()

## --- calibrate using a smoothing spline, then look at predictive scores

cal.fits <- Fits
for(j in 1:ncol(cal.fits)) { 
	cat(i," ")
	ss <- smooth.spline(Fits[,j],Y[,j], df=7)
	cal.fits[,j] <- predict(ss,Fits[,j])$y
	}

##     check calibration (some wiggle remains)

prep <- 'with'
	plot(Y[iPlot,prep] ~ cal.fits[iPlot, prep], main=paste("Auction Fit:",prep))
	ss <- smooth.spline(cal.fits[,prep],Y[,prep], df=7)
	lines(ss,col='red'); 
	abline(a=0,b=1,col='gray',lty=1)
	
##     compare to prior prediction (calibration looks 'weird' since constrains to [0,1])

prpx <- 'for'; prpy <- 'on'

plot(    Fits[iPlot, prpx] ~     Fits[iPlot,prpy],col=color[iPlot], main="original auction pred")

plot( newFits[iPlot, prpx] ~  newFits[iPlot,prpy],col=color[iPlot], main="multivar regr pred")

plot(cal.fits[iPlot, prpx] ~ cal.fits[iPlot,prpy],col=color[iPlot], main="cal auction pred")


##     prediction errors reduced slightly for of, with, the two with main calibration issue

pred  <- apply( avg.fits [,1:length(prepositions)],1,which.max)
truth <- apply(       Y  [,1:length(prepositions)],1,which.max)
pred.tab <- table(truth,pred)
colnames(pred.tab) <- rownames(pred.tab) <- prepositions
round(pred.tab/20000,2)


##     try the 1-sum(others) using the 'multivariate' fits (which sum to 1))
##     this style is very highly correlated with the original Fit so little lift

hist(rowSums(newFits))

k <- 1
plot(Fits[iPlot,k], newFits[iPlot,k], col=color[iPlot])

avg.fits <- (Fits + newFits)/2
