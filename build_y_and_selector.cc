/*
  Converts the base data directory produced by running embed_auction into a new
  'analysis' subdirectory that has a  binary response as well as subsets the data
  to match cases used in the binary response.  Choice of cases are either
	      word pair (as in binary choice problem): set word0 and word1
	      one word vs all others                 : set word1 (rest coded 0)
	      one word vs subset of others           : set wordlist
  In the case of one word vs subset of others (multinomial classification), builds
  k binary response variables, one for each word vs the others in the list

  Note:  The response file creates a variable stream, so is prefixed with n.
  
*/

#include <getopt.h>

#include <iostream>
#include <fstream>
#include <sstream>

#include <string>
#include <vector>
#include <set>
#include <map>
#include <numeric>   // accumulate

#include "string_trim.h"

/////

const bool verbose = true;

const std::string tag = "BYAS: ";


///// first is for two-word binomial comparison, second for the multinomial case; both call third

std::vector<bool>
write_binary_response(std::string word0, std::string word1, std::string inputDir, std::string outputDir);

std::vector<bool>
write_binary_responses( std::set<std::string> const& responseWords, std::string inputDir, std::string outputDir);

void
write_response(std::string word, std::string attributes, std::vector<std::string> const& words, std::string outputDir);


/////

template <class T>
inline
std::ostream& operator<< (std::ostream& os, std::vector<T> vec)   // /t separated
{
  if(vec.size() > 0)
  { os << vec[0];
    for (size_t i=1; i<vec.size(); ++i) os << "\t" << vec[i];
  }
  return os;
}

void
parse_arguments(int argc, char** argv,
		std::string& inputDataDir,
		std::string& word0, std::string& word1, std::string& wordListFileName,
		std::string& outputDataDir);

/////   

int main(int argc, char** argv)
{
  using std::string;
 
  string inputDataDir     ("input_data_dir/");
  string word0            ("");                 // all but word1
  string word1            ("word");
  string wordListFileName ("");                 // ignore word0 and word1 if set
  string outputDataDir    ("output_data_dir/");
  
  parse_arguments(argc, argv, inputDataDir, word0, word1, wordListFileName, outputDataDir);
  if ( inputDataDir[ inputDataDir.size()-1] != '/')  inputDataDir += '/';     // add trailing / to paths if needed
  if (outputDataDir[outputDataDir.size()-1] != '/') outputDataDir += '/';

  bool binaryCase = wordListFileName.empty();
  std::clog << "recode_data --input_dir=" << inputDataDir << " --output_dir=" << outputDataDir;
  if (binaryCase)
    std::clog << " --word0=" << word0 << " --word1=" << word1 << std::endl;
  else
    std::clog << " --word_list=" << wordListFileName << std::endl;
  
  // build set of eligible words if present
  std::set<string> responseWords;      
  if(binaryCase)
  { if(word0==std::string(""))
      std::clog << tag << "Model identifies word `" << word1 <<"' vs all other words.\n";
  }
  else
  { std::clog << tag << "Reading word list from file `" << wordListFileName << "'  ";
    std::ifstream wordStream(wordListFileName);
    while(wordStream.good())
    { string word;
      wordStream >> word;
      word = trim(word);
      if(word.empty()) break;
      std::clog << word << " ";
      responseWords.insert(word);
    }
    std::clog << "(" << responseWords.size() << " prepositions)\n";
  }
  // write responses and n_obs, and build a selector that records which cases match response words
  std::vector<bool> selector;
  if(binaryCase)
    selector = write_binary_response(word0, word1, inputDataDir, outputDataDir);
  else
    selector = write_binary_responses(responseWords, inputDataDir, outputDataDir);
  int nObsSelected = std::accumulate(selector.begin(), selector.end(), 0, [](int tot, bool x) { if(x) return tot+1; else return tot; });
  if (verbose) std::clog << tag << "Writing " << nObsSelected << " cases for word pair " << word0 << "-" << word1
			 << " from input dir " << inputDataDir << std::endl;

  { // write n_obs
    std::ofstream obsFile (outputDataDir + "_n_obs");
    if (!obsFile.good())
    { std::cerr << tag << "Could not open file `_n_obs' that holds number of selected cases.\n";
      return -30;
    }
    obsFile << nObsSelected << std::endl;
  }
  
  { // write the selector to output directory as 3 lines: nobs_selected total_n_obs, then binary on second, chosen line numbers (1 origin) on third
    std::ofstream selectorFile (outputDataDir + "_selector");
    if (!selectorFile.good())
    { std::cerr << tag << "Could not open file `_selector' that identifies cases to use.\n";
      return -20;
    }
    selectorFile << nObsSelected << " " << selector.size() << std::endl;
    for(bool b : selector)
      selectorFile << " " << ((b) ? '1' : '0');
    selectorFile << std::endl;
    for(size_t i=0; i<selector.size(); ++i)
      if(selector[i]) selectorFile << ' ' << i+1;   // 1 origin line indices
    selectorFile << std::endl;
  }
}

//     write_binary_response     write_binary_response     write_binary_response     write_binary_response     

//       converts intput text into 0/1, selecting only appropriate cases identified in selector
//       writes n_obs on first line followed by 3 line auction format.

std::vector<bool>
write_binary_responses(std::set<std::string> const& responseWords, std::string inputDir, std::string outputDir)
{
  using std::string;
  
  std::vector<bool> selector;
  std::ifstream input (inputDir + "Y");
  if (!input.good())
  { std::cerr << "ERROR: Cannot open input file " << inputDir << " Y text to convert to binary.\n";
    return selector;
  }
  std::ofstream output (outputDir + "Y_all.txt");
  if (!output.good())
  { std::cerr << "ERROR: Cannot open output file " << outputDir << " for writing binary responses.\n";
    return selector;
  }
  string yName;
  {
    string line;
    std::getline(input, line);             // names
    std::istringstream ss(line);
    ss >> yName;
  }
  string attributes;
  std::getline(input,attributes);          // attributes
  string word;
  std::vector<string> foundWords;
  while(input.good() && (input >> word))
  { std::set<string>::const_iterator it = responseWords.find(word);
    if (it != responseWords.end())
    { foundWords.push_back(word);
      selector.push_back(true);
    }
    else selector.push_back(false);
  }
  // write the actual text of used responses to file
  std::map<string, size_t> counts;
  for(size_t i=0; i<foundWords.size()-1; ++i)
  { ++counts[foundWords[i]];
    output << foundWords[i] << " ";
  }
  ++counts[foundWords[foundWords.size()-1]];
  output << foundWords[foundWords.size()-1] << std::endl;
  std::clog << tag << "Counts of multinomial key words: ";
  for(auto p : counts) std::clog << "{" << p.first << " " << p.second << "} ";
  std::clog << std::endl;
  // write binary response file for each selected word type: 4 lines, beginning with n_obs (acts as data stream with just one var)
  for(string w : responseWords)
    write_response(w, attributes, foundWords, outputDir);
  return selector;
}

void
write_response(std::string word, std::string attributes, std::vector<std::string> const& words, std::string outputDir)
{
  std::string name = "Y_"+word;
  std::ofstream output (outputDir + name);
  output << words.size() << std::endl;   // file starts with length
  output << name << std::endl;           // then name, attributes, data
  output << attributes << " word0 * word1 " << word << " name " << name << std::endl;
  for(std::string w : words)
  { if (w == word)
      output << "1 ";
    else
      output << "0 ";
  }
  output << std::endl;
}


std::vector<bool>
write_binary_response(std::string word0, std::string word1, std::string inputDir, std::string outputDir)
{
  using std::string;
  
  std::vector<bool> selector;
  std::ifstream input (inputDir + "Y");
  if (!input.good())
    { std::cerr << "ERROR: Cannot open input file " << inputDir << " Y text to convert to binary.\n";
      return selector;
    }
  std::ofstream output (outputDir + "Y");
  if (!output.good())
    { std::cerr << "ERROR: Cannot open output file " << outputDir << " for binary response.\n";
      return selector;
    }
  // read 3-line file, echoing
  string line;
  std::getline(input, line);             // handle names
  std::istringstream ss(line);
  string name;
  ss >> name;
  std::getline(input, line);             // attributes
  std::vector<int> binaryY;
  string word;
  int nObs = 0;
  if (word0.size() == 0) // code all but word1 as 0
    while(input.good() && (input >> word))
    { ++nObs;
      selector.push_back(true);
      if (word == word1)
	binaryY.push_back(1);
      else
	binaryY.push_back(0);
    }
  else // code only two selected words
    while(input.good() && (input >> word))
    { if ((word == word0) || (word == word1))
      { ++nObs;
	selector.push_back(true);
	if (word == word1)
	  binaryY.push_back(1);
	else
	  binaryY.push_back(0);
      }
      else selector.push_back(false);
    }
  // write to output
  output << nObs << std::endl;
  output << "Y" << std::endl;
  output << line << " word0 " << word0 << " word1 " << word1 << " name " << name << std::endl;
  output << binaryY << std::endl;
  return selector;
}

//     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments       

void
parse_arguments(int argc, char** argv,
		std::string& inputDir, std::string& word0, std::string& word1, std::string& wordListFileName, std::string& outputDir)
{
  static struct option long_options[] = {
    {"input_dir",  required_argument, 0, 'i'},
    {"output_dir", required_argument, 0, 'o'},
    {"word_list",  required_argument, 0, 'l'},
    {"word1",      required_argument, 0, 'w'},
    {"word0",      required_argument, 0, 'z'},
    {0, 0, 0, 0}                             // terminator
  };
  int key;
  int option_index = 0;
  while (-1 !=(key = getopt_long (argc, argv, "i:o:l:w:z:", long_options, &option_index))) // colon means has argument
  {
    switch (key)
    {
    case 'i' :  { inputDir         = optarg; break;      }
    case 'o' :  { outputDir        = optarg; break;      }
    case 'l' :  { wordListFileName = optarg; break;      }
    case 'w' :  { word1            = optarg; break;      }
    case 'z' :  { word0            = optarg; break;      }
      //    case 'n' :      { 	nRounds = read_utils::lexical_cast<int>(optarg);	break;      }
    default:
      {
	std::cout << "PARSE: Option not recognized; returning.\n";
      }
    } // switch
  } // while
}

