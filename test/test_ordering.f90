program test_ordering
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use feels_mod, only: feels_like_c
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [ new_testsuite('ordering', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1

contains

    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(3))
        testsuite(1) = new_unittest('archetype_ordering', test_archetype_ordering)
        testsuite(2) = new_unittest('monotonicity', test_monotonicity)
        testsuite(3) = new_unittest('floor_edge', test_floor_edge)
    end subroutine collect

    subroutine test_archetype_ordering(error)
        type(error_type), allocatable, intent(out) :: error
        real(wp) :: feels_industrial, feels_d1, feels_park, feels_cangio, feels_rural
        real(wp) :: t_base, w_build, w_urban, w_tree, w_water, d0, rh
        
        t_base = 28.0_wp
        w_build = 3.0_wp
        w_urban = 1.0_wp
        w_tree = 2.5_wp
        w_water = 2.0_wp
        d0 = 2.5_wp
        rh = 78.0_wp

        ! industrial (building=0.95, tree=0.02, water_km=8.0, urban)
        feels_industrial = feels_like_c(t_base, rh, 0.95_wp, 0.02_wp, 8.0_wp, .true., &
                                        w_build, w_urban, w_tree, w_water, d0)
        ! District-1 core (building=0.90, tree=0.10, water_km=3.0, urban)
        feels_d1 = feels_like_c(t_base, rh, 0.90_wp, 0.10_wp, 3.0_wp, .true., &
                                w_build, w_urban, w_tree, w_water, d0)
        ! park (building=0.30, tree=0.90, water_km=2.0, urban)
        feels_park = feels_like_c(t_base, rh, 0.30_wp, 0.90_wp, 2.0_wp, .true., &
                                  w_build, w_urban, w_tree, w_water, d0)
        ! Can Gio coast (building=0.10, tree=0.70, water_km=0.0, rural)
        feels_cangio = feels_like_c(t_base, rh, 0.10_wp, 0.70_wp, 0.0_wp, .false., &
                                    w_build, w_urban, w_tree, w_water, d0)
        ! rural fringe (building=0.10, tree=0.50, water_km=5.0, rural)
        feels_rural = feels_like_c(t_base, rh, 0.10_wp, 0.50_wp, 5.0_wp, .false., &
                                   w_build, w_urban, w_tree, w_water, d0)

        call check(error, feels_industrial > feels_park)
        if (allocated(error)) return
        call check(error, feels_industrial > feels_cangio)
        if (allocated(error)) return
        call check(error, feels_industrial > feels_rural)
        if (allocated(error)) return
        
        call check(error, feels_d1 > feels_park)
        if (allocated(error)) return
        call check(error, feels_d1 > feels_cangio)
    end subroutine test_archetype_ordering

    subroutine test_monotonicity(error)
        type(error_type), allocatable, intent(out) :: error
        real(wp) :: feels1, feels2
        real(wp) :: t_base, w_build, w_urban, w_tree, w_water, d0, rh
        
        t_base = 28.0_wp
        w_build = 3.0_wp
        w_urban = 1.0_wp
        w_tree = 2.5_wp
        w_water = 2.0_wp
        d0 = 2.5_wp
        rh = 78.0_wp

        ! More building -> hotter
        feels1 = feels_like_c(t_base, rh, 0.5_wp, 0.0_wp, 10.0_wp, .false., w_build, w_urban, w_tree, w_water, d0)
        feels2 = feels_like_c(t_base, rh, 0.8_wp, 0.0_wp, 10.0_wp, .false., w_build, w_urban, w_tree, w_water, d0)
        call check(error, feels2 > feels1)
        if (allocated(error)) return

        ! More tree -> cooler
        feels1 = feels_like_c(t_base, rh, 0.5_wp, 0.2_wp, 10.0_wp, .false., w_build, w_urban, w_tree, w_water, d0)
        feels2 = feels_like_c(t_base, rh, 0.5_wp, 0.8_wp, 10.0_wp, .false., w_build, w_urban, w_tree, w_water, d0)
        call check(error, feels2 < feels1)
        if (allocated(error)) return
        
        ! Closer to water -> cooler
        feels1 = feels_like_c(t_base, rh, 0.5_wp, 0.0_wp, 5.0_wp, .false., w_build, w_urban, w_tree, w_water, d0)
        feels2 = feels_like_c(t_base, rh, 0.5_wp, 0.0_wp, 1.0_wp, .false., w_build, w_urban, w_tree, w_water, d0)
        call check(error, feels2 < feels1)
        if (allocated(error)) return

        ! Urban vs non-urban (all else equal) -> hotter
        feels1 = feels_like_c(t_base, rh, 0.5_wp, 0.0_wp, 10.0_wp, .false., w_build, w_urban, w_tree, w_water, d0)
        feels2 = feels_like_c(t_base, rh, 0.5_wp, 0.0_wp, 10.0_wp, .true., w_build, w_urban, w_tree, w_water, d0)
        call check(error, feels2 > feels1)
    end subroutine test_monotonicity

    subroutine test_floor_edge(error)
        type(error_type), allocatable, intent(out) :: error
        real(wp) :: feels, t_adj_c
        real(wp) :: t_base, w_build, w_urban, w_tree, w_water, d0, rh
        
        t_base = 15.0_wp
        w_build = 3.0_wp
        w_urban = 1.0_wp
        w_tree = 2.5_wp
        w_water = 2.0_wp
        d0 = 2.5_wp
        rh = 20.0_wp
        
        ! Cool/dry cell: building=0.0, tree=1.0, water_km=0.0, urban=F
        feels = feels_like_c(t_base, rh, 0.0_wp, 1.0_wp, 0.0_wp, .false., &
                             w_build, w_urban, w_tree, w_water, d0)
                             
        ! Manually compute expected t_adj
        t_adj_c = t_base + (w_build*0.0_wp + w_urban*0.0_wp - w_tree*1.0_wp - w_water*1.0_wp)
        
        call check(error, abs(feels - t_adj_c) < 1.0e-6_wp)
    end subroutine test_floor_edge

end program test_ordering
