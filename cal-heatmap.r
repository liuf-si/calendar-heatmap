#!/usr/bin/env Rscript

# L I C E N S E ###############################################################
## Copyright 2009 Humedica.  All rights reserved.
## Modifications Copyright 2010 Indraniel Das

## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.

## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.

## You can find a copy of the GNU General Public License, Version 2 at:
## http://www.gnu.org/licenses/gpl-2.0.html

#S C R I P T ##################################################################
# cal-heatmap.r: An Rscript to display time-series data as a calendar heatmap 

# This is a first-pass Rscript form of the following R code:
#    http://blog.revolution-computing.com/downloads/calendarHeat.R
# More information about the code can be found in the following blog post:
#  http://blog.revolution-computing.com/2009/11/charting-time-series-as-calendar-heat-maps-in-r.html
#  The original author of calendarHeat.R was Paul Bleicher

library('methods');
library('optparse');
library('grid');
library('lattice');
library('chron');
library('Cairo');

calendarHeat <- function(opts,
                         dates, 
                         values, 
                         ncolors=99, 
                         color="r2g", 
                         varname="Values",
                         date.form = "%Y-%m-%d", ...) {
    if (class(dates) == "character" | class(dates) == "factor" ) {
      dates <- strptime(dates, date.form)
    }

    # construct date frame
    caldat   <- data.frame(value = values, dates = dates)
    min.date <- as.Date( paste(format(min(dates), "%Y"), "-1-1",sep = "") )
    max.date <- as.Date( paste(format(max(dates), "%Y"), "-12-31", sep = "") )
    dates.f  <- data.frame(date.seq = seq(min.date, max.date, by="days"))
    caldat   <- merge(dates.f, caldat, by.x="date.seq", by.y="dates", all=TRUE)

    caldat$dotw  <- as.numeric(format(caldat$date.seq, "%w"))
    caldat$woty  <- as.numeric(format(caldat$date.seq, "%U")) + 1
    caldat$yr    <- as.factor(format(caldat$date.seq, "%Y"))
    caldat$month <- as.numeric(format(caldat$date.seq, "%m"))

    yrs <- as.character(unique(caldat$yr))
    d.loc <- as.numeric()                        
    for (m in min(yrs):max(yrs)) {
      d.subset <- which(caldat$yr == m)  
      sub.seq  <- seq(1,length(d.subset))
      d.loc    <- c(d.loc, sub.seq)
    }  

    caldat <- cbind(caldat, seq=d.loc)

    # setup lattice graphing styles

    # -- color style (red to blue)
    r2b <- c("#0571B0", "#92C5DE", "#F7F7F7", "#F4A582", "#CA0020") 
    # -- color style (red to green)
    r2g <- c("#D61818", "#FFAE63", "#FFFFBD", "#B5E384")
    # -- color style (white to blue)
    w2b <- c("#045A8D", "#2B8CBE", "#74A9CF", "#BDC9E1", "#F1EEF6")
                
    assign("col.sty", get(color))
    calendar.pal <- colorRampPalette((col.sty), space = "Lab")
    def.theme <- lattice.getOption("default.theme")

    cal.theme <- function() {  
      theme <- list(
        strip.background = list(col = "transparent"),
        strip.border = list(col = "transparent"),
        axis.line = list(col="transparent"),
        par.strip.text=list(cex=0.8)
      )
    }

    lattice.options(default.theme = cal.theme)
    yrs <- (unique(caldat$yr))
    nyr <- length(yrs)

    # construct the basic heatmap plot
    cal.plot <- levelplot(
        value~woty*dotw | yr, 
        data=caldat,
        as.table=TRUE,
        aspect=.12,
        layout = c(1, nyr%%7),
        between = list(x=0, y=c(1,1)),
        strip=TRUE,
#        main = paste("Calendar Heat Map of ", varname, sep = ""),
        main = varname,
        scales = list(
            x = list(
                      at= c(seq(2.9, 52, by=4.42)),
                      labels = month.abb,
                      alternating = c(1, rep(0, (nyr-1))),
                      tck=0,
                      cex = 0.7
            ),
            y=list(
                 at = c(0, 1, 2, 3, 4, 5, 6),
                 labels = c(
                     "Sunday"   , "Monday"  ,"Tuesday", 
                     "Wednesday", "Thursday","Friday" , 
                     "Saturday"
                 ),
                 alternating = 1,
                 cex = 0.6,
                 tck=0
            )
        ),
        xlim =c(0.4, 54.6),
        ylim=c(6.6,-0.6),
        cuts= ncolors - 1,
        col.regions = (calendar.pal(ncolors)),
        xlab="" ,
        ylab="",
        colorkey= list(
                col = calendar.pal(ncolors), 
                width = 0.6, 
                height = 0.5
        ),
        subscripts=TRUE
    ) 
    if(opts$svg) {
        cat(paste("Making a SVG plot\n"))
        svg(
          filename  = opts$output,
          width     = opts$width,
          height    = opts$height,
          bg        = "white",
          pointsize = 12
        )
    }
    else {
        cat(paste("Making a PNG plot\n"))
        png(
          filename  = opts$output,
          width     = opts$width,
          height    = opts$height,
          bg        = "white",
          pointsize = 12,
          units     = "in",
          res       = 800
        )
    }
    print(cal.plot)

    panel.locs <- trellis.currentLayout()
    # appropriately place the grid lines on the heatmap
    for (row in 1:nrow(panel.locs)) {
        for (column in 1:ncol(panel.locs))  {
            if (panel.locs[row, column] > 0) {
                trellis.focus(
                        "panel", 
                        row = row, 
                        column = column,
                        highlight = FALSE
                )
                      
                xyetc <- trellis.panelArgs()
                subs  <- caldat[xyetc$subscripts,]
                dates.fsubs <- caldat[caldat$yr == unique(subs$yr),]
                y.start <- dates.fsubs$dotw[1]
                y.end   <- dates.fsubs$dotw[nrow(dates.fsubs)]
                dates.len <- nrow(dates.fsubs)
                adj.start <- dates.fsubs$woty[1]

                for (k in 0:6) {
                    if (k < y.start) {
                        x.start <- adj.start + 0.5
                    } 
                    else {
                        x.start <- adj.start - 0.5
                    }

                    if (k > y.end) {
                        x.finis <- dates.fsubs$woty[nrow(dates.fsubs)] - 0.5
                    } 
                    else {
                        x.finis <- dates.fsubs$woty[nrow(dates.fsubs)] + 0.5
                    }

                    grid.lines(
                        x = c(x.start, x.finis), 
                        y = c(k -0.5, k - 0.5), 
                        default.units = "native", 
                        gp=gpar(col = "grey", lwd = 1)
                    )
                }

                if (adj.start <  2) {
                    grid.lines(
                        x = c( 0.5,  0.5), 
                        y = c(6.5, y.start-0.5), 
                        default.units = "native", 
                        gp=gpar(col = "grey", lwd = 1)
                    )
                    grid.lines(
                        x = c(1.5, 1.5), 
                        y = c(6.5, -0.5), 
                        default.units = "native",
                        gp=gpar(col = "grey", lwd = 1)
                    )
                    grid.lines(
                        x = c(x.finis, x.finis), 
                        y = c(dates.fsubs$dotw[dates.len] -0.5, -0.5), 
                        default.units = "native",
                        gp=gpar(col = "grey", lwd = 1)
                    )

                    if (dates.fsubs$dotw[dates.len] != 6) {
                        grid.lines(
                            x = c(x.finis + 1, x.finis + 1), 
                            y = c(dates.fsubs$dotw[dates.len] -0.5, -0.5), 
                            default.units = "native",
                            gp=gpar(col = "grey", lwd = 1)
                        )
                    }

                    grid.lines(
                        x = c(x.finis, x.finis), 
                        y = c(dates.fsubs$dotw[dates.len] -0.5, -0.5), 
                        default.units = "native",
                        gp=gpar(col = "grey", lwd = 1)
                    )
                }

                for (n in 1:51) {
                    grid.lines(
                        x = c(n + 1.5, n + 1.5), 
                        y = c(-0.5, 6.5), 
                        default.units = "native", 
                        gp=gpar(col = "grey", lwd = 1)
                    )
                }

                x.start <- adj.start - 0.5

                if (y.start > 0) {
                    grid.lines(
                        x = c(x.start, x.start + 1),
                        y = c(y.start - 0.5, y.start -  0.5), 
                        default.units = "native",
                        gp=gpar(col = "black", lwd = 1.75)
                    )

                    grid.lines(
                        x = c(x.start + 1, x.start + 1),
                        y = c(y.start - 0.5 , -0.5), 
                        default.units = "native",
                        gp=gpar(col = "black", lwd = 1.75)
                    )
                    grid.lines(
                        x = c(x.start, x.start),
                        y = c(y.start - 0.5, 6.5), 
                        default.units = "native",
                        gp=gpar(col = "black", lwd = 1.75)
                    )

                    if (y.end < 6  ) {
                        grid.lines(
                            x = c(x.start + 1, x.finis + 1),
                            y = c(-0.5, -0.5), 
                            default.units = "native",
                            gp=gpar(col = "black", lwd = 1.75)
                        )
                        grid.lines(
                            x = c(x.start, x.finis),
                            y = c(6.5, 6.5), 
                            default.units = "native",
                            gp=gpar(col = "black", lwd = 1.75)
                        )
                   } 
                   else {
                        grid.lines(
                            x = c(x.start + 1, x.finis),
                            y = c(-0.5, -0.5), 
                            default.units = "native",
                            gp=gpar(col = "black", lwd = 1.75)
                        )
                        grid.lines(
                            x = c(x.start, x.finis),
                            y = c(6.5, 6.5), 
                            default.units = "native",
                            gp=gpar(col = "black", lwd = 1.75)
                        )
                   }
                } 
                else {
                    grid.lines(
                        x = c(x.start, x.start),
                        y = c( - 0.5, 6.5),
                        default.units = "native",
                        gp=gpar(col = "black", lwd = 1.75)
                    )
                }

                if (y.start == 0 ) {
                    if (y.end < 6  ) {
                        grid.lines(
                            x = c(x.start, x.finis + 1),
                            y = c(-0.5, -0.5), 
                            default.units = "native",
                            gp=gpar(col = "black", lwd = 1.75)
                        )
                        grid.lines(
                            x = c(x.start, x.finis),
                            y = c(6.5, 6.5), 
                            default.units = "native",
                            gp=gpar(col = "black", lwd = 1.75)
                        )
                   } 
                   else {
                      grid.lines(
                          x = c(x.start + 1, x.finis),
                          y = c(-0.5, -0.5), 
                          default.units = "native",
                          gp=gpar(col = "black", lwd = 1.75)
                      )
                      grid.lines(
                          x = c(x.start, x.finis),
                          y = c(6.5, 6.5), 
                          default.units = "native",
                          gp=gpar(col = "black", lwd = 1.75)
                      )
                   }
                }

                for (j in 1:12)  {
                    last.month <- max(dates.fsubs$seq[dates.fsubs$month == j])
                    x.last.m   <- dates.fsubs$woty[last.month] + 0.5
                    y.last.m   <- dates.fsubs$dotw[last.month] + 0.5
                    grid.lines(
                        x = c(x.last.m, x.last.m), 
                        y = c(-0.5, y.last.m),
                        default.units = "native", 
                        gp=gpar(col = "black", lwd = 1.75)
                    )
                    if ((y.last.m) < 6) {
                      grid.lines(
                          x = c(x.last.m, x.last.m - 1), 
                          y = c(y.last.m, y.last.m),
                          default.units = "native", 
                          gp=gpar(col = "black", lwd = 1.75)
                      )
                      grid.lines(
                          x = c(x.last.m - 1, x.last.m - 1),
                          y = c(y.last.m, 6.5),
                          default.units = "native", 
                          gp=gpar(col = "black", lwd = 1.75)
                      )
                    } 
                    else {
                        grid.lines(
                            x = c(x.last.m, x.last.m), 
                            y = c(- 0.5, 6.5),
                            default.units = "native", 
                            gp=gpar(col = "black", lwd = 1.75)
                        )
                    }
                 }
            } # end if panel.locs[row, column] > 0
        } # end column for loop
        trellis.unfocus()
    } # end row for loop 
    lattice.options(default.theme = def.theme);
    return(cal.plot)
}

# The 'main' script itself

option.list <- list(
    make_option( 
        c("-i", "--input"), 
        action  = "store",
        type    = "character",
        default = NULL,
        help    = "a tab separated value data table with a 'Date' column"
    ),

    make_option( 
        c("-o", "--output"), 
        action  = "store",
        type    = "character",
        default = "default-heatmap",
        help    = "name of the output image file"
    ),

    make_option( 
        c("-t", "--title"), 
        action  = "store",
        type    = "character",
        default = "DEFAULT",
        help    = "title of the calendar heatmap plot"
    ),

    make_option(
        c("-s", "--svg"),
        action  = "store_true",
        type    = "logical",
        default = FALSE,
        help    = "for svg output"
    ),

    make_option(
        c("-p", "--png"),
        action  = "store_true",
        type    = "logical",
        default = TRUE,
        help    = "for png output (default case)"
    ),

    make_option( 
        c("-w", "--width"), 
        action  = "store",
        type    = "numeric",
        default = 7,
        help    = "width of heatmap image (in inches)"
    ),

    make_option( 
        c("-l", "--height"), 
        action  = "store",
        type    = "numeric",
        default = 7,
        help    = "height of heatmap image (in inches)"
    )
);

opts <- parse_args(OptionParser(option_list=option.list))

# process the remaining command line options
# args <- commandArgs();
# image.file <- args[1];
 
cat( paste("input:  ", opts$input , "\n") )
cat( paste("output: ", opts$output, "\n") )
cat( paste("title:  ", opts$title , "\n") )

colour <- "r2g"
data   <- read.table(opts$input, header=TRUE, sep="\t")
plot   <- calendarHeat(opts, data$Date, data$count, varname=opts$title, color=colour)

dev.off()

quit(save="no", status=0)
