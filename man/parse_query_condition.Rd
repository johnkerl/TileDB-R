% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/QueryCondition.R
\name{parse_query_condition}
\alias{parse_query_condition}
\title{Create a 'tiledb_query_condition' object from an expression}
\usage{
parse_query_condition(
  expr,
  ta = NULL,
  debug = FALSE,
  strict = TRUE,
  use_int64 = FALSE
)
}
\arguments{
\item{expr}{An expression that is understood by the TileDB grammar for query conditions.}

\item{ta}{An optional tiledb_array object that the query condition is applied to}

\item{debug}{A boolean toogle to enable more verbose operations, defaults
to 'FALSE'.}

\item{strict}{A boolean toogle to, if set, errors if a non-existing attribute is selected
or filtered on, defaults to 'TRUE'; if 'FALSE' a warning is shown by execution proceeds.}

\item{use_int64}{A boolean toggle to switch to \code{integer64} if \code{integer} is seen,
default is false to remain as a default four-byte \code{int}}
}
\value{
A \code{tiledb_query_condition} object
}
\description{
The grammar for query conditions is at present constraint to six operators
and three boolean types.
}
\examples{
\dontshow{ctx <- tiledb_ctx(limitTileDBCores())}
\dontrun{
uri <- "mem://airquality"    # change to on-disk for persistence
fromDataFrame(airquality, uri, col_index=c("Month", "Day"))  # dense array
## query condition on dense array requires extended=FALSE
tiledb_array(uri, return_as="data.frame", extended=FALSE,
             query_condition=parse_query_condition(Temp > 90))[]
}
}
