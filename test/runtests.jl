using juliarc
using Base.Test

# write your own tests here
@test 1 == 1

import juliarc: Asymmetric
@test sum(Asymmetric(3, [1,2,3]) .== [0 1 2; -1 0 3; -2 -3 0]) == 9
