program test_scenario
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use grid_mod, only: grid_t, allocate_grid
    use scenario_mod, only: scenario_t, apply_scenario
    use feels_mod, only: feels_like_c
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none

    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [ new_testsuite('scenario', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1

contains

    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(4))
        testsuite(1) = new_unittest('test_immutability', test_immutability)
        testsuite(2) = new_unittest('test_one_driver', test_one_driver)
        testsuite(3) = new_unittest('test_clamp', test_clamp)
        testsuite(4) = new_unittest('test_delta_sign', test_delta_sign)
    end subroutine collect

    subroutine setup_grid(g)
        type(grid_t), intent(out) :: g
        call allocate_grid(g, 2, 2)
        ! High-tree cell
        g%cells(1,1)%tree = 0.95_wp
        g%cells(1,1)%building = 0.20_wp
        g%cells(1,1)%is_urban = .false.
        g%cells(1,1)%rh = 80.0_wp
        g%cells(1,1)%water_km = 1.0_wp
        g%cells(1,1)%occupied = .true.
        
        ! Urban core cell
        g%cells(2,2)%tree = 0.10_wp
        g%cells(2,2)%building = 0.90_wp
        g%cells(2,2)%is_urban = .true.
        g%cells(2,2)%rh = 75.0_wp
        g%cells(2,2)%water_km = 5.0_wp
        g%cells(2,2)%occupied = .true.
    end subroutine setup_grid

    subroutine test_immutability(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: baseline, work
        type(scenario_t) :: add_trees
        real(wp) :: orig_tree
        
        call setup_grid(baseline)
        orig_tree = baseline%cells(1,1)%tree
        
        add_trees%tree_delta = 0.2_wp
        work = baseline
        call apply_scenario(work, add_trees)
        
        call check(error, abs(baseline%cells(1,1)%tree - orig_tree) < 1.0e-12_wp)
    end subroutine test_immutability

    subroutine test_one_driver(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: baseline, work
        type(scenario_t) :: add_trees, more_concrete
        
        call setup_grid(baseline)
        
        add_trees%tree_delta = 0.2_wp
        work = baseline
        call apply_scenario(work, add_trees)
        call check(error, abs(work%cells(1,1)%building - baseline%cells(1,1)%building) < 1.0e-12_wp)
        if (allocated(error)) return
        call check(error, work%cells(1,1)%is_urban .eqv. baseline%cells(1,1)%is_urban)
        if (allocated(error)) return
        
        more_concrete%building_delta = 0.2_wp
        work = baseline
        call apply_scenario(work, more_concrete)
        call check(error, abs(work%cells(2,2)%tree - baseline%cells(2,2)%tree) < 1.0e-12_wp)
        if (allocated(error)) return
        call check(error, work%cells(2,2)%is_urban .eqv. baseline%cells(2,2)%is_urban)
    end subroutine test_one_driver

    subroutine test_clamp(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: baseline, work
        type(scenario_t) :: add_trees
        
        call setup_grid(baseline)
        add_trees%tree_delta = 0.2_wp
        work = baseline
        call apply_scenario(work, add_trees)
        
        ! 0.95 + 0.2 = 1.15, clamped to 1.0
        call check(error, abs(work%cells(1,1)%tree - 1.0_wp) < 1.0e-12_wp)
    end subroutine test_clamp

    subroutine test_delta_sign(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: baseline, work
        type(scenario_t) :: add_trees
        real(wp) :: feels_base, feels_scen
        real(wp) :: t_base, w_build, w_urban, w_tree, w_water, d0
        
        call setup_grid(baseline)
        
        add_trees%tree_delta = 0.2_wp
        work = baseline
        call apply_scenario(work, add_trees)
        
        t_base = 28.0_wp
        w_build = 3.0_wp
        w_urban = 1.0_wp
        w_tree = 2.5_wp
        w_water = 2.0_wp
        d0 = 2.5_wp
        
        feels_base = feels_like_c(t_base, 1.0_wp, baseline%cells(2,2)%rh, &
                                  baseline%cells(2,2)%building, baseline%cells(2,2)%tree, &
                                  baseline%cells(2,2)%water_km, baseline%cells(2,2)%is_urban, &
                                  w_build, w_urban, w_tree, w_water, d0)
                                  
        feels_scen = feels_like_c(t_base, 1.0_wp, work%cells(2,2)%rh, &
                                  work%cells(2,2)%building, work%cells(2,2)%tree, &
                                  work%cells(2,2)%water_km, work%cells(2,2)%is_urban, &
                                  w_build, w_urban, w_tree, w_water, d0)
                                  
        ! More trees -> cooler
        call check(error, feels_scen < feels_base)
    end subroutine test_delta_sign

end program test_scenario
