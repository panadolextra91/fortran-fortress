program test_summary
    use testdrive, only: new_unittest, unittest_type, error_type, check, testsuite_type, new_testsuite, run_testsuite
    use kinds_mod, only: wp
    use summary_mod, only: hottest, coolest
    use grid_mod, only: grid_t, allocate_grid
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none

    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [ &
        new_testsuite('summary_tests', collect_summary_tests) &
    ]
    
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) stop 1

contains

    subroutine collect_summary_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(1))
        testsuite(1) = new_unittest('test_extremes', test_extremes)
    end subroutine collect_summary_tests

    subroutine test_extremes(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        real(wp), allocatable :: feels(:,:)
        integer :: ih, jh, ic, jc
        real(wp) :: val_hot, val_cool

        call allocate_grid(g, 3, 1)
        allocate(feels(3, 1))

        ! Mark 1,1 and 3,1 occupied
        g%cells(1,1)%occupied = .true.
        g%cells(1,1)%name = 'C1'
        g%cells(2,1)%occupied = .false.
        g%cells(2,1)%name = 'C2'
        g%cells(3,1)%occupied = .true.
        g%cells(3,1)%name = 'C3'

        ! Put max in unoccupied, occupied min in 1, occupied max in 3
        feels(1,1) = 31.0_wp
        feels(2,1) = 99.0_wp
        feels(3,1) = 35.0_wp

        call hottest(feels, g, ih, jh, val_hot)
        call coolest(feels, g, ic, jc, val_cool)

        call check(error, ih == 3)
        if (allocated(error)) return
        call check(error, jh == 1)
        if (allocated(error)) return
        call check(error, abs(val_hot - 35.0_wp) < 1.0e-5_wp)
        if (allocated(error)) return

        call check(error, ic == 1)
        if (allocated(error)) return
        call check(error, jc == 1)
        if (allocated(error)) return
        call check(error, abs(val_cool - 31.0_wp) < 1.0e-5_wp)
        if (allocated(error)) return

        ! Test empty grid behavior
        g%cells(1,1)%occupied = .false.
        g%cells(3,1)%occupied = .false.
        call hottest(feels, g, ih, jh, val_hot)
        call check(error, ih == 0)
        if (allocated(error)) return
        call check(error, jh == 0)
        if (allocated(error)) return
        call check(error, abs(val_hot) < 1.0e-5_wp)
        if (allocated(error)) return
    end subroutine test_extremes

end program test_summary
