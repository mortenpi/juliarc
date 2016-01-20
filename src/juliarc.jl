module juliarc

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

end # module
