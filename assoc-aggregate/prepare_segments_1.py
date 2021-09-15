#~{segments_file}
IIsegments_fileII = "_test-data-and-truths_/assoc/segments.txt"

# ['~{sep="','" input_gds_files}']
IIinput_gds_filesII = ["_test-data-and-truths_/assoc/1KG_phase3_subset_chr1.gds", "_test-data-and-truths_/gds/a_vcf2gds/1KG_phase3_subset_chr2_butwithadifferentname.gds"]

#['~{sep="','" variant_include_files}']
IIvariant_include_filesII = [""]


def find_chromosome(file):
	chr_array = []
	chrom_num = split_on_chromosome(file)
	if len(chrom_num) == 1:
		acceptable_chrs = [str(integer) for integer in list(range(1,22))]
		acceptable_chrs.extend(["X","Y","M"])
		print(acceptable_chrs)
		print(type(chrom_num))
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
		gdss[int(find_chromosome(file_array[i]))] = file_array[i]
		i += 1
	return gdss

# This part of CWL may be a little hard to understand, but I think I figured it out.
# This region is an output evaulation wherein the output binding is *.txt, even though
# that doesn't actually match the final output of this task.
# Below the outputEval we see loadContents has been set to true. loadContents works like this:
# For each file matched in glob, read up to the first 64 KiB of text from the file 
# and place it in the contents field of the file object for manipulation by outputEval.
# So, the CWL's call for self[0].contents would be the first 64 KiB of the 0th file to match *.txt
# Presumably, that would be segments.txt
# Therefore, we will mimic that in the WDL by just reading segments.txt

def wdl_get_segments():
	segfile = open(IIsegments_fileII, 'rb')
	segments = str((segfile.read(64000))).split('\n') # var segments = self[0].contents.split('\n');
	segfile.close()
	segments = segments[1:] # segments = segments.slice(1) # cut off the first lineF
	return segments

# Prepare GDS output
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
output_gdss = []
gds_segments = wdl_get_segments()
for i in range(0, len(gds_segments)):
	try:
		chr = int(gds_segments[i].split('\t')[0])
	except ValueError: # chr X, Y, M
		chr = gds_segments[i].split('\t')[0]
	if(chr in input_gdss):
		output_gdss.append(input_gdss[chr])
gds_output_hack = open("gds_output_hack.txt", "a")
gds_output_hack.writelines(["%s " % thing for thing in output_gdss])
gds_output_hack.close()

# Prepare segment output
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
output_segments = []
actual_segments = wdl_get_segments()
for i in range(0, len(actual_segments)):
	try:
		chr = int(actual_segments[i].split('\t')[0])
	except ValueError: # chr X, Y, M
		chr = actual_segments[i].split('\t')[0]
	if(chr in input_gdss):
		output_segments.append(i+1)
segs_output_hack = open("segs_output_hack.txt", "a")
segs_output_hack.writelines(["%s " % thing for thing in output_segments])
segs_output_hack.close()

# Prepare aggregate output
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
agg_segments = wdl_get_segments()

# Prepare variant include output
input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
var_segments = wdl_get_segments()
if IIvariant_include_filesII != [""]:
	input_include_files = pair_chromosome_gds(IIvariant_include_filesII)
	output_variant_files = []