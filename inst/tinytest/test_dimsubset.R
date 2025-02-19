
## this test file has an implicit dependency on package 'nycflights13'

library(tinytest)
library(tiledb)
library(RcppSpdlog)                     # use logging for some informal profiling

isOldWindows <- Sys.info()[["sysname"]] == "Windows" && grepl('Windows Server 2008', osVersion)
if (isOldWindows) exit_file("skip this file on old Windows releases")

if (!requireNamespace("nycflights13", quietly=TRUE)) exit_file("Needed 'nycflights13' package missing")

log_setup("test_dimsubset", "warn")     # but set the default level to 'warn' -> silent, activate via 'info'
ctx <- tiledb_ctx(limitTileDBCores())
log_info("ctx created")

op <- options()
options(stringsAsFactors=FALSE)       # accomodate R 3.*
dir.create(tmp <- tempfile())

library(nycflights13)

set_allocation_size_preference(1e8)
dom <- tiledb_domain(dims = c(tiledb_dim("carrier", NULL, NULL, "ASCII"),
                              tiledb_dim("origin", NULL, NULL, "ASCII"),
                              tiledb_dim("dest", NULL, NULL, "ASCII"),
                              tiledb_dim("time_hour",
                                         c(as.POSIXct("2012-01-01 00:00:00"),
                                           as.POSIXct("2014-12-31 23:59:99")), 1000, "DATETIME_SEC")))
log_info("domain created")

sch <- tiledb_array_schema(dom,
                           attrs <- c(tiledb_attr("year", type = "INT32"),
                                      tiledb_attr("month", type = "INT32"),
                                      tiledb_attr("day", type = "INT32"),
                                      tiledb_attr("dep_time", type = "INT32", nullable = TRUE),
                                      tiledb_attr("sched_dep_time", type = "INT32"),
                                      tiledb_attr("dep_delay", type = "FLOAT64", nullable = TRUE),
                                      tiledb_attr("arr_time", type = "INT32"),
                                      tiledb_attr("sched_arr_time", type = "INT32"),
                                      tiledb_attr("arr_delay", type = "FLOAT64", nullable = TRUE),
                                      tiledb_attr("flight", type = "INT32", nullable = TRUE),
                                      tiledb_attr("tailnum", type = "ASCII", ncells = NA, nullable = TRUE),
                                      tiledb_attr("air_time", type = "FLOAT64", nullable = TRUE),
                                      tiledb_attr("distance", type = "FLOAT64"),
                                      tiledb_attr("hour", type = "FLOAT64"),
                                      tiledb_attr("minute", type = "FLOAT64")),
                           sparse = TRUE,
                           allows_dups = TRUE)
log_info("schema created")
res <- tiledb_array_create(tmp, sch)
log_info("array created")

arr <- tiledb_array(res, query_type="WRITE")
log_info("array opened for write")
## we reorder the data.frame / tibble on the fly, and yes there are a number of ways to do this
newlst <- list(carrier = flights$carrier,
               origin = flights$origin,
               dest = flights$dest,
               time_hour = flights$time_hour,
               year = flights$year,
               month = flights$month,
               day = flights$day,
               dep_time = flights$dep_time,
               sched_dep_time = flights$sched_dep_time,
               dep_delay = flights$dep_delay,
               arr_time = flights$arr_time,
               sched_arr_time = flights$sched_arr_time,
               arr_delay = flights$arr_delay,
               flight = flights$flight,
               tailnum = flights$tailnum,
               air_time = flights$air_time,
               distance = flights$distance,
               hour = flights$hour,
               minute = flights$minute)
log_info("re-arranged list object made")
arr[] <- newlst
log_info("array written")

newarr <- tiledb_array(tmp, return_as="data.frame", query_layout="UNORDERED")
dat <- newarr[]
log_info("array read")
expect_equal(nrow(dat), nrow(flights))
## compare some columns, as we re-order comparing all trickers
expect_equal(sort(dat$carrier), sort(as.character(flights$carrier)))
expect_equal(table(dat$origin), table(flights$origin))

## test list of four with one null
selected_ranges(newarr) <- list(cbind("AA","AA"),
                                cbind("JFK","JFK"),
                                cbind("BOS", "BOS"),
                                NULL)
dat <- newarr[]
expect_equal(unique(dat$carrier), "AA")
expect_equal(unique(dat$origin), "JFK")
expect_equal(unique(dat$dest), "BOS")

## same via selected_points
newarr <- tiledb_array(tmp, return_as="data.frame", query_layout="UNORDERED",
                       selected_points= list("AA", "JFK", "BOS", NULL))
dat <- newarr[]
expect_equal(unique(dat$carrier), "AA")
expect_equal(unique(dat$origin), "JFK")
expect_equal(unique(dat$dest), "BOS")

## test named lists with one element
newarr <- tiledb_array(tmp, return_as="data.frame", query_layout="UNORDERED")
selected_ranges(newarr) <- list(carrier = cbind("AA","AA"))
dat <- newarr[]
expect_equal(unique(dat$carrier), "AA")

selected_ranges(newarr) <- list(origin = cbind("JFK","JFK"))
dat <- newarr[]
expect_equal(unique(dat$origin), "JFK")

selected_ranges(newarr) <- list(dest = cbind("BOS", "BOS"))
dat <- newarr[]
expect_equal(unique(dat$dest), "BOS")

daterange <- c(as.POSIXct("2013-01-10 00:00:00"), as.POSIXct("2013-01-19 23:59:99"))
selected_ranges(newarr) <- list(time_hour = cbind(daterange[1], daterange[2]))
dat <- newarr[]
expect_true(all(dat$time_hour >= daterange[1]))
expect_true(all(dat$time_hour <= daterange[2]))


## test named lists of two
selected_ranges(newarr) <- list(dest = cbind("BOS", "BOS"), origin = cbind("LGA", "LGA"))
dat <- newarr[]
expect_equal(unique(dat$dest), "BOS")
expect_equal(unique(dat$origin), "LGA")

selected_ranges(newarr) <- list()
selected_points(newarr) <- list(dest = "BOS", origin = "LGA")
dat <- newarr[]
expect_equal(unique(dat$dest), "BOS")
expect_equal(unique(dat$origin), "LGA")


selected_points(newarr) <- list()
selected_ranges(newarr) <- list(origin = cbind("JFK", "JFK"), carrier = cbind("AA", "AA"))
dat <- newarr[]
expect_equal(unique(dat$carrier), "AA")
expect_equal(unique(dat$origin), "JFK")

selected_ranges(newarr) <- list()
selected_points(newarr) <- list(origin = "JFK", carrier = "AA")
dat <- newarr[]
expect_equal(unique(dat$carrier), "AA")
expect_equal(unique(dat$origin), "JFK")


selected_points(newarr) <- list()
selected_ranges(newarr) <- list(dest = cbind("BOS", "BOS"), origin = cbind("JFK", "LGA"))
dat <- newarr[]
expect_equal(unique(dat$origin), c("JFK", "LGA"))
expect_equal(unique(dat$dest), "BOS")

## use both
if (Sys.info()[["sysname"]] == "Windows") exit_file("Skip remainder on Windows")
selected_points(newarr) <- list(dest = "BOS")
selected_ranges(newarr) <- list(origin = cbind("JFK", "LGA"))
dat <- newarr[]
expect_equal(unique(dat$origin), c("JFK", "LGA"))
expect_equal(unique(dat$dest), "BOS")
