
#--------------------------------------------------#
# Replication of Monte Carlo Exercise in Appendix A 
#--------------------------------------------------#

#  Borrowing the code by Anthony Cookson's code and modify

library(MASS)
library(lpSolve)
library(maxLik)
library(survival)
set.seed(20220419)

##------------------------------- ##
## Parameters for the Monte Carlo ##
##------------------------------- ##

N = 100  ## Number of firms
B = N  ## Number of banks
beta_b  = 2
beta_f  = 4
sigma_e = 8.0 ## S.D of Error terms in the matching equation
gamma_b = 2
gamma_f = 1
sigma_p = 2.0 ## S.D of Error terms in the matching equation
delta   = 0.4

mu_fb= c(10, 10)
corr = 0
sig = 2
sigMat = sig*matrix(c(1, corr, corr, 1), nrow=2)

sig_xi = 2

## --------------------- ##
## Function to get data  ##
## --------------------- ##

givemedata = function(B, N=NULL){
  if(length(N)==0){ N = B}
  
   b = rnorm(B, mean = 10, sd = 2 )      ## bank and firm attributes
   f = rnorm(N, mean = 10, sd = 2)
   b_id = c(1:B)                         ## bank and firm ids
   f_id = c(1:N)
   banks = data.frame(b, b_id) 
   firms = data.frame(f, f_id)                       

   expander = expand.grid(b_id, f_id)
   names(expander) = c("b_id", "f_id")          
   dat = merge(banks, expander)
   dat = merge(dat, firms)                  ## attributes with ids (all banks, firms; matched or not)
    
   errs = data.frame( mvrnorm(N*B, mu= c(0,0), Sigma = matrix(c(sigma_p^2 + (delta^2)*sigma_e^2, delta*sigma_e^2,
                                           delta*sigma_e^2, sigma_e^2), nrow=2)))
   names(errs) = c("nu_bf", "eps_bf")     
   xi_bf = rnorm(N*B, mean=0, sd = sig_xi)
   dat = cbind(dat, errs)
   dat = within(dat, P_bf <- beta_b*b + beta_f*f + eps_bf+xi_bf)
   dat = within(dat, U_bf <- gamma_b*b + gamma_f*f + nu_bf)
   dat = dat[order(dat$f_id, dat$b_id),]
   row.names(dat) = NULL
   return(dat)
}

selectdatTU = function(dat){
   f_const = t(as.matrix(model.matrix(~0+as.factor(dat$f_id))))
   names(f_const) = NULL
   row.names(f_const) = NULL
   attr(f_const,"assign") = NULL
   attr(f_const,"contrasts") = NULL

   b_const = t(as.matrix(model.matrix(~0+as.factor(dat$b_id))))
   names(b_const) = NULL
   row.names(b_const) = NULL
   attr(b_const,"assign") = NULL
   attr(b_const,"contrasts") = NULL

   const_mat = rbind(f_const, b_const)
   rhs_vec = rep(1, 2*nrow(b_const))
   dir = rep("<=", 2*nrow(b_const))

   soln = lp("max", dat$P_b, const_mat, dir, rhs_vec, all.bin=TRUE)$solution

   dat = cbind(dat, soln)
   dat$soln = round(dat$soln)
   sel_dat = dat[dat$soln==1, ]
   return(sel_dat)
}

selectdatNTU = function(dat){
  pstor = dat[,c("f_id", "b_id", "P_bf")]
  
  offers_held = NULL
  offers_rej = pstor
  
  while(nrow(offers_rej)>0){
    best_f <- NULL
    unheld_ids <- pstor$f_id %in% offers_rej$f_id
    best_f <- as.matrix(tapply(pstor[unheld_ids,"P_bf"], pstor[unheld_ids,"f_id"], max) )                                        ## un"held" firms compute max
    offers_made <- pstor[which(pstor[,"P_bf"] %in% best_f), ]                                                      ## un"held" firms offer max
    offers_made <- rbind(offers_made, offers_held)                                                                    ## combine new offers with best "held"
    offers_held <- offers_made[which(offers_made$P_bf %in% tapply(offers_made[,"P_bf"], offers_made[,"b_id"], max)), ]       ## banks hold max
    offers_rej  <- offers_made[which(!(offers_made$P_bf %in% tapply(offers_made[,"P_bf"], offers_made[,"b_id"], max))), ]    ## banks reject non-max
    pstor <- pstor[!(pstor[,"P_bf"] %in% offers_made[,"P_bf"]), ]                                                     ## remaining rank-order list, drop the offers made this round
  }
  soln = 1
  offers_held = cbind(offers_held,soln)
  offers_held$P_bf = NULL
  
  sel_dat = merge(dat, offers_held, all.x=TRUE)
  sel_dat$soln[is.na(sel_dat$soln)] = 0
  sel_dat = sel_dat[sel_dat$soln==1, ]
  return(sel_dat)
}

selectdatNTUmany = function(dat, quotas=NULL){
  pstor = dat[,c("f_id", "b_id", "P_bf")]
  
  bankids = unique(dat$b_id)
  myimpute = length(quotas) - length(bankids) 
  
  if(length(bankids) > length(quotas)){
    quotas = c(quotas, rep(1, myimpute))
    cat("Quotas vector does not contain enough elements.  Imputed quotas of 1 for unspecified ones. \n")
  }
  if(length(bankids) < length(quotas)){
    quotas = quotas[1:length(unique(dat$b_id))]
    cat("Quotas vector contains too many elements.  Dropped the extras. \n")
  }
  
  bankos = data.frame(bankids, quotas)
  
  ## Map to related marriage problem ##
  
  bankos.spl = split(bankos, bankids)
  
  myfun = function(bdat){ 
    q = bdat[,"quotas"]
    datty = data.frame(rep(bdat[,"bankids"],q), rep(q, q), 1:q)
    names(datty) = c("b_id", "quotas", "thisquota")
    return(datty)
  }
  
  mybanks = do.call(rbind, lapply(bankos.spl, myfun))
  mybanks = within(mybanks, b_id2 <- paste(b_id, thisquota))
  
  pstor = merge(pstor, mybanks)
  pstor = within(pstor, matchindex <- paste("b", b_id2, "f", f_id))
  
  offers_held = NULL
  offers_rej = pstor
  
  while(nrow(offers_rej)>0){
    best_f <- NULL
    unheld_ids <- pstor$f_id %in% offers_rej$f_id
    best_f <- as.matrix(tapply(pstor[unheld_ids,"P_bf"], pstor[unheld_ids,"f_id"], max) )                             ## un"held" firms compute max
    offers_made <- pstor[which(pstor[,"P_bf"] %in% best_f), ]                                                         ## un"held" firms offer max
    offers_made <- offers_made[!duplicated(offers_made[,c("b_id", "f_id")]), ]                                        ## drop duplicate offers
    offers_made <- rbind(offers_made, offers_held)                                                                    ## combine new offers with best "held"
    offers_held <- offers_made[which(offers_made$P_bf %in% tapply(offers_made[,"P_bf"], offers_made[,"b_id2"], max)), ]       ## banks hold max
    offers_rej  <- offers_made[which(!(offers_made$P_bf %in% tapply(offers_made[,"P_bf"], offers_made[,"b_id2"], max))), ]    ## banks reject non-max
    pstor <- pstor[!(pstor[,"matchindex"] %in% offers_made[,"matchindex"]), ]                                                     ## remaining rank-order list, drop the offers made this round
  }
  soln = 1
  offers_held = cbind(offers_held,soln)
  offers_held$P_bf = NULL
  offers_held$thisquota = NULL
  offers_held$b_id2 = NULL
  offers_held$matchindex = NULL
  
  sel_dat = merge(dat, offers_held, all.x=TRUE)
  sel_dat$soln[is.na(sel_dat$soln)] = 0
  sel_dat = sel_dat[sel_dat$soln==1, ]
  sel_dat = sel_dat[order(sel_dat[,"b_id"]),]
  return(sel_dat)
}


dat = givemedata(5, 10)
quotas = c(1,3,2,1,3)

selectdatNTUmany(dat, quotas)

censdat = function(seed){
  set.seed(seed)
  ct <<- ct+1
  cat(ct, "\n")
  dat = givemedata(N)
  seldat = selectdatNTU(dat)
  seldat = seldat[,c("f_id", "b_id", "b", "f", "P_bf", "U_bf", "soln")]

  realpeace = dat[,c("f_id", "b_id", "P_bf")]
  names(realpeace) = c("f_id", "b_id", "P_real")
  
  Pbarmat = matrix(rep(NA, B*N),nrow=B)

  for(f in 1:N){
    for(b in 1:B){
      P2 = min(seldat$P_bf[seldat$b_id==b])
      P1 = seldat$P_bf[seldat$f_id==f]
      Pbarmat[b,f] = max(P1, P2)
    }
  }

  Pbar = as.vector(Pbarmat)

  expander = expand.grid(1:B, 1:N)
  names(expander) = c("f_id", "b_id")

  solddat = merge(expander, seldat[,c("b_id", "b")])
  solddat = merge(solddat, seldat[, c("f_id", "f")])

  solddat = merge(solddat, seldat, all.x=TRUE)

  solddat = cbind(solddat, Pbar)
  solddat$soln[is.na(solddat$soln)] = 0
  solddat = merge(solddat, realpeace)
  solddat$Pbar[solddat$soln==0] = solddat$Pbar[solddat$soln==0] -0.1
  return(solddat)
}

fitmatcor = NULL
fitmat = NULL
fitmatcor2 = NULL
fitmat2   = NULL
ct=0
for(i in 1:100){
  cd = censdat(i)
  cens_tob <- survreg(Surv(Pbar, soln, type='left') ~0+ b+f, data=cd, dist='gaussian')
  olsfit = lm(P_bf~0+b+f, data=cd)
  ehat = residuals(cens_tob)
  corfit = lm(U_bf~0+b+f+ehat, data=cd)
  olsfit2    = lm(U_bf~0+b+f, data=cd)
  fitcor = coef(cens_tob)
  fit    = coef(olsfit)
  correr = coef(corfit)
  fit2   = coef(olsfit2)
  fitmatcor = rbind(fitmatcor, fitcor)
  fitmat    = rbind(fitmat, fit)
  fitmatcor2 = rbind(fitmatcor2, correr)
  fitmat2   = rbind(fitmat2, fit2)
}

colMeans(fitmatcor)
colMeans(fitmat)
colMeans(fitmatcor2)
colMeans(fitmat2)
