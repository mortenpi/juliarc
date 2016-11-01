using juliarc
using Base.Test

# load everything
juliarc.load()

import juliarc: Asymmetric
@test sum(Asymmetric(3, [1,2,3]) .== [0 1 2; -1 0 3; -2 -3 0]) == 9
