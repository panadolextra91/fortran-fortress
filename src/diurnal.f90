module diurnal_mod
    use kinds_mod, only: wp
    use grid_mod, only: coeffs_t
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
    implicit none
    private
    public :: NT, T_MORNING, T_AFTERNOON, T_EVENING, T_PREDAWN, &
              diurnal_m, diurnal_base, time_label

    integer, parameter :: NT = 4
    integer, parameter :: T_MORNING = 1, T_AFTERNOON = 2, &
                          T_EVENING = 3, T_PREDAWN = 4

contains

    pure function diurnal_m(c, it) result(m)
        type(coeffs_t), intent(in) :: c
        integer, intent(in) :: it
        real(wp) :: m

        select case (it)
            case (T_MORNING)
                m = c%m_morning
            case (T_AFTERNOON)
                m = c%m_afternoon
            case (T_EVENING)
                m = c%m_evening
            case (T_PREDAWN)
                m = c%m_predawn
            case default
                m = ieee_value(1.0_wp, ieee_quiet_nan)
        end select
    end function diurnal_m

    pure function diurnal_base(c, it) result(base)
        type(coeffs_t), intent(in) :: c
        integer, intent(in) :: it
        real(wp) :: base

        select case (it)
            case (T_MORNING)
                base = c%base_morning
            case (T_AFTERNOON)
                base = c%base_afternoon
            case (T_EVENING)
                base = c%base_evening
            case (T_PREDAWN)
                base = c%base_predawn
            case default
                base = ieee_value(1.0_wp, ieee_quiet_nan)
        end select
    end function diurnal_base

    pure function time_label(it) result(s)
        integer, intent(in) :: it
        character(len=:), allocatable :: s

        select case (it)
            case (T_MORNING)
                s = 'morning'
            case (T_AFTERNOON)
                s = 'afternoon'
            case (T_EVENING)
                s = 'evening'
            case (T_PREDAWN)
                s = 'predawn'
            case default
                s = 'invalid'
        end select
    end function time_label

end module diurnal_mod
