using juliarc
using Base.Test

# load everything
juliarc.load()

import juliarc: Asymmetric
@test Asymmetric(3, [1,2,3]) == [0 1 2; -1 0 3; -2 -3 0]

# test the @dataframe snippet
@dataframe for x in linspace(1, 20, 5)
    @dfcol x::Float64 = x
    @dfcol y::Float64 = x^2
end
