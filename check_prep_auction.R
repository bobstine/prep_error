Data <- read.delim("~/C/projects/prep_error/auction_run/model_data.csv")

dim(Data); names(Data)

train <- Data[,1]=="est"
test <-  !train

## ------------------------------------------------------------------------------------------------------------------
## check calibration along the way

model.size <- 30
(  formula <- as.formula( paste("Y~",paste(names(Data)[5:(4 + model.size)],collapse='+')) )  )

summary( regr <- lm(formula, data=Data[test,])  )

Y <- Data[train,"Y"]
o <- order( X<- fitted.values(regr) )

y <- Y[o]; x <- X[o];
plot(x,y,xlab="Fitted Values", ylab="Y")

lines(x,fitted.values(lm(y~poly(x,5))), col='red')

2
## messed up?
## lines(loess(y~x, span=0.7, col='red')  )

## ------------------------------------------------------------------------------------------------------------------
## check early fit results: regression and confusion matrix...
## to make these relevant, need to suppress the calibration
summary( regr <-  lm(Y~CHILD_LABEL1_NA + GP_ew0 + GP_ew1 + GP_ew2 + GP_ew3, data=Data[ Data[,1]=="est", ]) )   # R2 should match

fit <- fitted.values(regr); binary.fit <- as.numeric(fit > 0.5)            # confusion counts should match
table(as.factor(Data[train,"Y"]), as.factor(binary.fit))

pred <- predict(regr,newdata=Data[!train,]); binary.pred <-  as.numeric(pred>0.5)
table(as.factor(Data[!train,"Y"]), as.factor(binary.pred))

##  intermediate formula (used to form beam)

summary(
    regr <-
        lm(Y~CHILD_LABEL1_NA + GP_ew0+GP_ew1+GP_ew2+GP_ew3,     data=Data[ Data[,1]=="est", ]) )

(b <- coefficients(regr) )[1:6]

Data$beam <- rowSums(Data[,c("GP_ew0", "GP_ew1", "GP_ew2", "GP_ew3")] * t(matrix(b[3:6],nrow=4,ncol=nrow(Data))))
Data$beam <- Data$beam - mean(Data$beam)

Data$beam[1:5]^2; Data$xb_4.2[1:5]  # these match; beam is centered before squared


## build the later formula just before beam and then after

summary(  # just before
    regr <-
        lm(Y~CHILD_LABEL1_NA + GP_ew0+GP_ew1+GP_ew2+GP_ew3+
               PARENT_ew0+PARENT_ew1+PARENT_ew2+PARENT_ew3+PARENT_ew4+PARENT_ew5+PARENT_ew6+PARENT_ew7+PARENT_ew8+PARENT_ew9+PARENT_ew10+PARENT_ew11+PARENT_ew13+PARENT_ew14+
                 WL1_ew0 + WL2_ew0+WL2_ew1 + WL3_ew0 + WR1_ew0 + WR2_ew0 + WR2_ew1 + WR2_ew3 + WR3_ew0 +
                 I(PARENT_ew0^2) + I(WL1_ew0^2) + WL1_ew0.WL1_ew1 + I(WR2_ew0^2) ,
           data=Data[ Data[,1]=="est", ]) )

summary( # with beam
    regr <-
        lm(Y~CHILD_LABEL1_NA + GP_ew0+GP_ew1+GP_ew2+GP_ew3+
               PARENT_ew0+PARENT_ew1+PARENT_ew2+PARENT_ew3+PARENT_ew4+PARENT_ew5+PARENT_ew6+PARENT_ew7+PARENT_ew8+PARENT_ew9+PARENT_ew10+PARENT_ew11+PARENT_ew13+PARENT_ew14+
                 WL1_ew0 + WL2_ew0+WL2_ew1 + WL3_ew0 + WR1_ew0 + WR2_ew0 + WR2_ew1 + WR2_ew3 + WR3_ew0 +
                 I(PARENT_ew0^2) + I(WL1_ew0^2) + WL1_ew0.WL1_ew1 + I(WR2_ew0^2) + I(beam^2) ,
           data=Data[ Data[,1]=="est", ]) )



