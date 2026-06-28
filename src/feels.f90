module feels_mod
    use kinds_mod, only: wp
    use heat_index_mod, only: heat_index_f
    use uhi_mod, only: uhi_offset
    use constants_mod, only: c_to_f, f_to_c
    implicit none
    private
    public :: feels_like_c

contains

    elemental pure function feels_like_c(t_base, rh, building, tree, water_km, is_urban, &
                                         w_build, w_urban, w_tree, w_water, d0) result(feels_c)
        real(wp), intent(in) :: t_base, rh, building, tree, water_km
        logical,  intent(in) :: is_urban
        real(wp), intent(in) :: w_build, w_urban, w_tree, w_water, d0
        real(wp) :: feels_c, t_adj_c, hi_f
        
        t_adj_c = t_base + uhi_offset(building, tree, water_km, is_urban, &
                                      w_build, w_urban, w_tree, w_water, d0)
        hi_f    = heat_index_f(c_to_f(t_adj_c), rh)
        feels_c = max(f_to_c(hi_f), t_adj_c)
    end function feels_like_c

end module feels_mod
