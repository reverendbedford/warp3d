# All our sources
# CMake actually handles modules correctly!!!
list(APPEND main
      "addifv.f"
      "addmas.f"
      "adapt_check.f"
      "aplacc.f"
      "allocate_damage.f"
      "allocate_load.f"
      "assemble_code.f"
      "bdbt.f"
      "blcmp1.f"
      "bmod.f"
      "chkcrack.f"
      "chkcrack_ctoa.f"
      "chkcrack_gurson.f"
      "chkcrack_smcs.f"
      "chkcrack_cohesive.f"
      "chk_stp_reduce.f"
      "chk_stp_reduce_ctoa.f"
      "chk_stp_reduce_gurson.f"
      "chk_stp_reduce_smcs.f"
      "chk_stp_reduce_cohes.f"
      "cmpmas.f"
      "cohes_elem.f"
      "con_dump.f"
      "contact.f"
      "comput.f"
      "cpu_time.f"
      "cvtest.f"
      "derivs.f"
      "didriv.f"
      "distup.f"
      "distributed_assembly.f"
      "difrar.f"
      "difrtn.f"
      "di1dsf.f"
      "dimrot.f"
      "dicmj.f"
      "dielem_a.f"
      "dielem_b.f"
      "dielem_c.f"
      "direct_driver_sparse.f"
      "direct_sparse_mkl.f"
      "diexp4.f"
      "dptstf.f"
      "drive_eps_sig_internal_forces.f"
      "dupmas.f"
      "dupstr.f"
      "elmas1.f"
      "elem_load_a.f"
      "elem_load_b.f"
      "elem_load_c.f"
      "elprp.f"
      "energy.f"
      "eqivld.f"
      "equiv_strain.f"
      "errchk.f"
      "errmsg.f"
      "find_neighbors.f"
      "gastr.f"
      "gatemps.f"
      "get_edest.f"
      "growth_loads.f"
      "gp_temp_eps.f"
      "gpifv1.f"
      "gpmas1.f"
      "gptns1.f"
      "gtlsn1.f"
      "gtmat1.f"
      "incomp.f"
      "inclmass.f"
      "incontact.f"
      "incon.f"
      "incoor.f"
      "incrystal.f"
      "insurf.f"
      "intied.f"
      "indypm.f"
      "inelbk.f"
      "inelem.f"
      "infile.f"
      "incurv.f"
      "indom.f"
      "inalpha.f"
      "incrack.f"
      "infgm.f"
      "inicon.f"
      "ininc.f"
      "initdm.f"
      "initst.f"
      "inlod.f"
      "inmat.f"
      "innum.f"
      "intab.f"
      "iterative_sparse_hypre.f"
      "iodevn.f"
      "kg1.f"
      "kill_element.f"
      "license.f"
      "linked_list.f"
      "main_program.f"
      "mnralg.f"
      "mem_allocate.f"
      "mm01.f"
      "mm02.f"
      "mm03.f"
      "mm04.f"
      "mm05.f"
      "mm06.f"
      "mm07.f"
      "mm08.f"
      "mm09.f"
      "mm10_a.f"
      "mm10_b.f"
      "mm10_c.f"
      "mm10_d.f"
      "mm10_e.f"
      "mm10_f.f"
      "mm11.f"
      "mmnoopt.f"
      "mod_adaptive_steps.f" 
      "mod_contact.f" 
      "mod_crack_growth.f"
      "mod_crystals.f"
      "mod_damage.f" 
      "mod_elblk.f" 
      "mod_eleblocks.f" 
      "mod_elem_load.f" 
      "mod_file_info.f" 
      "mod_hypre.f" 
      "mod_jintegral.f" 
      "mod_local_stiffness.f" 
      "mod_main.f" 
      "mod_mpc.f" 
      "mod_mpi_lnpcg.f" 
      "mod_pconvert.f" 
      "mod_performance.f" 
      "mod_segmental_curves.f" 
      "mod_stiffness.f"
      "mpi_code.f"
      "mpi_handle_slaves.f"
      "mpc_modify.f"
      "name_strip.f"
      "ndpts1.f"
      "ou3dpr.f"
      "oualph.f"
      "ouddpa.f"
      "oudriv.f"
      "oudups.f"
      "oudva.f"
      "oueff1.f"
      "ouext1.f"
      "ouext2.f"
      "ouflnm.f"
      "ougts1.f"
      "ouhdva.f"
      "ouhel.f"
      "ouhnod.f"
      "ouhprn.f"
      "ouhrks.f"
      "ouhstr.f"
      "ouinv1.f"
      "oulbdd.f"
      "oulbir.f"
      "oulbst.f"
      "oulbta.f"
      "oulg1.f"
      "oulrlh.f"
      "oumkcv.f"
      "oundhd.f"
      "ounds1.f"
      "ouocdd.f"
      "ouocst.f"
      "ouneut.f"
      "ouocst_elem.f"
      "oupads.f"
      "ouparm.f"
      "oupdva.f"
      "oupele.f"
      "oupri1.f"
      "ouprks.f"
      "oupstr_elem.f"
      "oupstr_node.f"
      "oures.f"
      "ourlhd.f"
      "ousthd.f"
      "oustpa.f"
      "oust_elem.f"
      "oustates.f"
      "outfil.f"
      "oustr.f"
      "outime.f"
      "ouyld1.f"
      "packets.f"
      "pconvert.f"
      "princ_inv_strain.f"
      "princ_inv_stress.f"
      "princ_strain.f"
      "princ_stress.f"
      "prcsel.f"
      "qmply1.f"
      "getgpts.f"
      "read_damage.f"
      "read_write.f"
      "reopen.f"
      "rknifv.f"
      "rknmas.f"
      "rknstr.f"
      "rktstf.f"
      "rplstr.f"
      "rscmp1.f"
      "rstgp1.f"
      "scan.f"
      "scstr.f"
      "setelb.f"
      "setup.f"
      "shapef.f"
      "setup_mat_props.f"
      "splunj.f"
      "statistics.f"
      "steptime.f"
      "store.f"
      "store_ifv.f"
      "stpdrv.f"
      "star_com.f"
      "tanstf.f"
      "temsto.f"
      "thyme.f"
      "trnvec.f"
      "trnmtx.f"
      "tied_mesh.f"
      "tilde.f"
      "update.f"
      "update_node_elecnt.f"
      "uppbar.f"
      "upres.f"
      "user_list.f"
      "user_routines_module.f"
      "user_routines_umat.f"
      "user_routines_other_Abaqus.f"
      "user_routines_warp3d.f"
      "user_routines_support.f"
      "vol_terms.f"
      "vol_avg.f"
      "yield_function.f"
      "zero_vector.f"
      "zero_vol.f"
      )

# You can specify a list of files for each set_source_files_properties
#if(CMAKE_BUILD_TYPE MATCHES Release) # Don't make changes if we're in DEBUG
#      if(APPLE)
#            set_source_files_properties(
#                  dicmi.f
#                  mmnoopt.f 
#                  PROPERTIES COMPILE_FLAGS "-O1")
#      elseif(WIN32 OR CYGWIN) # We could distinguish cygwin
#            set_source_files_properties(
#                  dicmi.f
#                  mmnoopt.f 
#                  PROPERTIES COMPILE_FLAGS "-O1")
#      else() # Linux
#            set_source_files_properties(
#                  dicmi.f
#                  mmnoopt.f 
#                  PROPERTIES COMPILE_FLAGS "-O1")
#      endif()
#endif()

add_executable(${EXE_NAME} ${main})
target_link_libraries(${EXE_NAME} ${MKL_LIBRARIES} ${MPI_Fortran_LIBRARIES} ${HYPRE_LIBRARIES})

