/*
  Converts input probabilities read from stdin to weights for stdout

  Input parameter sigma determines the exponential weighting to use
  
*/

#include <getopt.h>

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>

#include <set>
#include <map>
#include <vector>

#include "string_trim.h"
#include "read_utils.h"

/////

using std::string;

const std::string tag = "FLTS: ";

/////

void
parse_arguments(int argc, char** argv, float& sigma);

/////   

int main(int argc, char** argv)
{
  // defaults
  size_t nExamples        (10);
  string wordListFileName ("");   
  
  parse_arguments(argc, argv, nExamples, wordListFileName);

  std::clog << "filter_sentences --n=" << nExamples << " --words=" << wordListFileName << std::endl;
  
  // build set of eligible words
  std::set<string> prepositions;
  { std::clog << tag << "Reading word list from file `" << wordListFileName << "'  ";
    std::ifstream wordStream(wordListFileName);
    while(wordStream.good())
    { string word;
      wordStream >> word;
      word = trim(word);
      if(word.empty()) break;
      std::clog << word << " ";
      prepositions.insert(word);
    }
    std::clog << "(" << prepositions.size() << " prepositions)\n";
  }
    
  // hold counts in map
  std::map<string,size_t> prepCounts;
  for(string prep : prepositions)
    prepCounts[prep] = nExamples;
  while(0 < prepositions.size())
  { string theLine;
    std::getline(std::cin, theLine);
    std::istringstream ss(theLine);
    string thePrep;
    ss >> thePrep;
    auto it = prepositions.find(thePrep);
    if(it != prepositions.end())
    { std::cout << theLine << std::endl;
      --prepCounts[thePrep];
      if (0 == prepCounts[thePrep])
	prepositions.erase(it);
    }
  }
}

//     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments       
void
parse_arguments(int argc, char** argv, float &sigma)
{
  static struct option long_options[] = {
    {"sigma"   ,  required_argument, 0, 's'}
    {0, 0, 0, 0}                             // terminator
  };
  int key;
  int option_index = 0;
  while (-1 !=(key = getopt_long (argc, argv, "s:", long_options, &option_index))) // colon means has argument
  {
    switch (key)
    {
    case 's' :  { sigma        = read_utils::lexical_cast<float>(optarg) ; break;   }
    default:
      {
	std::cout << "PARSE: Option not recognized; returning.\n";
      }
    } // switch
  } // while
}

