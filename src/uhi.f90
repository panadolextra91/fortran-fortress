module uhi_mod
    use kinds_mod, only: wp
    implicit none
    private
    public :: uhi_offset

contains

    elemental pure function uhi_offset(building, tree, water_km, is_urban, &
                                       w_build, w_urban, w_tree, w_water, d0) result(dT)
        real(wp), intent(in) :: building, tree, water_km
        logical,  intent(in) :: is_urban
        real(wp), intent(in) :: w_build, w_urban, w_tree, w_water, d0
        real(wp) :: dT, U, Wprox
        
        U     = merge(1.0_wp, 0.0_wp, is_urban)
        Wprox = exp(-water_km/d0)
        
        dT = w_build*building + w_urban*U - w_tree*tree - w_water*Wprox
    end function uhi_offset

end module uhi_mod
