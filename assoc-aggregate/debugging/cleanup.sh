# run after prepare_segments_1.py
rm *.integer
rm dotprod*.zip
rm gds_output_debug.txt
rm segs_output_debug.txt
rm variant_output_debug.txt
rm -rf temp/
rm -rf varinclude/
# copy test data over
cp ../_test-data-and-truths_/assoc/1KG_phase3_subset_chr1.gds .
cp ../_test-data-and-truths_/gds/a_vcf2gds/1KG_phase3_subset_chr2_butwithadifferentname.gds .
cp ../_test-data-and-truths_/assoc/1KG_phase3_subset_chrX.gds .
cp ../_test-data-and-truths_/assoc/aggregate_list_chr1.RData .
cp ../_test-data-and-truths_/assoc/aggregate_list_chr2.RData .
cp ../_test-data-and-truths_/assoc/aggregate_list_chrX.RData .
cp ../_test-data-and-truths_/assoc/variant_include_chr1.RData .
cp ../_test-data-and-truths_/assoc/variant_include_chr2.RData .
cp ../_test-data-and-truths_/assoc/variant_include_chrX.RData .
cp ../_test-data-and-truths_/assoc/segments.txt .
