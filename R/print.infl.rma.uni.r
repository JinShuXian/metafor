print.infl.rma.uni <- function(x, digits=x$digits, ...) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (!inherits(x, "infl.rma.uni"))
      stop(mstyle$stop("Argument 'x' must be an object of class \"infl.rma.uni\"."))

   digits <- .get.digits(digits=digits, xdigits=x$digits, dmiss=FALSE)

   if (x$p == 1) {

      x <- list(rstudent=x$inf$rstudent, dffits=x$inf$dffits, cook.d=x$inf$cook.d, cov.r=x$inf$cov.r,
                tau2.del=x$inf$tau2.del, QE.del=x$inf$QE.del, hat=x$inf$hat, weight=x$inf$weight,
                dfbs=x$dfbs[[1]], inf=x$inf$inf, slab=x$inf$slab, digits=digits)
      class(x) <- "list.rma"

   } else {

      x <- x[1:2]
      x$inf[["digits"]]  <- digits
      x$dfbs[["digits"]] <- digits
      attr(x$inf,  ".rmspace") <- TRUE
      attr(x$dfbs, ".rmspace") <- TRUE

   }

   print(x)

}
