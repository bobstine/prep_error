/*
  Converts input probabilities read from stdin to weights for stdout

  Input parameter sigma determines the exponential weighting to use
  
*/

#include <getopt.h>

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>

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
  float sigma = 10;
  parse_arguments(argc, argv, sigma);
  std::clog << "calc_weights --s=" << sigma << std::endl;

  string theLine;
  while (getline(std::cin,theLine))
  { std::vector<float> probs;
    float max = 0.0;
    {
      std::istringstream ss(theLine);
      float x;
      while(ss >> x)
      { if (max < x) max = x;
	probs.push_back(x);
      }
    }
    std::cout << exp(sigma * (probs[0]-max));
    for(size_t i=1; i<probs.size(); ++i)
      std::cout << '\t' << exp(sigma * (probs[i]-max));
    std::cout << std::endl;
  }
  return 0;
}

//     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments       
void
parse_arguments(int argc, char** argv, float &sigma)
{
  static struct option long_options[] = {
    {"sigma"   ,  required_argument, 0, 's'},
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

