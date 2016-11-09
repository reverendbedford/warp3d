#include "defines.h"
c     ****************************************************************
c     *                                                              *
c     *                      subroutine ouocdd                       *
c     *                                                              *
c     *                       written by : bh                        *
c     *                                                              *
c     *                   last modified : 4/13/2014 rhd              *
c     *                                                              *
c     *     handle file open/close for Patran and flat file results  *
c     *     make file name based on load step, results type, etc.    *
c     *     this routine handles result types:                       *
c     *     displacements, velocities, accelerations, reactions,     *
c     *     temperatures                                             *
c     *                                                              *
c     ****************************************************************
c
c
c
      subroutine ouocdd( dva, ltmstp, oubin, ouasc, bnfile, fmfile,
     &                   opt, use_mpi, myid, flat_file, stream_file,
     &                   text_file, compressed, flat_file_number )
      implicit integer (a-z)
      character*14 bflnam, fflnam
      character*4 strtnm, slist(5)
      character*3 flat_list(5)
      character*30 command
      character*20, save :: flat_name
      logical oubin, ouasc, use_mpi, patran_file, ok, flat_file, 
     &        stream_file, text_file, compressed 
      external warp3d_get_device_number
      
      data slist / 'wn?d','wn?v', 'wn?a', 'wn?r', 'wn?t' /
      data flat_list /  'wnd','wnv', 'wna', 'wnr', 'wnt' / 
c
c                       close patran or flat result file
c                       compress for flat text file if option
c                       requested.
c
      patran_file = oubin .or. ouasc
      ok = patran_file .or. flat_file
c      
      if( .not. ok ) then
        k = 0
        call errmsg3( 22, k )
        call die_abort
      end if
c                     
      if( opt .eq. 2 .and. patran_file ) then  ! close file
        if( oubin ) close(bnfile,status='keep')
        if( ouasc ) close(fmfile,status='keep')
        return
      end if
c      
      if( opt .eq. 2 .and. flat_file ) then
         close(unit=flat_file_number,status='keep')
         if( .not. text_file ) return
          if( compressed ) then
c             command(1:) = ' '
c             command(1:) = 'gzip ' // flat_name
c             result = system( command )
c             CALL ZLIB
          end if
          return
      end if
c
c                       opt =1, create file name and open file
c                       valid request for here?
c
      if( dva .lt. 1 .or. dva .gt. 5 ) then
        k = 0
        call errmsg3( 21, k )
        call die_abort
      end if
c
c                       patran result files. ltmstp is step number
c
c                         wn(b)(f) +    X     + step no + MPI rank
c                        char*3      char*1      i5.5     i4.4
c
c                        X = d, v, a, r, t
c
      step_number = ltmstp
      if ( patran_file ) then      
        strtnm = slist(dva)
        if( oubin ) then
          strtnm(3:3) = "b"
          call ouflnm( strtnm, bflnam, step_number, use_mpi, myid )
          bnfile = 98
          open(bnfile,file=bflnam,status='unknown',
     &         access='sequential',form='unformatted',recl=350 )
        end if
        if( ouasc)  then
          strtnm(3:3) = "f"
          call ouflnm( strtnm, fflnam, step_number, use_mpi, myid )
          fmfile = 99
          open(fmfile,file=fflnam,status='unknown',
     &         access='sequential',form='formatted',recl=350 )
         end if
         return
      end if         
c
c                       flat result files. name structure
c                        wnX + step # + _text   + MPI rank
c                        wnX + step # + _stream + MPI rank
c                              i5.5                i4.4
c                        where X is d, v, a, r, t
c
      flat_file_number = warp3d_get_device_number()
      flat_name(1:20) = ' '
      flat_name(1:3)  = flat_list(dva)
      if( step_number .gt. 99999 ) step_number = step_number - 99999
      write(flat_name(4:),9000) step_number
c      
      if( stream_file ) then
        flat_name(9:) = '_stream'
        if( use_mpi )  write(flat_name(16:),9100) myid  
        open( unit=flat_file_number, file=flat_name, status='unknown',
     &        access='stream', form='unformatted' )
        return  
      end if
      if( text_file ) then
        flat_name(9:) = '_text'
        if( use_mpi ) write(flat_name(14:),9100) myid  
        open( unit=flat_file_number, file=flat_name, status='unknown',
     &        access='sequential', form='formatted' )
        return
      end if         
c
 9000 format(i5.5)
 9100 format(i4.4)
      end

