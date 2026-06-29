module scenario_mod
    use kinds_mod, only: wp
    use grid_mod, only: grid_t
    implicit none
    private
    public :: scenario_t, apply_scenario

    type, public :: scenario_t
        character(len=:), allocatable :: label
        logical :: is_baseline = .false.
        real(wp) :: tree_delta = 0.0_wp
        real(wp) :: building_delta = 0.0_wp
    end type scenario_t

contains

    subroutine apply_scenario(work, scen)
        type(grid_t), intent(inout) :: work
        type(scenario_t), intent(in) :: scen
        
        work%cells%tree = min(1.0_wp, max(0.0_wp, work%cells%tree + scen%tree_delta))
        work%cells%building = min(1.0_wp, max(0.0_wp, work%cells%building + scen%building_delta))
    end subroutine apply_scenario

end module scenario_mod
