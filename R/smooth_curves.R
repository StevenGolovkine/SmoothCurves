################################################################################
#        Functions that performs kernel smoothing over a set of curves         #
################################################################################

#' Perform a non-parametric smoothing of a set of curves
#'
#' This function performs a non-parametric smoothing of a set of curves using the
#' Nadaraya-Watson estimator. The bandwidth is estimated using the method from 
#' \cite{add ref}.
#' 
#' @importFrom magrittr %>%
#'
#' @param data A list, where each element represents a curve. Each curve have to
#'  be defined as a list with two entries:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The observed points.
#'  } 
#' @param U A vector of numerics, sampling points at which estimate the curves.
#'  If NULL, the sampling points for the estimation are the same than the 
#'  observed ones.
#' @param t0_list A vector of numerics, the sampling points at which we estimate 
#'  \eqn{H0}. We will consider the \eqn{8k0 - 7} nearest points of \eqn{t_0} for 
#'  the estimation of \eqn{H_0} when \eqn{\sigma} is unknown.
#' @param k0_list A vector of numerics, the number of neighbors of \eqn{t_0} to 
#'  consider. Should be set as \deqn{k0 = M* exp(-log(log(M))^2)}. We can set a 
#'  different \eqn{k_0}, but in order to use the same for each \eqn{t_0}, just 
#'  put a unique numeric.
#' @param K Character string, the kernel used for the estimation:
#'  \itemize{
#'   \item epanechnikov (default)
#'   \item uniform
#'   \item beta
#'  }
#'
#' @return A list, which contains two elements. The first one is a list which 
#'  contains the estimated parameters:
#'  \itemize{
#'   \item \strong{sigma} An estimation of the standard deviation of the noise
#'   \item \strong{H0} An estimation of \eqn{H_0}
#'   \item \strong{L0} An estimation of \eqn{L_0}
#'   \item \strong{b} An estimation of the bandwidth
#'  }
#'  The second one is another list which contains the estimation of the curves:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The estimated points.
#'  } 
#' @export
#' @examples 
#' df <- generate_fractional_brownian(N = 1000, M = 300, H = 0.5, sigma = 0.05)
#' df_smooth <- smooth_curves(df)
#' 
#' df_piece <- generate_piecewise_fractional_brownian(N = 1000, M = 300, 
#'                                                    H = c(0.2, 0.5, 0.8), 
#'                                                    sigma = 0.05)
#' df_piece_smooth <- smooth_curves(df_piece, t0_list = c(0.15, 0.5, 0.85), 
#'                                  k0_list = 6)
smooth_curves <- function(data, U = NULL, t0_list = 0.5,
                          k0_list = 2, K = "epanechnikov"){

  # Estimation of the different parameters
  param_estim <- estimate_bandwidth_curves(data, t0_list = t0_list,
                                           k0_list = k0_list, K = K)

  # Get the bandwidths
  b_estim <- param_estim$b %>% 
    purrr::transpose() %>% 
    purrr::map(~ unname(unlist(.x)))

  # Estimation of the curves
  if (is.null(U)) {
    curves <- data %>% 
      purrr::map2(b_estim, ~ estimate_curve(.x, U = .x$t, b = .y,
                                            t0_list = t0_list, kernel = K))
  } else {
    curves <- data %>% 
      purrr::map2(b_estim, ~ estimate_curve(.x, U = U, b = .y,
                                            t0_list = t0_list, kernel = K))
  }

  list(
    "parameter" = param_estim,
    "smooth" = curves
  )
}


#' Perform a non-parametric smoothing of a set of curves for mean estimation
#'
#' This function performs a non-parametric smoothing of a set of curves using the
#' Nadaraya-Watson estimator. The bandwidth is estimated using the method from 
#' \cite{add ref}.
#' 
#' @importFrom magrittr %>%
#'
#' @param data A list, where each element represents a curve. Each curve have to
#'  be defined as a list with two entries:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The observed points.
#'  } 
#' @param U A vector of numerics, sampling points at which estimate the curves.
#'  If NULL, the sampling points for the estimation are the same than the 
#'  observed ones.
#' @param t0_list A vector of numerics, the sampling points at which we estimate 
#'  \eqn{H0}. We will consider the \eqn{8k0 - 7} nearest points of \eqn{t_0} for 
#'  the estimation of \eqn{H_0} when \eqn{\sigma} is unknown.
#' @param k0_list A vector of numerics, the number of neighbors of \eqn{t_0} to 
#'  consider. Should be set as \deqn{k0 = M* exp(-log(log(M))^2)}. We can set a 
#'  different \eqn{k_0}, but in order to use the same for each \eqn{t_0}, just 
#'  put a unique numeric.
#'
#' @return A list, which contains two elements. The first one is a list which 
#'  contains the estimated parameters:
#'  \itemize{
#'   \item \strong{sigma} An estimation of the standard deviation of the noise
#'   \item \strong{H0} An estimation of \eqn{H_0}
#'   \item \strong{L0} An estimation of \eqn{L_0}
#'   \item \strong{b} An estimation of the bandwidth
#'  }
#'  The second one is another list which contains the estimation of the curves:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The estimated points.
#'  } 
#' @export
smooth_curves_mean <- function(data, U = NULL, t0_list = 0.5, k0_list = 2,
                          grid = NULL,
                          nb_obs_minimal = 2, K = 'epanechnikov'){
  
  if(K == 'uniform')
    type_k = 1
  else if (K == 'epanechnikov')
    type_k = 2
  else if(K == 'biweight')
    type_k = 3
  else
    type_k = 1

  # Estimation of the different parameters
  param_estim <- estimate_bandwidth_mean(data, t0_list = t0_list,
                                         k0_list = k0_list, grid = grid,
                                         nb_obs_minimal = nb_obs_minimal,
                                         type_k = type_k)
  
  # Get the bandwidths
  b_estim <- unname(unlist(param_estim$b))
  
  # Estimation of the curves
  if (is.null(U)) {
    curves <- data %>% 
      purrr::map(~ estimate_curve(.x, U = .x$t, b = b_estim,
                                  t0_list = t0_list, kernel = K,
                                  n_obs_min = nb_obs_minimal))
  } else {
    curves <- data %>% 
      purrr::map(~ estimate_curve(.x, U = U, b = b_estim,
                                  t0_list = t0_list, kernel = K,
                                  n_obs_min = nb_obs_minimal))
  }
  
  list(
    "parameter" = param_estim,
    "smooth" = curves
  )
}


#' Perform a non-parametric smoothing of a set of curves when the regularity is
#' larger than 1
#'
#' This function performs a non-parametric smoothing of a set of curves using the
#' Nadaraya-Watson estimator when the regularity of the underlying curves is
#' larger than 1. The bandwidth is estimated using the method from 
#' \cite{add ref}. In the case of a regularly larger than 1, we currently 
#' assume that the regularly is the same all over the curve.
#' 
#' @importFrom magrittr %>%
#'
#' @param data A list, where each element represents a curve. Each curve have to
#'  be defined as a list with two entries:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The observed points.
#'  } 
#' @param U A vector of numerics, sampling points at which estimate the curves.
#'  If NULL, the sampling points for the estimation are the same than the 
#'  observed ones.
#' @param t0 Numeric, the sampling point at which we estimate \eqn{H0}. We will 
#'  consider the \eqn{8k0 - 7} nearest points of \eqn{t_0} for the estimation of
#'  \eqn{H_0} when \eqn{\sigma} is unknown.
#' @param k0 Numeric, the number of neighbors of \eqn{t_0} to consider. Should 
#'  be set as \eqn{k0 = M * exp(-log(log(M))^2)}.
#' @param K Character string, the kernel used for the estimation:
#'  \itemize{
#'   \item epanechnikov (default)
#'   \item uniform
#'   \item beta
#'  }
#' @param gamma float, default=0.5
#' @param Gamma float, default=1
#' @param reason Character string, for what purpose we compute the bandwidth
#'  \itemize{
#'   \item curve (default)
#'   \item mean
#'   \item covariance
#'  }
#'  
#' @return A list, which contains two elements. The first one is a list which 
#'  contains the estimated parameters:
#'  \itemize{
#'   \item \strong{sigma} An estimation of the standard deviation of the noise
#'   \item \strong{H0} An estimation of \eqn{H_0}
#'   \item \strong{L0} An estimation of \eqn{L_0}
#'   \item \strong{b} An estimation of the bandwidth
#'  }
#'  The second one is another list which contains the estimation of the curves:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The estimated points.
#'  } 
#' @export
#' @examples
#' df <- generate_integrate_fractional_brownian(N = 1000, M = 300, 
#'                                               H = 0.5, sigma = 0.01)
#' df_smooth <- smooth_curves_regularity(df, U = seq(0, 1, length.out = 101), 
#'                                       t0 = 0.5, k0 = 14)
smooth_curves_regularity <- function(data, U = NULL, t0 = 0.5, k0 = 2,
                                     K = "epanechnikov", gamma = 0.5, Gamma = 1,
                                     reason = "curve", old = FALSE){

  if(!inherits(data, 'list')){
    data <- checkData(data)
  }
  
  # Estimation of the noise
  sigma_estim <- estimate_sigma_list(data, t0, k0)

  # Estimation of H0
  if(old){
    H0_estim <- estimate_H0_deriv_list_old(data, t0_list = t0, k0_list = k0)
  } else{
    H0_estim <- estimate_H0_deriv_list(data, t0_list = t0,
                                       gamma = gamma, Gamma = Gamma)
  }
  
  # Estimation of L0
  L0_estim <- estimate_L0_list(data, t0_list = t0, H0_list = H0_estim, k0_list = k0)

  # Estimation of the bandwidth
  b_estim <- estimate_b_list(data, H0_list = H0_estim, t0_list = t0_list,
                             L0_list = L0_estim, sigma = sigma_estim, K = K,
                             reason = reason) %>%
    purrr::transpose() %>% 
    purrr::map(~ unname(unlist(.x)))

  # Estimation of the curves
  if (is.null(U)) {
    curves <- data %>% purrr::map2(b_estim, ~ estimate_curve(.x,
      U = .x$t, b = .y,
      t0_list = t0, kernel = K
    ))
  } else {
    curves <- data %>% purrr::map2(b_estim, ~ estimate_curve(.x,
      U = U, b = .y,
      t0_list = t0, kernel = K
    ))
  }
  
  list(
    "parameter" = list(
      "sigma" = sigma_estim,
      "H0" = H0_estim,
      "L0" = L0_estim,
      "b" = b_estim
    ),
    "smooth" = curves
  )
}
