program test_diurnal
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use grid_mod, only: coeffs_t
    use diurnal_mod, only: NT, T_MORNING, T_AFTERNOON, T_EVENING, T_PREDAWN, &
                           diurnal_m, diurnal_base, time_label
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none

    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [ new_testsuite('diurnal', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1

contains

    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(1))
        testsuite(1) = new_unittest('test_selectors', test_selectors)
    end subroutine collect

    subroutine test_selectors(error)
        type(error_type), allocatable, intent(out) :: error
        type(coeffs_t) :: c
        
        c%m_morning = 0.5_wp
        c%m_afternoon = 0.3_wp
        c%m_evening = 0.8_wp
        c%m_predawn = 1.0_wp
        c%base_morning = 29.0_wp
        c%base_afternoon = 33.0_wp
        c%base_evening = 30.0_wp
        c%base_predawn = 25.0_wp
        
        call check(error, abs(diurnal_m(c, T_AFTERNOON) - 0.3_wp) < 1.0e-9_wp)
        if (allocated(error)) return
        call check(error, abs(diurnal_m(c, T_PREDAWN) - 1.0_wp) < 1.0e-9_wp)
        if (allocated(error)) return
        call check(error, abs(diurnal_base(c, T_AFTERNOON) - 33.0_wp) < 1.0e-9_wp)
        if (allocated(error)) return
        call check(error, abs(diurnal_base(c, T_PREDAWN) - 25.0_wp) < 1.0e-9_wp)
        if (allocated(error)) return
        call check(error, time_label(T_PREDAWN) == 'predawn')
    end subroutine test_selectors

end program test_diurnal
