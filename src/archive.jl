# Rewrite of Gadfly's spy()
# Merged into Gadfly master now.
function _findnz{T}(testf::Function, A::AbstractMatrix{T})
    nnzA = Base.count(testf, A)
    I = zeros(Int, nnzA)
    J = zeros(Int, nnzA)
    NZs = Array(T, nnzA)
    count = 1
    if nnzA > 0
        for j=1:size(A,2), i=1:size(A,1)
            Aij = A[i,j]
            if testf(Aij)
                I[count] = i
                J[count] = j
                NZs[count] = Aij
                count += 1
            end
        end
    end
    return (I, J, NZs)
end

import Gadfly: spy
function spy(M::AbstractMatrix, elements::Gadfly.ElementOrFunction...; mapping...)
    is, js, values = _findnz(x->!isnan(x), M)
    n,m = size(M)
    df = DataFrames.DataFrame(i=is, j=js, value=values)
    plot(df, x="j", y="i", color="value",
        Coord.cartesian(yflip=true, fixed=true, xmin=0.5, xmax=m+.5, ymin=0.5, ymax=n+.5),
        Scale.color_continuous,
        Geom.rectbin,
        Scale.x_continuous,
        Scale.y_continuous,
        elements...; mapping...)
end
