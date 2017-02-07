# The Orthopolys packages is not in the package repo
orthopolys_installed = false
try
    orthopolys_installed = (Pkg.installed("Orthopolys") !== nothing)
catch end
orthopolys_installed || Pkg.clone("https://github.com/mortenpi/Orthopolys.jl.git")
