/*
  Embeds the output of convert.cc into an eigenword representation
  Builds the eigenword dictionary with prior input from a given
  vocabulary.  Only embeds fields identified by "xxx_WORD" variable
  name.  Otherwise encodes things like POS as categorical.

  Input: Rectangular style (tab delimited, with uniform set of columns)
       Y        BGL      BGR   FF   FH         PV      
       into     hurry    the   ,    classroom  [blank]
       around   look     the   IN   [blank]    look

  Output: embeds explanatory features into eigenwords in streaming layout
          wanted by auction.  
	      response
	      cv_indicator
	      eigen_stream_1
	      eigen_stream_2
	       ...
*/

#include "read_utils.h"
#include "nan_utils.h"
#include "simple_vocabulary.h"
#include "simple_eigenword_dictionary.h"

#include <getopt.h>

#include <iostream>
#include <fstream>
#include <sstream>

#include <string>
#include <vector>
#include <map>
#include <set>

#include <iterator>
#include <algorithm> // find
#include <assert.h>


void
write_raw_field(std::string fieldName, std::vector<std::string> const& data, std::ofstream &shellStream, std::string outputDirectory);

void
write_categorical_bundle(std::string fieldName, std::vector<std::string> const& data, std::ofstream &shellStream, std::string outputDirectory);

void
write_eigenword_bundle(std::string fieldName, std::vector<std::string> const& data, size_t nEigenDim, Text::SimpleEigenwordDictionary const& eigenDictionary,
		       std::ofstream &shellStream, std::string outputDirectory);


// -----  various templates used to write streaming data

template<class T1, class T2>
void
write_bundle(std::string bundleName, std::string streamName, std::string attributes,
	     std::vector<std::vector<T1>> const& coor, std::vector<T2> const& sum, int nMissing,
	     std::vector<std::string> const& labels, std::string attributeOfLabels,   // var name labels optionally added as attribute if not empty
	     std::ofstream &shellFile, std::string outputDir);


// -----

template <class Item>
bool found(Item x, std::vector<Item> const& c)
{ return c.end() != std::find(c.begin(), c.end(), x); }
      
void
parse_arguments(int argc, char** argv,
		std::string& vocabularyFileName,
		std::string& eigenwordFileName, int& eigenwordDimension, bool &downcase,
		std::string& outputDirectory);


template <class T>
inline
std::ostream& operator<< (std::ostream& os, std::vector<T> vec)
// write with tabs *between* elements
{
  // using stl would be nice, but appends a trailing separator
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
  bool   downcase      (false);             // tokens

  parse_arguments(argc, argv, vocabFileName, eigenFileName, nEigenDim, downcase, outputDir);
  if (outputDir[outputDir.size()-1]!='/') outputDir += "/";
  std::clog << "embed_auction --vocab_file=" << vocabFileName << " --eigen_file=" << eigenFileName
	    << " --eigen_dim=" << nEigenDim << " --output_dir=" << outputDir;
  if (downcase) std::clog << " --downcase";
  std::clog << std::endl;
  
  // read vocabulary
  Text::SimpleVocabulary vocabulary =  Text::make_simple_vocabulary(vocabFileName, downcase);
  if (verbose) std::clog << tag << "Input vocabulary has " << vocabulary.size() << " words.\n";

  // build eigen dictionary
  Text::SimpleEigenwordDictionary eigenDictionary = Text::make_simple_eigenword_dictionary(eigenFileName, nEigenDim, vocabulary, downcase);
  if (verbose) std::clog << tag << "Eigendictionary has " << eigenDictionary.size() << " words.\n";
  Text::compare_dictionary_to_vocabulary(eigenDictionary, vocabulary);

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
    file << "role y" << std::endl;
    file << response << std::endl;
  }
  {
    // for each bundle, must read all before writing due to possible missing data
    for(size_t field=0; field<nFields; ++field)
    { if (found(field,eigenwordFields))
	write_eigenword_bundle(fieldNames[field], theData[field], nEigenDim, eigenDictionary, shellFile, outputDir);
      else if (found(field,categoricalFields))
	write_categorical_bundle(fieldNames[field], theData[field], shellFile, outputDir);
      else
	write_raw_field(fieldNames[field], theData[field], shellFile, outputDir);
    }
  }
}

//     write_raw_field     write_raw_field     write_raw_field     write_raw_field     write_raw_field

template<class T>
void
write_simple_var(std::string varName, std::string attributes, std::vector<T> const& data,
		std::ofstream& shellStream, std::string outputDirectory)
{
  const size_t n = data.size();
  shellStream << "cat " << varName << std::endl;
  std::ofstream file(outputDirectory + varName);
  file << varName    << std::endl;
  file << attributes << std::endl;
  for(size_t i=0; i<n-1; ++i) file << data[i] << "\t";  // no tab at end
  file << data[n-1] << std::endl;
}

void
write_raw_field(std::string fieldName, std::vector<std::string> const& data,
		std::ofstream& shellStream, std::string outputDirectory)
{
  using std::string;
  const size_t n = data.size();
  size_t nMissing = 0;
  double sum = 0.0;
  std::vector<size_t> missing (n);
  std::vector<float>  numbers (n);
  for(size_t i=0; i<n; ++i)
  { if(data[i]=="NA")
    { missing[i] = 1;
      ++nMissing;
      numbers[i] = 0;
    }
    else
    { missing[i]=0;
      sum += (double) numbers[i];
      std::istringstream(data[i]) >> numbers[i];
    }
  }
  if (0<nMissing)
  { float mean = float( (sum/(double)(n-nMissing)) );
    for(size_t i=0; i<n; ++i)
      if(1==missing[i]) numbers[i] = mean;
  }
  const string attributes = "role x stream main";
  write_simple_var(fieldName, attributes, numbers, shellStream, outputDirectory);
  if (0<nMissing)
    write_simple_var(fieldName+"_missing", attributes+" parent "+fieldName, missing, shellStream, outputDirectory);
}		      


//     write_categorical_bundle     write_categorical_bundle     write_categorical_bundle     write_categorical_bundle

void
write_categorical_bundle(std::string fieldName, std::vector<std::string> const& data,
			 std::ofstream& shellStream, std::string outputDirectory)
{
  using std::string;
  // identify the categories present
  std::set<string> categories;
  for(string item : data) categories.insert(item);
  const size_t nCategories = categories.size();
  if (verbose) std::clog << "       Found " << nCategories << " categories for field " << fieldName << std::endl;
  std::vector<std::vector<int>> dummyVars (data.size());  // must be vector of rows to agree with eigen coor
  for (size_t i=0; i<data.size(); ++i)
  { std::vector<int> row(nCategories);
    auto cat = categories.begin();
    for (size_t j=0; j<nCategories; ++j, ++cat)
    { if (*cat == data[i])
      { row[j]=1; break; }
    }
    dummyVars[i] = row;
  }
  std::vector<std::string> labels{categories.size()};
  auto cat = categories.begin();
  for(size_t i=0; i<categories.size(); ++i) labels[i] = *cat++;
  const std::string streamName       = fieldName + "_cat";
  const std::string commonAttributes = " parent " + fieldName;
  write_bundle(fieldName, streamName, commonAttributes, dummyVars, std::vector<float>(0), 0, labels, "category", shellStream, outputDirectory);
}

//     write_eigenword_bundle     write_eigenword_bundle     write_eigenword_bundle     write_eigenword_bundle
void
write_eigenword_bundle(std::string fieldName, std::vector<std::string> const& data, size_t nEigenDim, Text::SimpleEigenwordDictionary const& eigenDictionary,
		       std::ofstream& shellStream, std::string outputDirectory)
{
  using std::string;
  
  std::vector<std::vector<float>> eigenCoord (data.size());   // vector of rows
  if (verbose) std::clog << "       Processing eigendata for field " << fieldName << std::endl;
  int nMissing = 0;
  std::vector<double> sum (nEigenDim, 0.0);
  for (size_t i=0; i<data.size(); ++i)
  { string token = data[i];
    bool missing = false;
    if (token == "NA")                                        // a simple dict assigns nan to 'NA' token
    { ++nMissing;
      missing = true;
    }
    else if (eigenDictionary.count(token) == 0)
      token = "OOV";                                          // if not found, label as OOV
    eigenCoord[i] = eigenDictionary.find(token)->second;  
    if (!missing) for(size_t j=0; j<nEigenDim; ++j) sum[j] += (double) eigenCoord[i][j];
  }
  if (verbose)
    std::clog << tag << "Found " << nMissing << " missing cases for eigenword bundle " << fieldName << std::endl;
  std::vector<std::string> labels{nEigenDim};
  for (size_t i=0; i<nEigenDim; ++i) labels[i] = "ew" + std::to_string(i);
  std::string commonAttributes  ("");
  std::string attributeForLabels("");
  write_bundle(fieldName, fieldName, commonAttributes, eigenCoord, sum, nMissing, labels, attributeForLabels, shellStream, outputDirectory);
}
  
//     write_bundle     write_bundle     write_bundle     write_bundle     write_bundle     write_bundle
//
//  write the several dummy variables to represent a single categorical variable or
//  the bundle of coordinates for an eigenword embedding; encodes missing using mean
//  computed from observed sum
//

template<class T1, class T2>
void
write_bundle(std::string bundleName, std::string streamName, std::string commonAttributePairs,
	     std::vector<std::vector<T1>> const& coor, std::vector<T2> const& sum, int nMissing, 
	     std::vector<std::string> const& labels, std::string attributeOfLabels,
	     std::ofstream &shellFile, std::string outputDir)      
{
  size_t n = coor.size();
  size_t nEigenDim = coor[0].size();
  assert (nEigenDim == labels.size());
  if (0 < nMissing)  // write one missing indicator for the bundle
  { std::string varName = bundleName + "_" + "Missing";
    shellFile << "cat " << varName << std::endl;
    std::ofstream file(outputDir + varName);
    file << varName << std::endl;
    file << " role x stream missing originalstream " << bundleName << " indicator missing" << std::endl;
    for(size_t i=0; i<n-1; ++i)
    { if (IsNanf((float)coor[i][0]))
	file << 1 << "\t";
      else file << 0 << "\t";
    }
    if (IsNanf((float)coor[n-1][0]))
      file << 1 << std::endl;
    else file << 0 << std::endl;
  }
  for(size_t d=0; d<nEigenDim; ++d)
  { std::string varName = bundleName + "_" + labels[d];
    shellFile << "cat " << varName << std::endl;
    std::ofstream file(outputDir + varName);
    file << varName << std::endl;
    file << "role x stream " << streamName << commonAttributePairs;
    if (!attributeOfLabels.empty())
      file << " " << attributeOfLabels << " " << labels[d];
    file << std::endl;
    if(nMissing == 0)
    { for(size_t i=0; i<n-1; ++i) file << coor[i][d] << "\t";  // no tab at end
      file << coor[n-1][d] << std::endl;
    } else
    { double mean = sum[d]/(double)(n-nMissing);
      for(size_t i=0; i<n; ++i)
      { float x = (float)coor[i][d];
	if (IsNan(x))
	  file << mean;
	else
	  file << x;
	if (i < n-1) file << "\t";
      }
      file << std::endl;
    }
  }
}


void
parse_arguments(int argc, char** argv,
		std::string& vocabFileName,
		std::string& eigenFileName, int& eigenDim, bool& downcase,
		std::string& outputDir)
{
  static struct option long_options[] = {
    {"downcase",   no_argument,       0, 'c'},
    {"eigen_dim",  required_argument, 0, 'd'},
    {"eigen_file", required_argument, 0, 'e'},
    {"output_dir", required_argument, 0, 'o'},
    {"vocab",      required_argument, 0, 'v'},
    {0, 0, 0, 0}                             // terminator
  };
  int key;
  int option_index = 0;
  while (-1 !=(key = getopt_long (argc, argv, "cd:e:o:v:", long_options, &option_index))) // colon means has argument
  {
    // std::cout << "Key " << char(key) << " to option " << long_options[option_index].name << " index=" << option_index << std::endl;
    switch (key)
    {
    case 'c' :  { downcase = true;        break;      }
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

