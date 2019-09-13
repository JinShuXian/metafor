############################################################################

### function to set default 'btt' value(s) or check specified 'btt' values

.set.btt <- function(btt, p, int.incl) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (missing(btt) || is.null(btt)) {

      if (p > 1) {                        ### if the model matrix has more than one column
         if (int.incl) {
            btt <- seq.int(from=2, to=p)     ### and the model has an intercept term, test all coefficients except the intercept
         } else {
            btt <- seq_len(p)                ### and the model does not have an intercept term, test all coefficients
         }
      } else {
         btt <- 1                         ### if the model matrix has a single column, test that single coefficient
      }

   } else {

      ### round, take unique values, and sort
      btt <- sort(unique(round(btt)))

      ### check for mix of positive and negative values
      if (any(btt < 0) && any(btt > 0))
         stop(mstyle$stop("Cannot mix positive and negative 'btt' values."))

      ### keep/remove from 1:p vector as specified
      btt <- seq_len(p)[btt]

      ### (1:5)[5:6] yields c(5, NA) so remove NAs if this happens
      btt <- btt[!is.na(btt)]

      ### make sure that at least one valid value is left
      if (length(btt) == 0L)
         stop(mstyle$stop("Non-existent coefficients specified via 'btt'."))

   }

   return(btt)

}

### function to format 'btt' values for printing

.format.btt <- function(btt) {

   sav <- c()

   if (length(btt) > 1) {

      while (length(btt) > 0) {

         x <- rle(diff(btt))

         if (x$values[1] == 1 && length(x$values) != 0) {
            sav <- c(sav, c(btt[1], ":", btt[x$lengths[1] + 1]))
            btt <- btt[-c(1:(x$lengths[1] + 1))]
            sav <- c(sav, ", ")
         } else {
            sav <- c(sav, btt[1], ",")
            btt <- btt[-1]
         }

      }

      sav <- paste0(sav[-length(sav)], collapse="")

   } else {

      sav <- paste0(btt)

   }

   return(sav)

}

############################################################################

### pairwise sorting of the elements of two vectors

.psort <- function(x,y) {

   ### t(apply(xy, 1, sort)) would be okay, but problematic if there are NAs;
   ### either they are removed completely (na.last=NA) or they are always put
   ### first/last (na.last=FALSE/TRUE); but we just want to leave the NAs in
   ### their position!

   if (is.null(x) || length(x) == 0) ### need to catch this
      return(NULL)

   if (missing(y)) {
      if (is.matrix(x)) {
         xy <- x
      } else {
         xy <- rbind(x) ### in case x is just a vector
      }
   } else {
      xy <- cbind(x,y)
   }

   n <- nrow(xy)

   for (i in seq_len(n)) {
      if (anyNA(xy[i,]))
         next
      xy[i,] <- sort(xy[i,])
   }

   colnames(xy) <- NULL

   return(xy)

}

############################################################################

### c(m) calculation function for bias correction of SMDs (mi = n1i + n2i - 2) or SMCC/SMCRs (mi = ni - 1)

.cmicalc <- function(mi) {

   ### this can overflow if mi is 'large' (on my machine, if mi >= 344)
   #cmi <- gamma(mi/2)/(sqrt(mi/2)*gamma((mi-1)/2))
   ### catch those cases and apply the approximate formula (which is accurate then)
   #is.na <- is.na(cmi)
   #cmi[is.na] <- 1 - 3/(4*mi[is.na] - 1)

   ### this avoids the problem with overflow altogether
   cmi <- ifelse(mi <= 1, NA, exp(lgamma(mi/2) - log(sqrt(mi/2)) - lgamma((mi-1)/2)))
   return(cmi)

}

############################################################################

### function to obtain the trace of a matrix

.tr <- function(X)
   return(sum(diag(X)))

### function to check if a matrix is square

.is.square <- function(X)
   NROW(X) == NCOL(X)

### use NROW/NCOL to better deal with scalars; compare:
### (V <- list(matrix(1, nrow=2, ncol=2), 3, c(1,4), cbind(c(2,1)))); sapply(V, function(x) nrow(x) == ncol(x)); sapply(V, function(x) NROW(x) == NCOL(x))

### function to test whether a vector is all equal to 1s (e.g., to find intercept(s) in a model matrix)

.is.intercept <- function(x, eps=1e-08)
   return(all(abs(x - 1) < eps))

### function to test whether a vector is a dummy variable (i.e., consists of only 0s and 1s)

.is.dummy <- function(x, eps=1e-08)
   return(all(abs(x) < eps | abs(x - 1) < eps))
   #return(all(sapply(x, identical, 0) | sapply(x, identical, 1)))

############################################################################

### function to test for missings in a var-cov matrix

.anyNAv <- function(x) {
   k <- nrow(x)
   not.na <- not.na.diag <- !is.na(diag(x))
   for (i in seq_len(k)[not.na.diag]) {
      not.na[i] <- !anyNA(x[i, seq_len(k)[not.na.diag]])
   }
   return(!not.na)
}

### function to test each row for any missings in the lower triangular part of a matrix

#.anyNAv <- function(x)
#   return(sapply(seq_len(nrow(x)), FUN=function(i) anyNA(x[i,seq_len(i)])))

### function above is faster (and does not require making a copy of the object)

#.anyNAv <- function(X) {
#   X[upper.tri(X)] <- 0
#   return(apply(is.na(X), 1, any))
#}

############################################################################

### function to format p-values
### if showeq=FALSE, c(.001, .00001) becomes c("0.0010", "<.0001")
### if showeq=TRUE,  c(.001, .00001) becomes c("=0.0010", "<.0001")
### if add0=FALSE, "<.0001"; if add0=TRUE, "<0.0001"

.pval <- function(p, digits=4, showeq=FALSE, sep="", add0=FALSE) {

   digits <- max(digits, 1)
   cutoff  <- paste(c(".", rep(0,digits-1),1), collapse="")
   ncutoff <- as.numeric(cutoff)

   ifelse(is.na(p), paste0(ifelse(showeq, "=", ""), sep, NA),
                    ifelse(p >= ncutoff, paste0(ifelse(showeq, "=", ""), sep, formatC(p, digits=digits, format="f")),
                                         paste0("<", sep, ifelse(add0, "0", ""), cutoff)))

}

### function to format/round values in general

.fcf <- function(x, digits) {

   if (all(is.na(x))) { # since formatC(NA, format="f", digits=2) fails
      x
   } else {
      formatC(x, format="f", digits=digits)
   }

}

############################################################################

### function to print a named (character) vector right aligned with
### a gap of two spaces between adjacent values and no padding

.print.vector <- function(x) {

   if (is.null(names(x)))
      names(x) <- seq_along(x)

   len.n   <- nchar(names(x))
   len.x   <- nchar(x)
   len.max <- pmax(len.n, len.x)
   format  <- sapply(len.max, function(x) paste("%", x, "s", sep=""))

   row.n <- paste(sprintf(format, names(x)), collapse="  ")
   row.x <- paste(sprintf(format, x), collapse="  ")

   cat(row.n, "\n", row.x, "\n", sep="")

}

############################################################################

### function like make.unique(), but starts at .1 for the first instance
### of a repeated element

.make.unique <- function(x) {

   x <- as.character(x)
   ux <- unique(x)

   for (i in seq_along(ux)) {
      xiTF <- x == ux[i]
      xi <- x[xiTF]
      if (length(xi) == 1L)
         next
      x[xiTF] <- paste(xi, seq_along(xi), sep=".")
   }

   return(x)

}

############################################################################

### function to check if extra/superfluous arguments are specified via ...

.chkdots <- function(ddd, okargs) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   for (i in seq_along(okargs))
      ddd[okargs[i]] <- NULL

   if (length(ddd) > 0)
      warning(mstyle$warning(paste0("Extra argument", ifelse(length(ddd) > 1, "s ", " "), "(", paste0("'", names(ddd), "'", collapse=", "), ") disregarded.")), call.=FALSE)

}

############################################################################

### function to calculate:
### solve(t(X) %*% W %*% X) = .invcalc(X=X, W=W, k=k)
### solve(t(X) %*% X)       = .invcalc(X=X, W=diag(k), k=k)
### without taking the actual inverse

.invcalc <- function(X, W, k) {

   sWX <- sqrt(W) %*% X
   res.qrs <- qr.solve(sWX, diag(k))
   #res.qrs <- try(qr.solve(sWX, diag(k)), silent=TRUE)
   #if (inherits(res.qrs, "try-error"))
   #   stop("Cannot compute QR decomposition.")
   return(tcrossprod(res.qrs))

}

############################################################################

### function for confint.rma.uni() with Q-profile method and for the PM estimator

.QE.func <- function(tau2val, Y, vi, X, k, objective, verbose=FALSE, digits=4) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (any(tau2val + vi < 0))
      stop(mstyle$stop("Some marginal variances are negative."))

   W     <- diag(1/(vi + tau2val), nrow=k, ncol=k)
   stXWX <- .invcalc(X=X, W=W, k=k)
   P     <- W - W %*% X %*% stXWX %*% crossprod(X,W)
   RSS   <- crossprod(Y,P) %*% Y

   if (verbose)
      cat(mstyle$verbose(paste("tau2 =", formatC(tau2val, digits=digits[["var"]], width=digits[["var"]]+4, format="f"), "  RSS - objective =", formatC(RSS - objective, format="f", digits=digits[["var"]], flag=" "), "\n")))

   return(RSS - objective)

}

############################################################################

### function for confint.rma.uni() with method="GENQ"

.GENQ.func <- function(tau2val, P, vi, Q, level, k, p, getlower, verbose=FALSE, digits=4) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   S <- diag(sqrt(vi + tau2val), nrow=k, ncol=k)
   lambda <- Re(eigen(S %*% P %*% S, symmetric=TRUE, only.values=TRUE)$values)
   tmp <- CompQuadForm::farebrother(Q, lambda[seq_len(k-p)])

   ### starting with version 1.4.2 of CompQuadForm, the element is called 'Qq' (before it was called 'res')
   ### this way, things should work regardless of the version of CompQuadForm that is installed

   if (exists("res", tmp))
      tmp$Qq <- tmp$res

   if (getlower) {
      res <- tmp$Qq - level
   } else {
      res <- (1 - tmp$Qq) - level
   }

   if (verbose)
      cat(mstyle$verbose(paste("tau2 =", formatC(tau2val, digits=digits[["var"]], width=digits[["var"]]+4, format="f"), "  objective =", formatC(res, format="f", digits=digits[["var"]], flag=" "), "\n")))

   return(res)

}

############################################################################

.process.G.aftersub <- function(mf.g, struct, formula, tau2, rho, isG, k, sparse, verbose) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (verbose > 1)
      message(mstyle$message(paste0("Processing '", paste0(formula, collapse=""), "' term (#1) ...")))

   ### number of variables in model frame

   nvars <- ncol(mf.g)

   ### check that the number of variables is correct for the chosen structure

   if (is.element(struct, c("CS","HCS","UN","UNR","AR","HAR","CAR","ID","DIAG","PHYBM","PHYPL","PHYPD")) && nvars != 2)
      stop(mstyle$stop(paste0("Only a single inner variable allowed for an '~ inner | outer' term when 'struct=\"", struct, "\"'.")), call.=FALSE)

   ### get variables names in mf.g

   g.names <- names(mf.g) ### names for inner and outer factors/variables

   ### check that inner variable is a factor (or character variable) for structures that require this

   if (is.element(struct, c("CS","HCS","UN","UNR","ID","DIAG")) && !is.factor(mf.g[[1]]) && !is.character(mf.g[[1]]))
      stop(mstyle$stop(paste0("Inner variable in '~ inner | outer' term must be a factor or character variable when 'struct=\"", struct, "\"'.")), call.=FALSE)

   ### for struct="CAR", check that inner term is numeric and get the unique numeric values

   if (is.element(struct, c("CAR"))) {
      if (!is.numeric(mf.g[[1]]))
         stop(mstyle$stop("Inner variable in '~ inner | outer' term must be numeric for 'struct=\"CAR\"'."), call.=FALSE)
      g.values <- sort(unique(mf.g[[1]]))
   } else {
      g.values <- NULL
   }

   ### turn each variable in mf.g into a factor (not for SP/PHY structures or GEN)
   ### if a variable was a factor to begin with, this drops any unused levels, but order of existing levels is preserved

   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN"))) {
      mf.g <- data.frame(mf.g[-nvars], outer=factor(mf.g[[nvars]]))
   } else {
      mf.g <- data.frame(inner=factor(mf.g[[1]]), outer=factor(mf.g[[2]]))
   }

   ### check if there are any NAs anywhere in mf.g

   if (anyNA(mf.g))
      stop(mstyle$stop("No NAs allowed in variables specified via the 'random' argument."), call.=FALSE)

   ### get number of levels of each variable in mf.g (vector with two values, for the inner and outer factor)

   #g.nlevels <- c(nlevels(mf.g[[1]]), nlevels(mf.g[[2]])) ### works only for factors
   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN"))) {
      g.nlevels <- c(length(unique(apply(mf.g[-nvars], 1, paste, collapse=" + "))), length(unique(mf.g[[nvars]])))
   } else {
      g.nlevels <- c(length(unique(mf.g[[1]])), length(unique(mf.g[[2]])))
   }

   ### get levels of each variable in mf.g

   #g.levels <- list(levels(mf.g[[1]]), levels(mf.g[[2]])) ### works only for factors
   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN"))) {
      g.levels <- list(sort(unique(apply(mf.g[-nvars], 1, paste, collapse=" + "))), sort(unique((mf.g[[nvars]]))))
   } else {
      #g.levels <- list(sort(unique(as.character(mf.g[[1]]))), sort(unique(as.character(mf.g[[2]]))))
      g.levels <- list(as.character(sort(unique(mf.g[[1]]))), as.character(sort(unique(mf.g[[2]]))))
   }

   ### determine appropriate number of tau2 and rho values (note: this is done *after* subsetting)
   ### note: if g.nlevels[1] is 1, then technically there is no correlation, but we still need one
   ### rho for the optimization function (this rho is fixed to 0 further in the rma.mv() function)

   if (is.element(struct, c("CS","ID","AR","CAR","SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD"))) {
      tau2s <- 1
      rhos  <- 1
   }
   if (is.element(struct, c("HCS","DIAG","HAR"))) {
      tau2s <- g.nlevels[1]
      rhos  <- 1
   }
   if (struct == "UN") {
      tau2s <- g.nlevels[1]
      rhos  <- ifelse(g.nlevels[1] > 1, g.nlevels[1]*(g.nlevels[1]-1)/2, 1)
   }
   if (struct == "UNR") {
      tau2s <- 1
      rhos  <- ifelse(g.nlevels[1] > 1, g.nlevels[1]*(g.nlevels[1]-1)/2, 1)
   }
   if (struct == "GEN") {
      p     <- nvars - 1
      tau2s <- p
      rhos  <- ifelse(p > 1, p*(p-1)/2, 1)
   }

   ### set default value(s) for tau2 if it is unspecified

   if (is.null(tau2))
      tau2 <- rep(NA_real_, tau2s)

   ### set default value(s) for rho argument if it is unspecified

   if (is.null(rho))
      rho <- rep(NA_real_, rhos)

   ### allow quickly setting all tau2 values to a fixed value

   if (length(tau2) == 1)
      tau2 <- rep(tau2, tau2s)

   ### allow quickly setting all rho values to a fixed value

   if (length(rho) == 1)
      rho <- rep(rho, rhos)

   ### check if tau2 and rho are of correct length

   if (length(tau2) != tau2s)
      stop(mstyle$stop(paste0("Length of ", ifelse(isG, 'tau2', 'gamma2'), " argument (", length(tau2), ") does not match actual number of variance components (", tau2s, ").")), call.=FALSE)
   if (length(rho) != rhos)
      stop(mstyle$stop(paste0("Length of ", ifelse(isG, 'rho', 'phi'), " argument (", length(rho), ") does not match actual number of correlations (", rhos, ").")), call.=FALSE)

   ### checks on any fixed values of tau2 and rho arguments

   if (any(tau2 < 0, na.rm=TRUE))
      stop(mstyle$stop(paste0("Specified value(s) of ", ifelse(isG, 'tau2', 'gamma2'), " must be >= 0.")), call.=FALSE)
   if (is.element(struct, c("CAR")) && any(rho > 1 | rho < 0, na.rm=TRUE))
      stop(mstyle$stop(paste0("Specified value(s) of ", ifelse(isG, 'rho', 'phi'), " must be in [0,1].")), call.=FALSE)
   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYPL","PHYPD")) && any(rho < 0, na.rm=TRUE))
      stop(mstyle$stop(paste0("Specified value(s) of ", ifelse(isG, 'rho', 'phi'), " must be >= 0.")), call.=FALSE)
   if (!is.element(struct, c("CAR","SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD")) && any(rho > 1 | rho < -1, na.rm=TRUE))
      stop(mstyle$stop(paste0("Specified value(s) of ", ifelse(isG, 'rho', 'phi'), " must be in [-1,1].")), call.=FALSE)

   ### create model matrix for inner and outer factors of mf.g

   if (is.element(struct, c("CS","HCS","UN","UNR","AR","HAR","CAR","ID","DIAG"))) {

      if (g.nlevels[1] == 1) {
         Z.G1 <- cbind(rep(1,k))
      } else {
         if (sparse) {
            Z.G1 <- sparse.model.matrix(~ mf.g[[1]] - 1)
         } else {
            Z.G1 <- model.matrix(~ mf.g[[1]] - 1)
         }
      }

   }

   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD"))) {

      if (sparse) {
         Z.G1 <- Diagonal(k)
      } else {
         Z.G1 <- diag(1, nrow=k, ncol=k)
      }

   }

   if (is.element(struct, c("GEN"))) {

      if (sparse) {
         Z.G1 <- Matrix(as.matrix(mf.g[-nvars]), sparse=TRUE)
      } else {
         Z.G1 <- as.matrix(mf.g[-nvars])
      }

   }

   if (g.nlevels[2] == 1) {
      Z.G2 <- cbind(rep(1,k))
   } else {
      if (sparse) {
         Z.G2 <- sparse.model.matrix(~ mf.g[[nvars]] - 1)
      } else {
         Z.G2 <- model.matrix(~ mf.g[[nvars]] - 1)
      }
   }

   attr(Z.G1, "assign")    <- NULL
   attr(Z.G1, "contrasts") <- NULL
   attr(Z.G2, "assign")    <- NULL
   attr(Z.G2, "contrasts") <- NULL

   return(list(mf.g=mf.g, g.names=g.names, g.nlevels=g.nlevels,
               g.levels=g.levels, g.values=g.values,
               tau2s=tau2s, rhos=rhos, tau2=tau2, rho=rho, Z.G1=Z.G1, Z.G2=Z.G2))

}

############################################################################

.process.G.afterrmna <- function(mf.g, g.nlevels, g.levels, g.values, struct, formula, tau2, rho, Z.G1, Z.G2, isG, sparse, distspec, verbose) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (verbose > 1)
      message(mstyle$message(paste0("Processing '", paste0(formula, collapse=""), "' term (#2) ...")))

   ### number of variables in model frame

   nvars <- ncol(mf.g)

   ### copy g.nlevels and g.levels

   g.nlevels.f <- g.nlevels
   g.levels.f  <- g.levels

   ### redo: turn each variable in mf.g into a factor (not for SP structures or GEN)
   ### (reevaluates the levels present, but order of existing levels is preserved)

   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN"))) {
      mf.g <- data.frame(mf.g[-nvars], outer=factor(mf.g[[nvars]]))
   } else {
      mf.g <- data.frame(inner=factor(mf.g[[1]]), outer=factor(mf.g[[2]]))
   }

   ### redo: get number of levels of each variable in mf.g (vector with two values, for the inner and outer factor)

   #g.nlevels <- c(nlevels(mf.g[[1]]), nlevels(mf.g[[2]])) ### works only for factors
   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN"))) {
      g.nlevels <- c(length(unique(apply(mf.g[-nvars], 1, paste, collapse=" + "))), length(unique(mf.g[[nvars]])))
   } else {
      g.nlevels <- c(length(unique(mf.g[[1]])), length(unique(mf.g[[2]])))
   }

   ### redo: get levels of each variable in mf.g

   #g.levels <- list(levels(mf.g[[1]]), levels(mf.g[[2]])) ### works only for factors
   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN"))) {
      g.levels <- list(sort(unique(apply(mf.g[-nvars], 1, paste, collapse=" + "))), sort(unique((mf.g[[nvars]]))))
   } else {
      #g.levels <- list(sort(unique(as.character(mf.g[[1]]))), sort(unique(as.character(mf.g[[2]]))))
      g.levels <- list(as.character(sort(unique(mf.g[[1]]))), as.character(sort(unique(mf.g[[2]]))))
   }

   ### determine which levels of the inner factor were removed

   g.levels.r <- !is.element(g.levels.f[[1]], g.levels[[1]])

   ### warn if any levels were removed (not for "AR","CAR","SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","GEN")

   if (any(g.levels.r) && !is.element(struct, c("AR","CAR","SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","GEN")))
      warning(mstyle$warning(paste0("One or more levels of inner factor (i.e., ", paste(g.levels.f[[1]][g.levels.r], collapse=", "), ") removed due to NAs.")), call.=FALSE)

   ### for "ID" and "DIAG", fix rho to 0

   if (is.element(struct, c("ID","DIAG")))
      rho <- 0

   ### if there is only a single arm for "CS","HCS","AR","HAR","CAR" (either to begin with or after removing NAs), then fix rho to 0

   if (g.nlevels[1] == 1 && is.element(struct, c("CS","HCS","AR","HAR","CAR")) && is.na(rho)) {
      rho <- 0
      warning(mstyle$warning(paste0("Inner factor has only a single level, so fixed value of ", ifelse(isG, 'rho', 'phi'), " to 0.")), call.=FALSE)
   }

   ### if there is only a single arm for SP/PHY structures or GEN (either to begin with or after removing NAs), cannot fit model

   if (g.nlevels[1] == 1 && is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN")))
      stop(mstyle$stop("Cannot fit model since inner term only has a single level."), call.=FALSE)

   ### k per level of the inner factor

   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN"))) {
      g.levels.k <- table(factor(apply(mf.g[-nvars], 1, paste, collapse=" + "), levels=g.levels.f[[1]]))
   } else {
      g.levels.k <- table(factor(mf.g[[1]], levels=g.levels.f[[1]]))
   }

   ### for "HCS","UN","DIAG","HAR": if a particular level of the inner factor only occurs once, then set corresponding tau2 value to 0 (if not already fixed)
   ### note: no longer done; variance component should still be (weakly) identifiable

   #if (is.element(struct, c("HCS","UN","DIAG","HAR"))) {
   #   if (any(is.na(tau2) & g.levels.k == 1)) {
   #      tau2[is.na(tau2) & g.levels.k == 1] <- 0
   #      warning(mstyle$warning("Inner factor has k=1 for one or more levels. Corresponding 'tau2' value(s) fixed to 0."))
   #   }
   #}

   ### check if each study has only a single arm (could be different arms!)
   ### for "CS","HCS","AR","HAR","CAR" must then fix rho to 0 (if not already fixed)
   ### for SP/PHY structures cannot fit model; for GEN rho may still be (weakly) identifiable

   if (g.nlevels[2] == nrow(mf.g)) {
      if (is.element(struct, c("CS","HCS","AR","HAR","CAR")) && is.na(rho)) {
         rho <- 0
         warning(mstyle$warning(paste0("Each level of the outer factor contains only a single level of the inner factor, so fixed value of ", ifelse(isG, 'rho', 'phi'), " to 0.")), call.=FALSE)
      }
      if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD")))
         stop(mstyle$stop("Cannot fit model since each level of the outer factor contains only a single level of the inner term."), call.=FALSE)
   }

   g.levels.comb.k <- NULL

   if (!is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN"))) {

      ### create matrix where each row (= study) indicates how often each arm occurred
      ### then turn this into a list (with each element equal to a row (= study))

      g.levels.comb.k <- crossprod(Z.G2, Z.G1)
      g.levels.comb.k <- split(g.levels.comb.k, seq_len(nrow(g.levels.comb.k)))

      ### create matrix for each element (= study) that indicates which combinations occurred
      ### sum up all matrices (numbers indicate in how many studies each combination occurred)
      ### take upper triangle part that corresponds to the arm combinations (in order of rho)

      g.levels.comb.k <- lapply(g.levels.comb.k, function(x) outer(x,x, FUN="&"))
      g.levels.comb.k <- Reduce("+", g.levels.comb.k)
      g.levels.comb.k <- g.levels.comb.k[upper.tri(g.levels.comb.k)]

      ### UN/UNR: if a particular combination of arms never occurs in any of the studies, then must fix the corresponding rho to 0 (if not already fixed)
      ### this also takes care of the case where each study has only a single arm

      if (is.element(struct, c("UN","UNR")) && any(g.levels.comb.k == 0 & is.na(rho))) {
         rho[g.levels.comb.k == 0] <- 0
         warning(mstyle$warning(paste0("Some combinations of the levels of the inner factor never occurred. Corresponding ", ifelse(isG, 'rho', 'phi'), " value(s) fixed to 0.")), call.=FALSE)
      }

      ### if there was only a single arm for "UN" or "UNR" to begin with, then fix rho to 0
      ### (technically there is then no rho at all to begin with, but rhos was still set to 1 earlier for the optimization routine)
      ### (if there is a single arm after removing NAs, then this is dealt with below by setting tau2 and rho values to 0)

      if (is.element(struct, c("UN","UNR")) && g.nlevels.f[1] == 1 && is.na(rho)) {
         rho <- 0
         warning(mstyle$warning(paste0("Inner factor has only a single level, so fixed value of ", ifelse(isG, 'rho', 'phi'), " to 0.")), call.=FALSE)
      }

   }

   ### construct G matrix for the various structures

   if (struct == "CS") {
      G <- matrix(rho*tau2, nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      diag(G) <- tau2
   }

   if (struct == "HCS") {
      G <- matrix(rho, nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      diag(G) <- 1
      G <- diag(sqrt(tau2), nrow=g.nlevels.f[1], ncol=g.nlevels.f[1]) %*% G %*% diag(sqrt(tau2), nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      diag(G) <- tau2
   }

   if (is.element(struct, c("UN","GEN"))) {
      G <- .con.vcov.UN(tau2, rho)
   }

   if (struct == "UNR") {
      G <- .con.vcov.UNR(tau2, rho)
   }

   if (is.element(struct, c("ID","DIAG"))) {
      G <- diag(tau2, nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
   }

   if (struct == "AR") {
      if (is.na(rho)) {
         G <- matrix(NA_real_, nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      } else {
         ### is g.nlevels.f[1] == 1 even possible here?
         if (g.nlevels.f[1] > 1) {
            G <- toeplitz(ARMAacf(ar=rho, lag.max=g.nlevels.f[1]-1))
         } else {
            G <- diag(1)
         }
      }
      G <- diag(sqrt(rep(tau2, g.nlevels.f[1])), nrow=g.nlevels.f[1], ncol=g.nlevels.f[1]) %*% G %*% diag(sqrt(rep(tau2, g.nlevels.f[1])), nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      diag(G) <- tau2
   }

   if (struct == "HAR") {
      if (is.na(rho)) {
         G <- matrix(NA_real_, nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      } else {
         ### is g.nlevels.f[1] == 1 even possible here?
         if (g.nlevels.f[1] > 1) {
            G <- toeplitz(ARMAacf(ar=rho, lag.max=g.nlevels.f[1]-1))
         } else {
            G <- diag(1)
         }
      }
      G <- diag(sqrt(tau2), nrow=g.nlevels.f[1], ncol=g.nlevels.f[1]) %*% G %*% diag(sqrt(tau2), nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      diag(G) <- tau2
   }

   if (struct == "CAR") {
      if (is.na(rho)) {
         G <- matrix(NA_real_, nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      } else {
         ### is g.nlevels.f[1] == 1 even possible here?
         if (g.nlevels.f[1] > 1) {
            G <- outer(g.values, g.values, function(x,y) rho^(abs(x-y)))
         } else {
            G <- diag(1)
         }
      }
      G <- diag(sqrt(rep(tau2, g.nlevels.f[1])), nrow=g.nlevels.f[1], ncol=g.nlevels.f[1]) %*% G %*% diag(sqrt(rep(tau2, g.nlevels.f[1])), nrow=g.nlevels.f[1], ncol=g.nlevels.f[1])
      diag(G) <- tau2
   }

   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD"))) {

      ### remove the '| outer' part from the formula and add '- 1'
      formula <- as.formula(paste0(strsplit(paste0(formula, collapse=""), "|", fixed=TRUE)[[1]][1], "- 1", collapse=""))

      ### create distance matrix

      if (is.matrix(distspec)) {

         if (anyNA(distspec))
            stop(mstyle$stop("No missing values allowed in matrices specified via 'dist'."))
         if (!.is.square(distspec))
            stop(mstyle$stop("Distance matrices specified via 'dist' must be square matrices."))
         if (!isSymmetric(unname(distspec)))
            stop(mstyle$stop("Distance matrices specified via 'dist' must be symmetric matrices."))
         if (is.null(rownames(distspec)))
            rownames(distspec) <- colnames(distspec)
         if (is.null(colnames(distspec)))
            colnames(distspec) <- rownames(distspec)
         if (length(colnames(distspec)) != length(unique(colnames(distspec))))
            stop(mstyle$stop("Distance matrices specified via 'dist' must have unique dimension names."))
         if (any(!is.element(as.character(mf.g[[1]]), colnames(distspec))))
            stop(mstyle$stop(paste0("There are levels in '", colnames(mf.g)[1], "' for which there are no matching rows/columns in the corresponding 'dist' matrix.")))

         if (is.element(struct, c("PHYBM","PHYPL","PHYPD")) && !all.equal(min(distspec), 0))
            warning(mstyle$warning("Minimum value in the distance matrix is not 0."), call.=FALSE)

         if (is.element(struct, c("PHYBM","PHYPL","PHYPD")) && !all.equal(max(distspec), 2))
            warning(mstyle$warning("Maximum value in the distance matrix is not 2."), call.=FALSE)

         Dmat <- distspec[as.character(mf.g[[1]]), as.character(mf.g[[1]])]

      } else {

         if (is.element(struct, c("PHYBM","PHYPL","PHYPD")))
            stop(mstyle$stop("Must supply distance matrix via 'dist' for phylogenetic correlation structures."))

         Cmat <- model.matrix(formula, data=mf.g[-nvars])

         if (is.function(distspec)) {
            Dmat <- distspec(Cmat)
         } else {
            if (is.element(distspec, c("euclidean", "maximum", "manhattan")))
               Dmat <- as.matrix(dist(Cmat, method=distspec))
            if (distspec == "gcd")
               Dmat <- sp::spDists(Cmat, longlat=TRUE)
         }

      }

      if (sparse)
         Dmat <- Matrix(Dmat, sparse=TRUE)

   } else {

      Dmat <- NULL

   }

   if (struct == "SPEXP") {
      Rmat <- exp(-Dmat/rho)
      G <- tau2 * Rmat * tcrossprod(Z.G2)
   }

   if (struct == "SPGAU") {
      Rmat <- exp(-Dmat^2/rho^2)
      G <- tau2 * Rmat * tcrossprod(Z.G2)
   }

   if (struct == "SPLIN") {
      Rmat <- (1 - Dmat/rho) * I(Dmat < rho)
      G <- tau2 * Rmat * tcrossprod(Z.G2)
   }

   if (struct == "SPRAT") {
      Rmat <- 1 - (Dmat/rho)^2 / (1 + (Dmat/rho)^2)
      G <- tau2 * Rmat * tcrossprod(Z.G2)
   }

   if (struct == "SPSPH") {
      Rmat <- (1 - 3/2*Dmat/rho + 1/2*(Dmat/rho)^3) * I(Dmat < rho)
      G <- tau2 * Rmat * tcrossprod(Z.G2)
   }

   if (struct == "PHYBM") {
      rho <- max(Dmat)
      Rmat <- 1 - Dmat/rho
      G <- tau2 * Rmat * tcrossprod(Z.G2)
   }

   if (struct == "PHYPL") {
      Rmat <- rho * (1 - Dmat/max(Dmat))
      diag(Rmat) <- 1
      Rmat[Dmat == 0] <- 1
      G <- tau2 * Rmat * tcrossprod(Z.G2)
   }

   if (struct == "PHYPD") {
      Rmat <- 1 - Dmat/max(Dmat)
      G <- tau2 * Rmat^rho * tcrossprod(Z.G2)
   }

   ### for spatial and phylogeny structures, compute a much more sensible initial value for rho

   if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD"))) {
      if (struct == "PHYBM")
         rho.init <- max(Dmat)
      if (struct == "PHYPL")
         rho.init <- 0.5
      if (struct == "PHYPD")
         rho.init <- 1
      if (!is.element(struct, c("PHYBM","PHYPL","PHYPD")))
         rho.init <- suppressMessages(quantile(Dmat[upper.tri(Dmat)], 0.25)) # suppressMessages() to avoid '<sparse>[ <logic> ] : .M.sub.i.logical() maybe inefficient' messages when sparse=TRUE
   } else {
      rho.init <- NULL
   }

   ### for "CS","AR","CAR","ID" set tau2 value to 0 for any levels that were removed

   if (any(g.levels.r) && is.element(struct, c("CS","AR","CAR","ID"))) {
      G[g.levels.r,] <- 0
      G[,g.levels.r] <- 0
   }

   ### for "HCS","HAR","DIAG" set tau2 value(s) to 0 for any levels that were removed

   if (any(g.levels.r) && is.element(struct, c("HCS","HAR","DIAG"))) {
      G[g.levels.r,] <- 0
      G[,g.levels.r] <- 0
      tau2[g.levels.r] <- 0
      warning(mstyle$warning(paste0("Fixed ", ifelse(isG, 'tau2', 'gamma2'), " to 0 for removed level(s).")), call.=FALSE)
   }

   ### for "UN", set tau2 value(s) and corresponding rho(s) to 0 for any levels that were removed

   if (any(g.levels.r) && struct == "UN") {
      G[g.levels.r,] <- 0
      G[,g.levels.r] <- 0
      tau2[g.levels.r] <- 0
      rho <- G[upper.tri(G)]
      warning(mstyle$warning(paste0("Fixed ", ifelse(isG, 'tau2', 'gamma2'), " and corresponding ", ifelse(isG, 'rho', 'phi'), " value(s) to 0 for removed level(s).")), call.=FALSE)
   }

   ### for "UNR", set rho(s) to 0 corresponding to any levels that were removed

   if (any(g.levels.r) && struct == "UNR") {
      G[g.levels.r,] <- 0
      G[,g.levels.r] <- 0
      diag(G) <- tau2 ### don't really need this
      rho <- G[upper.tri(G)]
      warning(mstyle$warning(paste0("Fixed ", ifelse(isG, 'rho', 'phi'), " value(s) to 0 for removed level(s).")), call.=FALSE)
   }

   ### special handling for the bivariate model:
   ### if tau2 (for "CS","AR","CAR","UNR") or either tau2.1 or tau2.2 (for "HCS","UN","HAR") is fixed to 0, then rho must be fixed to 0

   if (g.nlevels.f[1] == 2) {
      if (is.element(struct, c("CS","AR","CAR","UNR")) && !is.na(tau2) && tau2 == 0)
         rho <- 0
      if (is.element(struct, c("HCS","UN","HAR")) && ((!is.na(tau2[1]) && tau2[1] == 0) || (!is.na(tau2[2]) && tau2[2] == 0)))
         rho <- 0
   }

   return(list(mf.g=mf.g, g.nlevels=g.nlevels, g.nlevels.f=g.nlevels.f,
               g.levels=g.levels, g.levels.f=g.levels.f, g.levels.r=g.levels.r, g.levels.k=g.levels.k, g.levels.comb.k=g.levels.comb.k,
               tau2=tau2, rho=rho, G=G, Dmat=Dmat, rho.init=rho.init))

}

############################################################################

### function to construct var-cov matrix for "UN" and "GEN" structures given vector of variances and correlations

.con.vcov.UN <- function(vars, cors) {
   dims <- length(vars)
   G <- matrix(1, nrow=dims, ncol=dims)
   G[upper.tri(G)] <- cors
   G[lower.tri(G)] <- t(G)[lower.tri(G)]
   H <- diag(sqrt(vars), nrow=dims, ncol=dims)
   return(H %*% G %*% H)
}

### function to construct var-cov matrix for "UN" and "GEN" structures given vector of 'choled' variances and covariances

.con.vcov.UN.chol <- function(vars, covs) {
   dims <- length(vars)
   G <- matrix(0, nrow=dims, ncol=dims)
   G[upper.tri(G)] <- covs
   diag(G) <- vars
   return(crossprod(G))
}

### function to construct var-cov matrix for "UNR" structure given the variance and correlations

.con.vcov.UNR <- function(var, cors) {
   dims <- round((1 + sqrt(1 + 8*length(cors)))/2)
   G <- matrix(1, nrow=dims, ncol=dims)
   G[upper.tri(G)] <- cors
   G[lower.tri(G)] <- t(G)[lower.tri(G)]
   return(var * G)
}

### function to construct var-cov matrix for "UNR" structure given the variance and vector of 'choled' correlations

.con.vcov.UNR.chol <- function(var, cors) {
   dims <- round((1 + sqrt(1 + 8*length(cors)))/2)
   G <- matrix(0, nrow=dims, ncol=dims)
   G[upper.tri(G)] <- cors
   diag(G) <- 1
   return(var * crossprod(G))
}

############################################################################

### function to construct var-cov matrix (G or H) for '~ inner | outer' terms

.con.E <- function(v, r, v.val, r.val, Z1, Z2, levels.r, values, Dmat, struct, cholesky, vctransf, posdefify, sparse) {

   ### if cholesky=TRUE, back-transformation/substitution is done below; otherwise, back-transform and replace fixed values

   if (!cholesky) {
      if (vctransf) {
         v <- ifelse(is.na(v.val), exp(v), v.val)           ### variances are optimized in log space, so exponentiate
         if (struct == "CAR")
            r <- ifelse(is.na(r.val), plogis(r), r.val)     ### CAR correlation is optimized in qlogis space, so use plogis
         if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD")))
            r <- ifelse(is.na(r.val), exp(r), r.val)        ### spatial and phylogenetic 'correlation' parameter is optimized in log space, so exponentiate
         if (!is.element(struct, c("CAR","SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD")))
            r <- ifelse(is.na(r.val), tanh(r), r.val)       ### other correlations are optimized in atanh space, so use tanh
      } else {
         ### for Hessian computation, can choose to leave as is
         v <- ifelse(is.na(v.val), v, v.val)
         r <- ifelse(is.na(r.val), r, r.val)
         v[v < 0] <- 0
         if (struct == "CAR") {
            r[r < 0] <- 0
            r[r > 1] <- 1
         }
         if (is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD"))) {
            r[r < 0] <- 0
         }
         if (!is.element(struct, c("CAR","SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD"))) {
            r[r < -1] <- -1
            r[r > 1] <- 1
         }
      }
      v <- ifelse(v <= .Machine$double.eps*10, 0, v) ### don't do this with Cholesky factorization, since values can be negative
   }

   ncol.Z1 <- ncol(Z1)

   if (struct == "CS") {
      E <- matrix(r*v, nrow=ncol.Z1, ncol=ncol.Z1)
      diag(E) <- v
   }

   if (struct == "HCS") {
      E <- matrix(r, nrow=ncol.Z1, ncol=ncol.Z1)
      diag(E) <- 1
      E <- diag(sqrt(v), nrow=ncol.Z1, ncol=ncol.Z1) %*% E %*% diag(sqrt(v), nrow=ncol.Z1, ncol=ncol.Z1)
      diag(E) <- v
   }

   if (is.element(struct, c("UN","GEN"))) {
      if (cholesky) {
         E <- .con.vcov.UN.chol(v, r)
         v <- diag(E)                  ### need this, so correct values are shown when verbose=TRUE
         r <- cov2cor(E)[upper.tri(E)] ### need this, so correct values are shown when verbose=TRUE
         v[!is.na(v.val)] <- v.val[!is.na(v.val)] ### replace any fixed values
         r[!is.na(r.val)] <- r.val[!is.na(r.val)] ### replace any fixed values
      }
      E <- .con.vcov.UN(v, r)
      if (posdefify) {
         E <- as.matrix(nearPD(E)$mat) ### nearPD() in Matrix package
         v <- diag(E)                  ### need this, so correct values are shown when verbose=TRUE
         r <- cov2cor(E)[upper.tri(E)] ### need this, so correct values are shown when verbose=TRUE
      }
   }

   if (struct == "UNR") {
      if (cholesky) {
         E <- .con.vcov.UNR.chol(v, r)
         v <- diag(E)[1,1]             ### need this, so correct values are shown when verbose=TRUE
         r <- cov2cor(E)[upper.tri(E)] ### need this, so correct values are shown when verbose=TRUE
         v[!is.na(v.val)] <- v.val[!is.na(v.val)] ### replace any fixed values
         r[!is.na(r.val)] <- r.val[!is.na(r.val)] ### replace any fixed values
      }
      E <- .con.vcov.UNR(v, r)
      if (posdefify) {
         E <- as.matrix(nearPD(E, keepDiag=TRUE)$mat) ### nearPD() in Matrix package
         v <- E[1,1]                   ### need this, so correct values are shown when verbose=TRUE
         r <- cov2cor(E)[upper.tri(E)] ### need this, so correct values are shown when verbose=TRUE
      }
   }

   if (is.element(struct, c("ID","DIAG")))
      E <- diag(v, nrow=ncol.Z1, ncol=ncol.Z1)

   if (struct == "AR") {
      if (ncol.Z1 > 1) {
         E <- toeplitz(ARMAacf(ar=r, lag.max=ncol.Z1-1))
      } else {
         E <- diag(1)
      }
      E <- diag(sqrt(rep(v, ncol.Z1)), nrow=ncol.Z1, ncol=ncol.Z1) %*% E %*% diag(sqrt(rep(v, ncol.Z1)), nrow=ncol.Z1, ncol=ncol.Z1)
      diag(E) <- v
   }

   if (struct == "HAR") {
      if (ncol.Z1 > 1) {
         E <- toeplitz(ARMAacf(ar=r, lag.max=ncol.Z1-1))
      } else {
         E <- diag(1)
      }
      E <- diag(sqrt(v), nrow=ncol.Z1, ncol=ncol.Z1) %*% E %*% diag(sqrt(v), nrow=ncol.Z1, ncol=ncol.Z1)
      diag(E) <- v
   }

   if (struct == "CAR") {
      if (ncol.Z1 > 1) {
         E <- outer(values, values, function(x,y) r^(abs(x-y)))
      } else {
         E <- diag(1)
      }
      E <- diag(sqrt(rep(v, ncol.Z1)), nrow=ncol.Z1, ncol=ncol.Z1) %*% E %*% diag(sqrt(rep(v, ncol.Z1)), nrow=ncol.Z1, ncol=ncol.Z1)
      diag(E) <- v
   }

   if (struct == "SPEXP")
      E <- v * exp(-Dmat/r) * tcrossprod(Z2)

   if (struct == "SPGAU")
      E <- v * exp(-Dmat^2/r^2) * tcrossprod(Z2)

   if (struct == "SPLIN")
      E <- v * ((1 - Dmat/r) * I(Dmat < r)) * tcrossprod(Z2)

   if (struct == "SPRAT")
      E <- v * (1 - (Dmat/r)^2 / (1 + (Dmat/r)^2)) * tcrossprod(Z2)

   if (struct == "SPSPH")
      E <- v * ((1 - 3/2*Dmat/r + 1/2*(Dmat/r)^3) * I(Dmat < r)) * tcrossprod(Z2)

   if (struct == "PHYBM") {
      r <- max(Dmat)
      E <- 1 - Dmat/r
      E <- v * E * tcrossprod(Z2)
   }

   if (struct == "PHYPL") {
      E <- r * (1 - Dmat/max(Dmat))
      diag(E) <- 1
      E[Dmat == 0] <- 1
      E <- v * E * tcrossprod(Z2)
   }

   if (struct == "PHYPD") {
      E <- 1 - Dmat/max(Dmat)
      E <- v * E^r * tcrossprod(Z2)
   }

   ### set variance and corresponding correlation value(s) to 0 for any levels that were removed

   if (!is.element(struct, c("SPEXP","SPGAU","SPLIN","SPRAT","SPSPH","PHYBM","PHYPL","PHYPD","GEN")) && any(levels.r)) {
      E[levels.r,] <- 0
      E[,levels.r] <- 0
   }

   if (sparse)
      E <- Matrix(E, sparse=TRUE)

   return(list(v=v, r=r, E=E))

}

############################################################################

### -1 times the log likelihood (regular or restricted) for rma.mv models

.ll.rma.mv <- function(par, reml, Y, M, A, X.fit, k, pX, # note: X.fit due to hessian(); pX due to nlm(); M=V to begin with
                       D.S, Z.G1, Z.G2, Z.H1, Z.H2, g.Dmat, h.Dmat,
                       sigma2.val, tau2.val, rho.val, gamma2.val, phi.val,
                       sigma2s, tau2s, rhos, gamma2s, phis,
                       withS, withG, withH,
                       struct, g.levels.r, h.levels.r, g.values, h.values,
                       sparse, cholesky, posdefify, vctransf,
                       verbose, digits, REMLf, dofit=FALSE) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   ### only NA values in sigma2.val, tau2.val, rho.val, gamma2.val, phi.val should be estimated; otherwise, replace with fixed values

   if (withS) {

      if (vctransf) {
         sigma2 <- ifelse(is.na(sigma2.val), exp(par[seq_len(sigma2s)]), sigma2.val) ### sigma2 is optimized in log space, so exponentiate
      } else {
         sigma2 <- ifelse(is.na(sigma2.val), par[seq_len(sigma2s)], sigma2.val)      ### for Hessian computation, can choose to leave as is
         sigma2[sigma2 < 0] <- 0
      }

      #if (any(is.nan(sigma2)))
      #   return(Inf)

      ### set really small sigma2 values equal to 0 (anything below .Machine$double.eps*10 is essentially 0)
      sigma2 <- ifelse(sigma2 <= .Machine$double.eps*10, 0, sigma2)

      for (j in seq_len(sigma2s)) {
         M <- M + sigma2[j] * D.S[[j]]
      }

   }

   if (withG) {

      resG <- .con.E(v=par[(sigma2s+1):(sigma2s+tau2s)], r=par[(sigma2s+tau2s+1):(sigma2s+tau2s+rhos)],
                     v.val=tau2.val, r.val=rho.val, Z1=Z.G1, Z2=Z.G2, levels.r=g.levels.r, values=g.values, Dmat=g.Dmat,
                     struct=struct[1], cholesky=cholesky[1], vctransf=vctransf, posdefify=posdefify, sparse=sparse)
      tau2 <- resG$v
      rho  <- resG$r
      G    <- resG$E

      M <- M + (Z.G1 %*% G %*% t(Z.G1)) * tcrossprod(Z.G2)

   }

   if (withH) {

      resH <- .con.E(v=par[(sigma2s+tau2s+rhos+1):(sigma2s+tau2s+rhos+gamma2s)], r=par[(sigma2s+tau2s+rhos+gamma2s+1):(sigma2s+tau2s+rhos+gamma2s+phis)],
                     v.val=gamma2.val, r.val=phi.val, Z1=Z.H1, Z2=Z.H2, levels.r=h.levels.r, values=h.values, Dmat=h.Dmat,
                     struct=struct[2], cholesky=cholesky[2], vctransf=vctransf, posdefify=posdefify, sparse=sparse)
      gamma2 <- resH$v
      phi    <- resH$r
      H      <- resH$E

      M <- M + (Z.H1 %*% H %*% t(Z.H1)) * tcrossprod(Z.H2)

   }

   ### note: if M is sparse, then using nearPD() could blow up

   if (posdefify)
      M <- as.matrix(nearPD(M)$mat)

   if (verbose > 1) {
      W <- try(chol2inv(chol(M)), silent=FALSE)
   } else {
      W <- try(suppressWarnings(chol2inv(chol(M))), silent=TRUE)
   }

   ### note: need W for REML llval computation

   if (inherits(W, "try-error")) {

      ### if M is not positive-definite, set the (restricted) log likelihood to -Inf
      ### this idea is based on: http://stats.stackexchange.com/q/11368/1934 (this is crude, but should
      ### move the parameter estimates away from values that create the non-positive-definite M matrix)

      if (dofit) {
         stop(mstyle$stop("Final variance-covariance matrix not positive definite."))
      } else {
         llval <- -Inf
      }

   } else {

      if (verbose > 1) {
         U <- try(chol(W), silent=FALSE)
      } else {
         U <- try(suppressWarnings(chol(W)), silent=TRUE)
      }

      ### Y ~ N(Xbeta, M), so UY ~ N(UXbeta, UMU) where UMU = I
      ### return(U %*% M %*% U)

      if (inherits(U, "try-error")) {

         if (dofit) {
            stop(mstyle$stop("Cannot fit model based on estimated marginal variance-covariance matrix."))
         } else {
            llval <- -Inf
         }

      } else {

         if (!dofit || is.null(A)) {

            sX   <- U %*% X.fit
            sY   <- U %*% Y
            beta <- solve(crossprod(sX), crossprod(sX, sY))
            RSS  <- sum(as.vector(sY - sX %*% beta)^2)
            if (dofit)
               vb <- matrix(solve(crossprod(sX)), nrow=pX, ncol=pX)

         } else {

            stXAX <- chol2inv(chol(as.matrix(t(X.fit) %*% A %*% X.fit)))
            #stXAX <- tcrossprod(qr.solve(sX, diag(k)))
            beta  <- matrix(stXAX %*% crossprod(X.fit,A) %*% Y, ncol=1)
            RSS   <- as.vector(t(Y - X.fit %*% beta) %*% W %*% (Y - X.fit %*% beta))
            vb    <- matrix(stXAX %*% t(X.fit) %*% A %*% M %*% A %*% X.fit %*% stXAX, nrow=pX, ncol=pX)

         }

         llvals <- c(NA_real_, NA_real_)

         if (dofit || !reml)
            llvals[1]  <- -1/2 * (k) * log(2*base::pi) - 1/2 * determinant(M, logarithm=TRUE)$modulus - 1/2 * RSS

         if (dofit || reml)
            llvals[2]  <- -1/2 * (k-pX) * log(2*base::pi) + ifelse(REMLf, 1/2 * determinant(crossprod(X.fit), logarithm=TRUE)$modulus, 0) +
                          -1/2 * determinant(M, logarithm=TRUE)$modulus - 1/2 * determinant(crossprod(X.fit,W) %*% X.fit, logarithm=TRUE)$modulus - 1/2 * RSS

         if (dofit) {

            res <- list(beta=beta, vb=vb, M=M, llvals=llvals)

            if (withS)
               res$sigma2 <- sigma2

            if (withG) {
               res$G <- G
               res$tau2 <- tau2
               res$rho <- rho
            }

            if (withH) {
               res$H <- H
               res$gamma2 <- gamma2
               res$phi <- phi
            }

            return(res)

         } else {

            llval <- ifelse(reml, llvals[2], llvals[1])

         }

      }

   }

   if ((vctransf && verbose) || (!vctransf && (verbose > 1))) {
      cat(mstyle$verbose(paste0("ll = ", ifelse(is.na(llval), NA, formatC(llval, digits=digits[["fit"]], format="f", flag=" ")))), "  ")
      if (withS)
         cat(mstyle$verbose(paste0("sigma2 =", paste(ifelse(is.na(sigma2), NA, formatC(sigma2, digits=digits[["var"]], format="f", flag=" ")), collapse=" "), "  ")))
      if (withG) {
         cat(mstyle$verbose(paste0("tau2 =",   paste(ifelse(is.na(tau2),   NA, formatC(tau2,   digits=digits[["var"]], format="f", flag=" ")), collapse=" "), "  ")))
         cat(mstyle$verbose(paste0("rho =",    paste(ifelse(is.na(rho),    NA, formatC(rho,    digits=digits[["var"]], format="f", flag=" ")), collapse=" "), "  ")))
      }
      if (withH) {
         cat(mstyle$verbose(paste0("gamma2 =", paste(ifelse(is.na(gamma2), NA, formatC(gamma2, digits=digits[["var"]], format="f", flag=" ")), collapse=" "), "  ")))
         cat(mstyle$verbose(paste0("phi =",    paste(ifelse(is.na(phi),    NA, formatC(phi,    digits=digits[["var"]], format="f", flag=" ")), collapse=" "), "  ")))
      }
      cat("\n")
   }

   return(-1 * c(llval))

}

############################################################################

### for profile(), confint(), and multicore processing

.profile.rma.uni <- function(val, obj, parallel=FALSE, profile=FALSE, CI=FALSE, subset=FALSE, objective, sel, FE=FALSE, verbose=FALSE) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (parallel == "snow")
      library(metafor)

   if (profile || CI) {

      ### for profiling and CI construction, fit model with tau2 fixed to 'val'

      res <- try(suppressWarnings(rma.uni(obj$yi, obj$vi, weights=obj$weights, mods=obj$X, intercept=FALSE, method=obj$method, weighted=obj$weighted, test=obj$test, level=obj$level, control=obj$control, tau2=val)), silent=TRUE)

      if (profile) {

         if (inherits(res, "try-error")) {
            sav <- list(ll = NA, beta = matrix(NA, nrow=nrow(obj$beta), ncol=1), ci.lb = rep(NA, length(obj$ci.lb)), ci.ub = rep(NA, length(obj$ci.ub)))
         } else {
            sav <- list(ll = logLik(res), beta = res$beta, ci.lb = res$ci.lb, ci.ub = res$ci.ub)
         }

      }

      if (CI) {

         if (inherits(res, "try-error")) {

            if (verbose)
               cat(mstyle$verbose(paste("tau2 =", formatC(val, digits=obj$digits[["var"]], width=obj$digits[["var"]]+4, format="f"), "  LRT - objective = NA", "\n")))

            stop()

         } else {

            sav <- -2*(logLik(res) - logLik(obj)) - objective

            if (verbose)
               cat(mstyle$verbose(paste("tau2 =", formatC(val, digits=obj$digits[["var"]], width=obj$digits[["var"]]+4, format="f"), "  LRT - objective =", formatC(sav, digits=obj$digits[["test"]], width=obj$digits[["test"]]+4, format="f"), "\n")))

         }

      }

   }

   if (subset) {

      ### for subsetting, fit model to subset as specified in row 'val' of 'sel'

      if (FE) {

         if (parallel == "snow" || parallel == "multicore") {
            yi <- obj$yi[sel[val,]]
            vi <- obj$vi[sel[val,]]
         } else {
            yi <- obj$yi[sel]
            vi <- obj$vi[sel]
         }
         k <- length(yi)
         wi <- 1/vi
         est <- sum(wi*yi)/sum(wi)
         if (k > 1) {
            Q <- sum(wi * (yi - est)^2)
            I2 <- max(0, 100 * (Q - (k-1)) / Q)
            H2 <- Q / (k-1)
         } else {
            Q <- 0
            I2 <- 0
            H2 <- 1
         }
         tau2 <- 0
         if (parallel == "snow" || parallel == "multicore") {
            sav <- list(beta = est, het = c(k = k, QE = Q, I2 = I2, H2 = H2, tau2 = tau2))
         } else {
            sav <- list(beta = est, k = k, QE = Q, I2 = I2, H2 = H2, tau2 = tau2)
         }

      } else {

         res <- try(suppressWarnings(rma.uni(obj$yi, obj$vi, weights=obj$weights, mods=obj$X, intercept=FALSE, method=obj$method, weighted=obj$weighted, test=obj$test, level=obj$level, control=obj$control, tau2=ifelse(obj$tau2.fix, obj$tau2, NA), subset=sel[val,])), silent=TRUE)

         if (inherits(res, "try-error") || any(res$coef.na)) {
            sav <- list(beta = matrix(NA, nrow=nrow(obj$beta), ncol=1), het = rep(NA, 5))
         } else {
            sav <- list(beta = res$beta, het = c(res$k, res$QE, res$I2, res$H2, res$tau2))
         }

      }

   }

   return(sav)

}

.profile.rma.mv <- function(val, obj, comp, sigma2.pos, tau2.pos, rho.pos, gamma2.pos, phi.pos, parallel=FALSE, profile=FALSE, CI=FALSE, subset=FALSE, objective, verbose=FALSE) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (parallel == "snow")
      library(metafor)

   if (profile || CI) {

      ### for profiling and CI construction, fit model with variance component fixed to 'val'

      ### set any fixed components to their values
      sigma2.arg <- ifelse(obj$vc.fix$sigma2, obj$sigma2, NA)
      tau2.arg   <- ifelse(obj$vc.fix$tau2, obj$tau2, NA)
      rho.arg    <- ifelse(obj$vc.fix$rho, obj$rho, NA)
      gamma2.arg <- ifelse(obj$vc.fix$gamma2, obj$gamma2, NA)
      phi.arg    <- ifelse(obj$vc.fix$phi, obj$phi, NA)

      if (comp == "sigma2")
         sigma2.arg[sigma2.pos] <- val

      if (comp == "tau2")
         tau2.arg[tau2.pos] <- val

      if (comp == "rho")
         rho.arg[rho.pos] <- val

      if (comp == "gamma2")
         gamma2.arg[gamma2.pos] <- val

      if (comp == "phi")
         phi.arg[phi.pos] <- val

      res <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=sigma2.arg, tau2=tau2.arg, rho=rho.arg, gamma2=gamma2.arg, phi=phi.arg, sparse=obj$sparse, dist=obj$dist, control=obj$control)), silent=TRUE)

      if (profile) {

         if (inherits(res, "try-error")) {
            sav <- list(ll = NA, beta = matrix(NA, nrow=nrow(obj$beta), ncol=1), ci.lb = rep(NA, length(obj$ci.lb)), ci.ub = rep(NA, length(obj$ci.ub)))
         } else {
            sav <- list(ll = logLik(res), beta = res$beta, ci.lb = res$ci.lb, ci.ub = res$ci.ub)
         }

      }

      if (CI) {

         if (inherits(res, "try-error")) {

            if (verbose)
               cat(mstyle$verbose(paste("vc =", formatC(val, digits=obj$digits[["var"]], width=obj$digits[["var"]]+4, format="f"), "  LRT - objective = NA", "\n")))

            stop()

         } else {

            sav <- -2*(logLik(res) - logLik(obj)) - objective

            if (verbose)
               cat(mstyle$verbose(paste("vc =", formatC(val, digits=obj$digits[["var"]], width=obj$digits[["var"]]+4, format="f"), "  LRT - objective =", formatC(sav, digits=obj$digits[["fit"]], width=obj$digits[["fit"]]+4, format="f"), "\n")))

         }

      }

   }

   return(sav)

}

.profile.rma.mh <- function(val, obj, parallel=FALSE, subset=FALSE, sel) {

   if (parallel == "snow")
      library(metafor)

   if (subset) {

      ### for subsetting, fit model to subset as specified in row 'val' of 'sel'

      if (is.element(obj$measure, c("RR","OR","RD"))) {
         res <- try(suppressWarnings(rma.mh(ai=obj$ai, bi=obj$bi, ci=obj$ci, di=obj$di, measure=obj$measure, add=obj$add, to=obj$to, drop00=obj$drop00, correct=obj$correct, subset=sel[val,])), silent=TRUE)
      } else {
         res <- try(suppressWarnings(rma.mh(x1i=obj$x1i, x2i=obj$x2i, t1i=obj$t1i, t2i=obj$t2i, measure=obj$measure, add=obj$add, to=obj$to, drop00=obj$drop00, correct=obj$correct, subset=sel[val,])), silent=TRUE)
      }

      if (inherits(res, "try-error")) {
         sav <- list(beta = NA, het = rep(NA, 5))
      } else {
         sav <- list(beta = res$beta, het = c(res$k, res$QE, res$I2, res$H2, res$tau2))
      }

   }

   return(sav)

}

.profile.rma.peto <- function(val, obj, parallel=FALSE, subset=FALSE, sel) {

   if (parallel == "snow")
      library(metafor)

   if (subset) {

      ### for subsetting, fit model to subset as specified in row 'val' of 'sel'

      res <- try(suppressWarnings(rma.peto(ai=obj$ai, bi=obj$bi, ci=obj$ci, di=obj$di, add=obj$add, to=obj$to, drop00=obj$drop00, subset=sel[val,])), silent=TRUE)

      if (inherits(res, "try-error")) {
         sav <- list(beta = NA, het = rep(NA, 5))
      } else {
         sav <- list(beta = res$beta, het = c(res$k, res$QE, res$I2, res$H2, res$tau2))
      }

   }

   return(sav)

}

.cooks.distance.rma.mv <- function(i, obj, parallel, svb, cluster, ids, reestimate, btt) {

   if (parallel == "snow")
      library(metafor)

   incl <- cluster %in% ids[i]

   ### note: not.na=FALSE only when there are missings in data, not when model below cannot be fitted or results in dropped coefficients

   if (reestimate) {

      control             <- obj$control
      control$sigma2.init <- obj$sigma2
      control$tau2.init   <- obj$tau2
      control$rho.init    <- obj$rho
      control$gamma2.init <- obj$gamma2
      control$phi.init    <- obj$phi

      res <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=ifelse(obj$vc.fix$sigma2, obj$sigma2, NA), tau2=ifelse(obj$vc.fix$tau2, obj$tau2, NA), rho=ifelse(obj$vc.fix$rho, obj$rho, NA), gamma2=ifelse(obj$vc.fix$gamma2, obj$gamma2, NA), phi=ifelse(obj$vc.fix$phi, obj$phi, NA), sparse=obj$sparse, dist=obj$dist, control=control, subset=!incl)), silent=TRUE)

   } else {

      res <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=obj$sigma2, tau2=obj$tau2, rho=obj$rho, gamma2=obj$gamma2, phi=obj$phi, sparse=obj$sparse, dist=obj$dist, control=obj$control, subset=!incl)), silent=TRUE)

   }

   if (inherits(res, "try-error"))
      return(list(cook.d = NA))

   if (any(res$coef.na))
      return(list(cook.d = NA))

   dfb <- obj$beta[btt] - res$beta[btt]

   return(list(cook.d = crossprod(dfb,svb) %*% dfb))

}

.rstudent.rma.mv <- function(i, obj, parallel, cluster, ids, reestimate) {

   if (parallel == "snow")
      library(metafor)

   incl <- cluster %in% ids[i]

   k.id <- sum(incl)

   if (reestimate) {

      control             <- obj$control
      control$sigma2.init <- obj$sigma2
      control$tau2.init   <- obj$tau2
      control$rho.init    <- obj$rho
      control$gamma2.init <- obj$gamma2
      control$phi.init    <- obj$phi

      res <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=ifelse(obj$vc.fix$sigma2, obj$sigma2, NA), tau2=ifelse(obj$vc.fix$tau2, obj$tau2, NA), rho=ifelse(obj$vc.fix$rho, obj$rho, NA), gamma2=ifelse(obj$vc.fix$gamma2, obj$gamma2, NA), phi=ifelse(obj$vc.fix$phi, obj$phi, NA), sparse=obj$sparse, dist=obj$dist, control=control, subset=!incl)), silent=TRUE)

   } else {

      res <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=obj$sigma2, tau2=obj$tau2, rho=obj$rho, gamma2=obj$gamma2, phi=obj$phi, sparse=obj$sparse, dist=obj$dist, control=obj$control, subset=!incl)), silent=TRUE)

   }

   if (inherits(res, "try-error"))
      return(list(delresid = rep(NA, k.id), sedelresid = rep(NA, k.id), X2 = NA, k.id = NA, pos = which(incl)))

   if (any(res$coef.na))
      return(list(delresid = rep(NA, k.id), sedelresid = rep(NA, k.id), X2 = NA, k.id = NA, pos = which(incl)))

   tmp <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=res$sigma2, tau2=res$tau2, rho=res$rho, gamma2=res$gamma2, phi=res$phi, sparse=obj$sparse, dist=obj$dist, control=obj$control)), silent=TRUE)

   Xi <- obj$X[incl,,drop=FALSE]
   delpred  <- Xi %*% res$beta
   vdelpred <- Xi %*% res$vb %*% t(Xi)
   delresid <- c(obj$yi[incl] - delpred)
   sedelresid <- c(sqrt(diag(tmp$M[incl,incl,drop=FALSE] + vdelpred)))

   sve <- try(chol2inv(chol(tmp$M[incl,incl,drop=FALSE] + vdelpred)), silent=TRUE)

   if (inherits(sve, "try-error"))
      return(list(delresid = delresid, sedelresid = sedelresid, X2 = NA, k.id = k.id, pos = which(incl)))

   X2 <- c(rbind(delresid) %*% sve %*% cbind(delresid))

   return(list(delresid = delresid, sedelresid = sedelresid, X2 = X2, k.id = k.id, pos = which(incl)))

}

.dfbetas.rma.mv <- function(i, obj, parallel, cluster, ids, reestimate) {

   if (parallel == "snow")
      library(metafor)

   incl <- cluster %in% ids[i]

   if (reestimate) {

      control             <- obj$control
      control$sigma2.init <- obj$sigma2
      control$tau2.init   <- obj$tau2
      control$rho.init    <- obj$rho
      control$gamma2.init <- obj$gamma2
      control$phi.init    <- obj$phi

      res <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=ifelse(obj$vc.fix$sigma2, obj$sigma2, NA), tau2=ifelse(obj$vc.fix$tau2, obj$tau2, NA), rho=ifelse(obj$vc.fix$rho, obj$rho, NA), gamma2=ifelse(obj$vc.fix$gamma2, obj$gamma2, NA), phi=ifelse(obj$vc.fix$phi, obj$phi, NA), sparse=obj$sparse, dist=obj$dist, control=control, subset=!incl)), silent=TRUE)

   } else {

      res <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=obj$sigma2, tau2=obj$tau2, rho=obj$rho, gamma2=obj$gamma2, phi=obj$phi, sparse=obj$sparse, dist=obj$dist, control=obj$control, subset=!incl)), silent=TRUE)

   }

   if (inherits(res, "try-error"))
      return(list(dfbs = NA))

   if (any(res$coef.na))
      return(list(dfbs = NA))

   tmp <- try(suppressWarnings(rma.mv(obj$yi, V=obj$V, W=obj$W, mods=obj$X, random=obj$random, struct=obj$struct, intercept=FALSE, data=obj$mf.r, method=obj$method, test=obj$test, level=obj$level, R=obj$R, Rscale=obj$Rscale, sigma2=res$sigma2, tau2=res$tau2, rho=res$rho, gamma2=res$gamma2, phi=res$phi, sparse=obj$sparse, dist=obj$dist, control=obj$control)), silent=TRUE)

   dfb <- obj$beta - res$beta

   dfbs <- c(dfb / sqrt(diag(tmp$vb)))

   return(list(dfbs = dfbs))

}

############################################################################

### generate all possible permutations

# .genperms <- function(k) {
#
#    v <- seq_len(k)
#
#    sub <- function(k, v) {
#       if (k==1L) {
#          matrix(v,1,k)
#       } else {
#          X  <-  NULL
#          for(i in seq_len(k)) {
#             X <- rbind(X, cbind(v[i], Recall(k-1, v[-i])))
#          }
#       X
#       }
#    }
#
#    return(sub(k, v[seq_len(k)]))
#
# }

### generate all possible unique permutations

.genuperms <- function(x) {

   z <- NULL

   sub <- function(x, y) {
      len.x <- length(x)
      if (len.x == 0L) {
         return(y)
      } else {
         prev.num <- 0
         for (i in seq_len(len.x)) {
            num <- x[i]
            if (num > prev.num) {
               prev.num <- num
               z <- rbind(z, Recall(x[-i], c(y,num)))
            }
         }
         return(z)
      }
   }

   return(sub(x, y=NULL))

}

.permci <- function(val, obj, j, exact, iter, progbar, level, digits, control) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   ### fit model with shifted outcome
   res <- try(suppressWarnings(rma.uni(obj$yi - c(val*obj$X[,j]), obj$vi, weights=obj$weights, mods=obj$X, intercept=FALSE, method=obj$method, weighted=obj$weighted, test=obj$test, tau2=ifelse(obj$tau2.fix, obj$tau2, NA), control=obj$control)), silent=TRUE)

   if (inherits(res, "try-error"))
      stop()

   ### p-value based on permutation test
   pval <- permutest(res, exact=exact, iter=iter, progbar=FALSE, control=control)$pval[j]

   ### get difference between p-value and level
   diff <- pval - level / ifelse(control$alternative == "two.sided", 1, 2)

   ### show progress
   if (progbar)
      cat(mstyle$verbose(paste("pval =", formatC(pval, format="f", digits=digits[["pval"]]), " diff =", formatC(diff, format="f", digits=digits[["pval"]], flag=" "), " val =", formatC(val, format="f", digits=digits[["est"]], flag=" "), "\n")))

   ### penalize negative differences, which should force the CI bound to correspond to a p-value of *at least* level
   diff <- ifelse(diff < 0, diff*10, diff)

   return(diff)

}

############################################################################

### set axis label (for forest, funnel, and labbe functions)

.setlab <- function(measure, transf.char, atransf.char, gentype) {

   if (gentype == 1)
      lab <- "Observed Outcome"
   if (gentype == 2)
      lab <- "Overall Estimate" ### need this for forest.cumul.rma() function

   #########################################################################

   if (!is.null(measure)) {

      ######################################################################
      if (is.element(measure, c("RR","MPRR"))) {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Risk Ratio"
         } else {
            lab <- "Transformed Log Risk Ratio"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Risk Ratio (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Risk Ratio"
         }
      }
      if (is.element(measure, c("OR","PETO","D2OR","D2ORN","D2ORL","MPOR","MPORC","MPPETO"))) {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Odds Ratio"
         } else {
            lab <- "Transformed Log Odds Ratio"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Odds Ratio (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Odds Ratio"
         }
      }
      if (is.element(measure, c("RD","MPRD"))) {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Risk Difference"
         } else {
            lab <- "Transformed Risk Difference"
         }
      }
      if (measure == "AS") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Arcsine Transformed Risk Difference"
         } else {
            lab <- "Transformed Arcsine Transformed Risk Difference"
         }
      }
      if (measure == "PHI") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Phi Coefficient"
         } else {
            lab <- "Transformed Phi Coefficient"
         }
      }
      if (measure == "YUQ") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Yule's Q"
         } else {
            lab <- "Transformed Yule's Q"
         }
      }
      if (measure == "YUY") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Yule's Y"
         } else {
            lab <- "Transformed Yule's Y"
         }
      }
      ######################################################################
      if (measure == "IRR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Incidence Rate Ratio"
         } else {
            lab <- "Transformed Log Incidence Rate Ratio"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Incidence Rate Ratio (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Incidence Rate Ratio"
         }
      }
      if (measure == "IRD") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Incidence Rate Difference"
         } else {
            lab <- "Transformed Incidence Rate Difference"
         }
      }
      if (measure == "IRSD") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Square Root Transformed Incidence Rate Difference"
         } else {
            lab <- "Transformed Square Root Transformed Incidence Rate Difference"
         }
      }
      ######################################################################
      if (measure == "MD") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Mean Difference"
         } else {
            lab <- "Transformed Mean Difference"
         }
      }
      if (is.element(measure, c("SMD","SMDH","PBIT","OR2D","OR2DN","OR2DL"))) {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Standardized Mean Difference"
         } else {
            lab <- "Transformed Standardized Mean Difference"
         }
      }
      if (measure == "ROM") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Ratio of Means"
         } else {
            lab <- "Transformed Log Ratio of Means"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Ratio of Means (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Ratio of Means"
         }
      }
      if (measure == "RPB") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Point-Biserial Correlation"
         } else {
            lab <- "Transformed Point-Biserial Correlation"
         }
      }
      if (measure == "CVR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Coefficient of Variation Ratio"
         } else {
            lab <- "Transformed Log Coefficient of Variation Ratio"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Coefficient of Variation Ratio (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Coefficient of Variation Ratio"
         }
      }
      if (measure == "VR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Variability Ratio"
         } else {
            lab <- "Transformed Log Variability Ratio"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Variability Ratio (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Variability Ratio"
         }
      }
      ######################################################################
      if (is.element(measure, c("COR","UCOR","RTET","RBIS"))) {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Correlation Coefficient"
         } else {
            lab <- "Transformed Correlation Coefficient"
         }
      }
      if (measure == "ZCOR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Fisher's z Transformed Correlation Coefficient"
         } else {
            lab <- "Transformed Fisher's z Transformed Correlation Coefficient"
            if (atransf.char == "transf.ztor" || atransf.char == "transf.ztor.int")
               lab <- "Correlation Coefficient"
            if (transf.char == "transf.ztor" || transf.char == "transf.ztor.int")
               lab <- "Correlation Coefficient"
         }
      }
      ######################################################################
      if (measure == "PCOR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Partial Correlation Coefficient"
         } else {
            lab <- "Transformed Partial Correlation Coefficient"
         }
      }
      if (measure == "ZPCOR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Fisher's z Transformed Partial Correlation Coefficient"
         } else {
            lab <- "Transformed Fisher's z Transformed Partial Correlation Coefficient"
            if (atransf.char == "transf.ztor" || atransf.char == "transf.ztor.int")
               lab <- "Partial Correlation Coefficient"
            if (transf.char == "transf.ztor" || transf.char == "transf.ztor.int")
               lab <- "Partial Correlation Coefficient"
         }
      }
      if (measure == "SPCOR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Semi-Partial Correlation Coefficient"
         } else {
            lab <- "Transformed Semi-Partial Correlation Coefficient"
         }
      }
      ######################################################################
      if (measure == "PR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Proportion"
         } else {
            lab <- "Transformed Proportion"
         }
      }
      if (measure == "PLN") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Proportion"
         } else {
            lab <- "Transformed Log Proportion"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Proportion (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Proportion"
         }
      }
      if (measure == "PLO") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Odds"
         } else {
            lab <- "Transformed Log Odds"
            if (atransf.char == "transf.ilogit" || atransf.char == "transf.ilogit.int" || atransf.char == "plogis")
               lab <- "Proportion (logit scale)"
            if (transf.char == "transf.ilogit" || transf.char == "transf.ilogit.int" || transf.char == "plogis")
               lab <- "Proportion"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Odds (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Odds"
         }
      }
      if (measure == "PAS") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Arcsine Transformed Proportion"
         } else {
            lab <- "Transformed Arcsine Transformed Proportion"
            if (atransf.char == "transf.iarcsin" || atransf.char == "transf.iarcsin.int")
               lab <- "Proportion (arcsine scale)"
            if (transf.char == "transf.iarcsin" || transf.char == "transf.iarcsin.int")
               lab <- "Proportion"
         }
      }
      if (measure == "PFT") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Double Arcsine Transformed Proportion"
         } else {
            lab <- "Transformed Double Arcsine Transformed Proportion"
            if (atransf.char == "transf.ipft.hm")
               lab <- "Proportion"
            if (transf.char == "transf.ipft.hm")
               lab <- "Proportion"
         }
      }
      ######################################################################
      if (measure == "IR") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Incidence Rate"
         } else {
            lab <- "Transformed Incidence Rate"
         }
      }
      if (measure == "IRLN") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Incidence Rate"
         } else {
            lab <- "Transformed Log Incidence Rate"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Incidence Rate (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Incidence Rate"
         }
      }
      if (measure == "IRS") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Square Root Transformed Incidence Rate"
         } else {
            lab <- "Transformed Square Root Transformed Incidence Rate"
            if (atransf.char == "transf.isqrt" || atransf.char == "transf.isqrt.int")
               lab <- "Incidence Rate (square root scale)"
            if (transf.char == "transf.isqrt" || transf.char == "transf.isqrt.int")
               lab <- "Incidence Rate"
         }
      }
      if (measure == "IRFT") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Freeman-Tukey Transformed Incidence Rate"
         } else {
            lab <- "Transformed Freeman-Tukey Transformed Incidence Rate"
         }
      }
      ######################################################################
      if (measure == "MN") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Mean"
         } else {
            lab <- "Transformed Mean"
         }
      }
      if (measure == "MNLN") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Mean"
         } else {
            lab <- "Transformed Log Mean"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Mean (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Mean"
         }
      }
      if (measure == "CVLN") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Coefficient of Variation"
         } else {
            lab <- "Transformed Log Coefficient of Variation"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Coefficient of Variation (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Coefficient of Variation"
         }
      }
      if (measure == "SDLN") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Standard Deviation"
         } else {
            lab <- "Transformed Log Standard Deviation"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Standard Deviation (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Standard Deviation"
         }
      }
      ######################################################################
      if (measure == "MC") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Mean Change"
         } else {
            lab <- "Transformed Mean Change"
         }
      }
      if (is.element(measure, c("SMCC","SMCR","SMCRH"))) {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Standardized Mean Change"
         } else {
            lab <- "Transformed Standardized Mean Change"
         }
      }
      if (measure == "ROMC") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Ratio of Means"
         } else {
            lab <- "Transformed Log Ratio of Means"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Ratio of Means (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Ratio of Means"
         }
      }
      if (measure == "CVRC") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Coefficient of Variation Ratio"
         } else {
            lab <- "Transformed Log Coefficient of Variation Ratio"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Coefficient of Variation Ratio (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Coefficient of Variation Ratio"
         }
      }
      if (measure == "VRC") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Log Variability Ratio"
         } else {
            lab <- "Transformed Log Variability Ratio"
            if (atransf.char == "exp" || atransf.char == "transf.exp.int")
               lab <- "Variability Ratio (log scale)"
            if (transf.char == "exp" || transf.char == "transf.exp.int")
               lab <- "Variability Ratio"
         }
      }
      ######################################################################
      if (measure == "ARAW") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Coefficient alpha"
         } else {
            lab <- "Transformed Coefficient alpha"
         }
      }
      if (measure == "AHW") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Transformed Coefficient alpha"
         } else {
            lab <- "Transformed Coefficient alpha"
            if (atransf.char == "transf.iahw")
               lab <- "Coefficient alpha"
            if (transf.char == "transf.iahw")
               lab <- "Coefficient alpha"
         }
      }
      if (measure == "ABT") {
         if (transf.char == "FALSE" && atransf.char == "FALSE") {
            lab <- "Transformed Coefficient alpha"
         } else {
            lab <- "Transformed Coefficient alpha"
            if (atransf.char == "transf.iabt")
               lab <- "Coefficient alpha"
            if (transf.char == "transf.iabt")
               lab <- "Coefficient alpha"
         }
      }
      ######################################################################

   }

   return(lab)

}

############################################################################

### density of non-central hypergeometric distribution (based on Liao and Rosen, 2001) from MCMCpack
### Liao, J. G. & Rosen, O. (2001). Fast and stable algorithms for computing and sampling from the
### noncentral hypergeometric distribution. The American Statistician, 55, 366-369.

.dnoncenhypergeom <- function (x=NA, n1, n2, m1, psi) { ### x=ai, n1=ai+bi, n2=ci+di, m1=ai+ci, psi=ORi

   mstyle <- .get.mstyle("crayon" %in% .packages())

   mode.compute <- function(n1, n2, m1, psi, ll, uu) {
      a <- psi - 1
      b <- -((m1 + n1 + 2) * psi + n2 - m1)
      c <- psi * (n1 + 1) * (m1 + 1)
      q <- b + sign(b) * sqrt(b * b - 4 * a * c)
      q <- -q/2
      mode <- trunc(c/q)
      if (uu >= mode && mode >= ll)
         return(mode)
      else return(trunc(q/a))
   }
   r.function <- function(n1, n2, m1, psi, i) {
      (n1 - i + 1) * (m1 - i + 1)/i/(n2 - m1 + i) * psi
   }
   ll <- max(0, m1 - n2)
   uu <- min(n1, m1)

   if (n1 < 0 | n2 < 0)
      stop(mstyle$stop("'n1' or 'n2' negative in dnoncenhypergeom()."))

   if (m1 < 0 | m1 > (n1 + n2))
      stop(mstyle$stop("'m1' out of range in dnoncenhypergeom()."))

   if (psi <= 0)
      stop(mstyle$stop("'psi' [odds ratio] negative in dnoncenhypergeom()."))

   if (!is.na(x) & (x < ll | x > uu))
      stop(mstyle$stop("'x' out of bounds in dnoncenhypergeom()."))

   if (!is.na(x) & length(x) > 1)
      stop(mstyle$stop("'x' neither missing or scalar in dnoncenhypergeom()."))

   mode <- mode.compute(n1, n2, m1, psi, ll, uu)
   pi <- array(1, uu - ll + 1)
   shift <- 1 - ll

   if (mode < uu) {
      r1 <- r.function(n1, n2, m1, psi, (mode + 1):uu)
      pi[(mode + 1 + shift):(uu + shift)] <- cumprod(r1)
   }
   if (mode > ll) {
      r1 <- 1/r.function(n1, n2, m1, psi, mode:(ll + 1))
      pi[(mode - 1 + shift):(ll + shift)] <- cumprod(r1)
   }
   pi <- pi/sum(pi)
   if (is.na(x)) {
      return(cbind(ll:uu, pi))
   } else {
      return(pi[x + shift])
   }

}

############################################################################

### density of non-central hypergeometric distribution for fixed- and random/mixed-effects models

.dnchgi <- function(logOR, ai, bi, ci, di, mu.i, tau2, random, dnchgcalc, dnchgprec) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   k <- length(logOR)
   dnchgi <- rep(NA_real_, k)

   ### beyond these values, the results from dFNCHypergeo (from BiasedUrn package) become unstable

   pow <- 12

   logOR[logOR < log(10^-pow)] <- log(10^-pow)
   logOR[logOR > log(10^pow)]  <- log(10^pow)

   for (i in seq_len(k)) {

      ORi <- exp(logOR[i])

      if (dnchgcalc == "dnoncenhypergeom") {
         res <- try(.dnoncenhypergeom(x=ai, n1=ai+bi, n2=ci+di, m1=ai+ci, psi=ORi))
      } else {
         res <- try(BiasedUrn::dFNCHypergeo(x=ai, m1=ai+bi, m2=ci+di, n=ai+ci, odds=ORi, precision=dnchgprec))
      }

      if (inherits(res, "try-error")) {
         stop(mstyle$stop(paste0("Could not compute density of non-central hypergeometric distribution in study ", i, ".")))
      } else {
         dnchgi[i] <- res
      }

   }

   if (random)
      dnchgi <- dnchgi * dnorm(logOR, mu.i, sqrt(tau2))

   return(dnchgi)

}

############################################################################

### joint density of k non-central hypergeometric distributions for fixed- and random/mixed-effects models

.dnchg <- function(parms, ai, bi, ci, di, X.fit, random, verbose=FALSE, digits, dnchgcalc, dnchgprec, intCtrl) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   p    <- ncol(X.fit)
   k    <- length(ai)
   beta <- parms[seq_len(p)]                  ### first p elemenets in parms are the model coefficients
   tau2 <- ifelse(random, exp(parms[p+1]), 0) ### next value is tau^2 -- optimize over exp(tau^2) value or hold at 0 if random=FALSE
   mu.i <- X.fit %*% cbind(beta)

   lli  <- rep(NA_real_, k)

   if (!random) {

      for (i in seq_len(k)) {
         lli[i] <- log(.dnchgi(logOR=mu.i[i], ai=ai[i], bi=bi[i], ci=ci[i], di=di[i], random=random, dnchgcalc=dnchgcalc, dnchgprec=dnchgprec))
      }

      if (verbose)
         cat(mstyle$verbose(paste("ll =", .fcf(sum(lli), digits[["fit"]]), " ", .fcf(beta, digits[["est"]]), "\n")))

   }

   if (random) {

      for (i in seq_len(k)) {

         res <- try(integrate(.dnchgi, lower=intCtrl$lower, upper=intCtrl$upper, ai=ai[i], bi=bi[i], ci=ci[i], di=di[i], mu.i=mu.i[i], tau2=tau2, random=random, dnchgcalc=dnchgcalc, dnchgprec=dnchgprec, rel.tol=intCtrl$rel.tol, subdivisions=intCtrl$subdivisions, stop.on.error=FALSE), silent=!verbose)

         if (inherits(res, "try-error")) {
            stop(mstyle$stop(paste0("Could not integrate over density of non-central hypergeometric distribution in study ", i, ".")))
         } else {
            if (res$value > 0) {
               lli[i] <- log(res$value)
            } else {
               lli[i] <- -Inf
            }
         }

      }

      if (verbose)
         cat(mstyle$verbose(paste("ll = ", .fcf(sum(lli), digits[["fit"]]), " ", .fcf(tau2, digits[["var"]]), " ", .fcf(beta, digits[["est"]]), "\n")))

   }

   return(-sum(lli))

}

############################################################################

### -1 times the log likelihood (regular or restricted) for location-scale model

.ll.rma.ls <- function(par, yi, vi, X, Z, reml, k, pX, verbose, digits, REMLf, link) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   #beta  <- par[seq_len(pX)]
   #alpha <- par[-seq_len(pX)]

   alpha <- par

   ### compute predicted tau2 values

   if (link == "log")
      tau2 <- exp(c(Z %*% alpha))
   if (link == "identity")
      tau2 <- c(Z %*% alpha)

   if (any(tau2 < 0)) {

      llval <- -Inf

   } else {

      ### compute weights
      wi <- 1/(vi + tau2)

      ### when using this, the optimization only pertains to the parameter(s) in 'alpha', as 'beta' is then fully
      ### determined by the current value(s) of 'alpha'; this is actually also how the standard RE/ME model is fitted;
      ### but is this really the best way of doing this? one could also optimize over beta and alpha jointly
      W <- diag(wi, nrow=k, ncol=k)
      stXWX <- try(.invcalc(X=X, W=W, k=k), silent=TRUE)

      if (inherits(stXWX, "try-error")) {

         llval <- -Inf

      } else {

         beta <- stXWX %*% crossprod(X,W) %*% as.matrix(yi)

         ### compute residual sum of squares
         RSS <- sum(wi*(yi - X %*% beta)^2)

         ### log-likelihood (could leave out additive constants)
         if (!reml) {
            llval <- -1/2 * (k) * log(2*base::pi) - 1/2 * sum(log(vi + tau2)) - 1/2 * RSS
         } else {
            llval <- -1/2 * (k-pX) * log(2*base::pi) + ifelse(REMLf, 1/2 * determinant(crossprod(X), logarithm=TRUE)$modulus, 0) +
                     -1/2 * sum(log(vi + tau2)) - 1/2 * determinant(crossprod(X,W) %*% X, logarithm=TRUE)$modulus - 1/2 * RSS
         }

      }

   }

   if (verbose) {
      cat(mstyle$verbose(paste0("ll = ",          ifelse(is.na(llval), NA, formatC(llval, digits=digits[["fit"]], format="f", flag=" ")), "  ")))
      cat(mstyle$verbose(paste0("alpha = ", paste(ifelse(is.na(alpha), NA, formatC(alpha, digits=digits[["est"]], format="f", flag=" ")), collapse=" "))))
      cat("\n")
   }

   return(-1 * llval)

}

############################################################################

### function to compute the tetrachoric correlation coefficient and its sampling variance

.rtet <- function(ai, bi, ci, di, maxcor=.9999) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (!requireNamespace("mvtnorm", quietly=TRUE))
      stop(mstyle$stop("Please install the 'mvtnorm' package to compute this measure."))

   fn <- function(par, ai, bi, ci, di, maxcor, fixcut=FALSE) {

      rho <- par[1]
      cut.row <- par[2]
      cut.col <- par[3]

      ### truncate rho values outside of specified bounds
      if (abs(rho) > maxcor)
         rho <- sign(rho) * maxcor

      ### to substitute fixed cut values
      if (fixcut) {
         cut.row <- qnorm((ai+bi)/ni)
         cut.col <- qnorm((ai+ci)/ni)
      }

      #       │ ci : di    #   ci = lo X and hi Y    di = hi X and hi Y
      # var Y │∙∙∙∙:∙∙∙∙   #
      #       │ ai : bi    #   ai = lo X and lo Y    bi = hi X and lo Y
      #       ┼─────────
      #          var X
      #
      #      lo   hi
      #    ┌────┬────┐
      # lo │ ai │ bi │
      #    ├────┼────┤ var Y
      # hi │ ci │ di │
      #    └────┴────┘
      #       var X

      R <- matrix(c(1,rho,rho,1), nrow=2, ncol=2)

      p.ai <- mvtnorm::pmvnorm(lower=c(-Inf,-Inf), upper=c(cut.col,cut.row), corr=R)
      p.bi <- mvtnorm::pmvnorm(lower=c(cut.col,-Inf), upper=c(+Inf,cut.row), corr=R)
      p.ci <- mvtnorm::pmvnorm(lower=c(-Inf,cut.row), upper=c(cut.col,+Inf), corr=R)
      p.di <- mvtnorm::pmvnorm(lower=c(cut.col,cut.row), upper=c(+Inf,+Inf), corr=R)

      ### in principle, should be able to compute these values with the following code, but this
      ### leads to more numerical instabilities when optimizing (possibly due to negative values)
      #p.y.lo <- pnorm(cut.row)
      #p.x.lo <- pnorm(cut.col)
      #p.ai <- mvtnorm::pmvnorm(lower=c(-Inf,-Inf), upper=c(cut.col,cut.row), corr=R)
      #p.bi <- p.y.lo - p.ai
      #p.ci <- p.x.lo - p.ai
      #p.di <- 1 - p.ai - p.bi - p.ci

      if (any(p.ai <= 0 || p.bi <= 0 || p.ci <= 0 || p.di <= 0)) {
         ll <- -Inf
      } else {
         ll <- ai*log(p.ai) + bi*log(p.bi) + ci*log(p.ci) + di*log(p.di)
      }

      return(-ll)

   }

   ni <- ai + bi + ci + di

   ### if one of the margins is equal to zero, then r_tet could in principle be equal to any value,
   ### but we define it here to be zero (presuming independence until evidence of dependence is found)
   ### but with infinite variance
   if ((ai + bi) == 0L || (ci + di) == 0L || (ai + ci) == 0L || (bi + di) == 0L)
      return(list(yi=0, vi=Inf))

   ### if bi and ci is zero, then r_tet must be +1 with zero variance
   if (bi == 0L && ci == 0L)
      return(list(yi=1, vi=0))

   ### if ai and di is zero, then r_tet must be -1 with zero variance
   if (ai == 0L && di == 0L)
      return(list(yi=-1, vi=0))

   ### cases where only one cell is equal to zero are handled further below

   ### in all other cases, first optimize over rho with cut values set to sample values
   ### use suppressWarnings() to suppress "NA/Inf replaced by maximum positive value" warnings
   res <- try(suppressWarnings(optimize(fn, interval=c(-1,1), ai=ai, bi=bi, ci=ci, di=di, maxcor=maxcor, fixcut=TRUE)), silent=TRUE)

   ### check for non-convergence
   if (inherits(res, "try-error")) {
      warning(mstyle$warning("Could not estimate tetrachoric correlation coefficient."))
      return(list(yi=NA, vi=NA))
   }

   ### then use the value as the starting point and maximize over rho and the cut values
   ### (Nelder-Mead seems to do fine here; using L-BFGS-B doesn't seems to improve on this)
   res <- try(optim(par=c(res$minimum,qnorm((ai+bi)/ni),qnorm((ai+ci)/ni)), fn, ai=ai, bi=bi, ci=ci, di=di, maxcor=maxcor, fixcut=FALSE, hessian=TRUE), silent=TRUE)
   #res <- try(optim(par=c(res$minimum,qnorm((ai+bi)/ni),qnorm((ai+ci)/ni)), fn, method="L-BFGS-B", lower=c(-1,-Inf,-Inf), upper=c(1,Inf,Inf), ai=ai, bi=bi, ci=ci, di=di, maxcor=maxcor, fixcut=FALSE, hessian=TRUE), silent=TRUE)

   ### check for non-convergence
   if (inherits(res, "try-error")) {
      warning(mstyle$warning("Could not estimate tetrachoric correlation coefficient."))
      return(list(yi=NA, vi=NA))
   }

   ### take inverse of hessian and extract variance for estimate
   ### (using hessian() seems to lead to more problems, so stick with hessian from optim())
   vi <- try(chol2inv(chol(res$hessian))[1,1], silent=TRUE)
   #res$hessian <- try(chol2inv(chol(numDeriv::hessian(fn, x=res$par, ai=ai, bi=bi, ci=ci, di=di, maxcor=maxcor, fixcut=FALSE))), silent=TRUE)

   ### check for problems with computing the inverse
   if (inherits(vi, "try-error")) {
      warning(mstyle$warning("Could not estimate sampling variance of tetrachoric correlation coefficient."))
      vi <- NA
   }

   ### extract estimate
   yi <- res$par[1]

   ### but if bi or ci is zero, then r_tet must be +1
   if (bi == 0 || ci == 0)
      yi <- 1

   ### but if ai or di is zero, then r_tet must be -1
   if (ai == 0 || di == 0)
      yi <- -1

   ### note: what is the right variance when there is one zero cell?
   ### vi as estimated gets smaller as the table becomes more and more like
   ### a table with 0 diagonal/off-diagonal, which intuitively makes sense

   ### return estimate and sampling variance (and SE)
   return(list(yi=yi, vi=vi, sei=sqrt(vi)))

   ### Could consider implementing the Fisher scoring algorithm; first derivatives and
   ### elements of the information matrix are given in Tallis (1962). Could also consider
   ### estimating the variance from the inverse of the information matrix. But constructing
   ### the information matrix takes a bit of extra work and it is not clear to me how to
   ### handle estimated cell probabilities that go to zero here.

}

############################################################################

### function to calculate the Gaussian hypergeometric (Hypergeometric2F1) function

.Fcalc <- function(a, b, g, x) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (!requireNamespace("gsl", quietly=TRUE))
      stop(mstyle$stop("Please install the 'gsl' package to use measure='UCOR'."))

   k.g <- length(g)
   k.x <- length(x)
   k   <- max(k.g, k.x)

   res <- rep(NA_real_, k)

   if (k.g == 1)
      g <- rep(g, k)
   if (k.x == 1)
      x <- rep(x, k)

   if (length(g) != length(x))
      stop(mstyle$stop("Length of 'g' and 'x' arguments is not the same."))

   for (i in seq_len(k)) {

      if (!is.na(g[i]) && !is.na(x[i]) && g[i] > (a+b)) {
         res[i] <- gsl::hyperg_2F1(a, b, g[i], x[i])
      } else {
         res[i] <- NA
      }

   }

   return(res)

}

############################################################################

### pdf of SMD (with or without bias correction)

.dsmd <- function(x, n1, n2, theta, correct=TRUE, warn=FALSE) {

   nt <- n1 * n2 / (n1 + n2)
   m  <- n1 + n2 - 2

   if (correct) {
      cm <- .cmicalc(m)
   } else {
      cm <- 1
   }

   if (warn) {
      res <- dt(x * sqrt(nt) / cm, df = m, ncp = sqrt(nt) * theta) * sqrt(nt) / cm
   } else {
      res <- suppressWarnings(dt(x * sqrt(nt) / cm, df = m, ncp = sqrt(nt) * theta) * sqrt(nt) / cm)
   }

   return(res)

}

#integrate(function(x) .dsmd(x, n1=4, n2=4, theta=.5), lower=-Inf, upper=Inf)
#integrate(function(x) x*.dsmd(x, n1=4, n2=4, theta=.5), lower=-Inf, upper=Inf)

### pdf of COR

.dcor <- function(x, n, rho) {

   x[x < -1] <- NA
   x[x >  1] <- NA

   ### only accurate for n >= 5
   n[n <= 4] <- NA

   ### calculate density
   res <- exp(log(n-2) + lgamma(n-1) + (n-1)/2 * log(1 - rho^2) + (n-4)/2 * log(1 - x^2) -
          1/2 * log(2*base::pi) - lgamma(n-1/2) - (n-3/2) * log(1 - rho*x)) *
          .Fcalc(1/2, 1/2, n-1/2, (rho*x + 1)/2)

   ### make sure that density is 0 for r = +-1
   res[abs(x) == 1] <- 0

   return(res)

}

#integrate(function(x) .dcor(x, n=5, rho=.8), lower=-1, upper=1)
#integrate(function(x) x*.dcor(x, n=5, rho=.8), lower=-1, upper=1) ### should not be rho due to bias!
#integrate(function(x) x*.Fcalc(1/2, 1/2, (5-2)/2, 1-x^2)*.dcor(x, n=5, rho=.8), lower=-1, upper=1) ### should be ~rho

### pdf of ZCOR

.dzcor <- function(x, n, rho, zrho) {

   ### only accurate for n >= 5
   n[n <= 4] <- NA

   ### if rho is missing, then back-transform zrho value(s)
   if (missing(rho))
      rho <- tanh(zrho)

   ### copy x to z and back-transform z values (so x = correlation)
   z <- x
   x <- tanh(z)

   ### calculate density
   res <- exp(log(n-2) + lgamma(n-1) + (n-1)/2 * log(1 - rho^2) + (n-4)/2 * log(1 - x^2) -
          1/2 * log(2*base::pi) - lgamma(n-1/2) - (n-3/2) * log(1 - rho*x) +
          log(4) + 2*z - 2*log(exp(2*z) + 1)) *
          .Fcalc(1/2, 1/2, n-1/2, (rho*x + 1)/2)

   ### make sure that density is 0 for r = +-1
   res[abs(x) == 1] <- 0

   return(res)

}

#integrate(function(x) .dzcor(x, n=5, rho=.8), lower=-100, upper=100)
#integrate(function(x) x*.dzcor(x, n=5, rho=.8), lower=-100, upper=100)

############################################################################

### function that prints the model fitting time

.print.time <- function(x) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   hours   <- floor(x/60/60)
   minutes <- floor(x/60) - hours*60
   seconds <- round(x - minutes*60 - hours*60*60, ifelse(x > 60, 0, 2))

   cat("\n")
   cat(mstyle$message(paste("Processing time:", hours, ifelse(hours == 0 || hours > 1, "hours,", "hour,"), minutes, ifelse(minutes == 0 || minutes > 1, "minutes,", "minute,"), seconds, ifelse(x < 60 || seconds == 0 || seconds > 1, "seconds", "second"))))
   cat("\n")

}

############################################################################

### stuff related to colored/styled output

.get.mstyle <- function(withcrayon) {

   if (withcrayon) {

      if (exists(".mstyle")) {
         .mstyle <- get(".mstyle")
         if (!is.list(.mstyle))
            .mstyle <- list(.mstyle)
      } else {
         .mstyle <- list()
      }

      if (is.null(.mstyle$section)) {
         section <- crayon::bold
      } else {
         section <- .mstyle$section
      }
      if (is.null(.mstyle$header)) {
         header <- crayon::underline
      } else {
         header <- .mstyle$header
      }
      if (is.null(.mstyle$body)) {
         body <- crayon::reset
      } else {
         body <- .mstyle$body
      }
      if (is.null(.mstyle$text)) {
         text <- crayon::reset
      } else {
         text <- .mstyle$text
      }
      if (is.null(.mstyle$result)) {
         result <- crayon::reset
      } else {
         result <- .mstyle$result
      }
      if (is.null(.mstyle$stop)) {
         stop <- crayon::combine_styles(crayon::red, crayon::bold)
      } else {
         stop <- .mstyle$stop
      }
      if (is.null(.mstyle$warning)) {
         warning <- crayon::yellow
      } else {
         warning <- .mstyle$warning
      }
      if (is.null(.mstyle$message)) {
         message <- crayon::green
      } else {
         message <- .mstyle$message
      }
      if (is.null(.mstyle$verbose)) {
         verbose <- crayon::cyan
      } else {
         verbose <- .mstyle$verbose
      }
      if (is.null(.mstyle$legend)) {
         legend <- crayon::silver
      } else {
         legend <- .mstyle$legend
      }

   } else {

      tmp <- function(...) paste0(...)
      section <- tmp
      header  <- tmp
      body    <- tmp
      text    <- tmp
      result  <- tmp
      stop    <- tmp
      warning <- tmp
      message <- tmp
      verbose <- tmp
      legend  <- tmp

   }

   return(list(section=section, header=header, body=body, text=text, result=result, stop=stop, warning=warning, message=message, verbose=verbose, legend=legend))

}

.print.output <- function(x, mstyle) {

   if (missing(mstyle)) {
      for (i in seq_along(x)) {
         cat(x[i], "\n")
      }
   } else {
      for (i in seq_along(x)) {
         cat(mstyle(x[i]), "\n")
      }
   }

}

.print.table <- function(x, mstyle) {

   is.header <- !grepl(" [-0-9]", x)

   for (i in seq_along(x)) {
      if (is.header[i]) {
         x[i] <- trimws(x[i], which="right")
         x[i] <- mstyle$header(x[i])
      } else {
         x[i] <- mstyle$body(x[i])
      }
      cat(x[i], "\n")
   }

}

############################################################################

.set.digits <- function(digits, dmiss) {

   res <- c(est=4, se=4, test=4, pval=4, ci=4, var=4, sevar=4, fit=4, het=4)

   if (exists(".digits")) {
      .digits <- get(".digits")
      if (is.null(names(.digits)) && length(.digits) == 1) {
         # if .digits is a single unnamed scalar, set all digit values to that value
         res <- c(est=.digits, se=.digits, test=.digits, pval=.digits, ci=.digits, var=.digits, sevar=.digits, fit=.digits, het=.digits)
      } else if (any(names(.digits) != "") && any(names(.digits) == "")) {
         # if .digits has (at least) one unnamed element, use it to set all unnamed elements to that digits value
         pos <- pmatch(names(.digits), names(res))
         res[c(na.omit(pos))] <- .digits[!is.na(pos)]
         otherval <- .digits[names(.digits) == ""][1]
         res[(1:9)[-c(na.omit(pos))]] <- otherval
      } else {
         pos <- pmatch(names(.digits), names(res))
         res[c(na.omit(pos))] <- .digits[!is.na(pos)]
      }
   }

   if (!dmiss) {
      if (is.null(names(digits))) {
         res <- c(est=digits[[1]], se=digits[[1]], test=digits[[1]], pval=digits[[1]], ci=digits[[1]], var=digits[[1]], sevar=digits[[1]], fit=digits[[1]], het=digits[[1]])
      } else {
         pos <- pmatch(names(digits), names(res))
         res[c(na.omit(pos))] <- digits[!is.na(pos)]
      }
   }

   res

}

.get.digits <- function(digits, xdigits, dmiss) {

   res <- xdigits

   if (exists(".digits")) {
      .digits <- get(".digits")
      pos <- pmatch(names(.digits), names(res))
      res[c(na.omit(pos))] <- .digits[!is.na(pos)]
   }

   if (!dmiss) {
      if (is.null(names(digits))) {
         res <- c(est=digits[[1]], se=digits[[1]], test=digits[[1]], pval=digits[[1]], ci=digits[[1]], var=digits[[1]], sevar=digits[[1]], fit=digits[[1]], het=digits[[1]])
      } else {
         pos <- pmatch(names(digits), names(res))
         res[c(na.omit(pos))] <- digits[!is.na(pos)]
      }
   }

   ### so we can still print objects created with older metafor versions (where xdigit will be just an unnamed scalar)
   if (length(res) == 1 && is.null(names(res)))
      res <- c(est=res[[1]], se=res[[1]], test=res[[1]], pval=res[[1]], ci=res[[1]], var=res[[1]], sevar=res[[1]], fit=res[[1]], het=res[[1]])

   res
}

############################################################################

### check if x is logical and TRUE/FALSE (NAs and NULL always evaluate as FALSE)

.isTRUE <- function(x)
   !is.null(x) && is.logical(x) && !is.na(x) && x

.isFALSE <- function(x)
   !is.null(x) && is.logical(x) && !is.na(x) && !x

############################################################################

### to register getfit method for 'rma.uni' and 'rma.mv' objects: eval(metafor:::.glmulti)

.glmulti <- parse(text="

if (!(\"glmulti\" %in% .packages()))
   stop(\"Need to load the 'glmulti' package first to use this code.\")

setOldClass(\"rma.uni\")

setMethod(\"getfit\", \"rma.uni\", function(object, ...) {
   if (object$test==\"z\") {
      cbind(estimate=coef(object), se=sqrt(diag(vcov(object))), df=Inf)
   } else {
      cbind(estimate=coef(object), se=sqrt(diag(vcov(object))), df=object$k-object$p)
   }
})

setOldClass(\"rma.mv\")

setMethod(\"getfit\", \"rma.mv\", function(object, ...) {
   if (object$test==\"z\") {
      cbind(estimate=coef(object), se=sqrt(diag(vcov(object))), df=Inf)
   } else {
      cbind(estimate=coef(object), se=sqrt(diag(vcov(object))), df=object$k-object$p)
   }
})

setOldClass(\"rma.glmm\")

setMethod(\"getfit\", \"rma.glmm\", function(object, ...) {
   if (object$test==\"z\") {
      cbind(estimate=coef(object), se=sqrt(diag(vcov(object))), df=Inf)
   } else {
      cbind(estimate=coef(object), se=sqrt(diag(vcov(object))), df=object$k-object$p)
   }
})

")

### helper functions to make MuMIn work together with metafor

.MuMIn <- parse(text="

makeArgs.rma <- function (obj, termNames, comb, opt, ...) {
   ret <- MuMIn:::makeArgs.default(obj, termNames, comb, opt)
   names(ret)[1L] <- \"mods\"
   ret
}

coefTable.rma <- function (model, ...) {
  MuMIn:::.makeCoefTable(model$b, model$se, coefNames = rownames(model$b))
}

")

### helper functions to make mice work together with metafor

.mice <- parse(text="

glance.rma <- function (x, ...)
   data.frame(df.residual=df.residual(x))

tidy.rma <- function (x, ...) {
   ret <- coef(summary(x))
   colnames(ret)[2] <- \"std.error\"
   ret$term <- rownames(ret)
   return(ret)
}

")

############################################################################

### shorten a string vector so that elements remain distinguishable

.shorten <- function(x, minlen) {

   y <- x

   x <- c(na.omit(x))

   n <- length(unique(x))

   maxlen <- max(nchar(unique(x)))

   for (l in 1:maxlen) {
      tab <- table(x, substr(x, 1, l))
      if (nrow(tab) == n && ncol(tab) == n && sum(tab[upper.tri(tab)]) == 0 && sum(tab[lower.tri(tab)]) == 0)
         break
   }

   if (!missing(minlen) && l < minlen) {
      if (minlen > maxlen)
         minlen <- maxlen
      l <- minlen
   }

   return(substr(y, 1, l))

}

############################################################################
