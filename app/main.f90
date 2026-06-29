program uhi_sim
    use kinds_mod, only: wp
    use grid_mod, only: grid_t, coeffs_t
    use io_mod, only: read_coeffs_nml, read_grid_csv
    use feels_mod, only: feels_like_c
    use diurnal_mod, only: NT, diurnal_m, diurnal_base, time_label
    use scenario_mod, only: scenario_t, apply_scenario
    use summary_mod, only: urban_rural_gap
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
    
    write(output_unit, *) '--- Scenarios ---'
    do iscen = 1, 3
        work = baseline_grid
        call apply_scenario(work, scens(iscen))
        
        do it = 1, NT
            m_t = diurnal_m(coeffs, it)
            base_t = diurnal_base(coeffs, it)
            
            do j = 1, work%ny
                do i = 1, work%nx
                    feels_val = feels_like_c(base_t, m_t, work%cells(i,j)%rh, work%cells(i,j)%building, &
                                             work%cells(i,j)%tree, work%cells(i,j)%water_km, work%cells(i,j)%is_urban, &
                                             coeffs%w_build, coeffs%w_urban, coeffs%w_tree, coeffs%w_water, coeffs%d0)
                    feels_current(i,j) = feels_val
                    if (scens(iscen)%is_baseline) feels_baseline(i,j,it) = feels_val
                end do
            end do
            
            delta = feels_current - feels_baseline(:,:,it)
            
            if (count(work%cells%occupied) > 0) then
                avg_delta = sum(delta, mask=work%cells%occupied) / real(count(work%cells%occupied), wp)
            else
                avg_delta = 0.0_wp
            end if
            
            if (scens(iscen)%is_baseline) then
                gap_t = urban_rural_gap(feels_current, work)
                write(output_unit, '(A,A,F0.2,A)') &
                    trim(time_label(it)), ': gap = ', gap_t, ' C'
            end if
            
            write(output_unit, '(A,A,F0.2,A,A)') &
                trim(scens(iscen)%label), ': city-avg dT = ', avg_delta, ' C @ ', trim(time_label(it))
        end do
    end do
    
end program uhi_sim
