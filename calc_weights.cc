/*
  Converts input probabilities read from stdin to weights that are
  written to separate files (streaming, 3 line format):
    Weights
    role weights
    w0 w1 w2 ...

  Input parameter sigma determines the exponential weighting to use
  
*/

#include <assert.h>
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

const std::string tag = "CALW: ";

/////

void
parse_arguments(int argc, char** argv, string& wordFileName, float& sigma, string& outputDir);

float
weight_function(float x)
{
  const float minWeight = 0.0625;    // 1- 15*(x-.5)^4
  if ( x  <= 0.0 ) return minWeight;
  if (1.0 <=  x  ) return minWeight;
  float dev = x - 0.5f;
  float dev2=dev*dev;
  return 1.0f - (15.0f * dev2 * dev2);
}

/////   

int main(int argc, char** argv)
{
  // defaults
  string prepFileName = "prepositions.txt";
  float  sigma        = 10;
  string outputDir    = "auction_data";
  parse_arguments(argc, argv, prepFileName, sigma, outputDir);
  std::clog << "calc_weights --words=" << prepFileName << " --sigma=" << sigma << " --output_dir=" << outputDir << std::endl;
  // build vector of response prepositions 
  std::vector<string> prepositions;
  {
    std::clog << tag << "Reading prepositions from file `" << prepFileName << "'  ";
    std::ifstream prepStream(prepFileName);
    string word;
    while(prepStream >> word)
    { word = trim(word);
      if(word.empty()) break;
      std::clog << word << " ";
      prepositions.push_back(word);
    }
    std::clog << "(" << prepositions.size() << " prepositions)\n";
  }
  // open collection of output files, one for each named 'W_prep.txt'
  std::vector<std::ofstream *> outStreams;
  for (string p:prepositions)
  { string name = outputDir + "/W_" + p;
    std::ofstream *pOS = new std::ofstream(name);
    if(!pOS->good())
    { std::cerr << tag << "Could not open output file named `" << name << "' for writing weights; terminating.\n";
      return -1;
    }
    (*pOS) << "Weights" << std::endl << "role=weights" << std::endl;
    outStreams.push_back(pOS);
  }
  // interprets the file as columns related to the input prepositions
  string theLine;
  bool firstLine = true;
  while (getline(std::cin,theLine))
  { std::vector<float> probs;
    float max = 0.0;
    {
      std::istringstream ss(theLine);
      while(ss.good())
      { float x;
	ss >> x >> std::ws;
	if (max < x) max = x;
	probs.push_back(x);
      }
    }
    assert (probs.size() == prepositions.size());
    if (firstLine)
    { firstLine = false;
      for(size_t i=0; i<probs.size(); ++i)
	(*outStreams[i])         << weight_function(probs[i]);
    }
    else
      for(size_t i=0; i<probs.size(); ++i)
	(*outStreams[i]) << '\t' << weight_function(probs[i]);
  }
  for (size_t i=0; i<outStreams.size(); ++i)
  { (*outStreams[i]) << std::endl;
    outStreams[i]->close();
    delete outStreams[i];
  }
  return 0;
}

//     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments       
void
parse_arguments(int argc, char** argv, string &wordFileName, float &sigma, string &outputDir)
{
  static struct option long_options[] = {
    {"output_dir",  required_argument, 0, 'o'},
    {"sigma"     ,  required_argument, 0, 's'},
    {"words"     ,  required_argument, 0, 'w'},
    {0, 0, 0, 0}                             // terminator
  };
  int key;
  int option_index = 0;
  while (-1 !=(key = getopt_long (argc, argv, "o:s:w:", long_options, &option_index))) // colon means has argument
  {
    switch (key)
    {
    case 'o' :  { outputDir     =  optarg                                 ; break;   }
    case 's' :  { sigma         = read_utils::lexical_cast<float>(optarg) ; break;   }
    case 'w' :  { wordFileName  =  optarg                                 ; break;   }
    default:
      {
	std::cout << "PARSE: Option not recognized; returning.\n";
      }
    } // switch
  } // while
}

