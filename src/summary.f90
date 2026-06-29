module summary_mod
    use kinds_mod, only: wp
    use grid_mod, only: grid_t
    implicit none
    private
    public :: urban_rural_gap, city_average

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

end module summary_mod
