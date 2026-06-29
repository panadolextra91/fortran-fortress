module grid_mod
    use kinds_mod, only: wp
    implicit none
    private

    type, public :: cell
        character(len=:), allocatable :: name
        integer :: i, j
        real(wp) :: t_air = 0.0_wp
        real(wp) :: rh = 0.0_wp
        real(wp) :: water_km = 0.0_wp
        real(wp) :: building = 0.0_wp
        real(wp) :: tree = 0.0_wp
        logical :: is_urban = .false.
        logical :: occupied = .false.
    end type cell

    type, public :: grid_t
        integer :: nx, ny, ndist
        type(cell), allocatable :: cells(:,:)
    end type grid_t

    type, public :: coeffs_t
        real(wp) :: w_build, w_urban, w_tree, w_water
        real(wp) :: m_morning, m_afternoon, m_evening, m_predawn
        real(wp) :: base_morning, base_afternoon, base_evening, base_predawn
        real(wp) :: add_trees_delta, concrete_delta
        real(wp) :: t_base, rh_base, d0
        integer :: nx, ny
    end type coeffs_t

    public :: allocate_grid

contains

    subroutine allocate_grid(g, nx, ny)
        type(grid_t), intent(out) :: g
        integer, intent(in) :: nx, ny
        
        g%nx = nx
        g%ny = ny
        g%ndist = 0
        
        allocate(g%cells(nx, ny))
    end subroutine allocate_grid

end module grid_mod
