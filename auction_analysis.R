## --- use auction_progress.R to plot the auction history


## --- Analysis of auction results for multinomial classification:
##     Which words are being confused?

patha <- "~/C/projects/prep_error/saved_results/n1500_e200p_r10k_spline/"
pathb <- patha

##     while running the path is as follows
# patha <- "~/C/projects/prep_error/auction_data/multinomial/"
# pathb <- "~/C/projects/prep_error/auction_temp/"

##     get data to local machine
cmd <- paste0("scp -r hilbert:",patha," ~/C/projects/prep_error/saved_results/")
system(cmd)

##     y.all has the list of all prepositions (text)  896008
y.all <- scan(paste0(patha,"Y_all.txt"), what='char')

##     cv is 0/1 indicator of which words went to estimation
cv <- readLines(paste0(patha,"cv_indicator"))
cv <- as.numeric(  strsplit(cv[4],'\t')[[1]]  )  # only want first part of list result
sum(cv)
test  <- which(cv==0)
train <- which(cv==1)                            # frequencies should match balancing frequency
table( y.all[ train ] )

sort(table( y.all[ test ] ), decreasing=T)

## --------------------------------------------------------------
##     check one model
## one model: get the fitted values from a model
##
Data.of <- read.delim(paste0(pathb,"of/model_data.txt"))
names(Data.of); dim(Data.of)

##     check cases match between internal/external cv indicators
n.est <- sum(Data.of[,"Role"]=="est")
table(Data.of[1:n.est,"Y_of"], y.all[train])

n.val <- sum(Data.of[,"Role"]=="val")
table(Data.of[(n.est+1):nrow(Data.of),"Y_of"], y.all[test])

##     labeling of words; means of fit by word
table(0.5 < Data.of[1:n.est,"Fit"], y.all[train])
tapply(Data.of[1:n.est,"Fit"], y.all[train], mean)

table(0.5 < Data.of[(n.est+1):nrow(Data.of),"Fit"], y.all[test])
tapply(Data.of[(n.est+1):nrow(Data.of),"Fit"], y.all[test], mean)

##     only the right pattern in the training; not in test
table(y.all[train],Data.of[1:n.train,"Y_of"])
table(y.all[test],Data.of[(n.est+1):nrow(Data.of),"Y_of"])



## ----------------------------------------------------------------
##     join fits for all models ... just training
##

prepositions <- c("of","in","for","to","on","with")
n.train <- length(train)
n.test  <- length(test)
Y <-  Preds <- Fits  <- NULL
for(i in 1:length(prepositions)) {
    data <- read.delim(paste0(pathb,prepositions[i],"/model_data.txt"))
    Fits[[i]]  <- data[1:n.train,"Fit"]
    Preds[[i]] <- data[(n.train+1):(n.train+n.test),"Fit"]
    Y    [[i]] <- data[(n.train+1):(n.train+n.test),paste0("Y_",prepositions[i])]
}
dim( Fits <- as.data.frame(Fits ) )
dim(Preds <- as.data.frame(Preds) )
dim( Y    <- as.data.frame( Y   ) )
names(Preds) <- names( Fits) <- names(Y) <- paste0("fit_",prepositions)

dim(  Y   <- as.matrix(  Y  ) )  # Y is actual response in test
Y <- prepositions[Y %*% (1:6)]

##     check that these counts matche C++ counts in train and test
##     have to use the shuffled preds, not y.all for test
table(y.all[train]=="of",0.5< Fits$fit_of)
table(Y   ,              0.5<Preds$fit_of)

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
Preds.tab <- table(Y,choice)
colnames(Preds.tab) <- prepositions
Preds.tab <- Preds.tab[prepositions,]
s <- rowSums(Preds.tab)
round((Preds.tab)/s,2)

##         row probs
s <- colSums(Preds.tab)
round(t(t(Preds.tab)/s),2)

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

q   <- quantile(entropy.fit,(1:49)/50)
bin <- 1+rowSums(outer(entropy.fit,q,'>'))

correct <- prepositions[choice] == y.all[train]

pct <- tapply(correct,bin,mean)
plot((1:50)/50,pct, xlab="Entropy Percentile",ylab="Pct Correct", 
      main="Accuracy drops as entropy of predictions increases")

##     low entropy (easy to predict; run from C makefile)
o <- order(entropy.fit, decreasing=FALSE)

low <- sort(o[1:100])[1:10]   # sort so don't have to read too many lines to find
entropy.fit[low]
d.low <- data.frame(line=train[low], truth=(y.all[train])[low], choice=choice[low], Fit=round(Fits[low,],2)); 
d.low

##     high entropy
high <- sort(o[length(o)-0:100])[1:10]   # sort so don't have to read too many lines to find
entropy.fit[high]
d.high <- data.frame(line=train[high], truth=(y.all[train])[high], choice=choice[high], Fit=round(Fits[high,],2)); 
d.high


## -----------------------------------------------------------
##     regular calibration

Y <- 0+outer(y.all[train],prepositions,function(a,b){a == b})
colnames(Y) <- prepositions

Fits <- as.matrix(Fits)

i <- sample(1:nrow(Y),10000); 

##     example [ slope(OF) != 1 ???]
prp <- 'with'; fprp <- paste0("fit_",prp)
plot(Y[i,prp] ~ Fits[i,fprp])
summary( regr <-  lm(Y[,prp] ~ Fits[,fprp]) ); mean(Y[,prp]); mean(Fits[,fprp])
abline (a=0,b=1,col='gray',lty=3)
ss.fit <- smooth.spline(Y[i,prp] ~ Fits[i,fprp], df=7)
lines(ss.fit,col='red')

y <- Y[,prp]
x <- Fits[,fprp]
summary( regr <- lm(y ~ x) )
summary( cr   <- lm(y ~ poly(x,3,raw=T)))
pred <- outer(x[i],0:3,'^') %*% coefficients(cr)
points(x[i],pred)

points(pred,y[i],col='green')
lines(smooth.spline(pred,y[i],df=6),col='green')

##     what happens if smooth residual
resid <- residuals(regr)
plot(Fits[i,fprp],resid[i])
ss.res <- smooth.spline(resid[i] ~ Fits[i,fprp], df=7)
fit.res <- fitted(ss.res)
lines(ss.res,col='red')

##     shift preds by model fit to residuals
x <- Fits[,fprp]+fit.res; y <- Y[,prp]
plot(x[i],y[i])
abline (a=0,b=1,col='gray',lty=3)
ss.fit2 <- smooth.spline(x,y, df=7)
lines(ss.fit,col='red')

##     soft limits for 0/1
 plot(function(x){1+0.1*(1-exp(1-x))},xlim=c(1,4))
 plot(function(x){.1*(exp(x)-1)},xlim=c(-3,0))

## -----------------------------------------------------------
##     multivariate calibration

Y <- 0+outer(y.all[train],prepositions,function(a,b){a == b})
colnames(Y) <- prepositions

Fits <- as.matrix(Fits)

##     example
summary( regr <-  lm(Y[,1] ~ Fits) )

##     all of them
newFits <-  matrix(NA, nrow=nrow(Y), ncol=ncol(Y))
for(i in 1:6) { newFits[,i] <-  fitted(lm(Y[,i] ~ Fits)) }
colnames(newFits) <- paste0("fit.",prepositions)

##     which prep gets largest probability
choice <- apply(newFits[,1:length(prepositions)],1,which.max)
newFits.tab <- table(y.all[train],choice)
colnames(newFits.tab) <- prepositions

newFits.tab <- newFits.tab[prepositions,]; 

round(newFits.tab/50000,2)

save(Fits, newFits, Y, file="fits.Rdata")

## was like this before calibrating
         of   in  for   to   on with
  of   0.88 0.04 0.03 0.01 0.02 0.02
  in   0.19 0.56 0.06 0.04 0.08 0.07
  for  0.24 0.06 0.50 0.06 0.06 0.09
  to   0.12 0.05 0.06 0.66 0.05 0.06
  on   0.19 0.06 0.07 0.05 0.55 0.07
  with 0.16 0.05 0.06 0.05 0.05 0.64
## became this
         of   in  for   to   on with
  of   0.76 0.06 0.07 0.02 0.05 0.04
  in   0.06 0.61 0.09 0.05 0.11 0.08
  for  0.08 0.08 0.59 0.07 0.08 0.10
  to   0.03 0.06 0.08 0.68 0.07 0.07
  on   0.05 0.08 0.10 0.05 0.64 0.08
  with 0.04 0.06 0.09 0.06 0.07 0.68

## regular calibration is now much better with coef 1
prp <- 'of'; fprp <- paste0("fit.",prp)
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
