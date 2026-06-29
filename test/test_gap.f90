program test_gap
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use grid_mod, only: grid_t, allocate_grid
    use summary_mod, only: urban_rural_gap, city_average
    use feels_mod, only: feels_like_c
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none

    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [ new_testsuite('gap', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1

contains

    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(3))
        testsuite(1) = new_unittest('test_hard_direction', test_hard_direction)
        testsuite(2) = new_unittest('test_hard_night_sanity', test_hard_night_sanity)
        testsuite(3) = new_unittest('test_soft_magnitude', test_soft_magnitude)
    end subroutine collect
    
    subroutine setup_grid(g)
        type(grid_t), intent(out) :: g
        call allocate_grid(g, 3, 2)
        
        ! Urban cells (e.g. industrial, D1, D5)
        g%cells(1,1)%building = 0.95_wp; g%cells(1,1)%tree = 0.02_wp
        g%cells(1,1)%water_km = 8.0_wp; g%cells(1,1)%is_urban = .true.; g%cells(1,1)%rh = 75.0_wp
        
        g%cells(2,1)%building = 0.90_wp; g%cells(2,1)%tree = 0.10_wp
        g%cells(2,1)%water_km = 3.0_wp; g%cells(2,1)%is_urban = .true.; g%cells(2,1)%rh = 75.0_wp
        
        g%cells(3,1)%building = 0.82_wp; g%cells(3,1)%tree = 0.08_wp
        g%cells(3,1)%water_km = 1.5_wp; g%cells(3,1)%is_urban = .true.; g%cells(3,1)%rh = 75.0_wp
        
        ! Rural cells (e.g. Can Gio, Cu Chi, Nha Be)
        g%cells(1,2)%building = 0.10_wp; g%cells(1,2)%tree = 0.70_wp
        g%cells(1,2)%water_km = 0.0_wp; g%cells(1,2)%is_urban = .false.; g%cells(1,2)%rh = 75.0_wp
        
        g%cells(2,2)%building = 0.15_wp; g%cells(2,2)%tree = 0.55_wp
        g%cells(2,2)%water_km = 9.0_wp; g%cells(2,2)%is_urban = .false.; g%cells(2,2)%rh = 75.0_wp
        
        g%cells(3,2)%building = 0.30_wp; g%cells(3,2)%tree = 0.45_wp
        g%cells(3,2)%water_km = 0.5_wp; g%cells(3,2)%is_urban = .false.; g%cells(3,2)%rh = 75.0_wp
        
        g%cells(:,:)%occupied = .true.
    end subroutine setup_grid
    
    subroutine compute_feels_grid(g, base, m, feels)
        type(grid_t), intent(in) :: g
        real(wp), intent(in) :: base, m
        real(wp), allocatable, intent(out) :: feels(:,:)
        integer :: i, j
        real(wp) :: w_build, w_urban, w_tree, w_water, d0
        
        w_build = 3.0_wp; w_urban = 1.0_wp; w_tree = 2.5_wp; w_water = 2.0_wp; d0 = 2.5_wp
        allocate(feels(g%nx, g%ny))
        
        do j = 1, g%ny
            do i = 1, g%nx
                feels(i,j) = feels_like_c(base, m, g%cells(i,j)%rh, &
                                          g%cells(i,j)%building, g%cells(i,j)%tree, &
                                          g%cells(i,j)%water_km, g%cells(i,j)%is_urban, &
                                          w_build, w_urban, w_tree, w_water, d0)
            end do
        end do
    end subroutine compute_feels_grid

    subroutine test_hard_direction(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        real(wp), allocatable :: feels_aft(:,:), feels_pre(:,:)
        real(wp) :: gap_afternoon, gap_predawn
        
        call setup_grid(g)
        
        ! Afternoon: base=33, m=0.3
        call compute_feels_grid(g, 33.0_wp, 0.3_wp, feels_aft)
        gap_afternoon = urban_rural_gap(feels_aft, g)
        
        ! Predawn: base=25, m=1.0
        call compute_feels_grid(g, 25.0_wp, 1.0_wp, feels_pre)
        gap_predawn = urban_rural_gap(feels_pre, g)
        
        call check(error, gap_predawn > gap_afternoon)
    end subroutine test_hard_direction

    subroutine test_hard_night_sanity(error)
        type(error_type), allocatable, intent(out) :: error
        real(wp) :: feels_cangio
        
        feels_cangio = feels_like_c(25.0_wp, 1.0_wp, 88.0_wp, 0.05_wp, 0.85_wp, 0.2_wp, .false., &
                                    3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)
        
        call check(error, feels_cangio >= 21.0_wp .and. feels_cangio <= 26.0_wp)
    end subroutine test_hard_night_sanity

    subroutine test_soft_magnitude(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        real(wp), allocatable :: feels_pre(:,:)
        real(wp) :: gap_predawn
        
        call setup_grid(g)
        call compute_feels_grid(g, 25.0_wp, 1.0_wp, feels_pre)
        gap_predawn = urban_rural_gap(feels_pre, g)
        
        if (.not. (gap_predawn >= 3.0_wp .and. gap_predawn <= 8.0_wp)) then
            write(error_unit, '(A,F0.2,A)') 'WARN night gap = ', gap_predawn, ' C (expect ~3-8 C)'
        end if
        ! No check() here, soft warning only
    end subroutine test_soft_magnitude

end program test_gap
