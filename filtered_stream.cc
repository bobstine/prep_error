/*
  Reads a 'cat streaming script', a selector file, and a path; simulates the
  cat script after applying the selector to features in the *parent* directory
  which is written to stdout.
*/

#include <getopt.h>

#include <iostream>
#include <fstream>
#include <vector>
#include <assert.h>

#include "string_trim.h"

/////

const bool verbose = true;

const std::string tag = "FLTS: ";

void
parse_arguments(int argc, char** argv,
		std::string& dataDir,
		std::string& catFileName,
		std::string& selectorFileName);

/////   

int main(int argc, char** argv)
{
  using std::string;
 
  string dataDir     ("data_dir/");
  string catFileName ("X.sh");
  string selFileName ("selector");
  
  parse_arguments(argc, argv, dataDir, catFileName, selFileName);
  if ( dataDir[ dataDir.size()-1] != '/')  dataDir += '/';     // add trailing / to paths if needed  
  std::clog << "filtered_stream --data_dir=" << dataDir << " --cat_file=" << catFileName << " --selector=" << selFileName << std::endl;
  
  // build selector: read first line for n, then rest for selector (bools)
  size_t nObsSelected, nObsTotal;
  std::vector<bool> selector;
  {
    std::ifstream selectorFile{selFileName};
    if(!selectorFile.good())
    { std::cerr << tag << "Could not open selector file `" << selFileName << "'; terminating.\n";
      return 1;
    }
    selectorFile >> nObsSelected;
    selectorFile >> nObsTotal;
    if (verbose)
      std::clog << tag << "Reading selector with " << nObsSelected << " selected out of " << nObsTotal << std::endl;
    selector.resize(nObsTotal);
    for(size_t i=0; i<nObsTotal; ++i)
    { int k;
      selectorFile >> k;
      if((k!=0) && (k!=1))
      { std::clog << tag << "Error: Read k=" << k << " where 0/1 binary expected; terminating.\n";
	return -1;
      }
      selector[i] = (k == 1);
    }
    selectorFile.close();
  }
  
  // start streaming data from parent directory using selector file and names from cat file
  std::ifstream catFile{catFileName};
  if(!catFile.good())
  { std::cerr << tag << "Could not open catalog file `" << catFileName << "'; terminating.\n";
    return 1;
  }
  std::cout << nObsSelected << std::endl;       // start stream with number *selected* obs
  while (true)
  { string varName;
    getline(catFile, varName);
    if(varName.size()<5)                        // lines start with 'cat '
      return 0;
    varName = varName.substr(4);                // strip that off
    std::clog << tag << " Writing filtered " << varName << std::endl;
    std::ifstream varFile(dataDir+varName);
    if(!varFile.good())
    { std::cerr << tag << "Could not open data file `" << dataDir+varName << "' for filtering.\n";
      return 2;
    }
    string line;
    getline(varFile,line);                      // echo first two lines of var file (name, attributes)
    std::cout << line << std::endl;
    getline(varFile, line);
    std::cout << line << std::endl;
    for(size_t i=0; i<nObsTotal; ++i)
    { string value;
      varFile >> value;
      if (selector[i]) std::cout << ' ' << value;
    }
    std::cout << std::endl;
    varFile.close();
  }
}

//     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments     parse_arguments       

void
parse_arguments(int argc, char** argv,
		std::string& dataDir,  std::string& catFileName,  std::string& selectorFileName)
{
  static struct option long_options[] = {
    {"cat_file",  required_argument, 0, 'c'},
    {"data_dir",  required_argument, 0, 'd'},
    {"selector",  required_argument, 0, 's'},
    {0, 0, 0, 0}                             // terminator
  };
  int key;
  int option_index = 0;
  while (-1 !=(key = getopt_long (argc, argv, "c:d:s:", long_options, &option_index))) // colon means has argument
  {
    switch (key)
    {
    case 'c' :  { catFileName      = optarg; break;      }
    case 'd' :  { dataDir          = optarg; break;      }
    case 's' :  { selectorFileName = optarg; break;      }
    default:
      {
	std::cout << "PARSE: Option not recognized; returning.\n";
      }
    } // switch
  } // while
}

