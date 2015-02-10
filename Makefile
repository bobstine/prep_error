include ~/C/c_flags

###########################################################################
#
#   Note on special forms
#      $^ are prereq   $< is first prerequisite  $(word 2,$^) gives the second
#      $@ is target    $* is stem   % -> $*
#
###########################################################################

PROJECT_NAME = prep_error

USES = utils text

OPT = -O3 -std=c++11

level_1 = convert.o embed.o embed_auction.o recode_data.o
level_2 =
level_3 =

cleanup:
	rm -f prep_events.txt tag_count.txt rectangle_data.txt
	rm -f vocabulary.txt embedded_data.txt
	rm -f reversed_eigenwords.en 
	rm -rf auction_data

.PHONY: all

all: auction_data


###########################################################################
#
#	Prepositions
#
#		- first convert into column form
#               - probably want to edit tags.txt to pick subset to keep
#
###########################################################################

nlines = 25000
nEigenDim = 15

# raw_data_file = 7m-4d-Aug30-events.gz
#	This file has a messy parse involving _ and . that confuse R
#	sed -e 's/.*DY //' -e "s/#[-#A-Za-z0-9_?,=!;:\`\_\.\'$$]* / /g" -e 's/ $$//' $< | tr ' ' '\n' | sort | uniq > tag_count.txt
#       Also set the -e -r options when run convert
raw_data_file = nyt-eng.prepfeats.txt.gz

prep_events.txt: ~/data/joel/$(raw_data_file)
	echo Building base file 'prep_events.txt' from $(nlines) sentences.
	gunzip -c $< | head -n $(nlines) > $@

# delete everything *except* tags ...
# sed (removes leading prep) and (removes everything after a #); edit 'all_tags.txt' by hand to select specific tags to leave in tags.txt
all_tags.txt : prep_events.txt Makefile
	rm -f tag_count.txt all_tags.txt
	wc -l $<
	/usr/local/bin/sed -e 's/^[^\t]*\t//' -e 's/#[^\t]*//g' $< | tr '\t' '\n' | sort | uniq -c > tag_count.txt
	/usr/local/bin/sed -e 's/^[ 0-9]*//' tag_count.txt | tail -n +2  > $@

convert: convert.o
	$(GCC) $^ $(LDLIBS) -o  $@

rectangle_data.txt: prep_events.txt tags.txt convert
	./convert --tag_file=tags.txt < prep_events.txt > $@
	head $@

vocabulary.txt: rectangle_data.txt Makefile   # wipe out header line at start, blank at end
	tail -n +2 $< | tr '\t' '\n' | tr '=' '\n' | sort | uniq | tail -n +2 > $@

embed: embed.o
	$(GCC) $^ $(LDLIBS) -o  $@

embed_auction: embed_auction.o
	$(GCC) $^ $(LDLIBS) -o  $@

recode_data: recode_data.o
	$(GCC) $^ $(LDLIBS) -o  $@

# reverse Zipf order so later, more common words overwrite in dictionary
reversed_eigenwords.en: ~/data/text/eigenwords/eigenwords.300k.200.en.gz
	rm -f $@
	gunzip -c $< | tac > $@

embedded_data.txt: rectangle_data.txt vocabulary.txt reversed_eigenwords.en embed
	./embed --eigen_file=reversed_eigenwords.en --eigen_dim $(nEigenDim) --vocab=vocabulary.txt < rectangle_data.txt > $@

auction_data: rectangle_data.txt vocabulary.txt reversed_eigenwords.en embed_auction
	rm -rf $@
	mkdir auction_data
	./embed_auction --eigen_file=reversed_eigenwords.en --eigen_dim $(nEigenDim) --vocab=vocabulary.txt -o $@ < rectangle_data.txt
	chmod +x $@/index.sh

word0  = in
word1  = to
inDir  = auction_data
outDir = $(inDir)/$(word0)_$(word1)

.PHONY: doit

$(outDir): recode_data $(inDir)
	rm -rf $(outDir); mkdir $(outDir)
	sed "3d" $(inDir)/index.sh > $(outDir)/X.sh
	chmod +x $(outDir)/X.sh
	./recode_data --input_dir=$(inDir) --output_dir=$(outDir) --word0=$(word0) --word1=$(word1)
	cat $(outDir)/n_obs | ./random_indicator --header --choose 0.8 > $(outDir)/cv_indicator

doit: $(outDir)

run_auction: # $(outDir)
	# rm -rf $(outDir)/X  #  build manually while debugging
	# mkfifo $(outDir)/X 
	# cat ./$(outDir)/X.sh > $(outDir)/X &
	./auction -Y$(outDir)/Y -C$(outDir)/cv_indicator -X$(outDir)/X -o auction_run -r 100 -a 2 -p 3 -k 10 -c 0


###########################################################################

include ~/C/rules_for_makefiles
