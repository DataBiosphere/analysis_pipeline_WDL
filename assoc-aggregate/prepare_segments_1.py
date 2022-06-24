# Notes:
# 1. This needs to be run in Python2
# 2. This expects the input files to be in the workdir

#~{segments_file}
IIsegments_fileII = "_test-data-and-truths_/assoc/segments.txt"

# ['~{sep="','" input_gds_files}']
IIinput_gds_filesII = ["_test-data-and-truths_/assoc/1KG_phase3_subset_chr1.gds", "_test-data-and-truths_/gds/a_vcf2gds/1KG_phase3_subset_chr2_butwithadifferentname.gds", "_test-data-and-truths_/gds/a_vcf2gds/1KG_phase3_subset_chrX.gds"]

#['~{sep="','" variant_include_files}']
IIvariant_include_filesII = [""]

#['~{sep="','" aggregate_files}']
IIaggregate_filesII = ["_test-data-and-truths_/assoc/aggregate_list_chr1.RData", "_test-data-and-truths_/assoc/aggregate_list_chr2.RData", "_test-data-and-truths_/assoc/aggregate_list_chrX_bogus.RData" ]

from zipfile import ZipFile
import os
import shutil
import datetime

def find_chromosome(file):
	chr_array = []
	chrom_num = split_on_chromosome(file)
	if len(chrom_num) == 1:
		acceptable_chrs = [str(integer) for integer in list(range(1,22))]
		acceptable_chrs.extend(["X","Y","M"])
		if chrom_num in acceptable_chrs:
			return chrom_num
		else:
			print("%s appears to be an invalid chromosome number." % chrom_num)
			exit(1)
	elif (unicode(str(chrom_num[1])).isnumeric()):
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
	gdss = dict() # forced to use constructor due to WDL syntax issues
	for i in range(0, len(file_array)): 
		# Key is chr number, value is associated GDS file
		this_chr = find_chromosome(file_array[i])
		if this_chr == "X":
			gdss[23] = os.path.basename(file_array[i])
		elif this_chr == "Y":
			gdss[24] = os.path.basename(file_array[i])
		elif this_chr == "M":
			gdss[25] = os.path.basename(file_array[i])
		else:
			gdss[int(this_chr)] = os.path.basename(file_array[i])
	return gdss

def pair_chromosome_gds_special(file_array, agg_file):
	gdss = dict()
	for i in range(0, len(file_array)):
		gdss[int(find_chromosome(file_array[i]))] = os.path.basename(agg_file)
	return gdss

def wdl_get_segments():
	segfile = open(IIsegments_fileII, 'rb')
	segments = str((segfile.read(64000))).split('\n') # CWL x.contents only gets 64000 bytes
	segfile.close()
	segments = segments[1:] # remove first line
	return segments

######################
# prepare GDS output #
######################
beginning = datetime.datetime.now()
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
output_gdss = []
gds_segments = wdl_get_segments()
for i in range(0, len(gds_segments)): # for(var i=0;i<segments.length;i++){
	try:
		chr = int(gds_segments[i].split('\t')[0])
	except ValueError: # chr X, Y, M
		chr = gds_segments[i].split('\t')[0]
	if(chr in input_gdss):
		output_gdss.append(input_gdss[chr])
gds_output_hack = open("gds_output_debug.txt", "w")
gds_output_hack.writelines(["%s " % thing for thing in output_gdss])
gds_output_hack.close()
print("Info: GDS output prepared in %s minutes" % divmod((datetime.datetime.now()-beginning).total_seconds(), 60)[0])

######################
# prepare seg output #
######################
beginning = datetime.datetime.now()
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
output_segments = []
actual_segments = wdl_get_segments()
for i in range(0, len(actual_segments)): # for(var i=0;i<segments.length;i++){
	try:
		chr = int(actual_segments[i].split('\t')[0])
	except ValueError: # chr X, Y, M
		chr = actual_segments[i].split('\t')[0]
	if(chr in input_gdss):
		seg_num = i+1
		output_segments.append(seg_num)
		output_seg_as_file = open("%s.integer" % seg_num, "w")

# I don't know for sure if this case is actually problematic, but I suspect it will be.
if max(output_segments) != len(output_segments):
	print("ERROR: output_segments needs to be a list of consecutive integers.")
	print("Debug: Max of list: %s. Len of list: %s." % 
		[max(output_segments), len(output_segments)])
	print("Debug: List is as follows:\n\t%s" % output_segments)
	exit(1)

segs_output_hack = open("segs_output_debug.txt", "w")
segs_output_hack.writelines(["%s " % thing for thing in output_segments])
segs_output_hack.close()
print("Info: Segment output prepared in %s minutes" % divmod((datetime.datetime.now()-beginning).total_seconds(), 60)[0])

######################
# prepare agg output #
######################
# The CWL accounts for there being no aggregate files as the CWL considers them an optional
# input. We don't need to account for that because the way WDL works means it they are a
# required output of a previous task and a required input of this task. That said, if this
# code is reused for other WDLs, it may need some adjustments right around here.
beginning = datetime.datetime.now()
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
agg_segments = wdl_get_segments()
if 'chr' in os.path.basename(IIaggregate_filesII[0]):
	input_aggregate_files = pair_chromosome_gds(IIaggregate_filesII)
else:
	input_aggregate_files = pair_chromosome_gds_special(IIinput_gds_filesII, IIaggregate_filesII[0])
output_aggregate_files = []
for i in range(0, len(agg_segments)): # for(var i=0;i<segments.length;i++){
	try: 
		chr = int(agg_segments[i].split('\t')[0])
	except ValueError: # chr X, Y, M
		chr = agg_segments[i].split('\t')[0]
	if(chr in input_aggregate_files):
		output_aggregate_files.append(input_aggregate_files[chr])
	elif (chr in input_gdss):
		output_aggregate_files.append(None)
print("Info: Aggregate output prepared in %s minutes" % divmod((datetime.datetime.now()-beginning).total_seconds(), 60)[0])

#########################
# prepare varinc output #
#########################
beginning = datetime.datetime.now()
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
var_segments = wdl_get_segments()
if IIvariant_include_filesII != [""]:
	input_variant_files = pair_chromosome_gds(IIvariant_include_filesII)
	output_variant_files = []
	for i in range(0, len(var_segments)):
		try:
			chr = int(var_segments[i].split('\t')[0])
		except ValueError: # chr X, Y, M
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
		try:
			chr = int(var_segments[i].split('\t')[0])
		except ValueError: # chr X, Y, M
			chr = var_segments[i].split('\t')[0]
		if(chr in input_gdss):
			null_outputs.append(None)
	output_variant_files = null_outputs
var_output_hack = open("variant_output_debug.txt", "w")
var_output_hack.writelines(["%s " % thing for thing in output_variant_files])
var_output_hack.close()
print("Info: Variant include output prepared in %s minutes" % divmod((datetime.datetime.now()-beginning).total_seconds(), 60)[0])

# We can only consistently tell output files apart by their extension. If var include files 
# and agg files are both outputs, this is problematic, as they both share the RData ext.
# Therefore we put var include files in a subdir.
if IIvariant_include_filesII != [""]:
	os.mkdir("varinclude")
	os.mkdir("temp")

# make a bunch of zip files
print("Preparing zip file outputs...")
for i in range(0, max(output_segments)):
	beginning = datetime.datetime.now()
	plusone = i+1
	this_zip = ZipFile("dotprod%s.zip" % plusone, "w", allowZip64=True)
	this_zip.write("%s" % output_gdss[i])
	this_zip.write("%s.integer" % output_segments[i])
	this_zip.write("%s" % output_aggregate_files[i])
	if IIvariant_include_filesII != [""]:
		print("We detected %s as an output variant file." % output_variant_files[i])
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
			print("Variant include file appears unavailable. Exiting disgracefully...")
			exit(1)
		
		this_zip.write("varinclude/%s" % output_variant_files[i])
	this_zip.close()
	print("Info: Wrote dotprod%s.zip in %s minutes" % (plusone, divmod((datetime.datetime.now()-beginning).total_seconds(), 60)[0]))