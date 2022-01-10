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
		gdss[int(find_chromosome(file_array[i]))] = os.path.basename(file_array[i])
		i += 1
	return gdss

def pair_chromosome_gds_special(file_array, agg_file):
	gdss = dict()
	for i in range(0, len(file_array)):
		gdss[int(find_chromosome(file_array[i]))] = os.path.basename(agg_file)
	return gdss

def wdl_get_segments():
	segfile = open(IIsegments_fileII, 'rb')
	segments = str((segfile.read(64000))).split('\n') # var segments = self[0].contents.split('\n');
	segfile.close()
	segments = segments[1:] # segments = segments.slice(1) # cut off the first line
	return segments

# Prepare GDS output
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

# Prepare segment output
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
if max(output_segments) != len(output_segments): # I don't know if this case is actually problematic but I suspect it will be.
	print("ERROR: Subsequent code relies on output_segments being a list of consecutive integers.")
	print("Debug information: Max of list is %s, len of list is %s" % [max(output_segments), len(output_segments)])
	print("Debug information: List is as follows:\n\t%s" % output_segments)
	exit(1)
segs_output_hack = open("segs_output_debug.txt", "w")
segs_output_hack.writelines(["%s " % thing for thing in output_segments])
segs_output_hack.close()

# Prepare aggregate output
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
# The CWL accounts for there being no aggregate files, as the CWL considers them an optional
# input. We don't need to account for that because the way WDL works means it they are a
# required output of a previous task and a required input of this task. That said, if this
# code is reused for other WDLs, it may need some adjustments right around here.

# Prepare variant include output
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

# Make a bunch of zip files
for i in range(0, max(output_segments)):
	this_zip = ZipFile("dotprod%s.zip" % i+1, "w")
	this_zip.write("%s" % output_gdss[i])
	this_zip.write("%s.integer" % output_segments[i])
	this_zip.write("%s" % output_aggregate_files[i])
	if IIvariant_include_filesII != [""]: # not sure if this is robust
		this_zip.write("%s" % output_variant_files)
	this_zip.close()