program test_realgrid_gap
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use grid_mod, only: grid_t, coeffs_t
    use io_mod, only: read_coeffs_nml, read_grid_csv
    use summary_mod, only: urban_rural_gap
    use feels_mod, only: feels_like_c
    use diurnal_mod, only: NT, diurnal_m, diurnal_base, &
                           T_MORNING, T_AFTERNOON, T_EVENING, T_PREDAWN
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none

    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [ new_testsuite('realgrid_gap', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1

contains

    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(1))
        testsuite(1) = new_unittest('test_realgrid', test_realgrid)
    end subroutine collect
    
    subroutine compute_feels(g, c, it, feels)
        type(grid_t), intent(in) :: g
        type(coeffs_t), intent(in) :: c
        integer, intent(in) :: it
        real(wp), allocatable, intent(out) :: feels(:,:)
        integer :: i, j
        real(wp) :: m_t, base_t
        
        allocate(feels(g%nx, g%ny))
        m_t = diurnal_m(c, it)
        base_t = diurnal_base(c, it)
        
        do j = 1, g%ny
            do i = 1, g%nx
                feels(i,j) = feels_like_c(base_t, m_t, g%cells(i,j)%rh, &
                                          g%cells(i,j)%building, g%cells(i,j)%tree, &
                                          g%cells(i,j)%water_km, g%cells(i,j)%is_urban, &
                                          c%w_build, c%w_urban, c%w_tree, c%w_water, c%d0)
            end do
        end do
    end subroutine compute_feels

    subroutine test_realgrid(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        type(coeffs_t) :: c
        integer :: stat
        character(len=512) :: msg
        real(wp), allocatable :: feels(:,:)
        real(wp) :: gap_val(4)
        integer :: it
        
        call read_coeffs_nml('data/coeffs.nml', c, stat, msg)
        call check(error, stat == 0)
        if (allocated(error)) return
        
        call read_grid_csv('data/hcmc_districts.csv', c%nx, c%ny, g, stat, msg)
        call check(error, stat == 0)
        if (allocated(error)) return
        
        do it = 1, NT
            call compute_feels(g, c, it, feels)
            gap_val(it) = urban_rural_gap(feels, g)
            ! Assert all positive
            call check(error, gap_val(it) > 0.0_wp)
            if (allocated(error)) return
        end do
        
        ! Assert gap_predawn > gap_afternoon
        call check(error, gap_val(T_PREDAWN) > gap_val(T_AFTERNOON))
    end subroutine test_realgrid

end program test_realgrid_gap
