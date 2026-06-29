program test_output
    use testdrive, only: new_unittest, unittest_type, error_type, check, testsuite_type, new_testsuite, run_testsuite
    use kinds_mod, only: wp
    use io_mod, only: write_results_csv
    use grid_mod, only: grid_t, coeffs_t, allocate_grid
    use diurnal_mod, only: NT
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none

    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)
    
    testsuites = [ &
        new_testsuite('output_tests', collect_output_tests) &
    ]
    
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) stop 1

contains

    subroutine collect_output_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(1))
        testsuite(1) = new_unittest('test_csv_output', test_csv_output)
    end subroutine collect_output_tests

    subroutine test_csv_output(error)
        type(error_type), allocatable, intent(out) :: error
        type(grid_t) :: g
        type(coeffs_t) :: c
        real(wp), allocatable :: feels_all(:,:,:,:), uhi_all(:,:,:,:)
        character(len=32) :: scen_labels(3)
        integer :: stat, u, ios, nlines
        character(len=512) :: msg, row, header_expected

        call allocate_grid(g, 3, 2)
        ! mark (1,1) and (3,2) occupied
        g%cells(1,1)%occupied = .true.
        g%cells(1,1)%name = 'Dist1'
        g%cells(1,1)%t_air = 28.5_wp
        
        g%cells(3,2)%occupied = .true.
        g%cells(3,2)%name = 'Dist2'
        g%cells(3,2)%t_air = 29.0_wp
        
        c%base_morning = 29.0_wp
        c%base_afternoon = 33.0_wp
        c%base_evening = 30.0_wp
        c%base_predawn = 25.0_wp

        allocate(feels_all(3, 2, NT, 3))
        allocate(uhi_all(3, 2, NT, 3))
        feels_all = 30.0_wp
        uhi_all = 2.0_wp
        
        scen_labels = [character(len=32) :: 'baseline', 'add_trees', 'more_concrete']
        
        call write_results_csv('test_output_tmp.csv', g, c, feels_all, uhi_all, scen_labels, stat, msg)
        call check(error, stat == 0)
        if (allocated(error)) return
        
        open(newunit=u, file='test_output_tmp.csv', status='old', action='read', iostat=ios)
        call check(error, ios == 0)
        if (allocated(error)) return
        
        read(u, '(A)') row
        header_expected = 'i,j,name,time_label,scenario,t_air,base_t,feels_c,uhi_offset_c'
        call check(error, trim(row) == trim(header_expected))
        if (allocated(error)) return
        
        nlines = 1
        do
            read(u, '(A)', iostat=ios) row
            if (ios /= 0) exit
            nlines = nlines + 1
            call check(error, index(row, '.') > 0)
            if (allocated(error)) return
            call check(error, index(row, '*') == 0)
            if (allocated(error)) return
            if (nlines == 2) then
                call check(error, index(row, 'morning,baseline') > 0)
                if (allocated(error)) return
            end if
        end do
        close(u)
        
        ! 1 header + 2 occupied * 4 NT * 3 scenarios = 25 lines
        call check(error, nlines == 25)

    end subroutine test_csv_output

end program test_output
