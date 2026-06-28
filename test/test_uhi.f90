program test_uhi
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use uhi_mod, only: uhi_offset
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [ new_testsuite('uhi_tests', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1

contains

    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(3))
        testsuite(1) = new_unittest('test_signs', test_signs)
        testsuite(2) = new_unittest('test_monotonicity', test_monotonicity)
        testsuite(3) = new_unittest('test_magnitude', test_magnitude)
    end subroutine collect

    subroutine test_signs(error)
        type(error_type), allocatable, intent(out) :: error
        real(wp) :: dT

        ! w_build=3, w_urban=1, w_tree=2.5, w_water=2, d0=2.5
        ! Baseline urban core: building=1, urban=T, tree=0, water=inf
        dT = uhi_offset(1.0_wp, 0.0_wp, 100.0_wp, .true., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        call check(error, dT > 0.0_wp)
        if (allocated(error)) return

        ! Baseline park: building=0, urban=F, tree=1, water=0 (on water)
        dT = uhi_offset(0.0_wp, 1.0_wp, 0.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        call check(error, dT < 0.0_wp)
    end subroutine test_signs

    subroutine test_monotonicity(error)
        type(error_type), allocatable, intent(out) :: error
        real(wp) :: dT1, dT2

        ! w_build=3, w_urban=1, w_tree=2.5, w_water=2, d0=2.5
        
        ! More building -> hotter
        dT1 = uhi_offset(0.5_wp, 0.0_wp, 10.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        dT2 = uhi_offset(0.8_wp, 0.0_wp, 10.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        call check(error, dT2 > dT1)
        if (allocated(error)) return

        ! More tree -> cooler
        dT1 = uhi_offset(0.5_wp, 0.2_wp, 10.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        dT2 = uhi_offset(0.5_wp, 0.8_wp, 10.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        call check(error, dT2 < dT1)
        if (allocated(error)) return
        
        ! Closer to water -> cooler
        dT1 = uhi_offset(0.5_wp, 0.0_wp, 5.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        dT2 = uhi_offset(0.5_wp, 0.0_wp, 1.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        call check(error, dT2 < dT1)
        if (allocated(error)) return

        ! Urban vs non-urban (all else equal) -> hotter
        dT1 = uhi_offset(0.5_wp, 0.0_wp, 10.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        dT2 = uhi_offset(0.5_wp, 0.0_wp, 10.0_wp, .true., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        call check(error, dT2 > dT1)
    end subroutine test_monotonicity

    subroutine test_magnitude(error)
        type(error_type), allocatable, intent(out) :: error
        real(wp) :: dT_max, dT_min
        
        ! Max case: B=1, U=T, V=0, Wprox->0 (far from water)
        dT_max = uhi_offset(1.0_wp, 0.0_wp, 100.0_wp, .true., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        
        ! Min case: B=0, U=F, V=1, Wprox=1 (at water)
        dT_min = uhi_offset(0.0_wp, 1.0_wp, 0.0_wp, .false., 3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        
        ! Magnitude single-digit (-10 < dT < 10)
        call check(error, dT_max < 10.0_wp)
        if (allocated(error)) return
        call check(error, dT_min > -10.0_wp)
    end subroutine test_magnitude

end program test_uhi
