# Purpose: Clean RGB Images to be used in ML pipeline
# Author: John Francis
# Date Created: Oct. 20, 2022

# Load Dependencies
library(tidyverse)
library(terra)
library(sf)
library(sp)

################################################################################
#                          Data Cleaning Steps                                 #
################################################################################


################################################################################
# 1. Load in/Generate a clean road shapefile for the area of interest 
################################################################################
# read in the roads shapefile, note that TL correspondonds to the area with Cambridge
roads <- read_sf("data/raw/Download_2087242/open-map-local_4707745/TL_Road.shp")

################################################################################
# 2. Identify points along the road corresponding to the decided rules (with IDs)
################################################################################
# need to decide between these
# convert sf to shapefile
shp_multiline <- as(roads, "Spatial")

# regularly sample points along line
shp_points <- sp::spsample(shp_multiline, n=10, type="regular")

sf_linestring <- st_cast(sf_multiline, "LINESTRING")
sampled_points <- st_line_sample(roads, density = 1/100) # one point every 100 m

################################################################################
# 3. Create two square buffers centered around each point
################################################################################


################################################################################
# 4. identify which image(s) are included within each buffer
################################################################################
# whats the total extent of my image files? might want to crop my road file based on this earlier...
shapes <- list(cities, birds)
shape_extents <- lapply(shapes, raster::extent)
do.call(raster::merge, shape_extents)


# drop all of the points that i dont have images

################################################################################
# 5. Crop the image corresponding to buffers for each point
################################################################################

################################################################################
# 6. Combine rasters where necessary if buffer falls in between multiple images (or first create a larger iamge raster thats is then cropped)
################################################################################



################################################################################
# 7. Save cropped images to two separate folders based on size with id in name
################################################################################
