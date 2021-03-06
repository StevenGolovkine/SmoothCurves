################################################################################
#         Functions for H0 parameter estimation using regularity               #
################################################################################

# Reference
# ---------
# * Golovkine S., Klutchnikoff N., Patilea V. (2020) - Learning the smoothness
# of noisy curves with applications to online curves denoising.
# * Golovkine S., Klutchnikoff N., Patilea V. (2021) - Adaptive estimation of
# irregular mean and covariance functions.

#' Perform a presmoothing of the data
#' 
#' This function performs a presmoothing of the data by local linear smoother.
#' 
#' @param data A list, where each element represents a curve. Each curve have to
#'  be defined as a list with two entries:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The observed points.
#'  } 
#' @param t0_list List, the sampling point around which we presmooth the data.
#' @param gamma Numeric, constant \eqn{\gamma} used in the theorem 1 in the paper.
#'  Should be between 0 and 1.
#' @param order Integer, default=0. Regularity of the input data.
#' @param drv Integer, default=0. Order of derivative to be estimated.
#'
#' @return List of array which contains the smoothed data.
#' @importFrom magrittr %>%
#' @export
presmoothing <- function(data, t0_list = 0.5, gamma = 0.5,
                         order = 1, drv = 0, degree = 0){
  
  m <- data %>% purrr::map_dbl(~ length(.x$t)) %>% mean()
  delta <- exp(-log(m)**gamma)
  t1_list <- t0_list - delta / 2
  t3_list <- t0_list + delta / 2
  
  b_naive <- min((delta / round(m))**(1 / (2 * order + 1)), delta / log(1 + m))
  
  results <- list()
  for(idx_t0 in 1:length(t0_list)){
    df <- array(dim = c(length(data), 11))
    for(i in 1:length(data)){
      # The bandwidth is divided by 3 because of the Gaussian kernel used in
      # KernSmooth::locpoly
      pred <- KernSmooth::locpoly(data[[i]]$t, data[[i]]$x,
                                  bandwidth = b_naive / 3,
                                  drv = drv, degree = degree, gridsize = 11,
                                  range.x = c(t1_list[idx_t0], t3_list[idx_t0]))
      df[i, ] <- pred$y
    }
    results[[idx_t0]] <- list(t = pred$x, x = df)
  }
  
  return(results)
}

#' Perform an estimation of \eqn{var(X_{t_0)}}
#' 
#' This function performs an estimation of \eqn{var(X_{t_0})} used for the
#' estimation of the bandwidth for the mean and the covariance by a univariate
#' kernel regression estimator.
#' 
#' @importFrom magrittr %>% 
#' 
#' @param data A list of array, resulting from the presmoothing function.
#' 
#' @return List, estimation of the variance at each \eqn{t_0}.
#' @export
estimate_var <- function(data){
  data %>% map_dbl(~ var(.x$x[,6], na.rm = TRUE))
}

#' Perform an estimation of \eqn{H_0}
#' 
#' This function performs an estimation of \eqn{H_0} used for the estimation of
#' the bandwidth for a univariate kernel regression estimator defined over 
#' continuous domains data using the method of \cite{Golovkine et al. (2021)}. 
#' 
#' @importFrom magrittr %>%
#'
#' @family estimate \eqn{H_0}
#' 
#' @param data An array, resulting from the presmoothing function.
#' 
#' @return Numeric, an estimation of H0.
#' @references Golovkine S., Klutchnikoff N., Patilea V. (2021) - Adaptive
#' estimation of irregular mean and covariance functions.
#' @export
estimate_H0 <- function(data){
  
  a <- mean((data[, 6] - data[, 1])**2, na.rm = TRUE)
  b <- mean((data[, 11] - data[, 1])**2, na.rm = TRUE)
  
  max((log(b) - log(a)) / (2 * log(2)), 0.1)
}

#' Perform an estimation of \eqn{H_0} given a list of \eqn{t_0}
#' 
#' This function performs an estimation of \eqn{H_0} used for the estimation of 
#' the bandwidth for a univariate kernel regression estimator defined over 
#' continuous domains data using the method of \cite{Golovkine et al. (2020)}. 
#'
#' @importFrom magrittr %>%
#'
#' @family estimate \eqn{H_0}
#' 
#' @param data A list of array, resulting from the presmoothing function.
#' @return A vector of numeric, an estimation of \eqn{H_0} at each \eqn{t_0}.
#' @references Golovkine S., Klutchnikoff N., Patilea V. (2021) - Adaptive
#' estimation of irregular mean and covariance functions.
#' @export
#' @examples
#' df <- generate_fractional_brownian(N = 1000, M = 300, H = 0.5, sigma = 0.05)
#' df_smooth <- presmoothing(df, t0_list = 0.5, gamma = 0.5, order = 1,
#'                           drv = 0, degree = 0)
#' H0 <- estimate_H0_list(df_smooth)
#' 
#' df_piece <- generate_piecewise_fractional_brownian(N = 1000, M = 300, 
#'                                                    H = c(0.2, 0.5, 0.8), 
#'                                                    sigma = 0.05)
#' df_smooth <- presmoothing(df, t0_list = c(0.2, 0.5, 0.8), gamma = 0.5,
#'                           order = 1, drv = 0, degree = 0)
#' H0 <- estimate_H0_list(df_smooth)
estimate_H0_list <- function(data){
  data %>% purrr::map_dbl(~ estimate_H0(.x$x))
}

#' Perform an estimation of the random Hölder random constant
#' 
#' This function performs an estimation of \eqn{\Lambda_{\eta}} used for the
#' estimation of the bandwidth for the mean and the covariance by a univariate
#' kernel regression estimator.
#' 
#' @importFrom magrittr %>% 
#' 
#' @param data A list of array, resulting from the presmoothing function.
#' @param H0_list A vector of numeric, resulting from the estimate_H0_list 
#'  function.
#' 
#' @return List, estimation of the variance at each \eqn{t_0}
#' @export
estimate_lambda <- function(data, H0_list){
  V1 <- data %>% 
    map2(H0_list, ~ abs(.x$x[, 6] - .x$x[, 1]) / abs(.x$t[6] - .x$t[1])**.y)
  V2 <- data %>% 
    map2(H0_list, ~ abs(.x$x[, 11] - .x$x[, 6]) / abs(.x$t[11] - .x$t[6])**.y)
  V_max <- V1 %>% map2_dfc(V2, ~ pmax(.x, .y, na.rm = TRUE))
  unname(colMeans(V_max, na.rm = TRUE))
}


################################################################################

#' Perform an estimation of \eqn{H_0} when the curves are derivables
#' 
#' This function performs an estimation of \eqn{H_0} used for the estimation of 
#' the bandwidth for a univariate kernel regression estimator defined over 
#' continuous domains data in the case the curves are derivables.
#' 
#' @importFrom magrittr %>% 
#' @importFrom KernSmooth locpoly
#' 
#' @family estimate \eqn{H_0}
#' 
#' @param data A list, where each element represents a curve. Each curve have to
#' be defined as a list with two entries:
#' \itemize{
#'  \item \strong{$t} The sampling points
#'  \item \strong{$x} The observed points.
#' }
#' @param t0 Numeric, the sampling point at which we estimate \eqn{H0}. It
#'  corresponds to \eqn{t_2} in the equation (10) of the paper.
#' @param gamma Numeric, constant \eqn{\gamma} used in the theorem 1 in the paper.
#'  Should be between 0 and 1.
#' @param Gamma Numeric, constant \eqn{\Gamma} used in the theorem 1 in the paper.
#'  Should be striclty greater than 0.
#' 
#' @return Numeric, an estimation of \eqn{H_0}.
#' @references Golovkine S., Klutchnikoff N., Patilea V. (2021) - Adaptive
#' estimation of irregular mean and covariance functions.
#' @export
estimate_H0_deriv <- function(data, t0 = 0.5, gamma = 0.5, Gamma = 1){
  
  m <- data %>% purrr::map_dbl(~ length(.x$t)) %>% mean()
  phi <- log(m)**(-Gamma)
  
  H0_estim <- estimate_H0(data, t0 = t0, gamma = gamma,
                          order = 1, cst = 1,
                          drv = 0)
  
  cpt <- 0
  while ((H0_estim > 1 - phi) & (cpt < 5)){
    print(cpt)
    H0_estim <- estimate_H0(data, t0 = t0, gamma = gamma, order = cpt,
                            cst = 1, drv = cpt + 1, degree = cpt + 1)
    cpt <- cpt + 1
    print(H0_estim)
  }
  cpt + H0_estim
}

#' Perform an estimation of \eqn{H_0} given a list of \eqn{t_0} when the curves
#' are derivables
#' 
#' This function performs an estimation of \eqn{H_0} used for the estimation of 
#' the bandwidth for a univariate kernel regression estimator defined over 
#' continuous domains data using the method of \cite{Golovkine et al. (2021)}
#' in the case the curves are derivables.
#'
#' @importFrom magrittr %>%
#'
#' @family estimate \eqn{H_0}
#' 
#' @param data A list, where each element represents a curve. Each curve have to
#'  be defined as a list with two entries:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The observed points.
#'  } 
#' @param t0_list Vector, the sampling point at which we estimate \eqn{H0}. It
#'  corresponds to \eqn{t_2} in the equation (10) of the paper.
#' @param gamma Numeric, constant \eqn{\gamma} used in the theorem 1 in the paper.
#'  Should be between 0 and 1.
#' @param Gamma Numeric, constant \eqn{\Gamma} used in the theorem 1 in the paper.
#'  Should be striclty greater than 0.
#'
#' @return A vector of numeric, an estimation of \eqn{H_0} at each \eqn{t_0}.
#' @references Golovkine S., Klutchnikoff N., Patilea V. (2021) - Adaptive
#' estimation of irregular mean and covariance functions.
#' @export
#' @examples
#' df <- generate_integrate_fractional_brownian(N = 1000, M = 300,
#'                                              H = 0.5, sigma = 0.01)
#' H0 <- estimate_H0_deriv_list(df, t0_list = 0.5)
estimate_H0_deriv_list <- function(data, t0_list, gamma = 0.5, Gamma = 1) {
  if(!inherits(data, 'list')){
    data <- checkData(data)
  }
  
  t0_list %>%
    purrr::map_dbl(~ estimate_H0_deriv(data, t0 = .x, gamma = gamma, Gamma = Gamma))
}



################################################################################
# Old functions
################################################################################

#' Perform an estimation of \eqn{H_0}
#' 
#' This function performs an estimation of \eqn{H_0} used for the estimation of
#' the bandwidth for a univariate kernel regression estimator defined over 
#' continuous domains data using the method of \cite{Golovkine et al. (2020)}. 
#' 
#' @importFrom magrittr %>%
#'
#' @family estimate \eqn{H_0}
#' 
#' @param data A list, where each element represents a curve. Each curve have to
#'  be defined as a list with two entries:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The observed points.
#'  } 
#' @param t0 Numeric, the sampling point at which we estimate \eqn{H0}. We will 
#'  consider the \eqn{8k0 - 7} nearest points of \eqn{t_0} for the estimation of
#'  \eqn{H_0} when \eqn{\sigma} is unknown.
#' @param k0 Numeric, the number of neighbors of \eqn{t_0} to consider. Should 
#'  be set as \eqn{k0 = M * exp(-log(log(M))^2)}.
#' @param sigma Numeric, true value of sigma. Can be NULL if true value 
#'  is unknown.
#'
#' @return Numeric, an estimation of H0.
#' @references Golovkine S., Klutchnikoff N., Patilea V. (2020) - Learning the
#' smoothness of noisy curves with applications to online curves denoising.
estimate_H0_old <- function(data, t0 = 0, k0 = 2, sigma = NULL) {

  theta <- function(v, k, idx) (v[idx + 2 * k - 1] - v[idx + k])**2

  first_part <- 2 * log(2)
  second_part <- 0
  two_log_two <- 2 * log(2)
  if (is.null(sigma)) { # Case where sigma is unknown
    idxs <- data %>%
      purrr::map_dbl(~ min(order(abs(.x$t - t0))[seq_len(8 * k0 - 6)]))
    a <- data %>%
      purrr::map2_dbl(idxs, ~ theta(.x$x, k = 4 * k0 - 3, idx = .y)) %>%
      mean()
    b <- data %>%
      purrr::map2_dbl(idxs, ~ theta(.x$x, k = 2 * k0 - 1, idx = .y)) %>%
      mean()
    c <- data %>%
      purrr::map2_dbl(idxs, ~ theta(.x$x, k = k0, idx = .y)) %>%
      mean()
    if ((a - b > 0) & (b - c > 0) & (a - 2 * b + c > 0)) {
      first_part <- log(a - b)
      second_part <- log(b - c)
    }
  } else { # Case where sigma is known
    idxs <- data %>%
      purrr::map_dbl(~ min(order(abs(.x$t - t0))[seq_len(4 * k0 - 2)]))
    a <- data %>%
      purrr::map2_dbl(idxs, ~ theta(.x$x, k = 2 * k0 - 1, idx = .y)) %>%
      mean()
    b <- data %>%
      purrr::map2_dbl(idxs, ~ theta(.x$x, k = k0, idx = .y)) %>%
      mean()
    if ((a - 2 * sigma**2 > 0) & (b - 2 * sigma**2 > 0) & (a - b > 0)) {
      first_part <- log(a - 2 * sigma**2)
      second_part <- log(b - 2 * sigma**2)
    }
  }

  (first_part - second_part) / two_log_two
}

#' Perform an estimation of \eqn{H_0} given a list of \eqn{t_0}
#' 
#' This function performs an estimation of \eqn{H_0} used for the estimation of 
#' the bandwidth for a univariate kernel regression estimator defined over 
#' continuous domains data using the method of \cite{Golovkine et al. (2020)}. 
#'
#' @importFrom magrittr %>%
#'
#' @family estimate \eqn{H_0}
#' 
#' @param data A list, where each element represents a curve. Each curve have to
#'  be defined as a list with two entries:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The observed points.
#'  } 
#' @param t0_list A vector of numerics, the sampling points at which we estimate 
#'  \eqn{H0}. We will consider the \eqn{8k0 - 7} nearest points of \eqn{t_0} for 
#'  the estimation of \eqn{H_0} when \eqn{\sigma} is unknown.
#' @param k0_list A vector of numerics, the number of neighbors of \eqn{t_0} to 
#'  consider. Should be set as \deqn{k0 = M * exp(-(log(log(M))**2))}. We can set a 
#'  different \eqn{k_0}, but in order to use the same for each \eqn{t_0}, just 
#'  put a unique numeric.
#' @param sigma Numeric, true value of sigma. Can be NULL.
#'
#' @return A vector of numeric, an estimation of \eqn{H_0} at each \eqn{t_0}.
#' @references Golovkine S., Klutchnikoff N., Patilea V. (2020) - Learning the
#' smoothness of noisy curves with applications to online curves denoising.
#' @export
#' @examples 
#' df <- generate_fractional_brownian(N = 1000, M = 300, H = 0.5, sigma = 0.05)
#' H0 <- estimate_H0_list_old(df, t0_list = 0.5, k0_list = 6)
#' 
#' df_piece <- generate_piecewise_fractional_brownian(N = 1000, M = 300, 
#'                                                    H = c(0.2, 0.5, 0.8), 
#'                                                    sigma = 0.05)
#' H0 <- estimate_H0_list_old(df_piece, t0_list = c(0.15, 0.5, 0.85),
#'                            k0_list = c(2, 4, 6))
#' H0 <- estimate_H0_list_old(df_piece, t0_list = c(0.15, 0.5, 0.85), k0_list = 6)
estimate_H0_list_old <- function(data, t0_list, k0_list = 2, sigma = NULL) {
  if(!inherits(data, 'list')){
    data <- checkData(data)
  }
  
  t0_list %>%
    purrr::map2_dbl(k0_list, ~ estimate_H0_old(data, t0 = .x, k0 = .y, sigma = sigma))
}

#' Perform an estimation of \eqn{H_0} when the curves are derivables
#' 
#' This function performs an estimation of \eqn{H_0} used for the estimation of 
#' the bandwidth for a univariate kernel regression estimator defined over 
#' continuous domains data in the case the curves are derivables.
#' 
#' @importFrom magrittr %>% 
#' @importFrom KernSmooth locpoly
#' 
#' @family estimate \eqn{H_0}
#' 
#' @param data A list, where each element represents a curve. Each curve have to
#' be defined as a list with two entries:
#' \itemize{
#'  \item \strong{$t} The sampling points
#'  \item \strong{$x} The observed points.
#' }
#' @param t0 Numeric, the sampling points at which we estimate \eqn{H_0}. We will
#' consider the \eqn{8k0 - 7} nearest points of \eqn{t_0} for the estimation of
#' \eqn{H_0} when \eqn{\sigma} is unknown.
#' @param eps Numeric, precision parameter. It is used to control how much larger 
#'  than 1, we have to be in order to consider to have a regularity larger than 1
#'  (default to 0.01).
#' @param k0 Numeric, the number of neighbors of \eqn{t_0} to consider.
#' @param sigma Numeric, true value of sigma. Can be NULL.
#' 
#' @return Numeric, an estimation of \eqn{H_0}.
#' @references Golovkine S., Klutchnikoff N., Patilea V. (2020) - Learning the
#' smoothness of noisy curves with applications to online curves denoising.
estimate_H0_deriv_old <- function(data, t0 = 0, eps = 0.01, k0 = 2, sigma = NULL){

  sigma_estim <- estimate_sigma(data, t0, k0)
  
  H0_estim <- estimate_H0_old(data, t0 = t0, k0 = k0, sigma = sigma)
  
  cpt <- 0
  while ((H0_estim > 1 - eps) & (cpt < 5)){
    #L0 <- estimate_L0(data, t0 = t0, H0 = cpt + H0_estim, k0 = k0)
    L0 <- estimate_L0(data, t0 = t0, H0 = 1, k0 = k0)
    b <- estimate_b(data, sigma = sigma_estim, H0 = cpt + H0_estim, L0 = L0)
    smooth <- data %>% purrr::map2(b, ~ list(
      t = .x$t,
      x = KernSmooth::locpoly(.x$t, .x$x,
        drv = 1 + cpt,
        bandwidth = .y, gridsize = length(.x$t)
      )$y
    ))
    H0_estim <- estimate_H0_old(smooth, t0 = t0, k0 = k0, sigma = sigma)
    cpt <- cpt + 1
  }
  cpt + H0_estim
}

#' Perform an estimation of \eqn{H_0} given a list of \eqn{t_0} when the curves
#' are derivables
#' 
#' This function performs an estimation of \eqn{H_0} used for the estimation of 
#' the bandwidth for a univariate kernel regression estimator defined over 
#' continuous domains data using the method of \cite{Golovkine et al. (2020)}
#' in the case the curves are derivables.
#'
#' @importFrom magrittr %>%
#'
#' @family estimate \eqn{H_0}
#' 
#' @param data A list, where each element represents a curve. Each curve have to
#'  be defined as a list with two entries:
#'  \itemize{
#'   \item \strong{$t} The sampling points
#'   \item \strong{$x} The observed points.
#'  } 
#' @param t0_list A vector of numerics, the sampling points at which we estimate 
#'  \eqn{H0}. We will consider the \eqn{8k0 - 7} nearest points of \eqn{t_0} for 
#'  the estimation of \eqn{H_0} when \eqn{\sigma} is unknown. Be careful not to
#'  consider \eqn{t_0} close to the bound of the interval because local 
#'  polynomials do not behave well in this case.
#' @param eps Numeric, precision parameter. It is used to control how much larger 
#'  than 1, we have to be in order to consider to have a regularity larger than 1
#'  (default to 0.01). Should be set as \deqn{\epsilon = log^{-2}(M)}.
#' @param k0_list A vector of numerics, the number of neighbors of \eqn{t_0} to 
#'  consider. Should be set as \deqn{k0 = M * exp(-log(log(M))^2)}. We can set a 
#'  different \eqn{k_0}, but in order to use the same for each \eqn{t_0}, just 
#'  put a unique numeric.
#' @param sigma Numeric, true value of sigma. Can be NULL.
#'
#' @return A vector of numeric, an estimation of \eqn{H_0} at each \eqn{t_0}.
#' @references Golovkine S., Klutchnikoff N., Patilea V. (2020) - Learning the
#' smoothness of noisy curves with applications to online curves denoising.
#' @export
#' @examples
#' df <- generate_integrate_fractional_brownian(N = 1000, M = 300,
#'                                              H = 0.5, sigma = 0.01)
#' H0 <- estimate_H0_deriv_list(df, t0_list = 0.5, eps = 0.01, k0_list = 14)
estimate_H0_deriv_list_old <- function(data, t0_list, eps = 0.01, k0_list = 2,
                                       sigma = NULL) {
  if(!inherits(data, 'list')){
    data <- checkData(data)
  }
  
  t0_list %>%
    purrr::map2_dbl(k0_list, ~ estimate_H0_deriv_old(data, t0 = .x, k0 = .y, sigma = sigma))
}

