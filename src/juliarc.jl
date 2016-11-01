"""
# Dropping streams

E.g. if there's too much error / deprecation output that can safely be ignored.

```julia
@drop_streams juliarc.load(:gadfly)
```

Especially relevant for clusters where the amount of output is multiplied by the
number of processes:

```julia
import juliarc
@everywhere using juliarc
@everywhere @drop_streams juliarc.load(:gadfly)
```
"""
module juliarc

import Compat

const juliarc_src = dirname(@__FILE__)

_dynamic_features = Dict(
    :gadfly => "gadfly.jl",
    :experimental => "Experimental.jl",
)

"""
Loads "dynamic features".
"""
function load(feature::Symbol)
    if !(feature in keys(_dynamic_features))
        error("$feature not found. Available features: $(keys(_dynamic_features))")
    end
    feature_q = Expr(:quote, feature) # so that this could be interpolated as a value
    eval(:(include(joinpath(juliarc_src, _dynamic_features[$feature_q]))))
end

"""
Load all the dynamic features.
"""
function load()
    for feature in keys(_dynamic_features)
        load(feature)
    end
end


################################################################################
# STANDARD SNIPPETS
# ------------------------------------------------------------------------------

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


using DataFrames

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


# An antisymmetric matrix
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
    const wontretruns = [:using, :import]
    ex.head in wontretruns && return true
    retex = last(ex.args)
    isa(retex, Expr) && retex.head in wontretruns
end
wontreturn(::Any) = true


# Redirect STDOUT and STDERR streams
export @drop_streams

"""Stores the dropped `STDOUT` and `STDERR` output redirected by `@drop_streams`."""
const stored_streams = Ref{Tuple{Compat.UTF8String,Compat.UTF8String}}(("",""))

"""
    dropped_streams()
    dropped_streams(out, err)

Returns or sets the `stored_streams` variable.

To pretty print its contents:
```julia
    # for STDOUT
    juliarc.dropped_streams() |> first |> println
    # for STDERR
    juliarc.dropped_streams() |> last |> println
```
"""
dropped_streams() = stored_streams.x
dropped_streams(out, err) = stored_streams.x = (out, err)

"""
    @drop_streams ex

Redirects the STDERR and stores it in a global variable (accessible via the
`dropdropped_streamsped_stderr` functions).

# Usage

```julia
@drop_streams warn("...")
@drop_streams begin
    using Gadfly
    warn("More STDERR")
end
```
"""
macro drop_streams(ex)
    ex = wontreturn(ex) ? :($(esc(ex)); ret=nothing) : :(ret = $(esc(ex)))
    quote
        _STDOUT, _STDERR = STDOUT, STDERR
        out_r, out_w = redirect_stdout()
        err_r, err_w = redirect_stderr()
        $ex
        redirect_stdout(_STDOUT)
        redirect_stderr(_STDERR)
        close(out_w)
        close(err_w)
        _out = readavailable(out_r) |> Compat.UTF8String
        _err = readavailable(err_r) |> Compat.UTF8String
        dropped_streams(_out, _err)
        close(out_r)
        close(err_r)
        ret
    end
end

# An alternative implementation without macros
type StreamRedirects
    STDOUT
    out_r :: Base.PipeEndpoint
    out_w :: Base.PipeEndpoint
    out_buf :: Compat.UTF8String
    STDERR
    err_r :: Base.PipeEndpoint
    err_w :: Base.PipeEndpoint
    err_buf :: Compat.UTF8String
    StreamRedirects() = new()
end

const redirector = StreamRedirects()

function redirect_streams()
    r = redirector
    r.STDOUT = STDOUT
    r.out_r, r.out_w = redirect_stdout()
    r.STDERR = STDERR
    r.err_r, r.err_w = redirect_stderr()
    return nothing
end

function restore_streams()
    r = redirector
    redirect_stderr(r.STDERR)
    redirect_stdout(r.STDOUT)
    close(r.err_w)
    close(r.out_w)
    r.err_buf = readavailable(r.err_r) |> Compat.UTF8String
    r.out_buf = readavailable(r.out_r) |> Compat.UTF8String
    close(r.err_r)
    close(r.out_r)
    return nothing
end

end # module
