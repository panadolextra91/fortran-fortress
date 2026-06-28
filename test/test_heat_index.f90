program test_heat_index
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use heat_index_mod, only: heat_index_f
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [ new_testsuite('heat_index', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1

contains

    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(2))
        testsuite(1) = new_unittest('ref_values', test_ref)
        testsuite(2) = new_unittest('boundary', test_boundary)
    end subroutine collect

    subroutine test_ref(error)
        type(error_type), allocatable, intent(out) :: error
        
        ! 90/70 -> 105.9220
        call check(error, abs(heat_index_f(90.0_wp, 70.0_wp) - 105.9220_wp) < 1.0e-2_wp)
        if (allocated(error)) return

        ! 86/90 -> 105.3944 (RH>85% adj)
        call check(error, abs(heat_index_f(86.0_wp, 90.0_wp) - 105.3944_wp) < 1.0e-2_wp)
    end subroutine test_ref

    subroutine test_boundary(error)
        type(error_type), allocatable, intent(out) :: error

        ! 79/70 -> 79.4450 (Steadman)
        call check(error, abs(heat_index_f(79.0_wp, 70.0_wp) - 79.4450_wp) < 1.0e-2_wp)
        if (allocated(error)) return

        ! 80/40 -> 79.7900 (Algorithm value < 80)
        call check(error, abs(heat_index_f(80.0_wp, 40.0_wp) - 79.7900_wp) < 1.0e-2_wp)
        if (allocated(error)) return

        ! 75/80 -> 75.4800 (Cool branch)
        call check(error, abs(heat_index_f(75.0_wp, 80.0_wp) - 75.4800_wp) < 1.0e-2_wp)
        if (allocated(error)) return

        ! 75/20 -> < 75.0 (Cool/dry corner)
        call check(error, heat_index_f(75.0_wp, 20.0_wp) < 75.0_wp)
    end subroutine test_boundary

end program test_heat_index
