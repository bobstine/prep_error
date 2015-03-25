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

level_1 = convert.o embed_random_auction.o embed_auction.o recode_data.o    embed.o build_y_and_selector.o filtered_stream.o
level_2 =
level_3 =

cleanup:
	rm -f prep_events.txt rectangle_data.txt
	rm -f vocabulary.txt embedded_data.txt 	# reversed_eigenwords.en 
	rm -rf auction_data auction_run auction_temp

.PHONY: all test

all: auction_mult


###########################################################################
#
#	Prepositions
#
#		- first convert into column form
#               - probably want to edit tags.txt to pick subset to keep
#
###########################################################################

# nLines = n sentences, nExamples of each preposition
nlines =  1500000 
nExamples = 50000
nEigenDim =   200

# raw_data_file = 7m-4d-Aug30-events.gz
#	This file has a messy parse involving _ and . that confuse R
#	sed -e 's/.*DY //' -e "s/#[-#A-Za-z0-9_?,=!;:\`\_\.\'$$]* / /g" -e 's/ $$//' $< | tr ' ' '\n' | sort | uniq > tag_count.txt
#       Also set the -e -r options when run convert

raw_data_file = subset5M.prepfeats.gz
# raw_data_file = nyt-eng.prepfeats.gz
#	Both files have a clean parse in format varname#word with POS info moved to separate columns
#	       remove the prep     delete all past #
#	sed -e 's/^[^\t]*\t//' -e 's/#[^\t]*//g' $< | tr '\t' '\n' | sort | uniq -c > tag_count.txt

# --- prep_events	leading sentences from Joel
prep_events.txt: ~/data/joel/$(raw_data_file)
	echo Building base file 'prep_events.txt' from $(nlines) sentences.
	gunzip -c $< | head -n $(nlines) > $@

# --- all_tags, tags	stream identifiers, eg POS and WORD.  Only fields tagged as words get embedded
# delete everything *except* tags ...
# sed (removes leading prep) and (removes everything after a #); edit 'all_tags.txt' by hand to select specific tags to leave in tags.txt
all_tags.txt : prep_events.txt Makefile
	rm -f tag_count.txt all_tags.txt
	wc -l $<
	sed -e 's/^[^\t]*\t//' -e 's/#[^\t]*//g' $< | tr '\t' '\n' | sort | uniq -c > tag_count.txt
	sed -e 's/^[ 0-9]*//' tag_count.txt | tail -n +2  > $@
	echo " --- Must edit the file all_tags.txt to obtain a subset of tags to use. --- "

convert: convert.o
	$(GCC) $^ $(LDLIBS) -o  $@

# --- rectangle data	data frame layout of words as a fixed n x p matrix of tokens and values
#                       long tail or weird things labeled as prep, as well as capitalization
rectangle_data.tsv: prep_events.txt tags.txt convert
	./convert --tag_file=tags.txt < prep_events.txt > $@
	head $@

vocabulary.txt: rectangle_data.tsv    # wipe out header line at start, blank at end (mixes in POS tags!... oh well)
	tail -n +2 $< | tr '\t' '\n' | tr '=' '\n' | sort | uniq | tail -n +2 > $@

embed: embed.o
	$(GCC) $^ $(LDLIBS) -o  $@

embed_auction: embed_auction.o
	$(GCC) $^ $(LDLIBS) -o  $@

embed_random_auction: embed_random_auction.o
	$(GCC) $^ $(LDLIBS) -o  $@

recode_data: recode_data.o
	$(GCC) $^ $(LDLIBS) -o  $@

build_y_and_selector: build_y_and_selector.o
	$(GCC) $^ $(LDLIBS) -o  $@

filtered_stream: filtered_stream.o
	$(GCC) $^ $(LDLIBS) -o  $@

# was putting in reverse Zipf order so later, more common words overwrite in dictionary
# but stopped once started distinguising case; also had problems with tac of this file
#	gunzip -c $< | tac > $@
eigenwords.en: ~/data/text/eigenwords/eigenwords.300k.200.en.gz
	rm -f $@
	gunzip -c $< > $@

eigenwords.dean: $(HOME)/data/text/eigenwords/output_200_PHC.txt
	ln -s $< $@

eigenwords = eigenwords.dean

# --- auction data	streaming file layout of data from rectangle, with words embedded
#      decide here if want to downcase letters or leave in mixed cases (downcase option to embed_auction)
hide-auction_data: embed_auction rectangle_data.tsv vocabulary.txt $(eigenwords)
	rm -rf $@
	mkdir auction_data
	./embed_auction --eigen_file=$(eigenwords) --eigen_dim $(nEigenDim) --vocab=vocabulary.txt  -o $@ < rectangle_data.tsv
	chmod +x $@/index.sh

#     random version
rand-auction_data: embed_random_auction rectangle_data.tsv vocabulary.txt
	rm -rf $@
	mkdir $@
	./embed_random_auction --eigen_dim $(nEigenDim) --vocab=vocabulary.txt  -o $@ < rectangle_data.tsv
	chmod +x $@/index.sh

#---------------------------------------------------------------------------------------------------------------
#
# ---  testing auction (fewer cases, features)
#
#      typical build sequence...
#	make auction_test_data
#	make binomial
#	make auction_test
#---------------------------------------------------------------------------------------------------------------
nTestLines = 400000
nTestCases =  50000
nTestEigenDim  = 20

rect_test.tsv: prep_events.txt tags_test.txt convert
	head -n $(nTestLines) prep_events.txt | ./convert --tag_file=tags_test.txt > $@

auction_test_data: embed_auction rect_test.tsv eigenwords.en # vocabulary.txt used but don't want to rebuild
	rm -rf $@
	mkdir -p auction_test_data
	head -n $(nTestCases) rect_test.tsv | ./embed_auction --eigen_file=eigenwords.en --eigen_dim $(nTestEigenDim) --vocab=vocabulary.txt  -o $@
	chmod +x $@/index.sh

theAuction = ../../auctions/auction

.PHONY: run_auction run_mult_auction multinomial binomial

# --- binomial version converted to run in test data by modifying inDir to refer to test directory
#      blank word word0 defaults to all other words for baseline; multinomial case require prepositions.txt (pick words to use)

word0   = 
word1   = to

inTestDir   = auction_test_data

outTestDir  = $(inTestDir)/$(word0)_$(word1)

binomial: build_y_and_selector auction_test_data
	rm -rf $(outTestDir)/; mkdir $(outTestDir)
	tail -n+4 $(inTestDir)/index.sh > $(outTestDir)/catFile    # skip first 3 lines
	./build_y_and_selector --input_dir=$(inTestDir) --output_dir=$(outTestDir) --word0=$(word0) --word1=$(word1)
	cat $(outTestDir)/_n_obs | ../../tools/random_indicator --header --choose 0.8 > $(outTestDir)/_cv_indicator # nobs = # selected

auction_test: filtered_stream # $(outTestDir)/X  # build binomial first *manually*  ; to re-run, rm auction_test
	rm -rf $@
	mkdir $@
	rm -rf $(outTestDir)/Xpipe
	mkfifo $(outTestDir)/Xpipe
	./filtered_stream --cat_file $(outTestDir)/catFile --selector $(outTestDir)/_selector --data_dir $(inTestDir) > $(outTestDir)/Xpipe &
	$(theAuction) -Y$(outTestDir)/Y -C$(outTestDir)/_cv_indicator -X$(outTestDir)/Xpipe -o $@ -r 150 -a 2 -p 3 --calibration_gap=20 --debug=2 --output_x=50


#---------------------------------------------------------------------------------------------------------------
#
# --- multinomial auction
#
#---------------------------------------------------------------------------------------------------------------
#	recode_data puts several Ys with common selection indicator (which may force balanced estimation) into multDir
#	prepositions = of in for to on with that at as from by

# only big 6, nExamples of each
# prepositions = of
prepositions = of in for to on with

inDir = auction_data

multDir = $(inDir)/multinomial

#	recode data builds Y_all.txt for multinomials; since target is phony, run *by hand*
multinomial: recode_data prepositions.txt auction_data
	rm -rf $(multDir); mkdir $(multDir)
	sed "3d" $(inDir)/index.sh > $(multDir)/X.sh
	chmod +x $(multDir)/X.sh
	./recode_data --input_dir=$(inDir) --output_dir=$(multDir) --word_list=prepositions_6.txt

$(multDir)/cv_indicator: $(multDir)/Y_all.txt ../../tools/random_indicator
	cat $(multDir)/n_obs | ../../tools/random_indicator --header --choose=$(nExamples) --balance=$< > $@

resultsPath = auction_temp/
multAuctionRounds = 10000

$(multDir)/X : $(multDir)/X.sh 
	rm -rf $@
	cd $(multDir); ./X.sh > X

$(resultsPath)%: recode_data prepositions.txt $(multDir)/X $(multDir)/cv_indicator # target that runs auction for each prep (% symbol)
	mkdir -p $(resultsPath)
	mkdir -p $@
	$(theAuction) -Y$(multDir)/Y_$* -C$(multDir)/cv_indicator -X$(multDir)/X -r $(multAuctionRounds) -a 2 -p 3 --calibration_gap=20 --debug=1 --output_x=0 --output_path=$@

run_mult_auction: $(addprefix $(resultsPath),$(prepositions))                      # target that runs all prep auctions
	cp $(multDir)/cv_indicator $(resultsPath)/cv_indicator
	cp $(multDir)/Y_all.txt $(resultsPath)/Y_all.txt

###########################################################################
# ---  extract sentences with hi/low entropy  (find in R in auction_analysis.R)

entropy_low.txt: entropy_low.lnum    # -P for perl option to parse \t as tab
	gunzip -c ~/data/joel/subset5M.prepfeats.gz | grep -P '^(for|in|of|on|to|with)\t' | ~/C/tools/get_lines -n -l $< > $@

entropy_high.txt: entropy_high.lnum 
	gunzip -c ~/data/joel/subset5M.prepfeats.gz | grep -P '^(for|in|of|on|to|with)\t' | ~/C/tools/get_lines -n -l $< > $@

###########################################################################
###########################################################################

include ~/C/rules_for_makefiles
