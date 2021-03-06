% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data.R
\docType{data}
\name{canadian_temperature_daily}
\alias{canadian_temperature_daily}
\title{Canadian average annual temperature}
\format{
A list with 35 elements. Each element corresponds to a particular
Canadian station. Each station is a list with 2 elements which are:
\itemize{
\item \strong{t} The day of the year the temperature is taken (normalized on \eqn{[0, 1]})
\item \strong{x} The average temperature for each day of the year
}
}
\usage{
canadian_temperature_daily
}
\description{
Daily temperature at 35 different locations in Canada averaged over 1960 to
1994.
}
\references{
Ramsay, James O., and Silverman, Bernard W. (2006), Functional Data Analysis, 2nd ed., Springer, New York.

Ramsay, James O., and Silverman, Bernard W. (2002), Applied Functional Data Analysis, Springer, New York
}
\seealso{
\code{\link[fda]{CanadianWeather}}
}
\keyword{datasets}
