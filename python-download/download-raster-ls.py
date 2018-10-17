# ------------------------------------------------------------------------------------
# Script by 2018 Alexandre Almeida & Nathalia Menini
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

# back to right path
# os.chdir(pathPy)

# count individual download times for each file

start_time = time.time()
arq = imgListNames[i]+'.zip'
cond = os.path.exists(arq)
# verify if the file already exists
if(cond):
	# if yes, prints a message and skip
	print(str(i+1).zfill(len(str(imgColLen)))+' of '+str(imgColLen)+') '+arq+' - Already downloaded!')
	# continue
else:
	# if not, downloads the file
	print(str(i+1).zfill(len(str(imgColLen)))+' of '+str(imgColLen)+') '+arq+' - Downloading...')
	# tries to connect to the server in 'tryMax' times in a row
	# if it fails, gives up and warns user
	tryNo = 1
	tryMax = 3
	while(not(cond) and tryNo<=tryMax):
		try:
			path = ee.Image(imgList.get(i)).clip(bnd).getDownloadUrl({
				'scale': 30,
				'bands': imgBandsListDict,
				'region': str(tmp)
			})
			ignore = wget.download(url=path, bar=None, out=arq)
			cond = os.path.exists(arq)
			if(cond):
				try:
					zipfile.ZipFile(arq)
				except zipfile.BadZipfile:
					cond = False
					os.remove(arq)
		except ee.ee_exception.EEException:
			tryNo += 1
			sys.stdout.write('\033[F\033[K')
			print(str(i+1).zfill(len(str(imgColLen)))+' of '+str(imgColLen)+') '+arq+' - Connection to the server timed out. Trying to download again... (Try '+str(tryNo)+' of '+str(tryMax)+')')
	elapsed_time = time.time() - start_time
	dlTimes.append(elapsed_time)
	sys.stdout.write('\033[F\033[K')
	if(cond):
		print(str(i+1).zfill(len(str(imgColLen)))+' of '+str(imgColLen)+') '+arq+' - Download successful in '+str(int(elapsed_time))+' seconds.')
	else:
		print(str(i+1).zfill(len(str(imgColLen)))+' of '+str(imgColLen)+') '+arq+' - Download failed. Please retry again later. ('+str(int(elapsed_time))+' seconds elapsed)')
