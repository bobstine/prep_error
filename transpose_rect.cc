/*
  Transposes the rectagular data into streaming format with mapped
  variables for those identified with WORD (type = map, domain=words)
  and POS (type = mat, domain=categories).
*/

#include "read_utils.h"
#include <getopt.h>

#include <iostream>
#include <fstream>
#include <sstream>

#include <string>
#include <vector>
#include <map>
#include <set>

#include <iterator>
#include <assert.h>

// write with tabs *between* elements

template <class T>
inline
std::ostream& operator<< (std::ostream& os, std::vector<T> vec)
{
  if(vec.size() > 0)
  { os << vec[0];
    for (size_t i=1; i<vec.size(); ++i) os << "\t" << vec[i];
  }
  return os;
}

template <class F, class C>
bool
found(F item, C const& collection)
{
  for(auto member : collection)
    if (item == member) return true;
  return false;
}

void
parse_arguments(int argc, char** argv, std::string& outputDirectory);

///

const bool verbose = true;

const std::string tag = "TRNS: ";

///

int
main(int argc, char** argv)
{
  using std::string;
  using std::vector;

  // parse arguments after setting default parameters
  string outputDir     ("data_dir/");

  parse_arguments(argc, argv, outputDir);
  if (outputDir[outputDir.size()-1]!='/') outputDir += "/";
  std::clog << "transpose_rect output_dir=" << outputDir << std::endl;
  
  // use header line to distinguish words to embed from categorical to encode
  string responseName;
  vector<string> fieldNames;
  vector<size_t> categoricalFields;
  vector<size_t>   eigenwordFields;
  if (!std::cin.eof())
  { std::cin >> responseName;       
    string headerLine;
    std::getline(std::cin, headerLine);
    std::istringstream ss(headerLine);
    string name;
    while (ss >> name)
      fieldNames.push_back(name);
  }
  size_t nFields = fieldNames.size();
  for(size_t j=0; j<nFields; ++j)
  { string name = fieldNames[j];
    size_t wrd = name.find("_WORD");
    if(string::npos == wrd) // not found
    { if((string::npos != name.find("_POS")) || (string::npos != name.find("_LABEL")))
	categoricalFields.push_back(j);
    } else
    { fieldNames[j] = name.substr(0,wrd);
      eigenwordFields.push_back(j);
    }
  }
  if(verbose)  std::clog << tag << "Found " << nFields << " fields, with "
			 << categoricalFields.size() << " categorical and " << eigenwordFields.size() << " eigenword fields.\n";

  // process input data: read all as text. 
  std::vector<             string>   response;
  std::vector< std::vector<string> > theData(nFields);
  while (!std::cin.eof())
  { string thePrep;
    std::cin >> thePrep;
    if (thePrep.size() == 0) break;
    response.push_back(thePrep);
    for(size_t j=0; j<nFields; ++j)
    { string token;
      std::cin >> token;
      theData[j].push_back(token);
    }
  }
  std::clog << tag << "Read " << response.size() << " cases for response and " << theData[0].size() << " items for first predictor.\n";

  // start to write output here
  std::ofstream shellFile (outputDir + "index.sh");
  if (!shellFile.good())
  { std::cerr << "ERROR: Could not place index file in directory " << outputDir << "; exiting.\n";
    return 0;
  }
  shellFile << "#!/bin/sh"   << std::endl
	    << "cat _n_obs"  << std::endl
	    << "cat " << responseName << std::endl;
  {
    std::ofstream file (outputDir + "_n_obs");
    file << response.size() << std::endl;
  }
  {
    std::ofstream file (outputDir + responseName);
    file << responseName << std::endl;
    file << "role=y" << std::endl;
    file << response << std::endl;
  }
  {
    for(size_t j=0; j<theData.size(); ++j)
    { string field = fieldNames[j];
      shellFile << "cat " << field << std::endl;
      string attributes = "role=x";
      if (found(j, eigenwordFields))
	attributes += ",type=map,domain=words";
      else if (found(j, categoricalFields))
	attributes += ",type=map,domain=categories";
      std::ofstream file(outputDir + field);
      file << field      << std::endl;
      file << attributes << std::endl;
      file << theData[j] << std::endl;      
    }
  }
  return 0;
}


void
parse_arguments(int argc, char** argv, std::string& outputDir)
{
  static struct option long_options[] = {
    {"output_dir", required_argument, 0, 'o'},
    {0, 0, 0, 0}                             // terminator
  };
  int key;
  int option_index = 0;
  while (-1 !=(key = getopt_long (argc, argv, "o:", long_options, &option_index))) // colon means has argument
  {
    switch (key)
    {
    case 'o' :  { outputDir = optarg;     break;      }
    default:
      {
	std::cout << "PARSE: Option not recognized; returning.\n";
      }
    } // switch
  } // while
}

