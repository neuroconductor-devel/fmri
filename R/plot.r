plot.fmrisegment <- function(x,
		                      anatomic = NULL,
							  slice = 1,
							  view = c( "axial", "coronal", "sagittal"),
							  zlim.u = NULL,
							  zlim.o = NULL,
							  col.o = c( rainbow( 64, start = 2/6, end = 4/6), rainbow( 64, start = 0, end = 1/6)),
		                      col.u = grey(0:127/127),
							  verbose = FALSE,
							  ...) {

   if (verbose) cat( "plot.fmrisegment: entering function\n")
   view <- match.arg(view)

   if (is.null(anatomic)) anatomic <- array( 0, dim = x$dim[1:3])

   if ("fmridata" %in% class(anatomic)) {

	   if (verbose) cat( "plot.fmrisegment: calculate exact overlay\n")
	   img <- show.segmentslice(x, anatomic, slice =  slice, view = view, col.u = col.u, col.o = col.o, zlim.u, zlim.o)

   } else {
	   if ( any(dim(anatomic) != dim(x$cbeta))) {
		   stop( "dimension of anatomic does not match overlay data!")
	   } else {

		   if (verbose) cat( "plot.fmrisegment: perform simple overlay\n")
		   ## select correct overlay slice according to view
		   if (view == "axial") {
			   imgdata.o <- x$cbeta[ , , slice]
			   imgdata.o[ x$segm[ , , slice] == 0] <- NA ## no significant voxel
			   imgdata.u <- anatomic[ , , slice]
			   aspect <- x$delta[2]/x$delta[1]
		   } else if (view == "coronal") {
			   imgdata.o <- x$cbeta[ , slice, ]
			   imgdata.o[ x$segm[ , slice, ] == 0] <- NA ## no significant voxel
			   imgdata.u <- anatomic[ , slice, ]
			   aspect <- x$delta[3]/x$delta[1]
		   } else if (view == "sagittal") {
			   imgdata.o <- x$cbeta[ slice, , ]
			   imgdata.o[ x$segm[ slice, , ] == 0] <- NA ## no significant voxel
			   imgdata.u <- anatomic[ slice, , ]
			   aspect <- x$delta[3]/x$delta[2]
		   }

		   ## user defined data limits to scale the image contrast
		   ## not sure whether this is what the user wants
		   if (any(!is.na(imgdata.o))) {
			   if (is.null(zlim.o)) {
				   zlim.o <- range( abs(imgdata.o), na.rm = TRUE)
			   } else {
				   if (length(zlim.o) != 2) stop("zlim.o not length 2")
				   if (zlim.o[2] < zlim.o[1]) stop("zlim.o[2] < zlim.o[1]")
				   imgdata.o[imgdata.o > zlim.o[2]] <- zlim.o[2]
				   imgdata.o[imgdata.o < zlim.o[1]] <- zlim.o[1]
				   imgdata.o[imgdata.o < -zlim.o[2]] <- -zlim.o[2]
				   imgdata.o[imgdata.o > -zlim.o[1]] <- -zlim.o[1]
			   }
		   }
		   if (is.null(zlim.u)) {
			   zlim.u <- range(imgdata.u, na.rm = TRUE)
		   } else {
			   if (length(zlim.u) != 2) stop("zlim.u not length 2")
			   if (zlim.u[2] < zlim.u[1]) stop("zlim.u[2] < zlim.u[1]")
			   imgdata.u[imgdata.u > zlim.u[2]] <- zlim.u[2]
			   imgdata.u[imgdata.u < zlim.u[1]] <- zlim.u[1]
		   }

		   ## create the break points for the color scale
		   if (any(!is.na(imgdata.o))) {
			   zlim.o <- quantile( abs(imgdata.o), c( 0, 0.9, 1), na.rm = TRUE)
			   breaks.o <- c( -zlim.o[3], seq( -zlim.o[2], -zlim.o[1], length = 63), 0, seq( zlim.o[1], zlim.o[2], length = 63), zlim.o[3])
		   }
		   breaks.u <- seq( zlim.u[1], zlim.u[2], length = 129)

		   ## plot the image
		   graphics::image(1:dim(imgdata.u)[1], 1:dim(imgdata.u)[2], imgdata.u, col = col.u, asp = aspect, axes = FALSE, xlab = "",	ylab = "")
		   if (any(!is.na(imgdata.o))) {
			   graphics::image(1:dim(imgdata.o)[1], 1:dim(imgdata.o)[2], imgdata.o, asp = aspect, col = col.o, breaks = breaks.o, add = TRUE)
		   }

		   ## finally create img for adimpro
		   img <- array(0, dim = c( dim(imgdata.u), 3))
		   for (i in 1:dim(imgdata.u)[1]) {
			   for (j in 1:dim(imgdata.u)[2]) {
				   if (!is.na(imgdata.o[ i, j])) { # use overlay
					   ind <- (0:128)[imgdata.o[ i, j] < breaks.o]
					   level <- ifelse(length(ind) == 0, 128, min(ind))
					   img[ i, j, ] <- as.integer( col2rgb( col.o[level])) * 256
				   } else { # use underlay
					   ind <- (0:128)[imgdata.u[ i, j] < breaks.u]
					   level <- ifelse(length(ind) == 0, 128, min(ind))
					   img[ i, j, ] <- as.integer( col2rgb( col.u[level])) * 256
				   }
			   }
		   }

	   }
   }

   if (verbose) cat( "plot.fmrisegment: exiting function\n")
   return(invisible(img))

}

# can be called from fmri.gui or the command line (by plot)
# calls fmri.view2d or fmri.view3d with the fitting data
plot.fmridata <- function(x, anatomic = NULL , maxpvalue = 0.05, spm = TRUE,
                          pos = c(-1,-1,-1), type="slice", slice =  1, view = "axial",
                          zlim.u = NULL, zlim.o = NULL, col.o = heat.colors(256),
                          col.u = grey(0:255/255), cutOff = c(0,1),...) {
  if(!requireNamespace("tcltk",quietly=TRUE))
      stop("package tcltk not found. Please install from cran.r-project.org")
  if (!requireNamespace("tkrplot",quietly=TRUE))
      stop("package tkrplot not found. Please install from cran.r-project.org")
  cutOff[cutOff<0] <- 0
  cutOff[cutOff>1] <- 1
  if (cutOff[1] > cutOff[2]) cutOff[2] <- 1
  inputStuff <- list(anatomic,maxpvalue,cutOff)

  if ("fmripvalue" %in% class(x)) {
    if ("fmridata" %in% class(anatomic)) {
      img <- show.slice(x, anatomic, maxpvalue = maxpvalue, slice =  slice,
                        view = view, col.u, col.o, zlim.u, zlim.o)
      displayImage(img, ...)
      return(invisible(img))
    } else {
      signal <- x$pvalue
      cat("maxpvalue",maxpvalue,"\n")
      cat(sum(signal<maxpvalue),sum(signal<0.05),"mean signal",mean(signal),"\n")
      signal[signal > maxpvalue] <- 1
      cat(sum(signal<maxpvalue),"mean signal",mean(signal),"\n")
      signal[signal < 1e-10] <- 1e-10
      signal <- -log(signal)
      anatomic <- scaleAnatomic(anatomic,cutOff,dim(x$pvalue))
      # re-scale signal to 0.5 ... 1
      scale <- c(-log(maxpvalue),max(signal[is.finite(signal)]))
#      cat("scale",scale,"\n")
#      if (diff(scale)!=0) {
#        signal <- 0.5 + 0.5 * (signal - scale[1]) / diff(scale)
#      } else {
#        signal <- 0
#      }
#      # create an overlay
#      anatomic[signal >= 0.5] <- signal[signal >= 0.5]
#      anatomic[is.na(anatomic)] <- 0
#      anatomic[is.infinite(anatomic)] <- 0
      anatomic <- signalOverlay(signal,anatomic,scale)
      if (type == "3d" || type == "3D") {
        tt <- fmri.view3d(anatomic,col=mri.colors(255,255)$all,weights=x$weights,
                          scale=scale,scalecol=mri.colors(255,255)$col,
                          type= "pvalue",maxpvalue=maxpvalue,pos=pos)
      } else {
        posNew <- position(anatomic)
        fmri.view2d(anatomic,col=mri.colors(255,255)$all,weights=x$weights,scale=scale,
                    scalecol=mri.colors(255,255)$col,type= "pvalue",maxpvalue=maxpvalue,
                    posNew=position(anatomic),localx=x,inputStuff=inputStuff)
      }
    }
  } else if ("fmrispm" %in% class(x)) {
    signal <- if (spm) x$cbeta/sqrt(x$var) else x$cbeta
    # re-scale signal to 0 ... 1
    signal <- scaleSignal(signal,cutOff)
    if (type == "3d" || type == "3D") {
      if (spm) {
        tt <- fmri.view3d(signal$signal,col=mri.colors(255,255)$gray,weights=x$weights,
               scale=signal$scale,scalecol=mri.colors(255,255)$gray,type="spm",pos=pos)
      } else {
        quant <- qt(1-maxpvalue,
                 if(!is.null(x$df)) x$df else abs(diff(dim(attr(x, "design")))))
        tt <- fmri.view3d(signal$signal,sigma=sqrt(x$var),col=mri.colors(255,255)$gray,
                 weights=x$weights,scale=signal$scale,scalecol=mri.colors(255,255)$gray,
                 type="spm",hrf=x$hrf, quant = quant,pos=pos)
      }
    } else {
      fmri.view2d(signal$signal,col=mri.colors(255,255)$gray,weights=x$weights,
              scale=signal$scale,scalecol=mri.colors(255,255)$gray,type= "spm",
              maxpvalue=maxpvalue,posNew=position(x),localx=x,inputStuff=inputStuff)
    }
  } else if ("fmridata" %in% class(x)) {
    signal <- extract.data(x)
    signal <- scaleSignal(signal,cutOff)
    # re-scale signal to 0 ... 1
    if (type == "3d" || type == "3D") {
      tt <- fmri.view3d(signal$signal,col=mri.colors(255,255)$gray,weights=x$weights,
              scale=signal$scale,scalecol=mri.colors(255,255)$gray, type="data",pos=pos)
    } else {
      fmri.view2d(signal$signal,col=mri.colors(255,255)$gray, weights=x$weights,
                  scale=signal$scale,scalecol=mri.colors(255,255)$gray,type= "data",
                  maxpvalue=maxpvalue,posNew=position(x),localx=x,inputStuff=inputStuff)
    }
  } else {
    cat("Sorry, no plot for this class implemented\n
         Falling back to generic function, but this may fail!")
    plot(x)
  }
  if (exists("tt")) invisible(tt)
}

plot.fmripvalue.old <- function(x, template=NULL, mask=NULL,
                            view=c("axial","coronal","sagittal","orthographic"), slices=NULL, ncol=1, nrow=1, center=NULL, ...){
  # check arguments
  if(!view%in%c("axial","coronal","sagittal","orthographic")) stop("view needs to be 'axial', 'coronal', 'sagittal' or 'orthographic'")
  pvalue <- x$pvalue
	alpha <- x$alpha
  ddim <- dim(pvalue)
  if(is.null(template)) template <- pvalue
  if(any(ddim!=dim(template))) stop("template dimension does not match")
  if(is.null(mask)) mask <- array(TRUE,dim(pvalue))
  if(any(ddim!=dim(mask))) stop("mask dimension does not match")
  pvalue[pvalue>=alpha] <- NA
  pvalue[!mask] <- NA
	pvalue[pvalue<1e-10] <- 1e-10
  lpvalue <- -log(pvalue)
  if(view!="orthographic"&is.null(slices)){
    nslice <- ncol*nrow
    slices <- switch(view,
                     "sagittal"=sort(order(apply(lpvalue,1,sum,na.rm=TRUE),decreasing=TRUE)[1:nslice]),
                     "coronal"=sort(order(apply(lpvalue,2,sum,na.rm=TRUE),decreasing=TRUE)[1:nslice]),
                     "axial"=sort(order(apply(lpvalue,3,sum,na.rm=TRUE),decreasing=TRUE)[1:nslice]))
  }
  if(view=="orthographic"&is.null(center)){
    center <- c(order(apply(lpvalue,1,sum,na.rm=TRUE),decreasing=TRUE)[1],
                order(apply(lpvalue,2,sum,na.rm=TRUE),decreasing=TRUE)[1],
                order(apply(lpvalue,3,sum,na.rm=TRUE),decreasing=TRUE)[1])
    if(!mask[center[1],center[2],center[3]]) stop("Please specify center within brain mask\n")
  }
  n1 <- ddim[1]
  n2 <- ddim[2]
  n3 <- ddim[3]
  indx <- (1:n1)[apply(mask,1,any)]
  indy <- (1:n2)[apply(mask,2,any)]
  indz <- (1:n3)[apply(mask,3,any)]
  pvalue <- pvalue[indx,indy,indz]
  lpvalue <- lpvalue[indx,indy,indz]
  rlp <- range(lpvalue,na.rm=TRUE)
  template <- template[indx,indy,indz]
  n1 <- length(indx)
  n2 <- length(indy)
  n3 <- length(indz)
  if(view=="orthographic"){
    center[1] <- (1:n1)[indx==center[1]]
    center[2] <- (1:n2)[indy==center[2]]
    center[3] <- (1:n3)[indz==center[3]]
  } else {
    slices <- switch(view,
                     "sagittal"=slices[slices<=max(indx)],
                     "coronal"=slices[slices<=max(indy)],
                     "axial"=slices[slices<=max(indz)]
    )
    slices <- switch(view,
                     "sagittal"=slices-min(indx)+1,
                     "coronal"=slices-min(indy)+1,
                     "axial"=slices-min(indz)+1
    )
		nslice <- length(slices)
    nrow <- ceiling(nslice/ncol)
  }
  oldpar <- par(mar=c(2.5,2.5,2.5,.1),mgp=c(1.5,.5,0))
  if(view=="orthographic"){
		n12 <- max(n1,n2)
    wh <- 2*n1+n2+n12/8
    mat <- matrix(c(1,2,3,4),1,4)
    layout(mat,widths=c(n2,n1,n1,n12/8)/wh,
           heights=1)
    image(-indy[n2:1]*pdim[2],indz*pdim[3],template[center[1],n2:1,],col=grey(0:255/255),asp=TRUE,xlab="-yind")
    title("sagittal")
    lines(-indy[c(1,n2)]*pdim[2],rep(indz[center[3]]*pdim[3],2),col=2)
    lines(rep(-indy[center[2]]*pdim[2],2),indz[c(1,n3)]*pdim[3],col=2)
    image(-indy[n2:1]*pdim[2],indz*pdim[3],lpvalue[center[1],n2:1,],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
    image(indx*pdim[1],indz*pdim[3],template[,center[2],],col=grey(0:255/255),asp=TRUE)
    title("coronal")
    lines(indx[c(1,n1)]*pdim[1],rep(indz[center[3]]*pdim[3],2),col=2)
    lines(rep(indx[center[1]]*pdim[1],2),indz[c(1,n3)]*pdim[3],col=2)
    image(indx*pdim[1],indz*pdim[3],lpvalue[,center[2],],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
    image(indx*pdim[1],indy*pdim[2],template[,,center[3]],col=grey(0:255/255),asp=TRUE)
    title("axial")
    lines(indx[c(1,n1)]*pdim[1],rep(indy[center[2]]*pdim[2],2),col=2)
    lines(rep(indx[center[1]]*pdim[1],2),indy[c(1,n2)]*pdim[2],col=2)
    image(indx*pdim[1],indy*pdim[2],lpvalue[,,center[3]],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
    scalep <- seq(rlp[1],rlp[2],length=256)
    scalep <- t(matrix(scalep,length(scalep),10))
    image(1:10,scalep[1,],scalep,col=heat.colors(256),xaxt="n",xlab="",ylab="-log(pvalue)")
  } else {
    mat <- matrix(0,nrow,ncol+1)
    for(i in 1:nrow){
      mat[i,1:ncol] <- (i-1)*(ncol+1)+1:ncol
      mat[i,ncol+1] <- i*(ncol+1)
    }
    if(view=="sagittal"){
      widths <- c(rep(n2,ncol),n2/max(1,10-ncol))
      heights <- rep(n3,nrow)
    }
    if(view=="coronal"){
      widths <- c(rep(n1,ncol),n1/max(1,10-ncol))
      heights <- rep(n3,nrow)
    }
    if(view=="axial"){
      widths <- c(rep(n1,ncol),n1/max(1,10-ncol))
      heights <- rep(n2,nrow)
    }
    widths <- widths/sum(widths)
    heights <- heights/sum(heights)
    layout(mat,widths=widths,heights=heights)
    for(i in 1:nrow){
      for(j in 1:ncol){
        k <- (i-1)*ncol + j
        if(k>nslice) break
        if(view=="sagittal"){
          image(-indy[n2:1]*pdim[2],indz*pdim[3],template[slices[k],n2:1,],col=grey(0:255/255),asp=TRUE,xlab="-yind")
          title(paste("sagittal slice",indx[slices[k]]))
          image(-indy[n2:1]*pdim[2],indz*pdim[3],lpvalue[slices[k],n2:1,],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
        }
        if(view=="coronal"){
          image(indx*pdim[1],indz*pdim[3],template[,slices[k],],col=grey(0:255/255),asp=TRUE)
          title(paste("coronal slice",indy[slices[k]]))
          image(indx*pdim[1],indz*pdim[3],lpvalue[,slices[k],],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
        }
        if(view=="axial"){
          image(indx*pdim[1],indy*pdim[2],template[,,slices[k]],col=grey(0:255/255),asp=TRUE)
          title(paste("axial slice", indz[slices[k]]))
          image(indx*pdim[1],indy*pdim[2],lpvalue[,,slices[k]],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
        }
      }
      scalep <- seq(rlp[1],rlp[2],length=256)
      scalep <- t(matrix(scalep,length(scalep),10))
      image(1:10,scalep[1,],scalep,col=heat.colors(256),xaxt="n",xlab="",ylab="-log(pvalue)")
    }
    if(k>nslice) break
  }
  invisible(list(slices=slices,center=center))
}
getAlignedCoords <- function(spm,T1){
  if(class(T1)=="nifti"){
  qformcode <- spm$header$qformcode
  sformcode <- spm$header$sformcode
if(qformcode==1){
  qformcodeT1 <- T1@qform_code
  if(qformcodeT1!=1) stop(" can't realign with T1")
  if(T1@quatern_b!=spm$header$quaternb) stop("coordinate systems don't coincide")
  if(T1@quatern_c!=spm$header$quaternc) stop("coordinate systems don't coincide")
  if(T1@quatern_d!=spm$header$quaternd) stop("coordinate systems don't coincide")
  if(T1@qoffset_x!=spm$header$qoffsetx) stop("coordinate systems don't coincide")
  if(T1@qoffset_y!=spm$header$qoffsety) stop("coordinate systems don't coincide")
  if(T1@qoffset_z!=spm$header$qoffsetz) stop("coordinate systems don't coincide")
}
if(sformcode==1){
  sformcodeT1 <- T1@sform_code
  if(sformcodeT1!=1) stop(" can't realign with T1")
  if(any(T1@srow_x!=spm$header$srowx)) stop("coordinate systems don't coincide")
  if(any(T1@srow_y!=spm$header$srowy)) stop("coordinate systems don't coincide")
  if(any(T1@srow_z!=spm$header$srowz)) stop("coordinate systems don't coincide")
}
  pixdimT1 <- T1@pixdim
  pixdimspm <- spm$header$pixdim

  ixT1 <- round((1:spm$dim[1]-1/2)*pixdimspm[2]/pixdimT1[2]+1/2)
  iyT1 <- round((1:spm$dim[2]-1/2)*pixdimspm[3]/pixdimT1[3]+1/2)
  izT1 <- round((1:spm$dim[3]-1/2)*pixdimspm[4]/pixdimT1[4]+1/2)
  ixT1 <- ixT1[ixT1%in%1:T1@dim_[2]]
  iyT1 <- iyT1[iyT1%in%1:T1@dim_[3]]
  izT1 <- izT1[izT1%in%1:T1@dim_[4]]

  ixspm <- round((1:T1@dim_[2]-1/2)/pixdimspm[2]*pixdimT1[2]+1/2)
  iyspm <- round((1:T1@dim_[3]-1/2)/pixdimspm[3]*pixdimT1[3]+1/2)
  izspm <- round((1:T1@dim_[4]-1/2)/pixdimspm[4]*pixdimT1[4]+1/2)
  ixspm <- ixspm[ixspm%in%1:spm$dim[1]]
  iyspm <- iyspm[iyspm%in%1:spm$dim[2]]
  izspm <- izspm[izspm%in%1:spm$dim[3]]
  pdim <- T1@pixdim[2:4]
  } else {
    if(any(spm$dim[1:3]!=T1$dim[1:3])) stop(" can't realign with template")
    ixT1 <- ixspm <- 1:spm$dim[1]
    iyT1 <- iyspm <- 1:spm$dim[2]
    izT1 <- izspm <- 1:spm$dim[3]
    pdim <- spm$header$pixdim[2:4]
  }
  list(ixT1=ixT1, iyT1=iyT1, izT1=izT1, ixspm=ixspm, iyspm=iyspm, izspm=izspm, pixdim=pdim)
}

plot.fmripvalue <- function(x, template=NULL, mask=NULL,
                             view=c("axial","coronal","sagittal","orthographic"), slices=NULL, ncol=1, nrow=1, center=NULL, ...){
  # check arguments
  if(!view%in%c("axial","coronal","sagittal","orthographic")) stop("view needs to be 'axial', 'coronal', 'sagittal' or 'orthographic'")
  pvalue <- x$pvalue
  alpha <- x$alpha
  ddim <- dim(pvalue)
  if(is.null(template)) template <- x$pvalue
  if(is.null(mask)) mask <- array(TRUE,dim(pvalue))
  if(any(ddim!=dim(mask))) stop("mask dimension does not match")
  pvalue[pvalue>=alpha] <- NA
  pvalue[!mask] <- NA
  pvalue[pvalue<1e-10] <- 1e-10
  lpvalue <- -log(pvalue)
  if(view!="orthographic"&is.null(slices)){
    nslice <- ncol*nrow
    slices <- switch(view,
                     "sagittal"=sort(order(apply(lpvalue,1,sum,na.rm=TRUE),decreasing=TRUE)[1:nslice]),
                     "coronal"=sort(order(apply(lpvalue,2,sum,na.rm=TRUE),decreasing=TRUE)[1:nslice]),
                     "axial"=sort(order(apply(lpvalue,3,sum,na.rm=TRUE),decreasing=TRUE)[1:nslice]))
  }
  if(view=="orthographic"&is.null(center)){
    center <- c(order(apply(lpvalue,1,sum,na.rm=TRUE),decreasing=TRUE)[1],
                order(apply(lpvalue,2,sum,na.rm=TRUE),decreasing=TRUE)[1],
                order(apply(lpvalue,3,sum,na.rm=TRUE),decreasing=TRUE)[1])
    if(!mask[center[1],center[2],center[3]]) stop("Please specify center within brain mask\n")
  }
	slices0 <- slices
	center0 <- center
  if(is.nifti(template)){
      indaligned <- getAlignedCoords(x,template)
  } else {
      if(all(ddim==dim(template))){
      indaligned <- list(ixT1=1:ddim[1], iyT1=1:ddim[2], izT1=1:ddim[3],
                         ixspm=1:ddim[1], iyspm=1:ddim[2], izspm=1:ddim[3], pixdim=x$header$pixdim[2:4])
      } else {
        stop("incompatible template")
      }
  }
  pvalue <- pvalue[indaligned$ixspm,indaligned$iyspm,indaligned$izspm]
  lpvalue <- lpvalue[indaligned$ixspm,indaligned$iyspm,indaligned$izspm]
  mask <- mask[indaligned$ixspm,indaligned$iyspm,indaligned$izspm]
  if(view=="orthographic") {
     center <- c(indaligned$ixT1[center[1]],indaligned$iyT1[center[2]],indaligned$izT1[center[3]])
  }  else {
     slices <- switch(view,
                   "sagittal"=indaligned$ixT1[slices],
                   "coronal"=indaligned$iyT1[slices],
                   "axial"=indaligned$izT1[slices])
  }
  pdim <- indaligned$pixdim
  ddim <- dim(pvalue)
  n1 <- ddim[1]
  n2 <- ddim[2]
  n3 <- ddim[3]
  indx <- (1:n1)[apply(mask,1,any)]
  indy <- (1:n2)[apply(mask,2,any)]
  indz <- (1:n3)[apply(mask,3,any)]
  pvalue <- pvalue[indx,indy,indz]
  lpvalue <- lpvalue[indx,indy,indz]
  rlp <- range(lpvalue,na.rm=TRUE)
  template <- template[indx,indy,indz]
  n1 <- length(indx)
  n2 <- length(indy)
  n3 <- length(indz)
  if(view=="orthographic"){
    center[1] <- (1:n1)[indx==center[1]]
    center[2] <- (1:n2)[indy==center[2]]
    center[3] <- (1:n3)[indz==center[3]]
  } else {
    slices <- switch(view,
                     "sagittal"=slices[slices<=max(indx)],
                     "coronal"=slices[slices<=max(indy)],
                     "axial"=slices[slices<=max(indz)]
    )
    slices <- switch(view,
                     "sagittal"=slices-min(indx)+1,
                     "coronal"=slices-min(indy)+1,
                     "axial"=slices-min(indz)+1
    )
    nslice <- length(slices)
    nrow <- ceiling(nslice/ncol)
  }
  oldpar <- par(mar=c(2.5,2.5,2.5,.1),mgp=c(1.5,.5,0))
  if(view=="orthographic"){
    n12 <- max(n1,n2)
    wh <- 2*n1+n2+n12/8
    mat <- matrix(c(1,2,3,4),1,4)
    layout(mat,widths=c(n2,n1,n1,n12/8)/wh,heights=1)
    image(-indy[n2:1]*pdim[2],indz*pdim[3],template[center[1],n2:1,],col=grey(0:255/255),asp=TRUE,xlab="-yind")
    title("sagittal")
    lines(-indy[c(1,n2)]*pdim[2],rep(indz[center[3]]*pdim[3],2),col=2)
    lines(rep(-indy[center[2]]*pdim[2],2),indz[c(1,n3)]*pdim[3],col=2)
    image(-indy[n2:1]*pdim[2],indz*pdim[3],lpvalue[center[1],n2:1,],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
    image(indx*pdim[1],indz*pdim[3],template[,center[2],],col=grey(0:255/255),asp=TRUE)
    title("coronal")
    lines(indx[c(1,n1)]*pdim[1],rep(indz[center[3]]*pdim[3],2),col=2)
    lines(rep(indx[center[1]]*pdim[1],2),indz[c(1,n3)]*pdim[3],col=2)
    image(indx*pdim[1],indz*pdim[3],lpvalue[,center[2],],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
    image(indx*pdim[1],indy*pdim[2],template[,,center[3]],col=grey(0:255/255),asp=TRUE)
    title("axial")
    lines(indx[c(1,n1)]*pdim[1],rep(indy[center[2]]*pdim[2],2),col=2)
    lines(rep(indx[center[1]]*pdim[1],2),indy[c(1,n2)]*pdim[2],col=2)
    image(indx*pdim[1],indy*pdim[2],lpvalue[,,center[3]],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
    scalep <- seq(rlp[1],rlp[2],length=256)
    scalep <- t(matrix(scalep,length(scalep),10))
    image(1:10,scalep[1,],scalep,col=heat.colors(256),xaxt="n",xlab="",ylab="-log(pvalue)")
  } else {
    mat <- matrix(0,nrow,ncol+1)
    for(i in 1:nrow){
      mat[i,1:ncol] <- (i-1)*(ncol+1)+1:ncol
      mat[i,ncol+1] <- i*(ncol+1)
    }
    if(view=="sagittal"){
      widths <- c(rep(n2,ncol),n2/max(1,10-ncol))
      heights <- rep(n3,nrow)
    }
    if(view=="coronal"){
      widths <- c(rep(n1,ncol),n1/max(1,10-ncol))
      heights <- rep(n3,nrow)
    }
    if(view=="axial"){
      widths <- c(rep(n1,ncol),n1/max(1,10-ncol))
      heights <- rep(n2,nrow)
    }
    widths <- widths/sum(widths)
    heights <- heights/sum(heights)
    layout(mat,widths=widths,heights=heights)
    for(i in 1:nrow){
      for(j in 1:ncol){
        k <- (i-1)*ncol + j
        if(k>nslice) break
        if(view=="sagittal"){
          image(-indy[n2:1]*pdim[2],indz*pdim[3],template[slices[k],n2:1,],col=grey(0:255/255),asp=TRUE,xlab="-yind")
          title(paste("sagittal slice",indx[slices[k]]))
          image(-indy[n2:1]*pdim[2],indz*pdim[3],lpvalue[slices[k],n2:1,],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
        }
        if(view=="coronal"){
          image(indx*pdim[1],indz*pdim[3],template[,slices[k],],col=grey(0:255/255),asp=TRUE)
          title(paste("coronal slice",indy[slices[k]]))
          image(indx*pdim[1],indz*pdim[3],lpvalue[,slices[k],],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
        }
        if(view=="axial"){
          image(indx*pdim[1],indy*pdim[2],template[,,slices[k]],col=grey(0:255/255),asp=TRUE)
          title(paste("axial slice", indz[slices[k]]))
          image(indx*pdim[1],indy*pdim[2],lpvalue[,,slices[k]],zlim=rlp,add=TRUE,col=heat.colors(256),asp=TRUE)
        }
      }
      scalep <- seq(rlp[1],rlp[2],length=256)
      scalep <- t(matrix(scalep,length(scalep),10))
      image(1:10,scalep[1,],scalep,col=heat.colors(256),xaxt="n",xlab="",ylab="-log(pvalue)")
    }
    if(k>nslice) break
  }
  invisible(list(slices=slices0,center=center0))
}


scaleSignal <- function(signal,cutOff){
    scale <- range(signal,finite=TRUE)
    if (diff(scale) != 0) {
      signal <-  (signal - scale[1]) / diff(scale)
    } else {
      signal <- 0
    }
    signal[is.na(signal)] <- 0
    signal[is.infinite(signal)] <- 0
    if (diff(scale) != 0){
      signal[signal<cutOff[1]] <- cutOff[1]
      signal[signal>cutOff[2]] <- cutOff[2]
      signal <- signal - cutOff[1]
      signal <- signal/(cutOff[2]-cutOff[1])
    }
    scale <- scale*(cutOff[2]-cutOff[1])
    list(signal=signal,scale=scale)
}
signalOverlay <- function(signal,anatomic,scale){
      if (diff(scale) != 0) {
        signal <- 0.5 + 0.5 * (signal - scale[1]) / diff(scale)
      } else if (scale[1] == 0) {
        signal <- 1
      } else {
        signal <- 1
      }
      # create an overlay
      anatomic[signal > 0.5] <- signal[signal > 0.5]
      anatomic[is.na(anatomic)] <- 0
      anatomic[is.infinite(anatomic)] <- 0
anatomic
}
scaleAnatomic <- function(anatomic,cutOff,ddim){
      if (is.null(anatomic)) anatomic <- array(0,dim=ddim)
      # re-scale anatomic to 0 ... 0.5
      if (diff(range(anatomic)) !=0) {
        anatomic <- 0.5 * (anatomic - range(anatomic,finite=TRUE)[1]) /
                                  diff(range(anatomic,finite=TRUE))
      }
      anatomic[anatomic>cutOff[2]*0.5] <- cutOff[2]*0.5
      anatomic[anatomic<cutOff[1]*0.5] <- cutOff[1]*0.5
      anatomic <- anatomic - cutOff[1]*0.5
      anatomic <- anatomic/(cutOff[2]-cutOff[1])
}
position <- function(obj){
  dt <- dim(obj)
  if(is.null(dt)) dt <- obj$dim
  c(1:dt[1],1:dt[2],1:dt[3])
}
displayImage <- function(img, ...){
      hex <- c(0:9, LETTERS[1:6])
      hex <- paste(hex[(0:255)%/%16+1],hex[(0:255)%%16+1],sep="")
      color <- paste("#",hex[img[,,1]%/%256+1],hex[img[,,2]%/%256+1],
                         hex[img[,,3]%/%256+1],sep="")
      xxx <- seq(1,dim(img)[1],length=dim(img)[1])
      yyy <- seq(1,dim(img)[2],length=dim(img)[2])
      zzz <- matrix(1:prod(dim(img)[1:2]),nrow = dim(img)[1],ncol = dim(img)[2])
      # display the image
      image(xxx, yyy, zzz, col = color, asp = 1, xlab="",ylab="", ...)
}

mri.colors <- function (n1, n2, factor=n1/(n1+n2), from=0, to=.2) {
    colors1 <- gray((0:n1)/(n1+n2))
    colors2 <- if(n2>0) hsv(h = seq(from,to,length=n2+1),
                   s = seq(from = n2/(n2+factor*n1) - 1/(2 * (n2+factor*n1)), to =
                     1/(2 * (n2+factor*n1)), length = n2+1),
                   v = 1) else NULL
    list(all=c(colors1,colors2),gray=colors1,col=colors2)
}
