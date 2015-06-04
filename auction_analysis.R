## --- Analysis of auction results for multinomial classification:
##     Which words are being confused?
## --- use auction_progress.R to plot the auction history

patha <- "~/C/projects/prep_error/saved_results/n1000_e200p_r25k_poly_fast/"

## --- the 40k test series
patha <- "~/C/projects/prep_error/saved_results/40k/"          # control, with pos tags, parse results
patha <- "~/C/projects/prep_error/saved_results/40k_no_pos/"   # use parse position words

patha <- "~/C/projects/prep_error/saved_results/40k_pre_post/" # 5 to left, 5 to right only

patha <- "~/C/projects/prep_error/auction_temp/"

##     while running the path is as follows
# patha <- "~/C/projects/prep_error/auction_data/multinomial/"
# pathb <- "~/C/projects/prep_error/auction_temp/"

##     get data to local machine
cmd <- paste0("scp -r hilbert:",patha," ~/C/projects/prep_error/saved_results/")
# system(cmd)


##     y.all has the list of all prepositions (text) but not aligned with test data 896008
y.all <- scan(paste0(patha,"Y_all.txt"), what='char')

##     cv is 0/1 indicator of which words went to estimation
cv <- readLines(paste0(patha,"cv_indicator"))
cv <- as.numeric(  strsplit(cv[4],'\t')[[1]]  )  # only want first part of list result
sum(cv)
test  <- which(cv==0)
train <- which(cv==1)                            # frequencies should match balancing frequency
table( y.all[ train ] )

sort(table( y.all[ test ] ), decreasing=T)       # frequencies in test set will vary

## --------------------------------------------------------------
##     check one model
## one model: get the fitted values from a model
##
Data.with<- read.delim(paste0(pathb,"with.before/model_data.txt"))
names(Data.with); dim(Data.with)

##   smaller data
n.est <- 300000
y <- Data.with$Y_with
x <- Data.with$Fit
i <- sample(1:n.est,20000)
plot(y[i] ~ x[i], xlab="Model Fit, Y^", ylab="Y")
summary( regr <-  lm(y ~ x) ); mean(y); mean(x)   # not happy that means do not match (soft-limits)
abline (a=0,b=1,col='gray',lty=3)
ss.fit <- smooth.spline(y ~ x, df=7)
lines(ss.fit,col='red')

##     is spline calibrated?
x2 <- fitted(ss.fit)
plot(x2[i],y[i])
abline (a=0,b=1,col='gray',lty=3)
ss.fit2 <- smooth.spline(y ~ x2, df=7)
lines(ss.fit,col='red')

##     what happens if smooth residual
resid <- Data.with$Residual
plot(x[i],resid[i], xlab="Model Fit Y^", ylab="Residuals")
ss.res <- smooth.spline(resid ~ x, df=7)
fit.res <- fitted(ss.res)
lines(ss.res,col='red')

##     shift preds by model fit to residuals
xp <- x + fit.res
plot(xp[i],y[i], xlab="Calibrated Fit", ylab="Y")
abline (a=0,b=1,col='gray',lty=3)
ss.fit2 <- smooth.spline(xp,y, df=7)
lines(ss.fit2,col='red')
mean(y-xp)  # much closer to 0

##     check cases match between internal/external cv indicators
##     first are in order, validation/test are inverted order
n.est <- sum(Data.with[,"Role"]=="est")
table(Data.with[1:n.est,"Y_with"], y.all[train])

n.val <- sum(Data.with[,"Role"]=="val")
table(Data.with[nrow(Data.with):(n.est+1),"Y_with"], y.all[test])

##     labeling of words; means of fit by word
table(0.5 < Data.with[1:n.est,"Fit"], y.all[train])
tapply(Data.with[1:n.est,"Fit"], y.all[train], mean)

table(0.5 < Data.with[(n.est+1):nrow(Data.with),"Fit"], y.all[test])
tapply(Data.with[nrow(Data.with):(n.est+1),"Fit"], y.all[test], mean)

x <- Data.with[1:n.est,"Fit"]; y <- Data.with[1:n.est,"Y_with"]; s <- Data.with[1:n.est,5]

i <- sample (1:n.est,20000)
plot(y[i] ~ x[i])
plot(s[i] ~ x[i])

## ----------------------------------------------------------------
##     join fits for all models
## --------------------------------------------------------------

prepositions <- c("of","in","for","to","on","with")
n.train <- length(train)
n.test  <- length(test)
Y.test <- Y.train <-  Preds <- Fits  <- NULL
for(i in 1:length(prepositions)) { 
    data <- read.delim(paste0(patha,"prep_",prepositions[i],"/model_data.txt"))
    i.test <- !(i.train <- data[,"Role"]=="est")
    Fits[[i]]   <- data[i.train,"Fit"]
    Y.train[[i]]<- data[i.train,"Y"]
    Preds[[i]]  <- data[i.test ,"Fit"]
    Y.test[[i]] <- data[i.test ,"Y"]
}
dim( Fits    <- as.data.frame(Fits ) )
dim(Preds    <- as.data.frame(Preds) )
dim( Y.train <- as.data.frame( Y.train  ) )
dim( Y.test  <- as.data.frame( Y.test   ) )
names(Y.test) <- names(Y.train) <- prepositions
names(Preds)  <- names( Fits)   <- paste0("fit_",prepositions)

##     means
colMeans( Fits); colMeans(Y.train)
colMeans(Preds); colMeans(Y.test )

dim(  Y.test   <- as.matrix(  Y.test  ) )
Y.test <- prepositions[Y.test %*% (1:6)]

##     check that these counts match C++ counts in train and test
##     have to use the shuffled preds, not y.all for test
table(y.all[train]=="of",0.5< Fits$fit_of)
table(Y.test=="of"      ,0.5<Preds$fit_of)

##     which prep gets largest probability
##        first in training
choice <- apply(Fits[,1:length(prepositions)],1,which.max)
Fits.tab <- table(y.all[train],choice)
colnames(Fits.tab) <- prepositions
Fits.tab <- Fits.tab[prepositions,]      # arrange rows
round(Fits.tab/50000,2)

##         row probs in train
s <- colSums(Fits.tab)
round(t(t(Fits.tab)/s),2)

##         and in test
choice <- apply(Preds[,1:length(prepositions)],1,which.max)
Preds.tab <- table(Y.test,choice)
colnames(Preds.tab) <- prepositions
Preds.tab <- Preds.tab[prepositions,]
s <- rowSums(Preds.tab)
round((Preds.tab)/s,2)

##         row probs
s <- colSums(Preds.tab)
round(t(t(Preds.tab)/s),2)


## ----------------------------------------------------------------
##     fits for weighted models
## --------------------------------------------------------------

prepositions <- c("of","in","for","to","on","with")
n.train <- length(train)
n.test  <- length(test)
wY.test <- wY.train <-  wPreds <- wFits  <- NULL
for(i in 1:length(prepositions)) {
    wdata <- read.delim(paste0(patha,"wprep_",prepositions[i],"/model_data.txt"))
    i.test <- !(i.train <- wdata[,"Role"]=="est")
    wFits[[i]]   <- wdata[i.train,"Fit"]
    wY.train[[i]]<- wdata[i.train,"Y"]
    wPreds[[i]]  <- wdata[i.test ,"Fit"]
    wY.test[[i]] <- wdata[i.test ,"Y"]
}

dim( wFits    <- as.data.frame(wFits ) )
dim(wPreds    <- as.data.frame(wPreds) )
dim( wY.train <- as.data.frame( wY.train  ) )
dim( wY.test  <- as.data.frame( wY.test   ) )
names(wY.test) <- names(wY.train) <- prepositions
names(wPreds)  <- names( wFits)   <- paste0("fit_",prepositions)

##     means
colMeans( wFits); colMeans(wY.train)
colMeans(wPreds); colMeans(wY.test )

dim(  wY.test   <- as.matrix(  wY.test  ) )
wY.test <- prepositions[wY.test %*% (1:6)]

##     check that these counts match C++ counts in train and test
##     have to use the shuffled preds, not y.all for test
table(y.all[i.train]=="of",0.5< Fits$fit_of)
table(Y.test=="of  "      ,0.5<Preds$fit_of)

##     which prep gets largest probability
##        first in training
choice <- apply(wFits[,1:length(prepositions)],1,which.max)
wFits.tab <- table(y.all[i.train],choice)
colnames(wFits.tab) <- prepositions
wFits.tab <- wFits.tab[prepositions,]      # arrange rows
round(wFits.tab/50000,2)

##         row probs in train
s <- colSums(wFits.tab)
round(t(t(wFits.tab)/s),2)

##         and in test
choice <- apply(wPreds[,1:length(prepositions)],1,which.max)
wPreds.tab <- table(wY.test,choice)
colnames(wPreds.tab) <- prepositions
wPreds.tab <- wPreds.tab[prepositions,]
s <- rowSums(wPreds.tab)
round((wPreds.tab)/s,2)

##         row probs
s <- colSums(wPreds.tab)
round(t(t(wPreds.tab)/s),2)

## -----------------------------------------------------------
##     entropy and errors
##
##            accuracy is monotone decreasing in entropy
##

entropy <- function(p) {
    p <- pmin(0.99999,pmax(0.00001,p))
    p <- p/sum(p)
    -sum(p*log(p))
}

entropy.fit <- apply(Fits,1,entropy)

#     bin entropy results
q   <- quantile(entropy.fit,(1:99)/100)
bin <- 1+rowSums(outer(entropy.fit,q,'>'))

correct <- prepositions[choice] == y.all[train]

pct <- tapply(correct,bin,mean)
plot((1:100)/100,pct, xlab="Entropy Percentile",ylab="Pct Correct",
      main="Accuracy drops as entropy of predictions increases")

##     low entropy examples (easy to predict; run from C makefile)
o <- order(entropy.fit, decreasing=FALSE)

low <- sort(o[1:100])[1:10]   # sort so don't have to read too many lines to find
entropy.fit[low]
d.low <- data.frame(line=train[low], truth=(y.all[train])[low], choice=choice[low], Fit=round(Fits[low,],2));
d.low
d.low$line

##     high entropy
high <- sort(o[length(o)-0:100])[1:10]   # sort so don't have to read too many lines to find
entropy.fit[high]
d.high <- data.frame(line=train[high], truth=(y.all[train])[high], choice=choice[high], Fit=round(Fits[high,],2));
d.high
d.high$line


## -----------------------------------------------------------
##     regular calibration

Y <- 0+outer(y.all[train],prepositions,function(a,b){a == b})
colnames(Y) <- prepositions

Fits <- as.matrix(Fits)

i <- sample(1:nrow(Y),10000);

##     example [ slope(OF) != 1 ???]
prp <- 'with'; fprp <- paste0("fit_",prp)
y <- Y[,prp]
x <- Fits[,fprp]

plot(y[i] ~ x[i], xlab="Model Fit, Y^", ylab="Y")
summary( regr <-  lm(y ~ x) ); mean(y); mean(x)
abline (a=0,b=1,col='gray',lty=3)
ss.fit <- smooth.spline(y[i] ~ x[i], df=7)
lines(ss.fit,col='red')

summary( cr   <- lm(y ~ poly(x,3,raw=T)))
pred <- outer(x[i],0:3,'^') %*% coefficients(cr)
points(x[i],pred)

points(pred,y[i],col='green')
lines(smooth.spline(pred,y[i],df=6),col='green')

##     what happens if smooth residual
resid <- y - x
plot(x[i],resid[i], xlab="Model Fit Y^", ylab="Residuals")
ss.res <- smooth.spline(resid[i] ~ x[i], df=7)
fit.res <- fitted(ss.res)
lines(ss.res,col='red')

##     shift preds by model fit to residuals
xp <- x + fit.res
plot(xp[i],y[i], xlab="Calibrated Fit", ylab="Y")
abline (a=0,b=1,col='gray',lty=3)
ss.fit2 <- smooth.spline(xp,y, df=7)
lines(ss.fit2,col='red')
mean(y-xp)  # much closer to 0

##     soft limits for 0/1
hi <- function(x){1+0.5*(1-exp(1-x))}
lo <- function(x){.5*(exp(x)-1)}

plot(hi,xlim=c(1,4))
plot(lo,xlim=c(-3,0))

fit <- function(x){
	if(x<0) return(lo(x))
	if(x>1) return(hi(x))
	x
}
x <- seq(-3,4, length.out=100)
y <- mapply(fit,x)
plot(x,y, xlim=c(-3,4))
abline(a=0,b=1,lty=2,col='gray', main="Soft Limits on Predictions")


## -----------------------------------------------------------
##     multivariate calibration

Y <- 0+outer(y.all[train],prepositions,function(a,b){a == b})
colnames(Y) <- prepositions

Fits <- as.matrix(Fits)

##     example
summary( regr <-  lm(Y[,1] ~ Fits[,1]) )
summary( regr <-  lm(Y[,1] ~ Fits    ) )

##     add interaction
cFits <- Fits
summary( regr <-  lm(Y[,1] ~ Fits * cFits  ) )

##     all of them
newFits <-  matrix(NA, nrow=nrow(Y), ncol=ncol(Y))
for(i in 1:6) { newFits[,i] <-  fitted(lm(Y[,i] ~ Fits * cFits)) }
colnames(newFits) <- paste0("fit.",prepositions)

##     which prep gets largest probability
choice <- apply(newFits[,1:length(prepositions)],1,which.max)
newFits.tab <- table(y.all[train],choice)
colnames(newFits.tab) <- prepositions

newFits.tab <- newFits.tab[prepositions,];

round(newFits.tab/50000,2)

save(Fits, newFits, Y, file="fits.Rdata")


## regular calibration is now much better with coef 1
prp <- 'with'; fprp <- paste0("fit.",prp)
i <- sample(1:nrow(Y),10000);
plot(Y[i,prp] ~ newFits[i,fprp])
summary( regr <-  lm(Y[,prp] ~ newFits[,fprp]) )
abline (a=0,b=1,col='gray',lty=3)
ss <- smooth.spline(Y[i,prp] ~ newFits[i,fprp], df=6)
lines(ss,col='red')

## could have also just plugged in a calibrated prediction for 'of'


## -----------------------------------------------------------
##     model data
##
##            look at the spline calibrator
##

Data <- read.delim("~/Desktop/model_data.txt")
dim(Data); names(Data)

pred.formula <- paste(names(Data)[5:25], collapse="+")

regr <- lm(paste("Y ~",pred.formula),data=Data)
summary(regr)

##     fit before adding spline
##          pretty well calibrated but for the neg values
x <- fitted(regr); y <- Data[,"Y"]
plot(x, y)
abline(a=0,b=1,col='gray',lty=3)
lines(smooth.spline(x,y,df=5), col='red')

##     spline from data matches smoothed residuals
x <- fitted(regr); y <- residuals(regr)
plot(x,y)
lines(smooth.spline(x,y,df=5),col='gray')
points(x, Data$spline.Y_hat_21.,col='pink')

##     add spline to regression fit ... pulls up points that were negative
regr.s <- lm(paste("Y ~",pred.formula,"+spline.Y_hat_21."), data=Data)
summary(regr.s)
x <- fitted(regr.s); y <- Data[,"Y"]
plot(x, y)
abline(a=0,b=1,col='gray',lty=3)
lines(smooth.spline(x,y,df=5), col='red')


## ------------------------------------------------  early test, debugging code  -------------------------------------

plot()

## --- Check the data used to fit auction models

xtrain <- which(cv==1)

y.of <- readLines(paste0(path,"of"))
y.of <- as.numeric( strsplit(y.of[4],' ')[[1]] )

sum(y.of[ train ])





## --- Embed some signal in an explanatory feature to see if found

resp <- readLines("~/C/projects/prep_error/auction_data/multinomial/Y_to")
y <- as.numeric(  strsplit(resp[4],' ')[[1]]  )  # only want first part of list result

pred <- readLines("~/C/projects/prep_error/auction_data/multinomial/GP_ew2")
x <- as.numeric( strsplit(pred[3],'\t')[[1]] )

length(x) == length(y)

mean(x); sd(x); fivenum(x)

##     add in enough relative to variation/range of x and write back

x <- x + 0.75*(2*y-1)

pred[3] <- paste(x, collapse="\t")
writeLines(pred, "~/C/projects/prep_error/auction_data/multinomial/GP_ew2")



## --- Read ground truth
##     beware in and for are reserved in R so pad all with leading underscore

prepositions <- scan("~/C/projects/prep_error/prepositions_6.txt", what='char')
prepositions <- paste0("_",prepositions)

Y <- NULL;
for(p in prepositions)  Y[[p]] <- scan(paste0("~/C/projects/prep_error/auction_data/multinomial/Y",p), skip=3)

Y <- as.data.frame(Y)

##     check that every row has just one, and that all have 1 (FALSE, TRUE)
any(rowSums(Y) != 1)
sum(Y)==nrow(Y)


## --- Read cv indicator, fitted probabilities from the various models
CV <- NULL; Fit <- NULL
for(p in prepositions) {
    cat(p," ");
    data <- read.delim(paste0("~/C/projects/prep_error/auction_run_mult/",substring(p,2),"/model_data.txt"))
    CV[[p]] <- data[,1];
    Fit[[p]] <- data[,2]
}

CV <- as.data.frame(CV)
Fit <-  as.data.frame(Fit)
names(Fit) <-  prepositions

##     check that all CV indicators agree
b <- 0+as.matrix(CV == "est")
sum( apply(b,1,prod) ) == sum(b[,1])


## --- Compare max col to word, in validation and estimation
truth    <- apply( Y ,1,which.max)
estimate <- apply(Fit,1,which.max)

table(truth==estimate,CV[,1])

train <- which("est"==CV[,1])
tab <- as.matrix(table(truth[train], estimate[train]))
colnames(tab) <- rownames(tab) <- prepositions
tab

chisq.test(as.table(tab))




## --- Check calibration of chosen model (need to move over data from hilbert)

Data <- read.delim("~/C/projects/prep_error/auction_run_mult/to/model_data.txt")
dim(Data)
names(Data)

test <- !(train <- Data[,1]=="est")

##     training
use <- test

x <- Data[use,"Fit"]; y <- Data[use,"Y_to"]
i <- order(x); x <- x[i]; y <- y[i]

plot(y ~ x)
abline(a=0,b=1,col="gray")
lines(smooth.spline(x,y,df=7), col='green')

##     play with some cutoffs

table(y,0.25 < x)
