program test_e2e_load
    use kinds_mod, only: wp
    use grid_mod, only: grid_t, coeffs_t
    use io_mod, only: read_coeffs_nml, read_grid_csv
    implicit none
    
    type(coeffs_t) :: coeffs
    type(grid_t) :: grid, badgrid
    integer :: stat
    character(len=512) :: msg
    integer :: u
    
    ! Test 1: Valid round-trip
    call read_coeffs_nml('data/coeffs.nml', coeffs, stat, msg)
    call check(stat == 0, 'coeffs.nml loaded OK')
    call check(coeffs%nx > 0 .and. coeffs%ny > 0, 'coeffs extent positive')
    
    call read_grid_csv('data/hcmc_districts.csv', coeffs%nx, coeffs%ny, grid, stat, msg)
    if (stat /= 0) print *, 'ERROR msg: ', trim(msg)
    call check(stat == 0, 'hcmc_districts.csv loaded OK')
    call check(grid%ndist == 14, 'ndist == 14')
    
    ! Test 2: Malformed row rejection
    open(newunit=u, file='test/scratch_bad.csv', status='replace')
    write(u, '(A)') 'name,i,j,t_air,rh,water_km,building,tree,urban'
    write(u, '(A)') 'District 1,4,5,33.0,142.0,1.0,0.85,0.10,1'
    close(u)
    
    call read_grid_csv('test/scratch_bad.csv', coeffs%nx, coeffs%ny, badgrid, stat, msg)
    call check(stat /= 0, 'bad RH rejected')
    call check(len_trim(msg) > 0 .and. index(msg, ':') > 0, 'line number in msg')
    
    open(newunit=u, file='test/scratch_bad.csv', status='old')
    close(u, status='delete')
    
    print *, 'E2E LOAD TEST: OK'
    
contains
    subroutine check(cond, label)
        logical, intent(in) :: cond
        character(len=*), intent(in) :: label
        if (.not. cond) then
            print *, 'ASSERTION FAILED: ', trim(label)
            error stop 1
        end if
    end subroutine check
end program test_e2e_load
