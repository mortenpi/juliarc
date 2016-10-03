module juliarc

import Compat

import Compose
using Gadfly
using DataFrames

include("experimental.jl")

# Macros to make working in Jupyter a bit more convenient
export @quiet
macro quiet(expr)
    :( _ = $expr; nothing )
end

export @display
macro display(obj)
    quote
        display($(esc(obj)))
        nothing
    end
end


# A small macro to quickly make Gadfly plots non-interactive
export @noninteractive

type NoninteractivePlot
    p::Gadfly.Plot
end

import Compose: writemime
function writemime(io::IO, m::MIME"text/html", p::NoninteractivePlot)
    buf = IOBuffer()
    svg = Gadfly.SVG(buf, Compose.default_graphic_width,
                Compose.default_graphic_height, false)
    Gadfly.draw(svg, p.p)
    writemime(io, m, svg)
end

macro noninteractive(plot)
    :( NoninteractivePlot($(esc(plot))) )
end


# A better constructor to a DataFrame
import DataFrames: DataFrame
"""
`DataFrame(ps::Pair...)` where the pairs are `::Symbol => ::Type`

It constructs an empty `DataFrame`, which has the columns specified by `ps`.

Example
```
df = DataFrame(:n => Int, :x =>Float64)
```
"""
function DataFrame(ps::Pair...)
    DF = DataFrame()
    for p=ps
        DF[p.first] = Vector{p.second}()
    end
    DF
end


# An ansymmetric matrix
import Base: length, size, getindex

"""
    Asymmetric{T} <: AbstractArray{T,2}

Defines a MxM asymmetric matrix. Data is stored in a
vector.
"""
type Asymmetric{T} <: AbstractArray{T,2}
    M::Int
    data::Vector{T}
end

length(mat::Asymmetric) = mat.M*(mat.M-1)
size(mat::Asymmetric) = (mat.M, mat.M)

getindex(mat::Asymmetric, i) = mat.data[i]
function getindex{T}(mat::Asymmetric{T}, m,n)
    M = mat.M
    if !(1 <= m <= M && 1 <= n <= M)
        error("Index ($m,$n) out of bounds.")
    end
    if m == n
        return zero(T)
    elseif m < n
        i = div((n-2)*(n-1), 2)+m
        mat[i]
    else
        i = div((m-2)*(m-1), 2)+n
        -mat[i]
    end

end

"""
    wontreturn(ex)

Checks whether the expression can be used in the RHS of an assignment.
"""
function wontreturn(ex::Expr)
    ex.head === :using && return true
    retex = last(ex.args)
    isa(retex, Expr) && retex.head === :using
end
wontreturn(::Any) = true


# Redirect STDERR
export @drop_stderr

"""Stores the `STDERR` output redirected by `@drop_stderr`."""
const dropped_stderr_ref = Ref{Compat.UTF8String}("")

"""
    dropped_stderr()
    dropped_stderr(x)

Returns or sets the `dropped_stderr_ref` variable.

To pretty print its contents:
    juliarc.dropped_stderr() |> println
"""
dropped_stderr() = dropped_stderr_ref.x
dropped_stderr(x) = dropped_stderr_ref.x = x

"""
    @drop_stderr ex

Redirects the STDERR and stores it in a global variable (accessible via the
`dropped_stderr` functions).

# Usage

```
@drop_stderr warn(".")
@drop_stderr begin
    using Gadfly
    warn("More STDERR")
end
```
"""
macro drop_stderr(ex)
    ex = wontreturn(ex) ? :($(esc(ex)); ret=nothing) : :(ret = $(esc(ex)))
    quote
        _STDERR = STDERR
        r,w = redirect_stderr()
        $ex
        redirect_stderr(_STDERR)
        close(w)
        readavailable(r) |> Compat.UTF8String |> dropped_stderr
        close(r)
        ret
    end
end

end # module
