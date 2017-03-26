using DataFrames

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
    body = expr.args[2]

    columns = Symbol[]
    coltypes = Symbol[]

    for arg in body.args
        # We only care about lines that have @dfcol in the beginning.
        (arg.head === :macrocall) && (arg.args[1] === Symbol("@dfcol")) || continue
        assignment = arg.args[2]

        # Is it a proper `colname :: Type` assignment? If so, extract name and type.
        assignment.head == :(=) && isa(assignment.args[1], Expr) && assignment.args[1].head === :(::) || error("Bad assignment.")

        @assert isa(assignment.args[1].args[1], Symbol)
        @assert isa(assignment.args[1].args[2], Symbol)

        push!(columns, assignment.args[1].args[1])
        push!(coltypes, assignment.args[1].args[2])

        # Remove the @dfcol call
        arg.head = :(=)
        arg.args = assignment.args
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
