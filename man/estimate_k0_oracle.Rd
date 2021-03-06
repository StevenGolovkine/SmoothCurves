% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/estimate_k0.R
\name{estimate_k0_oracle}
\alias{estimate_k0_oracle}
\title{Perform the estimation of the oracle \eqn{k_0}}
\usage{
estimate_k0_oracle(M, H)
}
\arguments{
\item{M}{Numeric, mean number of sampling points per curve}

\item{H}{Numeric, estimation of \eqn{H_0}}
}
\value{
Numeric, the oracle \eqn{k_0}
}
\description{
This function performs the estimation of the oracle \eqn{k_0} as used in
\cite{add ref}.
}
\examples{
estimate_k0_oracle(200, 0.5)
}
\seealso{
Other estimate \eqn{k_0}: 
\code{\link{estimate_k0_pilot}()},
\code{\link{estimate_k0}()}
}
\concept{estimate \eqn{k_0}}
