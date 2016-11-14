mktemp() do path, io
    write(io, "eval `ssh-agent -s`")
    flush(io)
    run(`sh $path`)
end
