module summary_mod
    use kinds_mod, only: wp
    use grid_mod, only: grid_t
    implicit none
    private
    public :: urban_rural_gap, city_average, hottest, coolest

contains

    pure function urban_rural_gap(feels, g) result(gap)
        real(wp), intent(in) :: feels(:,:)
        type(grid_t), intent(in) :: g
        real(wp) :: gap, u_mean, r_mean
        logical, allocatable :: mu(:,:), mr(:,:)
        
        allocate(mu(g%nx, g%ny))
        allocate(mr(g%nx, g%ny))
        
        mu = g%cells%is_urban .and. g%cells%occupied
        mr = (.not. g%cells%is_urban) .and. g%cells%occupied
        
        if (count(mu) == 0 .or. count(mr) == 0) then
            gap = 0.0_wp
        else
            u_mean = sum(feels, mask=mu) / real(count(mu), wp)
            r_mean = sum(feels, mask=mr) / real(count(mr), wp)
            gap = u_mean - r_mean
        end if
    end function urban_rural_gap

    pure function city_average(feels, g) result(avg)
        real(wp), intent(in) :: feels(:,:)
        type(grid_t), intent(in) :: g
        real(wp) :: avg
        
        if (count(g%cells%occupied) > 0) then
            avg = sum(feels, mask=g%cells%occupied) / real(count(g%cells%occupied), wp)
        else
            avg = 0.0_wp
        end if
    end function city_average

    pure subroutine hottest(feels, g, ih, jh, val)
        real(wp), intent(in) :: feels(:,:)
        type(grid_t), intent(in) :: g
        integer, intent(out) :: ih, jh
        real(wp), intent(out) :: val
        integer :: loc(2)
        
        if (count(g%cells%occupied) == 0) then
            ih = 0
            jh = 0
            val = 0.0_wp
            return
        end if
        
        loc = maxloc(feels, mask=g%cells%occupied)
        ih = loc(1)
        jh = loc(2)
        val = feels(ih, jh)
    end subroutine hottest

    pure subroutine coolest(feels, g, ic, jc, val)
        real(wp), intent(in) :: feels(:,:)
        type(grid_t), intent(in) :: g
        integer, intent(out) :: ic, jc
        real(wp), intent(out) :: val
        integer :: loc(2)
        
        if (count(g%cells%occupied) == 0) then
            ic = 0
            jc = 0
            val = 0.0_wp
            return
        end if
        
        loc = minloc(feels, mask=g%cells%occupied)
        ic = loc(1)
        jc = loc(2)
        val = feels(ic, jc)
    end subroutine coolest

end module summary_mod
