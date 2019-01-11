# ------------------------------------------------------------------------------------
# Script by 2016 Alexandre Almeida & Nathalia Menini
# ------------------------------------------------------------------------------------
# Description:
# 	- Download Landsat images and clip them using a shapefile
#	- Output is a .zip containing .tif images for every band
# ------------------------------------------------------------------------------------

import argparse
import ee
import os
import shapefile
import socket
import sys
import time
import wget
import zipfile
from datetime import datetime
import numpy as np

def valid_date(s):
	return datetime.strptime(s, '%Y-%m-%d')
	
# argparse
satsSR_old = ['LT4_SR', 'LT5_SR', 'LE7_SR', 'LC8_SR']
satsSR_new = ['LT04/C01/T1_SR', 'LT05/C01/T1_SR', 'LE07/C01/T1_SR', 'LC08/C01/T1_SR']
satsTOA = ['LT4_L1T_TOA_FMASK', 'LT5_L1T_TOA_FMASK', 'LE7_L1T_TOA_FMASK', 'LC8_L1T_TOA_FMASK']
satsNames = ['4', '5', '7', '8']
satsProd = ['SR_old', 'SR_new', 'TOA']

periodStart = valid_date(periodStart)
periodEnd = valid_date(periodEnd)

shape = shape
shapePath = shapePath
per_start = periodStart
per_end = periodEnd

if(satprod == 'SR_old'):
	sat = satsSR_old[satsNames.index(satellite)]
if(satprod == 'SR_new'):
	sat = satsSR_new[satsNames.index(satellite)]
if(satprod == 'TOA'):
	sat = satsTOA[satsNames.index(satellite)]

# earth engine init
ee.Initialize()

# chdir to shape folder and reads input shape
pathAtual = os.getcwd()
os.chdir(shapePath)
sf = shapefile.Reader(shape)
shapes = sf.shapes()
shapespoints = shapes[0].points
os.chdir(pathAtual)
# os.chdir('..'+os.sep)

# creating a polygon from input shape
tmp = list()
for i in range(0, len(shapespoints)-1):
	tmp.append(list(shapespoints[i]))
bnd = ee.Geometry.Polygon(tmp)

# if the provided shapefile is too complex, use the bounding box instead
# OBS: still not sure why this error happens, the only conclusion so far is
#	that the socket.error is called when the shapefile is too complex e.g.
#	when a lot of small Polygons have been joined into a single Polygon
try:
	bnd.getInfo()
except socket.error:
	bnd = ee.Geometry.Rectangle(shapes[0].bbox)

# entering to the user path
# os.chdir(pathRaster)

# chdir to raster folder
if(not(os.path.exists('raster'))):
	os.mkdir('raster')
os.chdir('raster')

# creating subfolders inside raster
if(not(os.path.exists(shape))):
	os.mkdir(shape)
if(not(os.path.exists(shape+os.sep+sat.replace('/', '-')))):
	os.mkdir(shape+os.sep+sat.replace('/', '-'))
if(not(os.path.exists(shape+os.sep+'SRTMGL1_003'))):
	os.mkdir(shape+os.sep+'SRTMGL1_003')
os.chdir(shape+os.sep+sat.replace('/', '-'))

# function to calculate and add the VI band & cloud cover band (LS 4,5,7)
def getVi(image):
	if(satprod == 'SR_old'):
		qa = image.select(['cfmask']).multiply(1)
		image2 = image.select(['cfmask'],['ignore'])
		# scale existing bands with scaling factor
		scalingFactor = 0.0001
	if(satprod == 'SR_new'):
		qa = image.select(['pixel_qa']).multiply(1)
		# there is an additional band (6) for this product with a 0.1 scaling factor
		b6 = image.select(['B6']).multiply(0.1)
		image2 = image.select(['pixel_qa'],['ignore'])
		image2 = image2.addBands(b6.select([0],['B6']))
		# scale existing bands with scaling factor
		scalingFactor = 0.0001
	if(satprod == 'TOA'):
		qa = image.select(['fmask']).multiply(1)
		image2 = image.select(['fmask'],['ignore'])
		# don't use scaling factor for TOA
		scalingFactor = 1
	b1 = image.select(['B1']).multiply(scalingFactor)
	b2 = image.select(['B2']).multiply(scalingFactor)
	b3 = image.select(['B3']).multiply(scalingFactor)
	b4 = image.select(['B4']).multiply(scalingFactor)
	b5 = image.select(['B5']).multiply(scalingFactor)
	b7 = image.select(['B7']).multiply(scalingFactor)
	evi = image.expression('2.5 * (NIR - R) / (NIR + 6.0*R - 7.5*B + 1)', {'R': b3, 'NIR': b4, 'B': b1}).clamp(-1,1)
	evi2 = image.expression('2.5 * (NIR - R) / (NIR + 2.4*R + 1)', {'R': b3, 'NIR': b4}).clamp(-1,1)
	ndvi = image.normalizedDifference(['B4','B3'])
	image2 = (
		image2
		.addBands(b1.select([0],['B1']))
		.addBands(b2.select([0],['B2']))
		.addBands(b3.select([0],['B3']))
		.addBands(b4.select([0],['B4']))
		.addBands(b5.select([0],['B5']))
		.addBands(b7.select([0],['B7']))
		.addBands(qa.select([0],['qa']))
		.addBands(evi.select([0],['evi']))
		.addBands(evi2.select([0],['evi2']))
		.addBands(ndvi.select([0],['ndvi']))
	)
	return(image2)

# function to calculate and add the VI band & cloud cover band (LS 8)
def getVi8(image):
	if(satprod == 'SR_old'):
		qa = image.select(['cfmask']).multiply(1)
		image2 = image.select(['cfmask'],['ignore'])
		# scale existing bands with scaling factor
		scalingFactor = 0.0001
	if(satprod == 'SR_new'):
		qa = image.select(['pixel_qa']).multiply(1)
		# there are two additional bands (10 & 11) for this product with a 0.1 scaling factor
		b10 = image.select(['B10']).multiply(0.1)
		b11 = image.select(['B11']).multiply(0.1)
		image2 = image.select(['pixel_qa'],['ignore'])
		image2 = (
			image2
			.addBands(b10.select([0],['B10']))
			.addBands(b11.select([0],['B11']))
		)
		# scale existing bands with scaling factor
		scalingFactor = 0.0001
	if(satprod == 'TOA'):
		qa = image.select(['fmask']).multiply(1)
		image2 = image.select(['fmask'],['ignore'])
		# don't use scaling factor for TOA
		scalingFactor = 1
	b1 = image.select(['B1']).multiply(scalingFactor)
	b2 = image.select(['B2']).multiply(scalingFactor)
	b3 = image.select(['B3']).multiply(scalingFactor)
	b4 = image.select(['B4']).multiply(scalingFactor)
	b5 = image.select(['B5']).multiply(scalingFactor)
	b6 = image.select(['B6']).multiply(scalingFactor)
	b7 = image.select(['B7']).multiply(scalingFactor)
	evi = image.expression('2.5 * (NIR - R) / (NIR + 6.0*R - 7.5*B + 1)', {'R': b4, 'NIR': b5, 'B': b2}).clamp(-1,1)
	evi2 = image.expression('2.5 * (NIR - R) / (NIR + 2.4*R + 1)', {'R': b4, 'NIR': b5}).clamp(-1,1)
	ndvi = image.normalizedDifference(['B5','B4'])
	image2 = (
		image2
		.addBands(b1.select([0],['B1']))
		.addBands(b2.select([0],['B2']))
		.addBands(b3.select([0],['B3']))
		.addBands(b4.select([0],['B4']))
		.addBands(b5.select([0],['B5']))
		.addBands(b5.select([0],['B6']))
		.addBands(b7.select([0],['B7']))
		.addBands(qa.select([0],['qa']))
		.addBands(evi.select([0],['evi']))
		.addBands(evi2.select([0],['evi2']))
		.addBands(ndvi.select([0],['ndvi']))
	)
	return(image2)

# define the image collection
if(satellite == '8'):
	imgCol = (
		ee.ImageCollection('LANDSAT/'+sat)
		.filterBounds(bnd)
		.filterDate(per_start, per_end)
		.map(getVi8)
	)
else:
	imgCol = (
		ee.ImageCollection('LANDSAT/'+sat)
		.filterBounds(bnd)
		.filterDate(per_start, per_end)
		.map(getVi)
	)

# quantity of images in imgCol
imgColLen = imgCol.size().getInfo()

# if no image is available, warns the user and exits
if(imgColLen == 0):
	msg = 'No images from '+sat+' match the criteria for the selected period.'
	print('\nNo images from '+sat+' match the criteria for the selected period.\n')
	os.chdir('..'+os.sep)
else:
	# creates a list with all images from imgCol
	imgList = imgCol.toList(imgColLen)

	# creates a list with the name of all images in imgList
	imgListNames = []
	for i in range(0, imgColLen):
		imgListNames += [ee.Image(imgList.get(i)).get('system:index')]
	imgListNames = ee.List(imgListNames)
	imgListNames = imgListNames.getInfo()

	# creates a list with the name of all bands in imgCol
	imgBands = ee.Image(imgList.get(0)).bandNames().getInfo()
	imgBandsListDict = list()
	for i, val in enumerate(imgBands):
		if(str(val) != 'ignore'):
			imgBandsListDict.append({'id': str(val)})

	# start the download task
	dlTimes = []


