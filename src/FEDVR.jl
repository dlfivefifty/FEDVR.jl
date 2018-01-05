module FEDVR

using RecipesBase

include("grid.jl")
include("lagrange.jl")
include("basis.jl")
include("derivatives.jl")
include("projections.jl")

end # module
