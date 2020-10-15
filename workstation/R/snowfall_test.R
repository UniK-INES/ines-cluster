require('snowfall')

sfInit(parallel=TRUE, cpus=4, type="SOCK")

require(mvna)
data(sir.adm)

wrapper <- function(idx) {
logfilecat( "Current index: ", idx, "\n" )
index <- sample(1:nrow(sir.adm), replace=TRUE)
temp <- sir.adm[index, ]
fit <- crr(temp$time, temp$status, temp$pneu)
return(fit$coef)
}

sfExport("sir.adm")
sfLibrary(cmprsk)

sfClusterSetupRNG()

result <- sfLapply(1:1000, wrapper)

mean(unlist(result))


sfStop()