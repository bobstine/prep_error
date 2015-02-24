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

level_1 = convert.o embed_auction.o recode_data.o    embed.o 
level_2 =
level_3 =

cleanup:
	rm -f prep_events.txt rectangle_data.txt
	rm -f vocabulary.txt embedded_data.txt 	# reversed_eigenwords.en 
	rm -rf auction_data auction_run auction_mult

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

# the file has 720860, but whatever...  I like round numbers
nlines = 200000 
nEigenDim = 30

# raw_data_file = 7m-4d-Aug30-events.gz
#	This file has a messy parse involving _ and . that confuse R
#	sed -e 's/.*DY //' -e "s/#[-#A-Za-z0-9_?,=!;:\`\_\.\'$$]* / /g" -e 's/ $$//' $< | tr ' ' '\n' | sort | uniq > tag_count.txt
#       Also set the -e -r options when run convert

raw_data_file = nyt-eng.prepfeats.gz
#	This file has a cleaner parse in format varname#word and POS info is moved to separate columns
#	       remove the prep     delete all past #
#	sed -e 's/^[^\t]*\t//' -e 's/#[^\t]*//g' $< | tr '\t' '\n' | sort | uniq -c > tag_count.txt

prep_events.txt: ~/data/joel/$(raw_data_file)
	echo Building base file 'prep_events.txt' from $(nlines) sentences.
	gunzip -c $< | head -n $(nlines) > $@

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

rectangle_data.txt: prep_events.txt tags.txt convert
	./convert --tag_file=tags.txt < prep_events.txt > $@
	head $@

vocabulary.txt: rectangle_data.txt Makefile   # wipe out header line at start, blank at end (mixes in POS tags!... oh well)
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

auction_data: rectangle_data.txt vocabulary.txt reversed_eigenwords.en embed_auction
	rm -rf $@
	mkdir auction_data
	./embed_auction --eigen_file=reversed_eigenwords.en --eigen_dim $(nEigenDim) --vocab=vocabulary.txt -o $@ < rectangle_data.txt
	chmod +x $@/index.sh

theAuction = ../../auctions/auction

inDir   = auction_data

.PHONY: run_auction run_mult_auction multinomial binomial

# --- binomial version
#      blank word word0 defaults to all other words for baseline; multinomial case require prepositions.txt (pick words to use)

word0   = 
word1   = to
biDir   = $(inDir)/$(word0)_$(word1)

binomial: recode_data # $(inDir)
	rm -rf $(biDir)/; mkdir $(biDir)
	sed "3d" $(inDir)/index.sh > $(biDir)/X.sh
	chmod +x $(biDir)/X.sh
	./recode_data --input_dir=$(inDir) --output_dir=$(biDir) --word0=$(word0) --word1=$(word1)
	cat $(biDir)/n_obs | ../../tools/random_indicator --header --choose 0.8 > $(biDir)/cv_indicator

run_auction: # $(outDir)
	# rm -rf $(outDir)/X  #  build manually [./X.sh > X in in_to] while debugging... this part is not running so just build X manually
	# mkfifo $(outDir)/X 
	# cat ./$(outDir)/X.sh > $(outDir)/X &
	# mkdir -p auction_run
	$(theAuction) -Y$(outDir)/Y -C$(outDir)/cv_indicator -X$(outDir)/X -o auction_run -r 1000 -a 2 -p 3 --calibration_gap=20 --debug=2 --output_x=40

# --- multinomial version

prepositions = of in for to on with that at as from by

multDir = $(inDir)/multinomial

multinomial: recode_data prepositions.txt auction_data
	rm -rf $(multDir); mkdir $(multDir)
	sed "3d" $(inDir)/index.sh > $(multDir)/X.sh
	chmod +x $(multDir)/X.sh
	./recode_data --input_dir=$(inDir) --output_dir=$(multDir) --word_list=prepositions.txt
	cat $(multDir)/n_obs | ../../tools/random_indicator --header --choose 0.8 > $(multDir)/cv_indicator

multAuctionPath = auction_run_mult/
multAuctionRounds = 1000

$(multDir)/X : $(multDir)/X.sh 
	rm -rf $@
	cd $(multDir); ./X.sh > X

$(multAuctionPath)%: recode_data prepositions.txt $(multDir)/X
	mkdir -p $(multAuctionPath)
	mkdir -p $@
	$(theAuction) -Y$(multDir)/Y_$* -C$(multDir)/cv_indicator -X$(multDir)/X -r $(multAuctionRounds) -a 2 -p 3 --calibration_gap=20 --debug=3 --output_x=0 --output_path=$@

run_mult_auction: $(multAuctionPath)to #  $(addprefix $(multAuctionPath),$(prepositions))

###########################################################################

include ~/C/rules_for_makefiles
