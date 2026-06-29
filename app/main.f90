program uhi_sim
    use kinds_mod, only: wp
    use grid_mod, only: grid_t, coeffs_t, cell
    use io_mod, only: read_coeffs_nml, read_grid_csv
    use feels_mod, only: feels_like_c
    use diurnal_mod, only: NT, diurnal_m, diurnal_base, time_label
    use, intrinsic :: iso_fortran_env, only: error_unit, output_unit
    implicit none
    
    type(coeffs_t) :: coeffs
    type(grid_t) :: grid
    integer :: stat
    character(len=512) :: msg
    character(len=*), parameter :: COEFFS_PATH = 'data/coeffs.nml'
    character(len=*), parameter :: GRID_PATH = 'data/hcmc_districts.csv'
    
    integer :: i, j, it
    character(len=1) :: marker
    real(wp) :: feels, m_t, base_t
    
    call read_coeffs_nml(COEFFS_PATH, coeffs, stat, msg)
    if (stat /= 0) then
        write(error_unit, '(A)') trim(msg)
        error stop 1
    end if
    
    call read_grid_csv(GRID_PATH, coeffs%nx, coeffs%ny, grid, stat, msg)
    if (stat /= 0) then
        write(error_unit, '(A)') trim(msg)
        error stop 1
    end if
    
    write(output_unit, '(A,I0,A,I0,A,I0,A,A)') &
        'Loaded ', grid%ndist, ' districts into ', grid%nx, 'x', grid%ny, ' grid from ', GRID_PATH
    write(output_unit, *) '--- District List ---'
    
    do j = 1, grid%ny
        do i = 1, grid%nx
            if (grid%cells(i,j)%occupied) then
                do it = 1, NT
                    m_t = diurnal_m(coeffs, it)
                    base_t = diurnal_base(coeffs, it)
                    feels = feels_like_c(base_t, m_t, grid%cells(i,j)%rh, grid%cells(i,j)%building, &
                                         grid%cells(i,j)%tree, grid%cells(i,j)%water_km, grid%cells(i,j)%is_urban, &
                                         coeffs%w_build, coeffs%w_urban, coeffs%w_tree, coeffs%w_water, coeffs%d0)
                    write(output_unit, '(A,A,I0,A,I0,A,A,A,A,g0,A,g0,A,g0,A,g0,A,g0,A,L1,A,g0)') &
                        trim(grid%cells(i,j)%name), ' at (', i, ',', j, ') ', &
                        '[', trim(time_label(it)), '] T=', &
                        grid%cells(i,j)%t_air, &
                        ', RH=', grid%cells(i,j)%rh, &
                        ', WKM=', grid%cells(i,j)%water_km, &
                        ', BLD=', grid%cells(i,j)%building, &
                        ', TRE=', grid%cells(i,j)%tree, &
                        ', URB=', grid%cells(i,j)%is_urban, &
                        ', FEELS=', feels
                end do
            end if
        end do
    end do
    
    write(output_unit, *) '--- Grid Layout ---'
    do j = grid%ny, 1, -1
        do i = 1, grid%nx
            if (grid%cells(i,j)%occupied) then
                if (grid%cells(i,j)%is_urban) then
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
    
end program uhi_sim
