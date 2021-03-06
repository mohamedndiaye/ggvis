#' Count data at each location
#'
#' @param x Dataset-like object to count. Built-in methods for data frames,
#'   grouped data frames and ggvis visualisations.
#' @param x_var,w_var Names of x and weight variables.
#' @seealso \code{\link{compute_bin}} For counting cases within ranges of
#'   a continuous variable.
#' @seealso \code{\link{compute_width}} For calculating the "width" of data.
#' @export
#' @return A data frame with columns:
#'  \item{count_}{the number of points}
#'  \item{x_}{the x value where the count was made}
#'
#' The width of each "bin" is set to the resolution of the data -- that is, the
#' smallest difference between two x values.
#'
#' @examples
#' mtcars %>% compute_count(~cyl)
#'
#' # Weight the counts by car weight value
#' mtcars %>% compute_count(~cyl, ~wt)
#'
#' # If there's one weight value at each x, it effectively just renames columns.
#' pressure %>% compute_count(~temperature, ~pressure)
#' # Also get the width of each bin
#' pressure %>% compute_count(~temperature, ~pressure) %>% compute_width(~x_)
#'
#' # It doesn't matter whether you transform inside or outside of a vis
#' mtcars %>% compute_count(~cyl, ~wt) %>%
#'   compute_width(~x_) %>%
#'   ggvis(x = ~xmin_, x2 = ~xmax_, y = ~count_, y2 = 0) %>%
#'   layer_rects() %>%
#'   scale_numeric("y", domain = c(0, NA))
#'
#' mtcars %>%
#'   ggvis(x = ~xmin_, x2 = ~xmax_, y = ~count_, y2 = 0) %>%
#'   compute_count(~cyl, ~wt) %>%
#'   compute_width(~x_) %>%
#'   layer_rects() %>%
#'   scale_numeric("y", domain = c(0, NA))
compute_count <- function(x, x_var, w_var = NULL) {
  UseMethod("compute_count")
}

#' @export
compute_count.data.frame <- function(x, x_var, w_var = NULL) {
  assert_that(is.formula(x_var))

  x_val <- eval_vector(x, x_var)

  if (is.null(w_var)) {
    w_val <- NULL
  } else {
    w_val <- eval_vector(x, w_var)
  }

  count_vector(x_val, weight = w_val)
}

#' @export
compute_count.grouped_df <- function(x, x_var, w_var = NULL) {
  dplyr::do(x, compute_count(., x_var, w_var = w_var))
}

#' @export
compute_count.ggvis <- function(x, x_var, w_var = NULL) {
  args <- list(x_var = x_var, w_var = w_var)

  register_computation(x, args, "count", function(data, args) {
    output <- do_call(compute_count, quote(data), .args = args)
    preserve_constants(data, output)
  })
}

# Count individual vector ------------------------------------------------------

count_vector <- function(x, weight = NULL, ...) {
  if (is.null(weight)) {
    weight <- rep.int(1, length(x))
  }
  counts <- unname(as.vector(tapply(weight, x, sum, na.rm = TRUE)))

  if (is.factor(x)) {
    # Get the factor levels, preserving factor-ness. Order should align
    # with counts.
    values <- unique(x)
  } else {
    # Need to get unique values this way instead of using names(counts),
    # because names are strings but the x values aren't always strings.
    values <- unname(as.vector(tapply(x, x, unique, na.rm = TRUE)))
  }

  data.frame(
    count_ = counts,
    x_ = values,
    stringsAsFactors = FALSE
  )
}
