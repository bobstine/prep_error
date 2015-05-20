/*
  Writes words read from stdin to stdout, followed by k random terms.

  Uses space for delimiter to agree with Paramveer's format.
*/

#include <getopt.h>

#include <iostream>
#include <sstream>
#include <string>
#include "read_utils.h"

#include <cstdlib>

/////

using std::string;

const string tag = "RNEW: ";
const char delim = ' ';

/////

void
parse_arguments(int argc, char** argv, size_t& nDim);

/////   

int main(int argc, char** argv)
{
  // defaults
  size_t nDim        (10);  
  parse_arguments(argc, argv, nDim);
  std::clog << "randomize_eigenwords --dim=" << nDim << std::endl;

  unsigned int seed = 17302;
  std::srand(seed);

  // build set of eligible words
  size_t nLines = 0;
  string restOfLine;
  while(std::cin.good())
  { string wordType;
    std::cin >> wordType;
    if(wordType.empty()) break;
    std::getline(std::cin, restOfLine);  // flush rest of line
    std::cout << wordType;
    for(size_t i=0; i<nDim; ++i)
    { float r = (float) (rand() - RAND_MAX/2);
      r /= (float)(RAND_MAX/2);
      std::cout << delim << r;
    }
    std::cout << std::endl;
    ++nLines;
  }
  std::clog << tag << "Wrote " << nLines << " lines to standard output.\n";
}

//     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments       
void
parse_arguments(int argc, char** argv, size_t& nDim)
{
  static struct option long_options[] = {
    {"dim" ,  required_argument, 0, 'd'},
    {0, 0, 0, 0}                             // terminator
  };
  int key;
  int option_index = 0;
  while (-1 !=(key = getopt_long (argc, argv, "d:", long_options, &option_index))) // colon means has argument
  {
    switch (key)
    {
    case 'd' :  { nDim        = read_utils::lexical_cast<size_t>(optarg) ; break;   }
    default:
      {
	std::cout << "PARSE: Option not recognized; returning.\n";
      }
    } // switch
  } // while
}

