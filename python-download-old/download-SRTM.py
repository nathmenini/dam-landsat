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

# also download SRTM Digital Elevation 30m data for the region
os.chdir('..'+os.sep)
os.chdir('SRTMGL1_003')
arq = shape+'_elevation'+'.zip'
cond = os.path.exists(arq)
if(cond):
	print('\nElevation) '+arq+' - Already downloaded!')
else:
	print('\nElevation) '+arq+' - Downloading elevation data...')
	tryNo = 1
	tryMax = 3
	while(not(cond) and tryNo<=tryMax):
		try:
			path = ee.Image('USGS/SRTMGL1_003').clip(bnd).getDownloadUrl({
				'scale': 30,
				'region': str(tmp)
			})
			ignore = wget.download(url=path, bar=None, out=arq)
			cond = os.path.exists(arq)
		except ee.ee_exception.EEException:
			tryNo += 1
			sys.stdout.write('\033[F\033[K')
			print('Elevation) '+arq+' - Connection to the server timed out. Trying to download again... (Try '+str(tryNo)+' of '+str(tryMax)+')')
	sys.stdout.write('\033[F\033[K')
	if(cond):
		print('Elevation) '+arq+' - Download successful.')
	else:
		print('Elevation) '+arq+' - Download failed. Please retry again later.')
msg = 'Images already donwloaded.'
