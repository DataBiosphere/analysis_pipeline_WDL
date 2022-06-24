# Author: Ash O'Farrell (aofarrel@ucsc.edu)
#
# Notes:
# 1. This needs to be run in Python2
# 2. This expects the input files to be in the workdir, or else it'll fail when making the zips

#~{segments_file}
IIsegments_fileII = "segments.txt"

# ['~{sep="','" input_gds_files}']
IIinput_gds_filesII = ["1KG_phase3_subset_chr1.gds", "1KG_phase3_subset_chr2_butwithadifferentname.gds", "1KG_phase3_subset_chrX.gds"]

#['~{sep="','" variant_include_files}']
IIvariant_include_filesII = []

#['~{sep="','" aggregate_files}']
IIaggregate_filesII = ["aggregate_list_chr1.RData", "aggregate_list_chr2.RData", "aggregate_list_chrX.RData"]

from zipfile import ZipFile
import os
import shutil
import datetime
import logging

logging.basicConfig(level=logging.DEBUG)

def find_chromosome(file):
	# Corresponds with find_chromosome() in CWL
	chr_array = []
	chrom_num = split_on_chromosome(file)
	if (unicode(str(chrom_num[1])).isnumeric()):
		# two digit number
		chr_array.append(chrom_num[0])
		chr_array.append(chrom_num[1])
	else:
		# one digit number or Y/X/M
		chr_array.append(chrom_num[0])
	return "".join(chr_array)

def split_on_chromosome(file):
	chrom_num = file.split("chr")[1]
	return chrom_num

def pair_chromosome_gds(file_array):
	# Corresponds with pair_chromosome_gds() in CWL
	gdss = dict() # forced to use constructor due to WDL syntax issues
	for i in range(0, len(file_array)): 
		# Key is chr number, value is associated GDS file
		gdss[find_chromosome(file_array[i])] = os.path.basename(file_array[i])
	logging.debug("pair_chromosome_gds returning %s" % gdss)
	return gdss

def pair_chromosome_gds_special(file_array, agg_file):
	# Corresponds with pair_chromosome_gds_special() in CWL
	gdss = dict()
	for i in range(0, len(file_array)):
		gdss[find_chromosome(file_array[i])] = os.path.basename(agg_file)
	logging.debug("pair_chromosome_gds_special returning %s" % gdss)
	return gdss

def wdl_get_segments():
	segfile = open(IIsegments_fileII, 'rb')
	segments = str((segfile.read(64000))).split('\n') # CWL x.contents only gets 64000 bytes
	segfile.close()
	segments = segments[1:] # segments = segments.slice(1) in CWL; removes first line
	return segments

logging.debug("\n######################\n# prepare gds output #\n######################")
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
output_gdss = []
gds_segments = wdl_get_segments()
for i in range(0, len(gds_segments)): # for(var i=0;i<segments.length;i++){
		chr = gds_segments[i].split('\t')[0]
		if(chr in input_gdss):
			output_gdss.append(input_gdss[chr])
logging.debug("GDS output prepared (len: %s)" % len(output_gdss))
logging.debug(["%s " % thing for thing in output_gdss])

logging.debug("\n######################\n# prepare seg output #\n######################")
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
output_segments = []
actual_segments = wdl_get_segments()
for i in range(0, len(actual_segments)): # for(var i=0;i<segments.length;i++){
	chr = actual_segments[i].split('\t')[0]
	if(chr in input_gdss):
		seg_num = i+1
		output_segments.append(int(seg_num))
		output_seg_as_file = open("%s.integer" % seg_num, "w")

# I don't know for sure if this case is actually problematic, but I suspect it will be.
try:
	if max(output_segments) != len(output_segments):
		print("Debug: Max of list: %s. Len of list: %s." % 
			[max(output_segments), len(output_segments)])
		print("Debug: List is as follows:\n\t%s" % output_segments)
		print("ERROR: output_segments needs to be a list of consecutive integers.")
		exit(1)
except TypeError:
	# due to a quirk of the formatting strings above, TypeError gets thrown if chr X/Y/M present
	# this allows us to warn user that our check for nonconsecutives won't work in those cases
	logging.warning("Check for nonconsecutive integer chromosomes is being skipped.")
logging.debug("Segment output prepared (len: %s)" % len(output_segments))
logging.debug(["%i" % thing for thing in output_segments])

logging.debug("\n######################\n# prepare agg output #\n######################")
# The CWL accounts for there being no aggregate files as the CWL considers them an optional
# input. We don't need to account for that because the way WDL works means it they are a
# required output of a previous task and a required input of this task. That said, if this
# code is reused for other WDLs, it may need some adjustments right around here.
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
agg_segments = wdl_get_segments()
if 'chr' in os.path.basename(IIaggregate_filesII[0]):
	input_aggregate_files = pair_chromosome_gds(IIaggregate_filesII)
else:
	input_aggregate_files = pair_chromosome_gds_special(IIinput_gds_filesII, IIaggregate_filesII[0])
output_aggregate_files = []
for i in range(0, len(agg_segments)): # for(var i=0;i<segments.length;i++){
	chr = agg_segments[i].split('\t')[0] # chr = segments[i].split('\t')[0]
	if(chr in input_aggregate_files):
		output_aggregate_files.append(input_aggregate_files[chr])
	elif (chr in input_gdss):
		output_aggregate_files.append(None)
logging.debug("Aggregate output prepared (len: %s)" % len(output_aggregate_files))
logging.debug(["%s " % thing for thing in output_aggregate_files])

logging.debug("\n#########################\n# prepare varinc output #\n##########################")
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
var_segments = wdl_get_segments()
if IIvariant_include_filesII != [""]:
	input_variant_files = pair_chromosome_gds(IIvariant_include_filesII)
	output_variant_files = []
	for i in range(0, len(var_segments)):
		chr = var_segments[i].split('\t')[0]
		if(chr in input_variant_files):
			output_variant_files.append(input_variant_files[chr])
		elif(chr in input_gdss):
			output_variant_files.append(None)
		else:
			pass
else:
	null_outputs = []
	for i in range(0, len(var_segments)):
		chr = var_segments[i].split('\t')[0]
		if(chr in input_gdss):
			null_outputs.append(None)
	output_variant_files = null_outputs
logging.debug("Variant include output prepared (len: %s)" % len(output_variant_files))
logging.debug(["%s " % thing for thing in output_variant_files])

# We can only consistently tell output files apart by their extension. If var include files 
# and agg files are both outputs, this is problematic, as they both share the RData ext.
# Therefore we put var include files in a subdir.
if IIvariant_include_filesII != [""]:
	os.mkdir("varinclude")
	os.mkdir("temp")

# make a bunch of zip files
logging.info("Preparing zip file outputs (this might take a while)...")
for i in range(0, len(output_segments)):
	# If the chromosomes are not consecutive, i != segment number, such as:
	# ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '71', '72', '73', '74']
	beginning = datetime.datetime.now()
	plusone = i+1
	logging.debug("Writing dotprod%s.zip for %s, segment %s" % 
		(plusone, 
		output_gdss[i], 
		output_segments[i]))
	this_zip = ZipFile("dotprod%s.zip" % plusone, "w", allowZip64=True)
	this_zip.write("%s" % output_gdss[i])
	this_zip.write("%s.integer" % output_segments[i])
	this_zip.write("%s" % output_aggregate_files[i])
	if output_variant_files[i] is not None:
		try:
			# Both the CWL and the WDL basically have duplicated output wherein each
			# segment for a given chromosome get the same var include output. If you
			# have six segments that cover chr2, then each segment will get the same
			# var include file for chr2.
			# Because we are handling output with zip files, we need to keep copying
			# the variant include file. The CWL does not need to do this.

			# make a temporary copy in the temp directory
			shutil.copy(output_variant_files[i], "temp/%s" % output_variant_files[i])
			
			# move the not-copy into the varinclude subdirectory
			os.rename(output_variant_files[i], "varinclude/%s" % output_variant_files[i])
			
			# return the copy to the workdir
			shutil.move("temp/%s" % output_variant_files[i], output_variant_files[i])
		
		except OSError:
			# Variant include for this chr has already been taken up and zipped.
			# The earlier copy should stop this but permissions can get iffy on
			# Terra, so we should at least catch the error here for debugging.
			logging.error("Variant include file appears unavailable.")
			exit(1)
		
		this_zip.write("varinclude/%s" % output_variant_files[i])
	this_zip.close()
	logging.info("Wrote dotprod%s.zip in %s minutes" % (plusone, divmod((datetime.datetime.now()-beginning).total_seconds(), 60)[0]))
logging.info("Finished. WDL executor will now attempt to delocalize the outputs. This step might take a long time.")
logging.info("If delocalization is very slow, try running the task again with more disk space (which increases IO speed on Google backends),")
logging.info("or you can try decreasing the number of segments.")