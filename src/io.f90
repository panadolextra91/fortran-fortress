module io_mod
    use kinds_mod, only: wp
    use constants_mod, only: T_MIN, T_MAX, RH_MIN, RH_MAX, DEN_MIN, DEN_MAX
    use grid_mod, only: cell, grid_t, coeffs_t, allocate_grid
    implicit none
    private
    public :: read_coeffs_nml, read_grid_csv

    integer, parameter :: NFIELD = 9

contains

    subroutine read_coeffs_nml(path, c, stat, msg)
        character(len=*), intent(in) :: path
        type(coeffs_t), intent(out) :: c
        integer, intent(out) :: stat
        character(len=*), intent(out) :: msg
        
        real(wp) :: w_build, w_urban, w_tree, w_water
        real(wp) :: m_morning, m_afternoon, m_evening, m_predawn
        real(wp) :: t_base, rh_base
        integer :: nx, ny
        integer :: u, ios
        
        namelist /coeffs/ w_build, w_urban, w_tree, w_water, &
                          m_morning, m_afternoon, m_evening, m_predawn, &
                          t_base, rh_base, nx, ny
                          
        ! Set defaults FIRST
        w_build = 3.0_wp
        w_urban = 1.0_wp
        w_tree = 2.5_wp
        w_water = 2.0_wp
        m_morning = 0.5_wp
        m_afternoon = 0.3_wp
        m_evening = 0.8_wp
        m_predawn = 1.0_wp
        t_base = 28.0_wp
        rh_base = 78.0_wp
        nx = 0
        ny = 0
        
        stat = 0
        msg = ''
        
        open(newunit=u, file=path, status='old', action='read', iostat=ios, iomsg=msg)
        if (ios /= 0) then
            stat = ios
            return
        end if
        
        read(u, nml=coeffs, iostat=ios, iomsg=msg)
        close(u)
        
        if (ios /= 0) then
            stat = ios
            return
        end if
        
        c%w_build = w_build
        c%w_urban = w_urban
        c%w_tree = w_tree
        c%w_water = w_water
        c%m_morning = m_morning
        c%m_afternoon = m_afternoon
        c%m_evening = m_evening
        c%m_predawn = m_predawn
        c%t_base = t_base
        c%rh_base = rh_base
        c%nx = nx
        c%ny = ny
    end subroutine read_coeffs_nml

    subroutine read_grid_csv(path, nx, ny, g, stat, msg)
        character(len=*), intent(in) :: path
        integer, intent(in) :: nx, ny
        type(grid_t), intent(out) :: g
        integer, intent(out) :: stat
        character(len=*), intent(out) :: msg
        
        integer :: u, ios, lineno
        character(len=512) :: line
        character(len=64) :: fld(NFIELD)
        integer :: nf
        
        integer :: ii, jj, urb
        real(wp) :: t, rh, wkm, bld, tre
        
        stat = 0
        msg = ''
        call allocate_grid(g, nx, ny)
        
        open(newunit=u, file=path, status='old', action='read', iostat=ios, iomsg=msg)
        if (ios /= 0) then
            stat = ios
            return
        end if
        
        lineno = 0
        read(u, '(A)', iostat=ios) line
        if (ios /= 0) then
            close(u)
            return
        end if
        lineno = 1
        
        do
            read(u, '(A)', iostat=ios) line
            if (ios /= 0) exit
            lineno = lineno + 1
            
            if (len_trim(line) == 0) cycle
            if (line(1:1) == '#') cycle
            
            call split_commas(line, fld, nf)
            if (nf /= NFIELD) then
                call make_msg('expected 9 fields, got ' // int2str(nf))
                stat = 1
                close(u)
                return
            end if
            
            read(fld(2), *, iostat=ios) ii
            if (ios /= 0) then; call make_msg('cannot parse i'); stat=1; close(u); return; end if
            
            read(fld(3), *, iostat=ios) jj
            if (ios /= 0) then; call make_msg('cannot parse j'); stat=1; close(u); return; end if
            
            read(fld(4), *, iostat=ios) t
            if (ios /= 0) then; call make_msg('cannot parse t_air'); stat=1; close(u); return; end if
            
            read(fld(5), *, iostat=ios) rh
            if (ios /= 0) then; call make_msg('cannot parse rh'); stat=1; close(u); return; end if
            
            read(fld(6), *, iostat=ios) wkm
            if (ios /= 0) then; call make_msg('cannot parse water_km'); stat=1; close(u); return; end if
            
            read(fld(7), *, iostat=ios) bld
            if (ios /= 0) then; call make_msg('cannot parse building'); stat=1; close(u); return; end if
            
            read(fld(8), *, iostat=ios) tre
            if (ios /= 0) then; call make_msg('cannot parse tree'); stat=1; close(u); return; end if
            
            read(fld(9), *, iostat=ios) urb
            if (ios /= 0) then; call make_msg('cannot parse urban'); stat=1; close(u); return; end if
            
            ! Validate bounds
            if (ii < 1 .or. ii > nx) then; call make_msg('i out of range'); stat=1; close(u); return; end if
            if (jj < 1 .or. jj > ny) then; call make_msg('j out of range'); stat=1; close(u); return; end if
            
            if (t < T_MIN .or. t > T_MAX) then; call make_msg('t_air out of range'); stat=1; close(u); return; end if
            if (rh < RH_MIN .or. rh > RH_MAX) then; call make_msg('rh out of range'); stat=1; close(u); return; end if
            if (wkm < 0.0_wp) then; call make_msg('water_km out of range'); stat=1; close(u); return; end if
            if (bld < DEN_MIN .or. bld > DEN_MAX) then; call make_msg('building out of range'); stat=1; close(u); return; end if
            if (tre < DEN_MIN .or. tre > DEN_MAX) then; call make_msg('tree out of range'); stat=1; close(u); return; end if
            if (urb /= 0 .and. urb /= 1) then; call make_msg('urban out of range'); stat=1; close(u); return; end if
            
            if (g%cells(ii,jj)%occupied) then
                call make_msg('duplicate cell (i,j)')
                stat = 1
                close(u)
                return
            end if
            
            g%cells(ii,jj)%name = trim(adjustl(fld(1)))
            g%cells(ii,jj)%i = ii
            g%cells(ii,jj)%j = jj
            g%cells(ii,jj)%t_air = t
            g%cells(ii,jj)%rh = rh
            g%cells(ii,jj)%water_km = wkm
            g%cells(ii,jj)%building = bld
            g%cells(ii,jj)%tree = tre
            g%cells(ii,jj)%is_urban = (urb == 1)
            g%cells(ii,jj)%occupied = .true.
            
            g%ndist = g%ndist + 1
        end do
        
        close(u)
        
    contains
        subroutine make_msg(reason)
            character(len=*), intent(in) :: reason
            character(len=32) :: num_str
            write(num_str, '(I0)') lineno
            msg = trim(path) // ':' // trim(adjustl(num_str)) // ': ' // trim(reason)
        end subroutine make_msg
        
        function int2str(val) result(res)
            integer, intent(in) :: val
            character(len=32) :: res
            write(res, '(I0)') val
            res = trim(adjustl(res))
        end function int2str
    end subroutine read_grid_csv

    subroutine split_commas(line, fld, nf)
        character(len=*), intent(in) :: line
        character(len=*), intent(out) :: fld(:)
        integer, intent(out) :: nf
        integer :: start_pos, comma_pos, i
        
        nf = 0
        start_pos = 1
        do i = 1, size(fld)
            comma_pos = index(line(start_pos:), ',')
            if (comma_pos == 0) then
                fld(i) = line(start_pos:)
                nf = nf + 1
                return
            else
                if (i == size(fld)) then
                    nf = nf + 2
                    return
                end if
                fld(i) = line(start_pos : start_pos+comma_pos-2)
                nf = nf + 1
                start_pos = start_pos + comma_pos
            end if
        end do
    end subroutine split_commas

end module io_mod
