#include "misc.h"

using namespace std;

int main(int argc, char *argv[])
  {
  if (argc != 3) ECHO_ERROR("$ add-float-raw-into-second <in> <inout>\nIf <inout> does not exist, it will be created with 0.0");
  // Read inFile
  ifstream inFile(argv[1], ios::binary);
  if (!inFile) ECHO_ERROR("'%s' does not exist", argv[1]);
  inFile.seekg(0, ios::end);
  const size_t inDataN = inFile.tellg() / sizeof(float);
  inFile.seekg(0, ios::beg);
  vector<float> inData(inDataN);
  inFile.read(reinterpret_cast<char*>(&inData[0]), inDataN * sizeof(float));
  inFile.close();
  // Read oder create inoutFile
  vector<float> inoutData(inDataN);
  ifstream inoutFile(argv[2], ios::binary);
  if (!inoutFile)
    fill(inoutData.begin(), inoutData.end(), 0.0);
  else
    {
    inoutFile.seekg(0, ios::end);
    const size_t inoutDataN = inoutFile.tellg() / sizeof(float);
    if (inoutDataN != inDataN) ECHO_ERROR("inoutDataN != inDataN");
    inoutFile.seekg(0, ios::beg);
    inoutFile.read(reinterpret_cast<char*>(&inoutData[0]), inoutDataN * sizeof(float));
    inoutFile.close();
    }
  // add inData to inoutData
  for(size_t i = 0; i < inoutData.size(); ++i)
    inoutData[i] += inData[i];
  // write outImage
  ofstream outFile(argv[2], ios_base::trunc | ios::binary);
  outFile.write(reinterpret_cast<char*>(&inoutData[0]), inoutData.size()*sizeof(float));
  return 0;
  }
