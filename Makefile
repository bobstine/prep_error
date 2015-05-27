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

OPT = -Ofast -mfpmath=sse -msse3 -m64 -march=native

level_1 = convert.o embed_random_auction.o embed_auction.o recode_data.o    embed.o transpose_rect.o filtered_stream.o
level_2 =
level_3 =

cleanup:
	rm -f prep_events.txt rectangle_data.tsv
	rm -f vocabulary.txt embedded_data.txt eigenwords.txt
	rm -rf auction_data auction_temp

.PHONY: all test

all: auction_mult

calc_weights: calc_weights.o
	$(GCC) $^ $(LDLIBS) -o  $@

filter_sentences: filter_sentences.o
	$(GCC) $^ $(LDLIBS) -o  $@

randomize_eigenwords: randomize_eigenwords.o
	$(GCC) $^ $(LDLIBS) -o  $@

convert: convert.o
	$(GCC) $^ $(LDLIBS) -o  $@

embed: embed.o
	$(GCC) $^ $(LDLIBS) -o  $@

embed_auction: embed_auction.o
	$(GCC) $^ $(LDLIBS) -o  $@

embed_random_auction: embed_random_auction.o
	$(GCC) $^ $(LDLIBS) -o  $@

transpose_rect: transpose_rect.o
	$(GCC) $^ $(LDLIBS) -o  $@

recode_data: recode_data.o
	$(GCC) $^ $(LDLIBS) -o  $@

encode_response: encode_response.o
	$(GCC) $^ $(LDLIBS) -o  $@

build_y_and_selector: build_y_and_selector.o
	$(GCC) $^ $(LDLIBS) -o  $@

filtered_stream: filtered_stream.o
	$(GCC) $^ $(LDLIBS) -o  $@


###########################################################################
#
#	Prepositions
#		- first convert into rectangular column form
#               - edit tags.txt to pick subset of terms to keep
#
###########################################################################

# nSentencesEach, later split into train and test

nSentencesEach = 100010

# raw_data_file = 7m-4d-Aug30-events.gz
#	This file has a messy parse involving _ and . that confuse R
#	sed -e 's/.*DY //' -e "s/#[-#A-Za-z0-9_?,=!;:\`\_\.\'$$]* / /g" -e 's/ $$//' $< | tr ' ' '\n' | sort | uniq > tag_count.txt
#       Also set the -e -r options when run convert
# raw_data_file = nyt-eng.prepfeats.gz
#	Both files have a clean parse in format varname#word with POS info moved to separate columns
#	       remove the prep     delete all past #
#	sed -e 's/^[^\t]*\t//' -e 's/#[^\t]*//g' $< | tr '\t' '\n' | sort | uniq -c > tag_count.txt

raw_data_file = subset5M.prepfeats.gz

# --- prep_events	extract nLines examples of the chosen prepositions
#	gunzip -c $< | grep -P '^(for|in|of|on|to|with)\t' | head -n $(nLines) > $@

prep_events.txt: ~/data/joel/$(raw_data_file) filter_sentences
	echo Building base file 'prep_events.txt' from $(nSentencesEach) for each preposition.
	gunzip -c $< | ./filter_sentences -n $(nSentencesEach) --wordlist "prepositions_6.txt" > $@
	wc -l $@

# --- all_tags, tags	stream identifiers, eg POS and WORD.  Only fields tagged as words get embedded
#        deletes everything *except* tags: sed (removes leading prep) and (removes everything after a #)
#        edit 'all_tags.txt' by hand specific tags; leave these in tags.txt

all_tags.txt : prep_events.txt Makefile
	rm -f tag_count.txt all_tags.txt
	wc -l $<
	sed -e 's/^[^\t]*\t//' -e 's/#[^\t]*//g' $< | tr '\t' '\n' | sort | uniq -c > tag_count.txt
	sed -e 's/^[ 0-9]*//' tag_count.txt | tail -n +2  > $@
	echo " --- Must edit the file all_tags.txt to obtain a subset of tags to use. --- "

# --- rectangle data	data frame layout of words as a fixed n x p matrix of tokens and values
#                       long tail or weird things labeled as prep, as well as capitalization

rectangle_data.tsv: prep_events.txt tags.txt convert
	./convert --tag_file=tags.txt < prep_events.txt > $@

vocabulary.txt: rectangle_data.tsv    # wipe out header line at start, blank at end (mixes in POS tags!... oh well)
	tail -n +2 $< | tr '\t' '\n' | tr '=' '\n' | sort | uniq | tail -n +2 > $@
	wc -l $@

# was putting in reverse Zipf order so later, more common words overwrite in dictionary
# but stopped once started distinguising case; also had problems with tac of this file
#	gunzip -c $< | tac > $@

eigenwords.en: ~/data/text/eigenwords/eigenwords.300k.200.en.gz
	rm -f $@
	gunzip -c $< > $@

eigenwords.rand: eigenwords.en randomize_eigenwords 
	cat $< | ./randomize_eigenwords --dim=200 > $@

eigenwords.dean: $(HOME)/data/text/eigenwords/output_200_PHC.txt  # replace tab with space
	sed -e "s/[\t]\+/ /g" $< > $@ 

nEigenDim    = 200   # careful! need to manually sync
nEigenCutDim = 201
eigenwords.txt: eigenwords.en
	cut -f1-$(nEigenCutDim) -d' ' $< > $@

# --- auction data	directory with streaming data files for features from rectangle

auction_data: transpose_rect rectangle_data.tsv vocabulary.txt eigenwords.txt
	rm -rf $@
	mkdir $@
	./transpose_rect -o $@ < rectangle_data.tsv
	chmod +x $@/index.sh

#     old version that split out before reading into auction
#     not fast, but not glacial either (20 mins for 1M cases with +-3 ewords and 200 dims)
hide1-auction_data: embed_auction rectangle_data.tsv vocabulary.txt $(eigenwords)
	rm -rf $@
	mkdir auction_data
	./embed_auction --eigen_file=$(eigenwords) --eigen_dim $(nEigenDim) --vocab=vocabulary.txt  -o $@ < rectangle_data.tsv
	chmod +x $@/index.sh

#     random version
hide2-auction_data: embed_random_auction rectangle_data.tsv vocabulary.txt
	rm -rf $@
	mkdir $@
	./embed_random_auction --eigen_dim $(nEigenDim) --vocab=vocabulary.txt  -o $@ < rectangle_data.tsv
	chmod +x $@/index.sh

#---------------------------------------------------------------------------------------------------------------
#
# --- multinomial auction
#
#---------------------------------------------------------------------------------------------------------------
#	recode_data puts several Ys with common selection indicator (which may force balanced estimation) into multDir
#	prepositions = of in for to on with that at as from by

# only big 6, train iwth nExamples of each 
prepositions = of in for to on with
# prepositions = of
nExamples = 50000

auctionOptions = --rounds=40000 --alpha=2 --protection=3 --cal_gap=25 --debug=0
textOptions = -Deigenwords.txt --dict_dim=$(nEigenDim) -Vvocabulary.txt --min_cat_size=2000

inPath = auction_data/
outPath = auction_temp/

#       join most-recent model predictions in common file  HERE
$(outPath)fit_%.txt: 
	cut -f2 $(outPath)$*/model_data.txt | tail -n +2 | cat "fit_$*" - > $@

$(outPath)fits_all.txt: $(addsuffix .txt,$(addprefix $(outPath)fit_,$(prepositions)))
	paste $^ > $@


#	build Y_all.txt and multinomial indicators Y_xxx
$(inPath)Y_all.txt: encode_response prepositions.txt
	./encode_response --input_dir=$(inPath) --output_dir=$(inPath) --word_list=prepositions_6.txt

$(inPath)cv_indicator: $(inPath)Y_all.txt ../../tools/random_indicator
	cat $(inPath)_n_obs | ../../tools/random_indicator --header --choose=$(nExamples) --balance=$< > $@

$(inPath)X.sh: $(inPath)index.sh
	rm -rf $@
	sed "3d" $(inPath)index.sh > $@
	chmod +x $@

$(outPath)%: eigenwords.txt $(inPath)Y_all.txt $(inPath)X.sh $(inPath)cv_indicator # target that runs auction for each prep (% symbol)
	mkdir -p $(outPath)
	mkdir -p $@
	mkfifo $(inPath)Xpipe_$*
	(cd $(inPath); ./X.sh > Xpipe_$*) &
	./nlp_auction -Y$(inPath)Y_$* -C$(inPath)cv_indicator -X$(inPath)Xpipe_$* $(textOptions) $(auctionOptions) --output_x=0 --output_path=$@
	rm -rf $(inPath)Xpipe_$*

run_auction: $(addprefix $(outPath),$(prepositions))                      # target that runs all prep auctions
	cp $(inPath)cv_indicator $(outPath)cv_indicator
	cp $(inPath)Y_all.txt $(outPath)Y_all.txt

# use the following to avoid the pipe when debugging (and comment last line in outPath)
# 	rm -rf $(inPath)Xpipe_$*          # avoid pipe (and comment last line)
#	cd $(inPath); ./X.sh > Xpipe_$*

###########################################################################
# ---  extract sentences with hi/low entropy  (find in R in auction_analysis

entropy_low.txt: entropy_low.lnum    # -P for perl option to parse \t as tab
	gunzip -c ~/data/joel/subset5M.prepfeats.gz | grep -P '^(for|in|of|on|to|with)\t' | ~/C/tools/get_lines -n -l $< > $@

entropy_high.txt: entropy_high.lnum 
	gunzip -c ~/data/joel/subset5M.prepfeats.gz | grep -P '^(for|in|of|on|to|with)\t' | ~/C/tools/get_lines -n -l $< > $@

###########################################################################

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

theAuction = ../../auctions/nlp_auction

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

###########################################################################

include ~/C/rules_for_makefiles
