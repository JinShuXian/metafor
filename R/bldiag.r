bldiag <- function(...) {

   mlist <- list(...)

   ### handle case in which a list of matrices is given
   if (length(mlist)==1L && is.list(mlist[[1]]))
      mlist <- unlist(mlist, recursive=FALSE)

   ### make sure each element is a matrix (so that bldiag(matrix(1, nrow=3, ncol=3), 2) also works)
   mlist <- lapply(mlist, function(x) if (inherits(x, "matrix")) x else diag(x, nrow=length(x), ncol=length(x)))

   csdim <- rbind(c(0,0), apply(sapply(mlist,dim), 1, cumsum)) ### consider using rowCumsums() from matrixStats package

   out  <- array(0, dim=csdim[length(mlist) + 1,])
   add1 <- matrix(rep(1:0,2), ncol=2)

   for (i in seq(along.with=mlist)) {

      indx <- apply(csdim[i:(i+1),] + add1, 2, function(x) x[1]:x[2])

      if (is.null(dim(indx))) {                 ### non-square matrix
         out[indx[[1]],indx[[2]]] <- mlist[[i]]
      } else {                                  ### square matrix
         out[indx[,1],indx[,2]] <- mlist[[i]]
      }

   }

   return(out)

}
