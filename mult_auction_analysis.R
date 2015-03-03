## --- use the link to auction_progress.R to see a plot of the history


## --- Analysis of auction results for multinomial classification:
##     Which words are being confused?

##     y.all has the list of all prepositions
y.all <- scan("~/C/projects/prep_error/auction_run_mult/Y_all.txt", what='char')

##     cv is 0/1 indicator of which words went to estimation
cv <- readLines("~/C/projects/prep_error/auction_run_mult/cv_indicator")
cv <- as.numeric(  strsplit(cv[4],'\t')[[1]]  )  # only want first part of list result
sum(cv)

##     frequencies should match balancing frequency
train <- which(cv==1)
table( y.all[ train ] )

##     get the fitted values from a model
Data.of <- read.delim("~/C/projects/prep_error/auction_run_mult/of/model_data.txt")
names(Data.of); dim(Data.of)

##     check cases match between internal/external cv indicators
n.est <- sum(Data.of[,"Role"]=="est")
table(Data.of[1:n.est,"Y_of"], y.all[train])

##     labeling of words; means of fit by word
table(0.5 < Data.of[1:n.est,"Fit"], y.all[train])

tapply(Data.of[1:n.est,"Fit"], y.all[train], mean)

## --- join fits for all models ... just training
prepositions <- c("of","in","for","to","on","with")
n.train <- 120000
Fits <- NULL
for(i in 1:length(prepositions)) {
    data <- read.delim(paste0("~/C/projects/prep_error/auction_run_mult/",prepositions[i],"/model_data.txt"))
    Fits[[i]] <- data[1:n.train,"Fit"]
}
Fits <-  as.data.frame(Fits)
names(Fits) <- paste0("fit_",prepositions)
dim(Fits)

train <- which(cv==1)
Fits$y <- y.all[train]

head(Fits)

Y <- 0+outer(y.all[train],prepositions,function(a,b){a == b})
colnames(Y) <- prepositions


##

newProb <-  matrix(NA, nrow=nrow(Y), ncol=ncol(Y))
for(i in 1:6) { newProb[,i] <-  fitted(lm(Y[,i] ~ Fits[,1] + Fits[,2] + Fits[,3] + Fits[,4] + Fits[,5] + Fits[,6])) }

i <- 1
regr <- lm(Y[,i] ~ Fits[,1] + Fits[,2] + Fits[,3] + Fits[,4] + Fits[,5] + Fits[,6])
summary(regr)

##     check that matches C++ sensitivity
table(Fits$y=="of",0.5<Fits$fit_of)

##     which prep gets largest probability
choice <- apply(Fits[,1:length(prepositions)],1,which.max)
tab <- table(Fits$y,choice)
colnames(tab) <- prepositions

tab <- tab[prepositions,]

round(tab/10000,2)




## --- Check the data used to fit auction models

train <- which(cv==1)

y.of <- readLines("~/C/projects/prep_error/auction_data/multinomial/Y_of")
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
