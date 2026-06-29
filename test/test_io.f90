program test_io
    use testdrive, only: new_unittest, unittest_type, testsuite_type, new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use grid_mod, only: grid_t, coeffs_t
    use io_mod, only: read_grid_csv, read_coeffs_nml
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    
    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)
    
    testsuites = [ &
        new_testsuite('io_tests', collect_io_tests) &
    ]
    
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1

contains

    subroutine collect_io_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(13))
        testsuite(1) = new_unittest('test_valid', test_valid)
        testsuite(2) = new_unittest('test_bad_cols', test_bad_cols)
        testsuite(3) = new_unittest('test_bad_num', test_bad_num)
        testsuite(4) = new_unittest('test_bad_rh', test_bad_rh)
        testsuite(5) = new_unittest('test_bad_dup', test_bad_dup)
        testsuite(6) = new_unittest('test_coeffs', test_coeffs)
        testsuite(7) = new_unittest('test_coeffs_partial', test_coeffs_partial)
        testsuite(8) = new_unittest('test_bad_d0', test_bad_d0)
        testsuite(9) = new_unittest('test_bad_base', test_bad_base)
        testsuite(10) = new_unittest('test_bad_m', test_bad_m)
        testsuite(11) = new_unittest('test_bad_dims', test_bad_dims)
        testsuite(12) = new_unittest('test_bad_empty', test_bad_empty)
        testsuite(13) = new_unittest('test_bad_header', test_bad_header)
    end subroutine collect_io_tests

    subroutine test_valid(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        integer :: stat
        character(len=512) :: msg
        
        call read_grid_csv('test/fixtures/valid.csv', 8, 10, g, stat, msg)
        
        call check(error, stat == 0)
        if (allocated(error)) return
        call check(error, g%ndist == 3)
        if (allocated(error)) return
        call check(error, g%cells(4,5)%is_urban .eqv. .true.)
        call check(error, abs(g%cells(4,5)%t_air - 31.5_wp) < 1.0e-5_wp)
        call check(error, g%cells(1,1)%is_urban .eqv. .false.)
    end subroutine test_valid

    subroutine test_bad_cols(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        integer :: stat
        character(len=512) :: msg
        
        call read_grid_csv('test/fixtures/bad_cols.csv', 8, 10, g, stat, msg)
        call check(error, stat /= 0)
        call check(error, index(msg, ':2:') > 0)
    end subroutine test_bad_cols

    subroutine test_bad_num(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        integer :: stat
        character(len=512) :: msg
        
        call read_grid_csv('test/fixtures/bad_num.csv', 8, 10, g, stat, msg)
        call check(error, stat /= 0)
    end subroutine test_bad_num

    subroutine test_bad_rh(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        integer :: stat
        character(len=512) :: msg
        
        call read_grid_csv('test/fixtures/bad_rh.csv', 8, 10, g, stat, msg)
        call check(error, stat /= 0)
        call check(error, index(msg, ':2:') > 0)
    end subroutine test_bad_rh

    subroutine test_bad_dup(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        integer :: stat
        character(len=512) :: msg
        
        call read_grid_csv('test/fixtures/bad_dup.csv', 8, 10, g, stat, msg)
        call check(error, stat /= 0)
    end subroutine test_bad_dup

    subroutine test_coeffs(error)
        type(error_type), allocatable, intent(out) :: error
        type(coeffs_t) :: c
        integer :: stat
        character(len=512) :: msg
        
        call read_coeffs_nml('test/fixtures/coeffs.nml', c, stat, msg)
        call check(error, stat == 0)
        if (allocated(error)) return
        call check(error, c%nx == 8)
        call check(error, c%ny == 10)
        call check(error, abs(c%w_build - 3.5_wp) < 1.0e-5_wp)
    end subroutine test_coeffs

    subroutine test_coeffs_partial(error)
        type(error_type), allocatable, intent(out) :: error
        type(coeffs_t) :: c
        integer :: stat
        character(len=512) :: msg
        
        call read_coeffs_nml('test/fixtures/coeffs_partial.nml', c, stat, msg)
        call check(error, stat == 0)
        if (allocated(error)) return
        call check(error, c%nx == 8)
        call check(error, c%ny == 10)
        call check(error, abs(c%w_urban - 1.0_wp) < 1.0e-5_wp) ! default retained
    end subroutine test_coeffs_partial

    subroutine test_bad_d0(error)
        type(error_type), allocatable, intent(out) :: error
        type(coeffs_t) :: c
        integer :: stat
        character(len=512) :: msg
        
        call read_coeffs_nml('test/fixtures/coeffs_bad_d0.nml', c, stat, msg)
        call check(error, stat /= 0)
    end subroutine test_bad_d0

    subroutine test_bad_base(error)
        type(error_type), allocatable, intent(out) :: error
        type(coeffs_t) :: c
        integer :: stat
        character(len=512) :: msg
        
        call read_coeffs_nml('test/fixtures/coeffs_bad_base.nml', c, stat, msg)
        call check(error, stat /= 0)
    end subroutine test_bad_base

    subroutine test_bad_m(error)
        type(error_type), allocatable, intent(out) :: error
        type(coeffs_t) :: c
        integer :: stat
        character(len=512) :: msg
        
        call read_coeffs_nml('test/fixtures/coeffs_bad_m.nml', c, stat, msg)
        call check(error, stat /= 0)
    end subroutine test_bad_m

    subroutine test_bad_dims(error)
        type(error_type), allocatable, intent(out) :: error
        type(coeffs_t) :: c
        integer :: stat
        character(len=512) :: msg
        
        call read_coeffs_nml('test/fixtures/coeffs_bad_dims.nml', c, stat, msg)
        call check(error, stat /= 0)
    end subroutine test_bad_dims

    subroutine test_bad_empty(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        integer :: stat
        character(len=512) :: msg
        
        call read_grid_csv('test/fixtures/bad_empty.csv', 8, 10, g, stat, msg)
        call check(error, stat /= 0)
    end subroutine test_bad_empty

    subroutine test_bad_header(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        integer :: stat
        character(len=512) :: msg
        
        call read_grid_csv('test/fixtures/bad_header_only.csv', 8, 10, g, stat, msg)
        call check(error, stat /= 0)
    end subroutine test_bad_header

end program test_io
