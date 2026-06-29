program uhi_sim
    use kinds_mod, only: wp
    use grid_mod, only: grid_t, coeffs_t
    use io_mod, only: read_coeffs_nml, read_grid_csv, write_results_csv, real2str
    use feels_mod, only: feels_like_c
    use diurnal_mod, only: NT, diurnal_m, diurnal_base, time_label
    use scenario_mod, only: scenario_t, apply_scenario
    use summary_mod, only: urban_rural_gap, city_average, hottest, coolest
    use uhi_mod, only: uhi_offset
    use, intrinsic :: iso_fortran_env, only: error_unit, output_unit
    implicit none
    
    type(coeffs_t) :: coeffs
    type(grid_t) :: baseline_grid, work
    type(scenario_t) :: scens(3)
    integer :: stat
    character(len=512) :: msg
    character(len=*), parameter :: COEFFS_PATH = 'data/coeffs.nml'
    character(len=*), parameter :: GRID_PATH = 'data/hcmc_districts.csv'
    
    integer :: i, j, it, iscen
    character(len=1) :: marker
    real(wp) :: feels_val, m_t, base_t
    real(wp), allocatable :: feels_baseline(:,:,:)
    real(wp), allocatable :: feels_current(:,:)
    real(wp), allocatable :: delta(:,:)
    real(wp) :: avg_delta, gap_t
    
    real(wp), allocatable :: feels_all(:,:,:,:)
    real(wp), allocatable :: uhi_all(:,:,:,:)
    real(wp) :: avg_delta_all(NT,3)
    character(len=32) :: scen_labels(3)
    integer :: ih, jh, ic, jc
    real(wp) :: vh, vc, avg_t
    
    call read_coeffs_nml(COEFFS_PATH, coeffs, stat, msg)
    if (stat /= 0) then
        write(error_unit, '(A)') trim(msg)
        error stop 1
    end if
    
    call read_grid_csv(GRID_PATH, coeffs%nx, coeffs%ny, baseline_grid, stat, msg)
    if (stat /= 0) then
        write(error_unit, '(A)') trim(msg)
        error stop 1
    end if
    
    write(output_unit, '(A,I0,A,I0,A,I0,A,A)') &
        'Loaded ', baseline_grid%ndist, ' districts into ', baseline_grid%nx, 'x', baseline_grid%ny, ' grid from ', GRID_PATH
    
    write(output_unit, *) '--- Grid Layout ---'
    do j = baseline_grid%ny, 1, -1
        do i = 1, baseline_grid%nx
            if (baseline_grid%cells(i,j)%occupied) then
                if (baseline_grid%cells(i,j)%is_urban) then
                    marker = '#'
                else
                    marker = '*'
                end if
            else
                marker = '.'
            end if
            write(output_unit, '(A)', advance='no') marker
        end do
        write(output_unit, *) ''
    end do
    
    allocate(feels_baseline(baseline_grid%nx, baseline_grid%ny, NT))
    allocate(feels_current(baseline_grid%nx, baseline_grid%ny))
    allocate(delta(baseline_grid%nx, baseline_grid%ny))
    allocate(feels_all(baseline_grid%nx, baseline_grid%ny, NT, 3))
    allocate(uhi_all(baseline_grid%nx, baseline_grid%ny, NT, 3))
    
    scens(1)%label = 'baseline'
    scens(1)%is_baseline = .true.
    scens(1)%tree_delta = 0.0_wp
    scens(1)%building_delta = 0.0_wp
    
    scens(2)%label = 'add_trees'
    scens(2)%tree_delta = coeffs%add_trees_delta
    scens(2)%building_delta = 0.0_wp
    
    scens(3)%label = 'more_concrete'
    scens(3)%tree_delta = 0.0_wp
    scens(3)%building_delta = coeffs%concrete_delta
    
    scen_labels(1) = 'baseline'
    scen_labels(2) = 'add_trees'
    scen_labels(3) = 'more_concrete'
    do iscen = 1, 3
        work = baseline_grid
        call apply_scenario(work, scens(iscen))
        
        do it = 1, NT
            m_t = diurnal_m(coeffs, it)
            base_t = diurnal_base(coeffs, it)
            
            do j = 1, work%ny
                do i = 1, work%nx
                    ! Note (WR-01): per-cell t_air is display/reference-only.
                    ! The diurnal base is citywide by design to avoid double-counting UHI.
                    feels_val = feels_like_c(base_t, m_t, work%cells(i,j)%rh, work%cells(i,j)%building, &
                                             work%cells(i,j)%tree, work%cells(i,j)%water_km, work%cells(i,j)%is_urban, &
                                             coeffs%w_build, coeffs%w_urban, coeffs%w_tree, coeffs%w_water, coeffs%d0)
                    feels_current(i,j) = feels_val
                    feels_all(i,j,it,iscen) = feels_val
                    uhi_all(i,j,it,iscen) = m_t * uhi_offset(work%cells(i,j)%building, work%cells(i,j)%tree, &
                                                             work%cells(i,j)%water_km, work%cells(i,j)%is_urban, &
                                                             coeffs%w_build, coeffs%w_urban, coeffs%w_tree, &
                                                             coeffs%w_water, coeffs%d0)
                    if (scens(iscen)%is_baseline) feels_baseline(i,j,it) = feels_val
                end do
            end do
            
            delta = feels_current - feels_baseline(:,:,it)
            avg_delta = city_average(delta, work)
            avg_delta_all(it, iscen) = avg_delta
        end do
    end do
    
    write(output_unit,'(A)') '--- Baseline summary (feels-like, C) ---'
    write(output_unit,'(A10,2X,A27,2X,A27,2X,A8,2X,A7)') 'Time', 'Hottest (C)', 'Coolest (C)', 'City-Avg', 'U-R Gap'
    do it = 1, NT
        call hottest(feels_baseline(:,:,it), baseline_grid, ih, jh, vh)
        call coolest(feels_baseline(:,:,it), baseline_grid, ic, jc, vc)
        avg_t = city_average(feels_baseline(:,:,it), baseline_grid)
        gap_t = urban_rural_gap(feels_baseline(:,:,it), baseline_grid)
        
        ! WR-01: guard the sentinel (0,0) that hottest/coolest return for an empty
        ! grid before dereferencing cells(ih,jh)%name (would be OOB under -fcheck=all).
        if (ih > 0 .and. jh > 0 .and. ic > 0 .and. jc > 0) then
            write(output_unit, '(A10,2X,A19,1X,F7.2,2X,A19,1X,F7.2,2X,F8.2,2X,F7.2)') &
                trim(time_label(it)), &
                trim(baseline_grid%cells(ih,jh)%name), vh, &
                trim(baseline_grid%cells(ic,jc)%name), vc, &
                avg_t, gap_t
        else
            write(output_unit, '(A10,2X,A)') trim(time_label(it)), '(no occupied cells)'
        end if
    end do
    
    write(output_unit,'(A)') '--- Scenario city-average dT (C) ---'
    do iscen = 2, 3
        do it = 1, NT
            ! F-B (WR-05): real2str keeps the leading zero (0.76, not .76) and stays width-free.
            write(output_unit, '(A,A,A,A,A)') &
                trim(scen_labels(iscen)), ': city-avg dT = ', trim(real2str(avg_delta_all(it,iscen))), ' C @ ', trim(time_label(it))
        end do
    end do
    
    call write_results_csv('results.csv', baseline_grid, coeffs, feels_all, uhi_all, scen_labels, stat, msg)
    if (stat /= 0) then
        write(error_unit,'(A)') trim(msg)
        error stop 1
    end if
    
end program uhi_sim
