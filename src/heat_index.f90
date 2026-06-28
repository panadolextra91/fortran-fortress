module heat_index_mod
    use kinds_mod, only: wp
    use constants_mod, only: ROTH_C1, ROTH_C2, ROTH_C3, ROTH_C4, ROTH_C5, &
                             ROTH_C6, ROTH_C7, ROTH_C8, ROTH_C9
    implicit none
    private
    public :: heat_index_f

contains

    elemental pure function heat_index_f(t_f, rh) result(hi)
        real(wp), intent(in) :: t_f, rh        ! T in °F, RH in %
        real(wp) :: hi
        hi = 0.5_wp*(t_f + 61.0_wp + (t_f - 68.0_wp)*1.2_wp + rh*0.094_wp)
        hi = (hi + t_f)/2.0_wp                  ! Steadman, averaged with T
        if (hi >= 80.0_wp) then
            hi = ROTH_C1 + ROTH_C2*t_f + ROTH_C3*rh        &
                 + ROTH_C4*t_f*rh + ROTH_C5*t_f*t_f            &
                 + ROTH_C6*rh*rh + ROTH_C7*t_f*t_f*rh          &
                 + ROTH_C8*t_f*rh*rh + ROTH_C9*t_f*t_f*rh*rh
            if (rh < 13.0_wp .and. t_f >= 80.0_wp .and. t_f <= 112.0_wp) then
                hi = hi - ((13.0_wp - rh)/4.0_wp)*sqrt((17.0_wp - abs(t_f - 95.0_wp))/17.0_wp)
            end if
            if (rh > 85.0_wp .and. t_f >= 80.0_wp .and. t_f <= 87.0_wp) then
                hi = hi + ((rh - 85.0_wp)/10.0_wp)*((87.0_wp - t_f)/5.0_wp)
            end if
        end if
    end function heat_index_f

end module heat_index_mod
