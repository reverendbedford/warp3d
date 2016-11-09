#include "defines.h"
c     ****************************************************************
c     *                                                              *
c     *              f-90 module segmental_curves                    *
c     *                                                              *
c     *                       written by : rhd                       *
c     *                                                              *
c     *                    last modified : 10/18/2009 RHD            *
c     *                              (fix bug in threadprivate)      *
c     *                                                              *
c     *     define the variables and data structures to support      *
c     *     segmental stress-strain curves                           *
c     *                                                              *
c     ****************************************************************
c
c
c
      module segmental_curves
c
      parameter (max_seg_points=20, max_seg_curves=20,
     &           max_seg_curve_sets=10)
c
c          This module has two sets of variables. The first
c          set down to the next comments are used to store the
c          data from user input to define various segmental
c          stress-strain curves. These variables are saved and
c          restored during setup for an execution of restart.
c          None of these variables are changed during 
c          problem solution once the input data has
c          been verified. they are shared read-only across threads
c
c                     double precision/reals
c
#dbl       double precision
#sgl       real
     & seg_curves(max_seg_points,2,max_seg_curves),
     & seg_curves_min_stress(max_seg_curves),
     & seg_curves_value(max_seg_curves),
     & seg_curves_ym(max_seg_curves),
     & seg_curves_nu(max_seg_curves),
     & seg_curves_alpha(max_seg_curves),
     & seg_curves_gp_sigma_0(max_seg_curves),
     & seg_curves_gp_h_u(max_seg_curves),
     & seg_curves_gp_beta_u(max_seg_curves),
     & seg_curves_gp_delta_u(max_seg_curves)
c
c                     integers
c
      integer
     &   num_seg_points(max_seg_curves), 
     &   seg_curves_type(max_seg_curves),
     &   max_current_pts,
     &   max_current_curves, num_points, num_curve, num_seg_curve_sets,
     &   seg_curve_table(max_seg_curves+1,max_seg_curve_sets)
c
c                     logicals
c
      logical
     &  seg_curve_def(max_seg_curves)
c
c          These variable below are used during problem
c          solution to support block-by-block computations.
c          The module is used to reduced the large number
c          of dummy arguments that would be passed many levels
c          down thru block computation rouitnes.
c
c          For OMP threaded parallel, these variables must be
c          private for each thread since different threads could
c          write concurrently on a single, global instance of this
c          module. We use the threadprivate declaration so
c          each thread gets their own copy. This works even for
c          allocated arrays
c
#dbl       double precision,
#sgl       real,
     &  dimension (:), allocatable :: sigma_curve_min_values,
     &  curve_temps, curve_e_values, curve_nu_values,
     &  curve_alpha_values, curve_rates,
     &  curve_gp_sig_0_values, curve_gp_h_u_values,
     &  curve_gp_beta_u_values, curve_gp_delta_u_values
#dbl       double precision,
#sgl       real, 
     &   dimension(max_seg_points) ::
     &   curve_plseps_values
c
#dbl       double precision,
#sgl       real,
     &  dimension (:,:), allocatable :: sigma_curves,
     &                                  sigma_inter_table
c
      integer :: active_curve_set=0, now_blk_relem=0
      data  curve_plseps_values(1:max_seg_points)/max_seg_points*0.0/
c
c$OMP THREADPRIVATE(
c$OMP&  sigma_curve_min_values, curve_temps, curve_e_values,
c$OMP&  curve_nu_values, curve_alpha_values, curve_rates,
c$OMP&  sigma_curves, sigma_inter_table, active_curve_set, 
c$OMP&  now_blk_relem, curve_plseps_values, curve_gp_sig_0_values,
c$OMP&  curve_gp_h_u_values, curve_gp_beta_u_values, 
c$OMP&  curve_gp_delta_u_values )
c
c
      end module


