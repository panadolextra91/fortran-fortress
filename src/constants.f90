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

    real(wp), parameter, public :: ROTH_C1 = -42.379_wp
    real(wp), parameter, public :: ROTH_C2 = 2.04901523_wp
    real(wp), parameter, public :: ROTH_C3 = 10.14333127_wp
    real(wp), parameter, public :: ROTH_C4 = -0.22475541_wp
    real(wp), parameter, public :: ROTH_C5 = -0.00683783_wp
    real(wp), parameter, public :: ROTH_C6 = -0.05481717_wp
    real(wp), parameter, public :: ROTH_C7 = 0.00122874_wp
    real(wp), parameter, public :: ROTH_C8 = 0.00085282_wp
    real(wp), parameter, public :: ROTH_C9 = -0.00000199_wp

    public :: c_to_f, f_to_c

contains

    elemental pure function c_to_f(c) result(f)
        real(wp), intent(in) :: c
        real(wp) :: f
        f = c*9.0_wp/5.0_wp + 32.0_wp
    end function c_to_f

    elemental pure function f_to_c(f) result(c)
        real(wp), intent(in) :: f
        real(wp) :: c
        c = (f - 32.0_wp)*5.0_wp/9.0_wp
    end function f_to_c

end module constants_mod
