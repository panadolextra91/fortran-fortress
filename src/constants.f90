module constants_mod
    use kinds_mod, only: wp
    implicit none
    private
    
    real(wp), parameter, public :: T_MIN = 10.0_wp
    real(wp), parameter, public :: T_MAX = 50.0_wp
    real(wp), parameter, public :: RH_MIN = 0.0_wp
    real(wp), parameter, public :: RH_MAX = 100.0_wp
    real(wp), parameter, public :: DEN_MIN = 0.0_wp
    real(wp), parameter, public :: DEN_MAX = 1.0_wp
end module constants_mod
