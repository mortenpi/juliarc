using juliarc
using Base.Test

# load everything
juliarc.load()

import juliarc: Asymmetric
@test Asymmetric(3, [1,2,3]) == [0 1 2; -1 0 3; -2 -3 0]

# test the @dataframe snippet
r = @dataframe for x in linspace(1, 20, 5)
    @dfcol x::Float64 = x
    @dfcol y::Float64 = x^2
end

import DataFrames
@test isa(r, DataFrames.DataFrame)

let xs = linspace(1, 20, 5), c = 2.0
    r = @dataframe for x in xs
        @dfcol x::Float64 = x
        @dfcol y::Float64 = x^2 + c
        q = (x+c)^2
        @dfcol z::Float64 = x^2 + y^2 + q^2
    end
    @test isa(r, DataFrames.DataFrame)
end
