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

export @dataframe
export @dfcol

"""
`@dfcol` is a pseudo-macro to be used in `@dataframe`
"""
macro dfcol(args...)
    error("@dfcol not in top level of a for loop.")
end

"""
    @dataframe for ... end

Syntactic sugar to construct `DataFrame` objects using simple for loops.
It hides the usual boilerplate code.

Lines starting with `@dfcol` macro determine the columns of the resulting `DataFrame`.
They have to be assignments of the form `column_name :: ColumnType  = ...`.

In the background, `@dataframe` constructs a vector for each column it finds in the body
of the `for` loop, populates these vectors at the end of each loop and then constructs and
returns a `DataFrame` at the very end.


Example:
```
@dataframe for x in linspace(1, 20, 5)
    @dfcol x::Float64 = x
    @dfcol y::Float64 = x^2
end
```
"""
macro dataframe(expr)
    @assert expr.head === :for

    # Fix hygiene for the iterable in the `for x in xs` statement.
    @assert expr.args[1].head === :(=)
    expr.args[1].args[1] = esc(expr.args[1].args[1])
    expr.args[1].args[2] = esc(expr.args[1].args[2])

    # We'll gather the intended columns and their types into these two arrays.
    columns = Symbol[]
    coltypes = Symbol[]

    body = expr.args[2]
    for (i,arg) in enumerate(body.args)
        # We only care about lines that have @dfcol in the beginning. If that's not the case
        # then we'll just escape the line and move on.
        if (arg.head !== :macrocall) || (arg.args[1] !== Symbol("@dfcol"))
            body.args[i] = esc(arg)
            continue
        end

        # Is it a proper `colname :: Type` assignment? If so, extract name and type.
        assignment = arg.args[2]
        assignment.head == :(=) && isa(assignment.args[1], Expr) && assignment.args[1].head === :(::) || error("Bad assignment.")
        @assert isa(assignment.args[1].args[1], Symbol)
        @assert isa(assignment.args[1].args[2], Symbol)
        fieldname = assignment.args[1].args[1]
        push!(columns, fieldname)
        push!(coltypes, assignment.args[1].args[2])

        # Remove the @dfcol call
        arg.head = :(=)
        arg.args[1] = fieldname
        arg.args[2] = esc(Expr(:(=), fieldname, assignment.args[2]))
    end

    column_vectors = [Symbol("__$(c)__dfcol__") for c in columns]

    dfvecs_expr = map(zip(column_vectors, coltypes)) do _
        cvname, cvtype = _
        :($(cvname) = $(cvtype)[])
    end

    for (cvname, column) in zip(column_vectors, columns)
        push_line_expr = :(push!($cvname, $column))
        push!(body.args, push_line_expr)
    end

    dfconstruct_args = map(zip(columns, column_vectors)) do _
        column, cvname = _
        Expr(:kw, column, cvname)
    end
    dfconstruct_expr = Expr(:call, :DataFrame, dfconstruct_args...)

    quote
        $(dfvecs_expr...)
        $(expr)
        $(dfconstruct_expr)
    end
end
