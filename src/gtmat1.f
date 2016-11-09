#include "defines.h"
c     ****************************************************************
c     *                                                              *
c     *                      subroutine gtmat1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 9/2/2102 rhd               *
c     *                                                              *
c     *      computes deformation gradients and stress               *
c     *      transformation matrices necessary for stress            *
c     *      recovery at a gauss point for a block of similar,       *
c     *      3-D (solid) elements including the                      *
c     *      effects of geometric nonlinearity.                      *
c     *                                                              *
c     ****************************************************************
c
      subroutine gtmat1( qnhalf, qn1, error, local_work )
      implicit integer (a-z)  
$add param_def
c
c          parameter declarations
c
#dbl      double precision
#sgl      real
     &     qnhalf(mxvl,nstr,*),  qn1(mxvl,nstr,*)
c
c          local declarations - make allocatable
c          to reduce stack size
c
$add include_sig_up
#dbl      double precision
#sgl      real
     & xi, eta, zeta, zero, one
c
#dbl      double precision,
#sgl      real,
     & allocatable :: rnh(:,:,:), fnh(:,:,:), theta(:,:),
     &                dfh(:), dfn(:)
c
      data zero, one / 0.0d00, 1.0d00 /
c
!DIR$ ASSUME_ALIGNED qnhalf:64, qn1:64        
c
      span  = local_work%span
      felem = local_work%felem
      type  = local_work%elem_type
      order = local_work%int_order
      nnode = local_work%num_enodes
      gpn   = local_work%gpn
c
      allocate( rnh(mxvl,ndim,ndim), fnh(mxvl,ndim,ndim), dfh(mxvl),
     &          theta(mxvl,mxtnsz), dfn(mxvl) )
     
      rnh = zero
      fnh = zero
      dfh = zero
      theta = zero
      dfn = zero
c
c           compute the deformation gradient at states
c           (n + 1/2) and (n + 1) relative to the config
c           at (n = 0). perform polar decompositions
c           [F] = [R][U]. we need the [R]'s to transform
c           between "unrotated" and "rotated" tensor
c           quantities. this routine performs these
c           operations for a gauss point (gpn) for all
c           elements in the block.
c
c           get the coordinate jacobians, inverses, det
c           for configuration n = 0. ce has nodal
c           coordinates for n = 0.
c
      call jacob1( type, span, felem, gpn, local_work%jac,
     &             local_work%det_j(1,gpn), local_work%gama(1,1,1,gpn),
     &             local_work%cohes_rot_block,
     &             local_work%nxi(1,gpn), local_work%neta(1,gpn),
     &             local_work%nzeta(1,gpn), local_work%ce_0, nnode )
c
c           get [F,n+1] and the polar decomposition
c           [R,n+1][U,n+1]. we need only [R,n+1] and
c           det[F,n+1] stored in dfn1. dfn1 is used
c           to get current element volume during
c           integration of internal work. [R,n+1] is
c           not used in strain/stress updating. it is
c           used in internal force, stiffness and output
c           to convert unrotated cauchy stresses to
c           cauchy stresses. rtcmp1 calls lower level
c           routines that eventually do the polar
c           decompositions.
c
c           note: we compute/store rn1 directly in the block
c           data structure, rot_blk_n1.
c
      call tcomp1( span, theta, local_work%nxi(1,gpn),
     &             local_work%neta(1,gpn),local_work%nzeta(1,gpn),
     &             local_work%gama(1,1,1,gpn), local_work%uen1, nnode )
c
      call fcomp1( span, felem, gpn, local_work%fn1,
     &             local_work%dfn1, theta, error )
      if ( error .eq. 1 ) go to 9000
      call rtcmp1( span, local_work%fn1,
     &             local_work%rot_blk_n1(1,1,gpn) )
c
      if( local_work%is_umat ) then
         call getrm1( span, qn1, local_work%rot_blk_n1(1,1,gpn), 3 )
      end if
c
c           get [F @ n+1/2] and the polar decomposition
c           [R @ n+1/2][U @ n+1/2]. we need only [ @ n+1/2]
c           to rotate the rate of deformation tensor to
c           unrotated configuration. we go ahead and build
c           the 6x6 [q] transformation matrix (@ n+1/2)
c           for this purpose.
c            {unrotated rate of deformation} = [qnhalf] *
c            {spatial rate of deformation}
c
      call tcomp1( span, theta, local_work%nxi(1,gpn),
     &             local_work%neta(1,gpn),local_work%nzeta(1,gpn),
     &             local_work%gama(1,1,1,gpn), local_work%uenh, nnode )
c
      call fcomp1( span, felem, gpn, fnh, dfh, theta, error )
      if ( error .eq. 1 ) go to 9000
      call rtcmp1( span, fnh, rnh )
      call getrm1( span, qnhalf, rnh, 1 )
c
      if( local_work%compute_f_n ) then
         if( local_work%step .eq. 1 ) then
           call gtmat1_init_fn( span, mxvl, local_work%fn, dfn )
         else
           call tcomp1( span, theta, local_work%nxi(1,gpn),
     &              local_work%neta(1,gpn),local_work%nzeta(1,gpn),
     &              local_work%gama(1,1,1,gpn), local_work%ue, nnode )
c
           call fcomp1( span, felem, gpn, local_work%fn, dfn,
     &              theta, error )
            if ( error .eq. 1 ) go to 9000
         end if
      end if
c
c           for the linear displacement element(s), modify [F] to define
c           [bar F] by adjusting to account for volume change. same
c           approach as used in Abaqus. These adjusted [Fs] are used
c           by the crystal plasticity model and possibly by UMATs
c           (for hyperelasticity). The scaling of [F] does not affect
c           [R] from polar decompositions above so doing this operation
c           here is ok.
c
      if( local_work%compute_f_bar ) then
        call gtmat1_make_fbar( span, mxvl, local_work%fn1,
     &            local_work%dfn1, local_work%volume_block_0,
     &            local_work%volume_block_n1 )
        call gtmat1_make_fbar( span, mxvl, local_work%fn,
     &            dfn, local_work%volume_block_0,
     &            local_work%volume_block_n  )
      end if
c
c                  done
c
 9000 continue
      deallocate( rnh, fnh, dfh, theta, dfn )
c
      return
      end

c     ****************************************************************
c     *                                                              *
c     *                    subroutine gtmat1_init_fn                 *
c     *                                                              *
c     *                       written by : rhd                       *
c     *                                                              *
c     *                   last modified : 9/1/2102 rhd               *
c     *                                                              *
c     *      make identity and set det [Fn] = 1.0. will be inlined   *
c     *                                                              *
c     ****************************************************************
c
c
      subroutine gtmat1_init_fn( span, mxvl, fn, dfn )
      implicit integer (a-z)
c
c                       parameter declarations
c
#dbl      double precision ::
#sgl      real ::
     &     fn(mxvl,3,3),  dfn(*)
c
c                       local declarations
c
#dbl      double precision
#sgl      real
     &  zero, one
c
        data zero, one / 0.0d00, 1.0d00 /
!DIR$ ASSUME_ALIGNED fn:64, dfn:64
c
c                       set [F @ 0] to identity. set determinant
c                       to 1.0 (no deformation). routine will
c                       be inlined.
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
        fn(i,1,1) = one
        fn(i,2,2) = one
        fn(i,3,3) = one
        dfn(i) = one
      end do
c
      return
      end

c     ****************************************************************
c     *                                                              *
c     *               subroutine gtmat1_make_fbar                    *
c     *                                                              *
c     *                       written by : rhd                       *
c     *                                                              *
c     *                   last modified : 09/2/2012                  *
c     *                                                              *
c     *      [F] is deformation gradient (3x3) at this Gauss pt for  *
c     *      for all elements in block. make the [F-bar]             *
c     *      modification to [F] at this Gauss pt                    *
c     *      for all elements in block. done only for linear         *
c     *      displacement solid elements                             *
c     *                                                              *
c     ****************************************************************

      subroutine gtmat1_make_fbar( span, mxvl, f, det_f,
     &                undeformed_elem_vols, deformed_elem_vols )
      implicit integer (a-z)
c
c                      parameter declarations
c
#dbl      double precision
#sgl      real
     &    f(mxvl,3,3), det_f(*), undeformed_elem_vols(*),
     &    deformed_elem_vols(*)
c
c                      locals
c
#dbl      double precision
#sgl      real
     &   factor, third, j_bar
      data third / 0.3333333333333333333333d00 /
!DIR$ ASSUME_ALIGNED deformed_elem_vols:64, undeformed_elem_vols:64
!DIR$ ASSUME_ALIGNED f:64, det_f:64
c
c                      bar [F] = [F] * (bar J/J)**0.333 where
c                      J = det [F], bar J is volume of deformed
c                      element / volume of element at n = 0
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
        j_bar = deformed_elem_vols(i) / undeformed_elem_vols(i)
        factor = (j_bar/ det_f(i) ) ** third
        f(i,1:3,1:3) =  f(i,1:3,1:3) * factor
      end do
c
      return
      end

c     ****************************************************************
c     *                                                              *
c     *                      subroutine jacob1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 04/24/09 rhd (remove block *
c     *                                    common)                   *
c     *                                                              *
c     *     this subroutine computes the jacobian matrix of the      *
c     *     mapping from uniform global space to parametric space,   *
c     *     its determinate (the jacobian), and its inverse at a     *
c     *     given gauss point for a block of solid elements          *
c     *                                                              *
c     *     Added the Jacobian matrix for axisymmetric elements      *
c     *     (axisymmetric elements use an augmented form of a 3x3    *
c     *     matrix); added etype. (gvt)                              *
c     *                                                              *
c     *     Added interface elements:                                *
c     *              8-noded quad (aroy)                             *
c     *              6 and 12 noded triangle (sushovan)              *
c     *                                                              *
c     ****************************************************************
c
c
      subroutine jacob1( etype, span, felem, gpn, jac, dj, gama,
     &                   lambda, nxi, neta, nzeta, ce, nnode )
      implicit integer (a-z)
c
$add param_def
c                   parameters
c
#dbl      double precision ::
#sgl      real ::
     &  jac(mxvl,3,3), dj(*), gama(mxvl,3,3), nxi(*), neta(*),
     &  nzeta(*), ce(mxvl,*)
c
c                   local work arrays (on stack)
c
#dbl      double precision ::
#sgl      real ::
     &   j1(mxvl), j2(mxvl), j3(mxvl), lambda(mxvl,3,3),
     &   ce_rotated(mxvl,mxecor)
c
#dbl      double precision ::
#sgl      real ::
     &       zero, zero_check, one, half
c
      logical :: local_debug, twod, cohesive_elem, threed_elem,
     &           ldum1, ldum2, ldum3, ldum4, ldum5, ldum6
      data zero, zero_check, one, half, local_debug
     &    / 0.0d0,    1.0d-20, 1.0d0,  0.5d0, .false. /
!DIR$ ASSUME_ALIGNED jac:64, dj:64, gama:64, nxi:64,neta:64
!DIR$ ASSUME_ALIGNED nzeta:64, ce:64, j1:64, j2:64, j3:64, lambda:64
!DIR$ ASSUME_ALIGNED ce_rotated:64
c
c           set flag for 2-D, 3-D, cohesive element.
c
      call set_element_type( etype, threed_elem, ldum1, ldum2,
     &                       ldum3, twod, ldum4, ldum5,
     &                       ldum6, cohesive_elem )
c
c
c           initialize the jacobian matrix and its inverse for this
c           gauss point.
c
      jac  = zero  ! just zero entire arrays - faster
      gama = zero
c
c           calculate the jacobian matrix
c
c           for cohesive elements, the element coordinates
c           are rotated from the global system to a
c           coordinate system in which the normal axis
c           (Z rotated) is perpendicular to the surface
c           of each cohesive element
c
      if( cohesive_elem ) then
           call rotate_cohes_var( mxvl, span, nnode, lambda, ce,
     &                             ce_rotated )
c
c         Loop through the number of nodes to get the terms in the
c         upper left 2x2 part of the Jacobian matrix. Set the (3,3)
c         location to augment the upper left 2x2 part of
c         the Jacobian matrix to one.
c
        do j = 1, nnode
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
           do i = 1, span
             jac(i,1,1) = jac(i,1,1) + nxi(j)*ce_rotated(i,j)
             jac(i,1,2) = jac(i,1,2) + nxi(j)*ce_rotated(i,nnode+j)
             jac(i,2,1) = jac(i,2,1) + neta(j)*ce_rotated(i,j)
             jac(i,2,2) = jac(i,2,2) + neta(j)*ce_rotated(i,nnode+j)
             jac(i,3,3) = one
           end do
        end do
      end if
c
c
c
      if( twod ) then
c
c         Loop through the number of nodes to get the terms in the
c         upper left 2x2 part of the Jacobian matrix. Set the (3,3)
c         location to augment the upper left 2x2 part of
c         the Jacobian matrix to one.
c
        do j = 1, nnode
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
           do i = 1, span
             jac(i,1,1) = jac(i,1,1) + nxi(j)*ce(i,j)
             jac(i,1,2) = jac(i,1,2) + nxi(j)*ce(i,nnode+j)
             jac(i,2,1) = jac(i,2,1) + neta(j)*ce(i,j)
             jac(i,2,2) = jac(i,2,2) + neta(j)*ce(i,nnode+j)
             jac(i,3,3) = one
           end do
        end do
      end if
c
c           for 3-D elements compute the Jacobian matrix
c
      if( threed_elem ) then
        do j = 1, nnode
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
           do i = 1, span
             jac(i,1,1)= jac(i,1,1)+nxi(j)*ce(i,j)
             jac(i,1,2)= jac(i,1,2)+nxi(j)*ce(i,nnode+j)
             jac(i,1,3)= jac(i,1,3)+nxi(j)*ce(i,2*nnode+j)
             jac(i,2,1)= jac(i,2,1)+neta(j)*ce(i,j)
             jac(i,2,2)= jac(i,2,2)+neta(j)*ce(i,nnode+j)
             jac(i,2,3)= jac(i,2,3)+neta(j)*ce(i,2*nnode+j)
             jac(i,3,1)= jac(i,3,1)+nzeta(j)*ce(i,j)
             jac(i,3,2)= jac(i,3,2)+nzeta(j)*ce(i,nnode+j)
             jac(i,3,3)= jac(i,3,3)+nzeta(j)*ce(i,2*nnode+j)
           end do
        end do
      end if
c
c           calculate the determinate of the jacobian matrix
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
          j1(i)= jac(i,2,2)*jac(i,3,3)-jac(i,2,3)*jac(i,3,2)
          j2(i)= jac(i,2,1)*jac(i,3,3)-jac(i,2,3)*jac(i,3,1)
          j3(i)= jac(i,2,1)*jac(i,3,2)-jac(i,2,2)*jac(i,3,1)
          dj(i)= jac(i,1,1)*j1(i)-jac(i,1,2)*j2(i)+jac(i,1,3)*j3(i)
      end do
c
      if ( local_debug ) then
          write(*,*) '>> coordindate jacobians:'
          do i =1, span
            write(*,*) '   > element: ',i
            write(*,9000) ((jac(i,j,k),k=1,3),j=1,3)
            write(*,*) '       det: ',dj(i)
          end do
      end if
c
c           check to insure a positive determinate.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
       if( dj(i) .le. zero_check ) then
         write(*,9169) gpn,felem+i-1, dj(i)
       end if
      end do
c
c           calculate the inverse of the jacobian matrix
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
         gama(i,1,1)=  j1(i)/dj(i)
         gama(i,2,1)= -j2(i)/dj(i)
         gama(i,3,1)=  j3(i)/dj(i)
         gama(i,1,2)= (jac(i,3,2)*jac(i,1,3)-
     &                 jac(i,1,2)*jac(i,3,3))/dj(i)
         gama(i,2,2)= (jac(i,1,1)*jac(i,3,3)-
     &                 jac(i,3,1)*jac(i,1,3))/dj(i)
         gama(i,3,2)= (jac(i,1,2)*jac(i,3,1)-
     &                 jac(i,1,1)*jac(i,3,2))/dj(i)
         gama(i,1,3)= (jac(i,1,2)*jac(i,2,3)-
     &                 jac(i,1,3)*jac(i,2,2))/dj(i)
         gama(i,2,3)= (jac(i,1,3)*jac(i,2,1)-
     &                 jac(i,1,1)*jac(i,2,3))/dj(i)
         gama(i,3,3)= (jac(i,1,1)*jac(i,2,2)-
     &                 jac(i,1,2)*jac(i,2,1))/dj(i)
      end do
c
      if ( local_debug ) then
        do i=1, span
          write(*,*)'       Jacobian matrix, elem #',i
          do row=1,3
            write(*,9000)(jac(i,row,col),col=1,3)
          end do
          write(*,*)'       determinant of the Jacobian matrix =',dj(i)
          write(*,*)'       inverse Jacobian matrix'
          do row=1,3
            write(*,9000)(gama(i,row,col),col=1,3)
          end do
        end do
      end if
c
      return
c
 9000 format(3x,3f10.5)
 9900 format(I10,3F10.4)
 9169 format(/1x,'>>>>> warning: the determinant of the jacobian',
     &           ' matrix for gauss point ',i6,/7x,'of element ',
     &           i6,' is non-positive. current value: ',e12.5,/)
c
      end
c     ****************************************************************
c     *                                                              *
c     *                      subroutine tcomp1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 07/01/90                   *
c     *                                 : 02/09/94                   *
c     *                                                              *
c     *     this subroutine computes the displacement gradients      *
c     *     at a given gauss point for a block of solid elements     *
c     *                                                              *
c     ****************************************************************
c
c
      subroutine tcomp1( span, theta, nxi, neta, nzeta, gama, ue,
     &                   nnode )
      implicit integer (a-z)
$add param_def
c
c                     parameter declarations
c
#dbl      double precision
#sgl      real
     &     theta(mxvl,9), nxi(*), neta(*), nzeta(*), gama(mxvl,ndim,*),
     &     ue(mxvl,*)
c
c                     locally allocated
c
#dbl      double precision
#sgl      real
     &     thtemp(mxvl,mxndel,ndim), zero
      data zero / 0.0d00 /
!DIR$ ASSUME_ALIGNED theta:64, nxi:64, neta:64, nzeta:64, gama:64
!DIR$ ASSUME_ALIGNED ue:64, thtemp:64
c
c           initialize theta
c
      theta = zero ! faster to just zero entire array
c
c           calculate and assign the terms of theta
c
      do j = 1, nnode
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      
         do i = 1, span
            thtemp(i,j,1)= gama(i,1,1)*nxi(j)+gama(i,1,2)*neta(j)+
     &                     gama(i,1,3)*nzeta(j)
            thtemp(i,j,2)= gama(i,2,1)*nxi(j)+gama(i,2,2)*neta(j)+
     &                     gama(i,2,3)*nzeta(j)
            thtemp(i,j,3)= gama(i,3,1)*nxi(j)+gama(i,3,2)*neta(j)+
     &                     gama(i,3,3)*nzeta(j)
         end do
      end do
c
c
      tpos1= nnode
      tpos2= 2*nnode
c
      do j = 1, nnode
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
         do i = 1, span
c
            theta(i,1)= theta(i,1)+thtemp(i,j,1)*ue(i,j)
            theta(i,2)= theta(i,2)+thtemp(i,j,1)*ue(i,tpos1+j)
            theta(i,3)= theta(i,3)+thtemp(i,j,1)*ue(i,tpos2+j)
c
            theta(i,4)= theta(i,4)+thtemp(i,j,2)*ue(i,j)
            theta(i,5)= theta(i,5)+thtemp(i,j,2)*ue(i,tpos1+j)
            theta(i,6)= theta(i,6)+thtemp(i,j,2)*ue(i,tpos2+j)
c
            theta(i,7)= theta(i,7)+thtemp(i,j,3)*ue(i,j)
            theta(i,8)= theta(i,8)+thtemp(i,j,3)*ue(i,tpos1+j)
            theta(i,9)= theta(i,9)+thtemp(i,j,3)*ue(i,tpos2+j)
c
        end do
      end do
c
      return
      end

c     ****************************************************************
c     *                                                              *
c     *                      subroutine fcomp1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 07/04/91                   *
c     *                                                              *
c     *     this subroutine computes the deformation gradient,       *
c     *     and its determinate at a given gauss point for a         *
c     *     block of similar solid elements                          *
c     *                                                              *
c     ****************************************************************
c
c
      subroutine fcomp1( span, felem, gpn, f, df, theta, error )
      implicit integer (a-z)
$add param_def
c
c                      parameter declarations
c
#dbl      double precision
#sgl      real
     &    f(mxvl,ndim,*), theta(mxvl,*), df(*)
c
c                      locally allocated
c
#dbl      double precision
#sgl      real
     &   f1(mxvl), f2(mxvl), f3(mxvl), zero_check, one
c
      data zero_check, one /1.0d-20, 1.0d00/
!DIR$ ASSUME_ALIGNED f:64, theta:64, df:64, f1:64, f2:64, f3:64
c
c                       compute the deformation gradient matrix
c                       and its determinate.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
         f(i,1,1)= theta(i,1)+one
         f(i,1,2)= theta(i,4)
         f(i,1,3)= theta(i,7)
         f(i,2,1)= theta(i,2)
         f(i,2,2)= theta(i,5)+one
         f(i,2,3)= theta(i,8)
         f(i,3,1)= theta(i,3)
         f(i,3,2)= theta(i,6)
         f(i,3,3)= theta(i,9)+one
      end do
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
         f1(i)= f(i,2,2)*f(i,3,3)-f(i,2,3)*f(i,3,2)
         f2(i)= f(i,2,1)*f(i,3,3)-f(i,2,3)*f(i,3,1)
         f3(i)= f(i,2,1)*f(i,3,2)-f(i,2,2)*f(i,3,1)
      end do
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
         df(i)= f(i,1,1)*f1(i)-f(i,1,2)*f2(i)+f(i,1,3)*f3(i)
      end do
c
c                       check to insure a positive determinate.
c
      error = 0
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
         if( df(i) .le. zero_check ) then
            write(*,9170) gpn, felem+i-1, df(i)
            error = 1
         end if
      end do
c
 9170 format(/1x,'>>>>> warning: the determinant of the deformation ',
     &           'gradient for gauss point ',i6,/7x,'of element ',i6,
     &           ' is non-positive. current value: ',e12.5,/,7x,
     &           'step size reduction requested...'/)

      return
      end

c     ****************************************************************
c     *                                                              *
c     *                      subroutine rtcmp1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 06/30/91                   *
c     *                                                              *
c     *     this subroutine computes the polar decompostion of the   *
c     *     deformation gradient into the rotation tensor [R] and a  *
c     *     deformation tensor [U] for a block of solid elements     *
c     *                                                              *
c     ****************************************************************
c
c
c
      subroutine rtcmp1(span,f,r)
      implicit integer (a-z)
$add param_def
#dbl      double precision
#sgl      real
     &     f(mxvl,ndim,*),r(mxvl,ndim,*),ui(mxvl,nstr)
!DIR$ ASSUME_ALIGNED r:64, f:64,ui:64
c
c                       compute the inverse of the right
c                       stretch tensor.
c
      call irscp1( span, f, ui )
c
c                       compute the rotation tensor.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i= 1,span
         r(i,1,1)= f(i,1,1)*ui(i,1)+f(i,1,2)*ui(i,2)+f(i,1,3)*ui(i,4)
         r(i,1,2)= f(i,1,1)*ui(i,2)+f(i,1,2)*ui(i,3)+f(i,1,3)*ui(i,5)
         r(i,1,3)= f(i,1,1)*ui(i,4)+f(i,1,2)*ui(i,5)+f(i,1,3)*ui(i,6)
         r(i,2,1)= f(i,2,1)*ui(i,1)+f(i,2,2)*ui(i,2)+f(i,2,3)*ui(i,4)
         r(i,2,2)= f(i,2,1)*ui(i,2)+f(i,2,2)*ui(i,3)+f(i,2,3)*ui(i,5)
         r(i,2,3)= f(i,2,1)*ui(i,4)+f(i,2,2)*ui(i,5)+f(i,2,3)*ui(i,6)
         r(i,3,1)= f(i,3,1)*ui(i,1)+f(i,3,2)*ui(i,2)+f(i,3,3)*ui(i,4)
         r(i,3,2)= f(i,3,1)*ui(i,2)+f(i,3,2)*ui(i,3)+f(i,3,3)*ui(i,5)
         r(i,3,3)= f(i,3,1)*ui(i,4)+f(i,3,2)*ui(i,5)+f(i,3,3)*ui(i,6)
      end do
c
c
      return
      end
c     ****************************************************************
c     *                                                              *
c     *                      subroutine getrm1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 08/23/12 rhd               *
c     *                                                              *
c     *     computes the rotation matrix taking one                  *
c     *     tensor to its corresponding value obtained by adding or  *
c     *     removing the material rotation, for a gauss point of an  *
c     *     element in a block of similar solid elements             *
c     *                                                              *
c     ****************************************************************
c
c
      subroutine getrm1( span, q, r, opt )
      implicit none
$add param_def
c
c           parameter declarations
c
      integer :: span, opt
#dbl      double precision :: q(mxvl,nstr,*), r(mxvl,ndim,*)
#sgl      real :: q(mxvl,nstr,*), r(mxvl,ndim,*)
     &  
c
c           locals
c
      integer :: i
#dbl      double precision
#sgl      real
     & two, rbar(mxvl,3,3)
      data two / 2.0d00 /
!DIR$ ASSUME_ALIGNED q:64, r:64, rbar:64
c
c           compute q. branch on quantity & direction of rotation.
c
      if ( opt .eq. 1 ) then
c
c      unrotated rate of deformation vector {d} = [q] *
c       (rotated) rate of deformation vector {D}. in tensor form:
c
c                 [d] = trans([R]) [D] [R]
c
c       both [D] and [d] are symmetric, [R] is orthogonal rotation.
c       vector forms for {d} and {D} use engineering shear strains.
c       vector ordering is {x,y,z,xy,yz,xz}
c

!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
         do i = 1, span
            q(i,1,1)= r(i,1,1)**2
            q(i,1,2)= r(i,2,1)**2
            q(i,1,3)= r(i,3,1)**2
            q(i,1,4)= r(i,1,1)*r(i,2,1)
            q(i,1,5)= r(i,3,1)*r(i,2,1)
            q(i,1,6)= r(i,1,1)*r(i,3,1)
            q(i,2,1)= r(i,1,2)**2
            q(i,2,2)= r(i,2,2)**2
            q(i,2,3)= r(i,3,2)**2
            q(i,2,4)= r(i,1,2)*r(i,2,2)
            q(i,2,5)= r(i,3,2)*r(i,2,2)
            q(i,2,6)= r(i,1,2)*r(i,3,2)
            q(i,3,1)= r(i,1,3)**2
            q(i,3,2)= r(i,2,3)**2
            q(i,3,3)= r(i,3,3)**2
            q(i,3,4)= r(i,1,3)*r(i,2,3)
            q(i,3,5)= r(i,3,3)*r(i,2,3)
            q(i,3,6)= r(i,1,3)*r(i,3,3)
            q(i,4,1)= two*r(i,1,1)*r(i,1,2)
            q(i,4,2)= two*r(i,2,1)*r(i,2,2)
            q(i,4,3)= two*r(i,3,1)*r(i,3,2)
            q(i,4,4)= r(i,1,1)*r(i,2,2)+r(i,1,2)*r(i,2,1)
            q(i,4,5)= r(i,2,1)*r(i,3,2)+r(i,3,1)*r(i,2,2)
            q(i,4,6)= r(i,1,1)*r(i,3,2)+r(i,3,1)*r(i,1,2)
            q(i,5,1)= two*r(i,1,2)*r(i,1,3)
            q(i,5,2)= two*r(i,2,3)*r(i,2,2)
            q(i,5,3)= two*r(i,3,2)*r(i,3,3)
            q(i,5,4)= r(i,1,2)*r(i,2,3)+r(i,2,2)*r(i,1,3)
            q(i,5,5)= r(i,2,2)*r(i,3,3)+r(i,2,3)*r(i,3,2)
            q(i,5,6)= r(i,1,2)*r(i,3,3)+r(i,3,2)*r(i,1,3)
            q(i,6,1)= two*r(i,1,1)*r(i,1,3)
            q(i,6,2)= two*r(i,2,1)*r(i,2,3)
            q(i,6,3)= two*r(i,3,1)*r(i,3,3)
            q(i,6,4)= r(i,1,1)*r(i,2,3)+r(i,2,1)*r(i,1,3)
            q(i,6,5)= r(i,2,1)*r(i,3,3)+r(i,3,1)*r(i,2,3)
            q(i,6,6)= r(i,1,1)*r(i,3,3)+r(i,1,3)*r(i,3,1)
        end do
        return
      end if
c
      if ( opt .eq. 2 ) then
c
c       cauchy stress {T} = [q] * (rotated) cauchy stress {t}.
c       in tensor form:
c
c                 [T] = [R] [t] trans([R])
c
c       both [T] and [t] are symmetric, [R] is orthogonal rotation.
c       vector ordering is {x,y,z,xy,yz,xz}. this [q] matrix
c       is the transpose of the one above.
c

!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
         do i = 1, span
            q(i,1,1)= r(i,1,1)**2
            q(i,1,2)= r(i,1,2)**2
            q(i,1,3)= r(i,1,3)**2
            q(i,1,4)= two*r(i,1,1)*r(i,1,2)
            q(i,1,5)= two*r(i,1,3)*r(i,1,2)
            q(i,1,6)= two*r(i,1,1)*r(i,1,3)
            q(i,2,1)= r(i,2,1)**2
            q(i,2,2)= r(i,2,2)**2
            q(i,2,3)= r(i,2,3)**2
            q(i,2,4)= two*r(i,2,1)*r(i,2,2)
            q(i,2,5)= two*r(i,2,3)*r(i,2,2)
            q(i,2,6)= two*r(i,2,1)*r(i,2,3)
            q(i,3,1)= r(i,3,1)**2
            q(i,3,2)= r(i,3,2)**2
            q(i,3,3)= r(i,3,3)**2
            q(i,3,4)= two*r(i,3,1)*r(i,3,2)
            q(i,3,5)= two*r(i,3,3)*r(i,3,2)
            q(i,3,6)= two*r(i,3,1)*r(i,3,3)
            q(i,4,1)= r(i,1,1)*r(i,2,1)
            q(i,4,2)= r(i,1,2)*r(i,2,2)
            q(i,4,3)= r(i,1,3)*r(i,2,3)
            q(i,4,4)= r(i,1,1)*r(i,2,2)+r(i,2,1)*r(i,1,2)
            q(i,4,5)= r(i,1,2)*r(i,2,3)+r(i,1,3)*r(i,2,2)
            q(i,4,6)= r(i,1,1)*r(i,2,3)+r(i,1,3)*r(i,2,1)
            q(i,5,1)= r(i,2,1)*r(i,3,1)
            q(i,5,2)= r(i,3,2)*r(i,2,2)
            q(i,5,3)= r(i,2,3)*r(i,3,3)
            q(i,5,4)= r(i,2,1)*r(i,3,2)+r(i,2,2)*r(i,3,1)
            q(i,5,5)= r(i,2,2)*r(i,3,3)+r(i,3,2)*r(i,2,3)
            q(i,5,6)= r(i,2,1)*r(i,3,3)+r(i,2,3)*r(i,3,1)
            q(i,6,1)= r(i,1,1)*r(i,3,1)
            q(i,6,2)= r(i,1,2)*r(i,3,2)
            q(i,6,3)= r(i,1,3)*r(i,3,3)
            q(i,6,4)= r(i,1,1)*r(i,3,2)+r(i,1,2)*r(i,3,1)
            q(i,6,5)= r(i,1,2)*r(i,3,3)+r(i,1,3)*r(i,3,2)
            q(i,6,6)= r(i,1,1)*r(i,3,3)+r(i,3,1)*r(i,1,3)
         end do
         return
      end if
c
c
      if ( opt .eq. 3 ) then
c
c       unrotated cauchy stress {t} = [q] * cauchy stress {T}.
c       in tensor form:
c
c                 [t] = trans([R]) [T] [R]
c
c       want to use code above for opt = 2. Set rbar = trans([R])
c       and compute [q]. We are computing the
c
c       both [T] and [t] are symmetric, [R] is orthogonal rotation.
c       vector ordering is {x,y,z,xy,yz,xz}. this [q] matrix
c       is the transpose of the one above.
c

!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
         do i = 1, span
          rbar(i,1,1) = r(i,1,1)
          rbar(i,1,2) = r(i,2,1)
          rbar(i,1,3) = r(i,3,1)
          rbar(i,2,1) = r(i,1,2)
          rbar(i,2,2) = r(i,2,2)
          rbar(i,2,3) = r(i,3,2)
          rbar(i,3,1) = r(i,1,3)
          rbar(i,3,2) = r(i,2,3)
          rbar(i,3,3) = r(i,3,3)
         end do
c

!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
         do i = 1, span
           q(i,1,1)= rbar(i,1,1)**2
           q(i,1,2)= rbar(i,1,2)**2
           q(i,1,3)= rbar(i,1,3)**2
           q(i,1,4)= two*rbar(i,1,1)*rbar(i,1,2)
           q(i,1,5)= two*rbar(i,1,3)*rbar(i,1,2)
           q(i,1,6)= two*rbar(i,1,1)*rbar(i,1,3)
           q(i,2,1)= rbar(i,2,1)**2
           q(i,2,2)= rbar(i,2,2)**2
           q(i,2,3)= rbar(i,2,3)**2
           q(i,2,4)= two*rbar(i,2,1)*rbar(i,2,2)
           q(i,2,5)= two*rbar(i,2,3)*rbar(i,2,2)
           q(i,2,6)= two*rbar(i,2,1)*rbar(i,2,3)
           q(i,3,1)= rbar(i,3,1)**2
           q(i,3,2)= rbar(i,3,2)**2
           q(i,3,3)= rbar(i,3,3)**2
           q(i,3,4)= two*rbar(i,3,1)*rbar(i,3,2)
           q(i,3,5)= two*rbar(i,3,3)*rbar(i,3,2)
           q(i,3,6)= two*rbar(i,3,1)*rbar(i,3,3)
           q(i,4,1)= rbar(i,1,1)*rbar(i,2,1)
           q(i,4,2)= rbar(i,1,2)*rbar(i,2,2)
           q(i,4,3)= rbar(i,1,3)*rbar(i,2,3)
           q(i,4,4)= rbar(i,1,1)*rbar(i,2,2)+rbar(i,2,1)*rbar(i,1,2)
           q(i,4,5)= rbar(i,1,2)*rbar(i,2,3)+rbar(i,1,3)*rbar(i,2,2)
           q(i,4,6)= rbar(i,1,1)*rbar(i,2,3)+rbar(i,1,3)*rbar(i,2,1)
           q(i,5,1)= rbar(i,2,1)*rbar(i,3,1)
           q(i,5,2)= rbar(i,3,2)*rbar(i,2,2)
           q(i,5,3)= rbar(i,2,3)*rbar(i,3,3)
           q(i,5,4)= rbar(i,2,1)*rbar(i,3,2)+rbar(i,2,2)*rbar(i,3,1)
           q(i,5,5)= rbar(i,2,2)*rbar(i,3,3)+rbar(i,3,2)*rbar(i,2,3)
           q(i,5,6)= rbar(i,2,1)*rbar(i,3,3)+rbar(i,2,3)*rbar(i,3,1)
           q(i,6,1)= rbar(i,1,1)*rbar(i,3,1)
           q(i,6,2)= rbar(i,1,2)*rbar(i,3,2)
           q(i,6,3)= rbar(i,1,3)*rbar(i,3,3)
           q(i,6,4)= rbar(i,1,1)*rbar(i,3,2)+rbar(i,1,2)*rbar(i,3,1)
           q(i,6,5)= rbar(i,1,2)*rbar(i,3,3)+rbar(i,1,3)*rbar(i,3,2)
           q(i,6,6)= rbar(i,1,1)*rbar(i,3,3)+rbar(i,3,1)*rbar(i,1,3)
         end do
         return
      end if

      write(*,*) ' ** Fatal Error: call to getrm1 with opt /= 1,2,3'
      write(*,*) '    is invalid. program terminated'
      call die_abort
      stop
c
      end
c
c     ****************************************************************
c     *                                                              *
c     *                      subroutine irscp1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 06/30/91                   *
c     *                                                              *
c     *     this subroutine computes the inverse of the right        *
c     *     stretch tensor. the computations are for a gauss         *
c     *     point for a block of solid elements                      *
c     *                                                              *
c     ****************************************************************
c
c
c
      subroutine irscp1( span, f, ui )
      implicit integer (a-z)
$add param_def
c
c                       parameter declarations
c
#dbl      double precision
#sgl      real
     &   f(mxvl,ndim,*),ui(mxvl,*)
c
c                       locally allocated arrays
c
#dbl      double precision
#sgl      real
     &   c(mxvl,nstr), cc(mxvl,nstr),
     &   iu(mxvl), iiu(mxvl), iiiu(mxvl), a2(mxvl), b2(mxvl),
     &   c2(mxvl),d2(mxvl), one, two
c
      data one, two / 1.0d00, 2.0d00 /
!DIR$ ASSUME_ALIGNED f:64, ui:64, c:64, cc:64, iu:64, iiu:64, iiiu:64
!DIR$ ASSUME_ALIGNED a2:64, b2:64, c2:64, d2:64
c
c                       ui is in symmetric upper triangular form.
c
c                       compute the invariants of the right
c                       stretch tensor, the metric tensor, and
c                       its square.
c
      call ivcmp1( span, f, c, cc, iu, iiu, iiiu )
c
c                       compute multipliers.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
         a2(i)= one/(iiiu(i)*(iu(i)*iiu(i)-iiiu(i)))
         b2(i)= iu(i)*iiu(i)*iiu(i)-iiiu(i)*(iu(i)*iu(i)+iiu(i))
         c2(i)= -iiiu(i)-iu(i)*(iu(i)*iu(i)-two*iiu(i))
         d2(i)= iu(i)
      end do
c
c                       compute the inverse of the right
c                       stretch tensor.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
         ui(i,1)= a2(i) * ( b2(i) + c2(i)*c(i,1) + d2(i)*cc(i,1) )
         ui(i,2)= a2(i) * (         c2(i)*c(i,2) + d2(i)*cc(i,2) )
         ui(i,3)= a2(i) * ( b2(i) + c2(i)*c(i,3) + d2(i)*cc(i,3) )
         ui(i,4)= a2(i) * (         c2(i)*c(i,4) + d2(i)*cc(i,4) )
         ui(i,5)= a2(i) * (         c2(i)*c(i,5) + d2(i)*cc(i,5) )
         ui(i,6)= a2(i) * ( b2(i) + c2(i)*c(i,6) + d2(i)*cc(i,6) )
      end do
c
      return
      end
c     ****************************************************************
c     *                                                              *
c     *                      subroutine ivcmp1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 9/6/2016 rhd               *
c     *                                                              *
c     *     this subroutine computes the invariants of the right     *
c     *     stretch tensor, the metric tensor, and its square.       *
c     *     the computations are for a gauss point in a bblock of    *
c     *     solid elements                                           *
c     *                                                              *
c     ****************************************************************
c
c
      subroutine ivcmp1( span, f, c, cc, iu, iiu, iiiu )
      implicit none
$add param_def
c
c               parameter declarations
c
      integer :: span
#dbl      double precision ::
#sgl      real ::
     & f(mxvl,ndim,*), c(mxvl,*), cc(mxvl,*), iu(*), iiu(*), iiiu(*)
c
c               locally allocated arrays
c
      integer :: i
      logical, parameter :: new = .true.
#dbl      double precision :: ct(mxvl,nstr), ev(mxvl,ndim)
#sgl      real :: ct(mxvl,nstr), ev(mxvl,ndim)
!DIR$ ASSUME_ALIGNED f:64, c:64, cc:64, iu:64, iiu:64, iiiu:64
!DIR$ ASSUME_ALIGNED ct:64, ev:64
c
c              c and cc are in symmetric upper triangular form.
c              compute the metric tensor.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
       c(i,1)= f(i,1,1)*f(i,1,1)+f(i,2,1)*f(i,2,1)+f(i,3,1)*f(i,3,1)
       c(i,2)= f(i,1,1)*f(i,1,2)+f(i,2,1)*f(i,2,2)+f(i,3,1)*f(i,3,2)
       c(i,3)= f(i,1,2)*f(i,1,2)+f(i,2,2)*f(i,2,2)+f(i,3,2)*f(i,3,2)
       c(i,4)= f(i,1,1)*f(i,1,3)+f(i,2,1)*f(i,2,3)+f(i,3,1)*f(i,3,3)
       c(i,5)= f(i,1,2)*f(i,1,3)+f(i,2,2)*f(i,2,3)+f(i,3,2)*f(i,3,3)
       c(i,6)= f(i,1,3)*f(i,1,3)+f(i,2,3)*f(i,2,3)+f(i,3,3)*f(i,3,3)
      end do
c
c              compute the square of the metric tensor
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
       cc(i,1)= c(i,1)*c(i,1)+c(i,2)*c(i,2)+c(i,4)*c(i,4)
       cc(i,2)= c(i,1)*c(i,2)+c(i,2)*c(i,3)+c(i,4)*c(i,5)
       cc(i,3)= c(i,2)*c(i,2)+c(i,3)*c(i,3)+c(i,5)*c(i,5)
       cc(i,4)= c(i,1)*c(i,4)+c(i,2)*c(i,5)+c(i,4)*c(i,6)
       cc(i,5)= c(i,2)*c(i,4)+c(i,3)*c(i,5)+c(i,5)*c(i,6)
       cc(i,6)= c(i,4)*c(i,4)+c(i,5)*c(i,5)+c(i,6)*c(i,6)
      end do
c
c              old or new algorithm to get eivenvalues. old
c              uses vectroized Givens rotations to diagonalize
c              the 3x3 symmetric, real matrix. New uses closed
c              form Cardano extraction of eigenvales for this
c              specific type & size of matrix. New is 
c              considerable faster.
c
      if( new ) call evcmp1_new( span, mxvl, c, ev )     
      if( .not. new ) then   
c
c              copy the metric tensor to stress vector
c              form then get principal values.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
          do i = 1, span
             ct(i,1)= c(i,1)
             ct(i,2)= c(i,3)
             ct(i,3)= c(i,6)
             ct(i,4)= c(i,2)
             ct(i,5)= c(i,5)
             ct(i,6)= c(i,4)
          end do
          call evcmp1( span, ct, ev )
      end if
c
c              set the principal values.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
         ev(i,1)= sqrt(ev(i,1))
         ev(i,2)= sqrt(ev(i,2))
         ev(i,3)= sqrt(ev(i,3))
      end do
c
c              invariants of right stretch tensor.
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do i = 1, span
       iu(i)  = ev(i,1)+ev(i,2)+ev(i,3)
       iiu(i) = ev(i,1)*ev(i,2)+ev(i,2)*ev(i,3)+ev(i,1)*ev(i,3)
       iiiu(i)= ev(i,1)*ev(i,2)*ev(i,3)
      end do
c
      return
      end
c     ****************************************************************
c     *                                                              *
c     *                      subroutine evcmp1_new                   *
c     *                                                              *
c     *                       written by : rhd                       *
c     *                                                              *
c     *                   last modified : 09/6/2016                  *
c     *                                                              *
c     *     eigenvalues of metric tensor. symmetric, real 3x3
c     *                                                              *
c     ****************************************************************
c
      subroutine evcmp1_new( span, mxvl, c, lamda )
      implicit none
c
c                 parameter declarations
c
      integer :: span, mxvl
#dbl      double precision :: c(mxvl,6), lamda(mxvl,3)
#sgl      real :: c(mxvl,6), lamda(mxvl,3)
c
c                 locals
c
      integer :: bel
#dbl      double precision ::
#sgl      real ::
     &  m11, m12, m13, m22, m23, m33, e1, e2, e3,
     &  swap1, swap2, swap3, zero,
     &  de, dd, ee, ff, m, c1, c0,p, q, sqrtp,phi, cphi, sphi,
     &  one, two, three, third, oneptfive, thirteenptfive,
     &  twentyseven, quarter, sixpt75, oneroot3
      data zero, one, two, three / 0.0d0, 1.0d0, 2.0d0, 3.0d0 /
      data third, oneptfive / 0.3333333333333333333d0, 1.5d0 /
      data thirteenptfive, twentyseven / 13.5d0, 27.0d0 /
      data quarter, sixpt75, oneroot3
     &     / 0.25d0, 6.75d0, 0.5773502691896258d0 /
c      
!DIR$ ASSUME_ALIGNED c:64, lamda:64
c
c              calculates the eigenvalues of a symmetric 3x3 matrix 
c              using Cardano's analytical algorithm.
c              Only the diagonal and upper triangular parts of matrix
c              are accessed. The access is read-only.
c              Copyright (C) 2006  Joachim Kopp. Avialble under 
c              GNU Lesser General Public License
c
      do bel = 1, span
       m11 = c(bel,1)
       m12 = c(bel,2)
       m13 = c(bel,4)
       m22 = c(bel,3)
       m23 = c(bel,5)
       m33 = c(bel,6)
       de  = m12 * m23
       dd  = m12**2
       ee  = m23**2
       ff  = m13**2
       m   = m11 + m22 + m33
       c1  = ( m11*m22 + m11*m33 + m22*m33 ) - (dd + ee + ff)
       c0  = m33*dd + m11*ee + m22*ff - m11*m22*m33 - two * m13*de
       p   = m*m - three * c1
       q   = m*(p - oneptfive*c1) - thirteenptfive*c0
       sqrtp = sqrt(abs(p))
       phi = twentyseven * ( quarter * c1*c1 * (p - c1)
     &          + c0 * (q + sixpt75 * c0) )
       phi = third * atan2(sqrt(abs(phi)), q)
       cphi = sqrtp * cos(phi)
       sphi = oneroot3 * sqrtp * sin(phi)
       e2 = third * (m - cphi)
       e3 = e2 + sphi
       e1 = e2 + cphi
       e2 = e2 - sphi
c       
       if( e2 .lt. e1 ) then
            swap1 = e1
            e1    = e2
            e2    = swap1
       end if
c
       if( e3 .lt. e1 ) then
            swap2 = e1
            e1    = e3
            e3    = swap2
       end if
c
       if( e3 .lt. e2 ) then
            swap3 = e2
            e2    = e3
            e3    = swap3
       end if
c         
       lamda(bel,1) = e1
       lamda(bel,2) = e2
       lamda(bel,3) = e3
c
      end do
c       
      return
      end
      

c     ****************************************************************
c     *                                                              *
c     *                      subroutine evcmp1                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 09/5/2016 rhd              *
c     *                                                              *
c     *     eigenvalues of a 3x3 positive definite matrix in         *
c     *     stress vector form for a block of solid elements.        *
c     *                                                              *
c     ****************************************************************
c
      subroutine evcmp1( span, k, lamda )
      implicit integer (a-z)
$add param_def
c
c                 parameter declarations
c
#dbl      double precision
#sgl      real
     &  k(mxvl,6), lamda(mxvl,3)
c
c                 local arrays allocated
c
#dbl      double precision
#sgl      real
     &  m(mxvl,ndim),kbari(mxvl),
     &  kbarj(mxvl), kbar(mxvl), ki(mxvl), kj(mxvl),mi(mxvl),
     &  mj(mxvl), scale(mxvl), alpha(mxvl), gamma(mxvl),x(mxvl),
     &  xsign(mxvl), rad(mxvl), errork(mxvl), swap(mxvl),
     &  ratiok(mxvl), sqtol, thold
      integer iexp(mxvl)
      logical cvgtst
#dbl      double precision
#sgl      real
     &  jactol, one, four, ten, ten_thouth
      data maxswp/15/,zero, one, two, jactol, four, ten, ten_thouth
     &   / 0.0d00, 1.0d00, 2.0d00, 1.0d-08,
     &     4.0d00, 10.0d00, 0.0001d00 /
!DIR$ ASSUME_ALIGNED k:64, lamda:64, m:64, kbari:64, kbarj:64
!DIR$ ASSUME_ALIGNED kbar:64, ki:64, kj:64, mi:64, mj:64, scale:64
!DIR$ ASSUME_ALIGNED alpha:64, gamma:64, x:64, xsign:64, rad:64
!DIR$ ASSUME_ALIGNED errork:64, swap:64, ratiok:64
c
c              initialize lamda, m, sweep parameters.
c
      swpnum = 0
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do bel = 1, span
c
         m(bel,1)= one
         m(bel,2)= one
         m(bel,3)= one
         lamda(bel,1) = k(bel,1)
         lamda(bel,2) = k(bel,2)
         lamda(bel,3) = k(bel,3)
c
c              scale [k] and ^0m^2 to avoid problems with exponential
c              overflow and underflow.
c
c              find the max and min terms on the diagonal of [k] & ^0m^2
c
         kj(bel) = k(bel,1)
         kj(bel) = min( k(bel,2),kj(bel) )
         kj(bel) = min( k(bel,3),kj(bel) )
         ki(bel) = k(bel,1)
         ki(bel) = max( k(bel,2),ki(bel) )
         ki(bel) = max( k(bel,3),ki(bel) )
         mj(bel) = one
         mi(bel) = one
c
c              compute the scale factor and do the scaling
c
#sgl         iexp(bel) = int( ( log10(kj(bel))+log10(ki(bel))+
#dbl         iexp(bel) = idint( ( log10(kj(bel))+log10(ki(bel))+
     &                      log10(mj(bel))+log10(mi(bel)) ) / four )
         scale(bel) = one / ( ten ** iexp(bel) )
         m(bel,1) = m(bel,1) * scale(bel)
         m(bel,2) = m(bel,2) * scale(bel)
         m(bel,3) = m(bel,3) * scale(bel)
         k(bel,1) = k(bel,1) * scale(bel)
         k(bel,4) = k(bel,4) * scale(bel)
         k(bel,2) = k(bel,2) * scale(bel)
         k(bel,6) = k(bel,6) * scale(bel)
         k(bel,5) = k(bel,5) * scale(bel)
         k(bel,3) = k(bel,3) * scale(bel)
c
      end do
c
c              begin a new sweep
c
      do !  rotate iterations to eliminate off diagonals
c      	
      swpnum = swpnum + 1
      thold  = ten_thouth ** swpnum
      sqtol  = jactol * jactol
      if( thold < sqtol ) thold = sqtol
c
c              enter sweep loop -- work on lower triangle only
c                                          ( i > j )
c
c              rows are done from top to bottom
c              columns are done from left to right.
c
c
c           ***************************************
c           *                                     *
c           *           row 2 and column 1.       *
c           *                                     *
c           ***************************************
c
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
c 
      do bel = 1, span
c
c                       check if term is within threshold
c
         ratiok(bel) = (k(bel,4)*k(bel,4))/(k(bel,2)*k(bel,1))
         if( ratiok(bel) < thold )  cycle
c
c                      compute the rotatiom matrix:  an identity
c                      matrix with alpha at position (2,1) and
c                      gamma at position (1,2).
c
            kbari(bel) = -m(bel,2)*k(bel,4)
            kbarj(bel) = -m(bel,1)*k(bel,4)
            kbar(bel)  = k(bel,2)*m(bel,1)-k(bel,1)*m(bel,2)
            rad(bel)   = (kbar(bel)*kbar(bel)/four) + 
     &                   kbari(bel)*kbarj(bel)
c
            xsign(bel) = one
            x(bel) = kbar(bel)/two+sign(xsign(bel),kbar(bel))*
     &               sqrt(rad(bel))
c
            if( (abs(x(bel)).lt.jactol*abs(kbarj(bel))).or.
     &          (abs(x(bel)).lt.jactol*abs(kbari(bel)))    ) then
               alpha(bel) = zero
               gamma(bel) = -k(bel,4)/k(bel,2)
            else
               alpha(bel) = kbarj(bel)/x(bel)
               gamma(bel) = -kbari(bel)/x(bel)
            end if
c
c                       perform the rotation.
c
c                       row 3, column 2
c                       row 3, column 1
c
            ki(bel)  = k(bel,5)
            kj(bel)  = k(bel,6)
            k(bel,5) = ki(bel)+gamma(bel)*kj(bel)
            k(bel,6) = kj(bel)+alpha(bel)*ki(bel)
c
c                       term (2,1) and diagonal terms (2,2) and (1,1).
c
            kj(bel)  = k(bel,1)
            mj(bel)  = m(bel,1)
            ki(bel)  = k(bel,2)
            mi(bel)  = m(bel,2)
            k(bel,1) = kj(bel)+alpha(bel)*alpha(bel)*ki(bel)+
     &                 two*alpha(bel)*k(bel,4)
            m(bel,1) = mj(bel)+alpha(bel)*alpha(bel)*mi(bel)
            k(bel,2) = ki(bel)+gamma(bel)*gamma(bel)*kj(bel)+
     &                 two*gamma(bel)*k(bel,4)
            m(bel,2) = mi(bel)+gamma(bel)*gamma(bel)*mj(bel)
            k(bel,4) = zero
c
      end do
c
c           ***************************************
c           *                                     *
c           *           row 3 and column 1.       *
c           *                                     *
c           ***************************************
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do bel = 1, span
c
c                       check if term is within threshold
c
         ratiok(bel) = (k(bel,6)*k(bel,6))/(k(bel,3)*k(bel,1))
         if( ratiok(bel) < thold ) cycle
c
c                       compute the rotatiom matrix:  an identity
c                       matrix with alpha at position (3,1) and
c                       gamma at position (1,3).
c
            kbari(bel) = -m(bel,3)*k(bel,6)
            kbarj(bel) = -m(bel,1)*k(bel,6)
            kbar(bel)  = k(bel,3)*m(bel,1)-k(bel,1)*m(bel,3)
            rad(bel)   = (kbar(bel)*kbar(bel)/four) + 
     &                   kbari(bel)*kbarj(bel)
c
            xsign(bel) = one
            x(bel) = kbar(bel)/two+sign(xsign(bel),kbar(bel))*
     &              sqrt(rad(bel))
            if( (abs(x(bel)).lt.jactol*abs(kbarj(bel))).or.
     &          (abs(x(bel)).lt.jactol*abs(kbari(bel)))    ) then
               alpha(bel) = zero
               gamma(bel) = -k(bel,6)/k(bel,3)
            else
               alpha(bel) =  kbarj(bel)/x(bel)
               gamma(bel) = -kbari(bel)/x(bel)
            end if
c
c                       perform the rotation.
c
c                       row 3, column 2
c                       row 2, column 1
c
            ki(bel)  = k(bel,5)
            kj(bel)  = k(bel,4)
            k(bel,5) = ki(bel)+gamma(bel)*kj(bel)
            k(bel,4) = kj(bel)+alpha(bel)*ki(bel)
c
c                       term (3,1) and diagonal terms (3,3) and (1,1).
c
            kj(bel)  = k(bel,1)
            mj(bel)  = m(bel,1)
            ki(bel)  = k(bel,3)
            mi(bel)  = m(bel,3)
            k(bel,1) = kj(bel)+alpha(bel)*alpha(bel)*ki(bel)+
     &                 two*alpha(bel)*k(bel,6)
            m(bel,1) = mj(bel)+alpha(bel)*alpha(bel)*mi(bel)
            k(bel,3) = ki(bel)+gamma(bel)*gamma(bel)*kj(bel)+
     &                 two*gamma(bel)*k(bel,6)
            m(bel,3) = mi(bel)+gamma(bel)*gamma(bel)*mj(bel)
            k(bel,6) = zero
c
      end do
c
c           ***************************************
c           *                                     *
c           *           row 3 and column 2.       *
c           *                                     *
c           ***************************************
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do bel = 1, span
c
c                       check if term is within threshold
c
         ratiok(bel) = (k(bel,5)*k(bel,5))/(k(bel,3)*k(bel,2))
         if( ratiok(bel) < thold ) cycle
c
c                       compute the rotatiom matrix:  an identity
c                       matrix with alpha at position (3,2) and
c                       gamma at position (2,3).
c
            kbari(bel) = -m(bel,3)*k(bel,5)
            kbarj(bel) = -m(bel,2)*k(bel,5)
            kbar(bel)  =  k(bel,3)*m(bel,2)-k(bel,2)*m(bel,3)
            rad(bel)   = (kbar(bel)*kbar(bel)/four)
     &                   + kbari(bel)*kbarj(bel)
c
            xsign(bel) = one
            x(bel) = kbar(bel)/two+sign(xsign(bel),kbar(bel))*
     &               sqrt(rad(bel))
            if( (abs(x(bel)).lt.jactol*abs(kbarj(bel))).or.
     &          (abs(x(bel)).lt.jactol*abs(kbari(bel)))    ) then
               alpha(bel) = zero
               gamma(bel) = -k(bel,5)/k(bel,3)
            else
               alpha(bel) =  kbarj(bel)/x(bel)
               gamma(bel) = -kbari(bel)/x(bel)
            end if
c
c                       perform the rotation.
c
c                       row 3, column 1
c                       row 2, column 1
c
            ki(bel)  = k(bel,6)
            kj(bel)  = k(bel,4)
            k(bel,6) = ki(bel)+gamma(bel)*kj(bel)
            k(bel,4) = kj(bel)+alpha(bel)*ki(bel)
c
c                       term (3,2) and diagonal terms (3,3) and (2,2).
c
            kj(bel)  = k(bel,2)
            mj(bel)  = m(bel,2)
            ki(bel)  = k(bel,3)
            mi(bel)  = m(bel,3)
            k(bel,2) = kj(bel)+alpha(bel)*alpha(bel)*ki(bel)+
     &                 two*alpha(bel)*k(bel,5)
            m(bel,2) = mj(bel)+alpha(bel)*alpha(bel)*mi(bel)
            k(bel,3) = ki(bel)+gamma(bel)*gamma(bel)*kj(bel)+
     &                 two*gamma(bel)*k(bel,5)
            m(bel,3) = mi(bel)+gamma(bel)*gamma(bel)*mj(bel)
            k(bel,5) = zero
c
      end do
c
c              end sweep
c
c              check off-diagonal elements for convergence
c
      cvgtst = .true.
c
      do bel = 1, span
c
         errork(bel) = k(bel,4)*k(bel,4)/(k(bel,2)*k(bel,1))
         if( errork(bel) .gt. sqtol ) then
           cvgtst = .false.
           exit
         end if  
c
         errork(bel) = k(bel,6)*k(bel,6)/(k(bel,3)*k(bel,1))
         if( errork(bel) .gt. sqtol ) then
         	  cvgtst = .false.
         	  exit
         end if
c
         errork(bel) = k(bel,5)*k(bel,5)/(k(bel,3)*k(bel,2))
         if( errork(bel) .gt. sqtol ) then
            cvgtst = .false.
            exit
         end if
c
      end do
c
      if( cvgtst ) exit
      if( swpnum .lt. maxswp ) cycle
c      
      end do   ! over rotation iterations
c
c              update eigenvalue vector 
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
      do bel = 1, span
         lamda(bel,1) = k(bel,1) / m(bel,1)
         lamda(bel,2) = k(bel,2) / m(bel,2)
         lamda(bel,3) = k(bel,3) / m(bel,3)
      end do
c
c             reorder the eigenvalues. small to big
c
!DIR$ LOOP COUNT MAX=MAX_SPAN  
!DIR$ IVDEP
c
      do bel = 1, span
c
         if( lamda(bel,2) .lt. lamda(bel,1) ) then
            swap(bel)    = lamda(bel,1)
            lamda(bel,1) = lamda(bel,2)
            lamda(bel,2) = swap(bel)
         end if
c
         if( lamda(bel,3) .lt. lamda(bel,1) ) then
            swap(bel)    = lamda(bel,1)
            lamda(bel,1) = lamda(bel,3)
            lamda(bel,3) = swap(bel)
         end if
c
         if( lamda(bel,3) .lt. lamda(bel,2) ) then
            swap(bel)    = lamda(bel,2)
            lamda(bel,2) = lamda(bel,3)
            lamda(bel,3) = swap(bel)
         end if
c
      end do
c
      return
      end



