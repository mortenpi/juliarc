module Experimental

export @mutate

"""
`@mutate(expression)`

"Allows" the mutation of the fields on an immutable type.
The expression passed has to be of the form `@mutate obj.field = value`,
where `obj` and `field` should be simple symbols and `value` can be any expression.

It actually works by creating a new of type `typeof(obj)`, where all the fields
except `field` have the old value and `field` is set to `value`.

An example using complex numbers

```julia
z = Complex{Int}(1,2)
@mutate z.im = 2
```

*Known bugs/limitations:*

- The function is very strict with the left hand side.
- Assumes that type of `obj` does not have a custom constructor.

[Inspired by a discussion on the `julia-dev` list.](https://groups.google.com/forum/#!topic/julia-dev/QOZfPkdRQwk)

"""
macro mutate(ex)
    if typeof(ex) != Expr
        error("Invalid expression for @mutate (ex::$(typeof(ex)) = $ex)")
    end
    if ex.head != :(=)
        error("Invalid expression for @mutate (ex.head::$(typeof(ex.head)) = $ex.head)")
    end

    lhs = ex.args[1]
    rhs = ex.args[2]
    if typeof(lhs) != Expr || lhs.head != :.
        error("Invalid expression for @mutate (lhs::$(typeof(lhs)) = $lhs)")
    end

    obj = lhs.args[1]
    field = lhs.args[2]
    if typeof(obj) != Symbol
        error("Invalid expression for @mutate (obj::$(typeof(obj)) = $obj)")
    end
    if !(typeof(field) == Expr && field.head == :quote)
        error("Invalid expression for @mutate (field::$(typeof(field)) = $field)")
    end
    if !(length(field.args) ==1 && typeof(field.args[1])==Symbol)
        error("Invalid expression for @mutate (field.args::$(typeof(field.args)) = $field.args)")
    end

    field = field.args[1]
    obj_type = typeof(eval(obj))

    if !(field in fieldnames(obj_type))
        error("type $obj_type has no field $field")
    end

    args = map(fieldnames(obj_type)) do name
        name == field ? rhs : :($obj.$name)
    end
    :( $(esc(obj)) = $obj_type($(args...)) )
end


"""
    @generic function f(...) ... end
    @generic f(...) = ...

Turns a normal function definition into a generic function assignment.

Can be used to work around [#265](https://github.com/JuliaLang/julia/issues/265)
regressions in 0.5 introduced by the fact that every function is now a type.
"""
macro generic(e)
    # Output should be the f = function(x,y) ... end syntax.
    # Expr(:(=), <name>, <generic_def>)
    # where:
    #   <generic_def> = Expr(:function, <args>, <block>)
    #   <args> = Expr(:tuple, ...)
    if (e.head === :function || e.head === :(=)) && e.args[1].head === :call
        println("Genericizing function ... end syntax")
        # e.args[1] should always be an Expr(:call, <name>, <args>...)
        @assert isa(e.args[1].args[1], Symbol)
        function_name = esc(e.args[1].args[1])
        arguments = e.args[1].args[2:end]
        # e.args[2] should be a quote block: Expr(:block, ...)
        @assert e.args[2].head === :block
        quoteblock = e.args[2]
        # putting the generic expression together
        Expr(:(=), function_name, Expr(:function, Expr(:tuple, arguments...), quoteblock))
    else
        error("Unable to genericize this expression: $e")
    end
end

end # module
