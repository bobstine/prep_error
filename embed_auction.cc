/*
  Embeds the output of convert.cc into an eigenword representation
  Builds the eigenword dictionary with prior input from a given
  vocabulary.

  Currently assuming no POS in the text

  Input: Rectangular style (tab delimited, with uniform set of columns)
       Y        BGL      BGR   FF   FH         PV
       into     hurry    the   ,    classroom  [blank]
       around   look     the   IN   [blank]    look

  Output: embeds explanatory features into eigenwords in streaming layout
          wanted by auction

	      response
	      cv_indicator
	      eigen_stream_1
	      eigen_stream_2
	       ...
*/

#include "../../utils/read_utils.h"
#include "simple_vocabulary.h"
#include "../eigen_dictionary.h"

#include <getopt.h>
#include <cmath>       // nan

#include <iostream>
#include <fstream>

#include <string>
#include <vector>
#include <map>
#include <set>

#include <iterator>

void
write_bundle(std::string bundleName, std::vector<std::vector<float>> const& coor, std::vector<double> const& sum, int nMissing,
	     std::ofstream &shellFile, std::string outputDir);

void
parse_arguments(int argc, char** argv,
		std::string& vocabularyFileName,
		std::string& eigenwordFileName, int& eigenwordDimension,
		std::string& outputDirectory);

template <class T>
inline
std::ostream& operator<< (std::ostream& os, std::vector<T> vec)
// write with tabs *between* elements
{
  // would be nice, but appends a trailing separator
  //   std::copy(vec.begin(), vec.end(), std::ostream_iterator<T>(os,"\t"));
  if(vec.size() > 0)
  { os << vec[0];
    for (size_t i=1; i<vec.size(); ++i) os << "\t" << vec[i];
  }
  return os;
}

///

const bool verbose = true;

const std::string tag = "EMBD: ";

///

int main(int argc, char** argv)
{
  using std::string;
  using std::vector;

  // parse arguments after setting default parameters
  string vocabFileName ("vocabulary.txt");
  string eigenFileName ("eigenwords.test");
  int    nEigenDim     (0);                 // use all that are found
  string outputDir     ("data_dir/");

  parse_arguments(argc, argv, vocabFileName, eigenFileName, nEigenDim, outputDir);
  if (outputDir[outputDir.size()-1]!='/') outputDir += "/";
  std::clog << "embed_auction --vocab_file=" << vocabFileName << " --eigen_file=" << eigenFileName
	    << " --eigen_dim=" << nEigenDim << " --output_dir=" << outputDir << std::endl;
  
  // read vocabulary
  SimpleVocabulary vocabulary = make_simple_vocabulary(vocabFileName);

  // build eigen dictionary
  EigenDictionary eigenDictionary = make_eigen_dictionary(eigenFileName, nEigenDim, vocabulary);
  compare_dictionary_to_vocabulary(eigenDictionary, vocabulary);

  // process each bundle of eigen coordinates; use header line to name bundles
  string responseName;
  vector<string> bundleNames;
  if (!std::cin.eof())
  { std::cin >> responseName;       
    string headerLine;
    std::getline(std::cin, headerLine);
    std::istringstream ss(headerLine);
    string name;
    while (ss >> name)
      bundleNames.push_back(name);
  }
  const int nBundles = (int) bundleNames.size();
  std::clog << tag << "Reading response and " << nBundles << " predictive words for each case to define modeling data.\n";
  std::vector<             string>   response;
  std::vector< std::vector<string> > theWords(nBundles);
  while (!std::cin.eof())
  { string thePrep;
    std::cin >> thePrep;
    if (thePrep.size() == 0) break;
    response.push_back(thePrep);
    for(int j=0; j<nBundles; ++j)
    { string token;
      std::cin >> token;
      theWords[j].push_back(token);
    }
  }
  std::clog << tag << "Read " << response.size() << " cases for response and " << theWords[0].size() << " words for first predictor.\n";
  std::clog << tag << "Embedding " << bundleNames.size() << " blocks of eigen coordinates.\n";

  // start to write output here
  std::ofstream shellFile (outputDir + "index.sh");
  if (!shellFile.good())
  { std::cerr << "ERROR: Could not place index file in directory " << outputDir << "; exiting.\n";
    return 0;
  }
  shellFile << "#!/bin/sh"   << std::endl
	    << "cat n_obs"  << std::endl
	    << "cat " << responseName << std::endl;
  {
    std::ofstream file (outputDir + "n_obs");
    file << response.size() << std::endl;
  }
  {
    std::ofstream file (outputDir + responseName);
    file << responseName << std::endl;
    file << "role y" << std::endl;
    file << response << std::endl;
  }
  {
    // for each bundle, must read all before writing due to possible missing data
    int n = (int)response.size();
    for(int bundle=0; bundle<nBundles; ++bundle)
    { std::vector<std::vector<float>> eigenCoord (n);
      if (verbose) std::clog << "       Processing eigendata for bundle " << bundle << std::endl;
      int nMissing = 0;
      std::vector<double> sum (nEigenDim, 0.0);
      for (int i=0; i<n; ++i)
      { string token = theWords[bundle][i];
	bool missing = false;
	if (token == "NA")
	{ ++nMissing;
	  missing = true;
	}
	else if (eigenDictionary.count(token) == 0)
	{ // if (verbose) std::clog << "WARNING: Token " << token << " was not found. Treating as OOV.\n";
	  token = "OOV";
	}
	eigenCoord[i] = eigenDictionary[token];
	if (!missing) for(int j=0; j<nEigenDim; ++j) sum[j] += (double) eigenCoord[i][j];
      }
      if (verbose)
	std::clog << tag << "Found " << nMissing << " missing cases for bundle " << bundleNames[bundle] << std::endl;
      write_bundle(bundleNames[bundle], eigenCoord, sum, nMissing, shellFile, outputDir);
    }
  }
}

//     write_bundle     write_bundle     write_bundle     write_bundle     write_bundle     write_bundle     

void
write_bundle(std::string bundleName, std::vector<std::vector<float>> const& coor, std::vector<double> const& sum, int nMissing, 
	     std::ofstream &shellFile, std::string outputDir)      
{
  int n = (int) coor.size();
  int nEigenDim = (int) coor[0].size();

  if (0 < nMissing)  // write missing indicator
  { std::string varName = bundleName + "_" + "Missing";
    shellFile << "cat " << varName << std::endl;
    std::ofstream file(outputDir + varName);
    file << varName << std::endl;
    file << " role x stream missing original_stream" << bundleName << " indicator missing" << std::endl;
    for(int i=0; i<n-1; ++i)
    { if (isnan(coor[i][0]))
	file << 1 << "\t";
      else file << 0 << "\t";
    }
    if (isnan(coor[n-1][0]))
      file << 1;
    else file << 0;
  }
  for(int d=0; d<nEigenDim; ++d)
  { std::string varName = bundleName + "_" + std::to_string(d);
    shellFile << "cat " << varName << std::endl;
    std::ofstream file(outputDir + varName);
    file << varName << std::endl;
    file << "role x stream " << bundleName << std::endl;    // attributes
    if(nMissing == 0)
    { for(int i=0; i<n-1; ++i) file << coor[i][d] << "\t";  // no tab at end
      file << coor[n-1][d];
    } else
    { double mean = sum[d]/(double)(n-nMissing);
      for(int i=0; i<n; ++i)
      { float x = coor[i][d];
	if (isnan(x))
	  file << mean;
	else
	  file << x;
	if (i < n-1) file << "\t";
      }
    }
  }
}


void
parse_arguments(int argc, char** argv,
		std::string& vocabFileName, std::string& eigenFileName, int& eigenDim, std::string& outputDir)
{
  static struct option long_options[] = {
    {"eigen_dim",  required_argument, 0, 'd'},
    {"eigen_file", required_argument, 0, 'e'},
    {"output_dir", required_argument, 0, 'o'},
    {"vocab",      required_argument, 0, 'v'},
    {0, 0, 0, 0}                             // terminator
  };
  int key;
  int option_index = 0;
  while (-1 !=(key = getopt_long (argc, argv, "d:e:o:v:", long_options, &option_index))) // colon means has argument
  {
    // std::cout << "Key " << char(key) << " to option " << long_options[option_index].name << " index=" << option_index << std::endl;
    switch (key)
    {
    case 'd' :  { eigenDim = read_utils::lexical_cast<int>(optarg); break; }
    case 'e' :  { eigenFileName = optarg; break;      }
    case 'o' :  { outputDir = optarg;     break;      }
    case 'v' :  { vocabFileName = optarg; break;      }
    default:
      {
	std::cout << "PARSE: Option not recognized; returning.\n";
      }
    } // switch
  } // while
}

