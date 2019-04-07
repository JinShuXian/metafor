print.regtest.rma <- function(x, digits=x$digits, ret.fit=x$ret.fit, ...) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   if (!inherits(x, "regtest.rma"))
      stop(mstyle$stop("Argument 'x' must be an object of class \"regtest.rma\"."))

   digits <- .get.digits(digits=digits, xdigits=x$digits, dmiss=FALSE)

   if (!exists(".rmspace"))
      cat("\n")

   cat(mstyle$section("Regression Test for Funnel Plot Asymmetry"))
   cat("\n\n")
   if (x$model == "lm") {
      cat(mstyle$text("model:     weighted regression with multiplicative dispersion"))
   } else {
      cat(mstyle$text(paste("model:    ", ifelse(x$method=="FE", "fixed-effects", "mixed-effects"), "meta-regression model")))
   }
   cat("\n")
   if (x$predictor == "sei")
      cat(mstyle$text("predictor: standard error"))
   if (x$predictor == "vi")
      cat(mstyle$text("predictor: sampling variance"))
   if (x$predictor == "ni")
      cat(mstyle$text("predictor: sample size"))
   if (x$predictor == "ninv")
      cat(mstyle$text("predictor: inverse of the sample size"))
   if (x$predictor == "sqrtni")
      cat(mstyle$text("predictor: square root sample size"))
   if (x$predictor == "sqrtninv")
      cat(mstyle$text("predictor: inverse of the square root sample size"))

   cat("\n")

   if (ret.fit) {
      if (exists(".rmspace"))
         cat("\n")
      print(x$fit)
      if (exists(".rmspace"))
         cat("\n")
   } else {
      cat("\n")
   }

   cat(mstyle$text("test for funnel plot asymmetry: "))
   if (is.na(x$dfs)) {
      cat(mstyle$result(paste0("z = ", .fcf(x$zval, digits[["test"]]), ", p ", .pval(x$pval, digits=digits[["pval"]], showeq=TRUE, sep=" "))))
   } else {
      cat(mstyle$result(paste0("t = ", .fcf(x$zval, digits[["test"]]), ", df = ", x$dfs, ", p ", .pval(x$pval, digits=digits[["pval"]], showeq=TRUE, sep=" "))))
   }
   cat("\n")
   #cat("H0: coefficient for predictor is equal to 0\n\n")

   if (!exists(".rmspace"))
      cat("\n")

   invisible()

}
