#include "misc.h"

using namespace std;

int main(int argc, char *argv[])
  {
  if (argc != 5)
    {
    cout << "  re-calculates the activity values in a Gate-compatible activity range file to solve for the\n";
    cout << "  requested total activity (in MBq) in the accompanying phantom atlas.\n";
    cout << "  USAGE: create-activity-dat-for-total-activity-in-phantom-mhd" << " <inputPhantomAtlas.mhd>\n";
    cout << "                                                                     <inputPhantomActivityRange.dat>\n";
    cout << "                                                                     <totalActivityMBq>\n";
    cout << "                                                                     <outputPhantomActivityRange.dat>\n";
    exit(0);
    }
  const string inputPhantomAtlasMhdFilename          = argv[1];
  const string inputPhantomActivityRangeDatFilename  = argv[2];
  const float  outputActivityMBqRequired             = atof(argv[3]);
  const string outputPhantomActivityRangeDatFilename = argv[4];
  // 1. Read mhd phantom image
  mhdHdr3D hdr = ReadMhdHeader3D(inputPhantomAtlasMhdFilename);
  if (hdr.elementType != MET_UCHAR && hdr.elementType != MET_USHORT)
    ECHO_ERROR("Voxelized phantom must be (for the time being) MET_UCHAR or MET_USHORT"); // TODO: include more when needed
  rarray<uint16_t,3> phantomImage(hdr.voxels.z, hdr.voxels.y, hdr.voxels.x);
  ReadMhdImage3D(hdr, &phantomImage);
  // 2. Read phantom activity range (.dat) and calculate total activity
  ifstream      inputFile(inputPhantomActivityRangeDatFilename);
  string        line;
  int           labelStart, labelEnd;
  float         activity;
  vector<int>   labels;
  vector<float> activities;
  while (getline(inputFile, line)) // Read one line at a time into line
    {
    stringstream lineStream(line);
    cout << lineStream.str() << endl;
    if (line.length() < 3 || (line[0] == '#')) continue; // line is too short or starts with '#'
    lineStream >> labelStart;
    lineStream >> labelEnd;
    lineStream >> activity;
    if (labelStart < 0 || labelStart > 65535 || labelEnd < 0 || labelEnd > 65535 || labelStart > labelEnd)
      continue; // line does not start with listing two labels (or label is invalid)
    for (int label = labelStart; label <= labelEnd; label++)
      {
      labels.push_back(label);
      activities.push_back(activity);
      }
    }
  inputFile.close();
  // 3. Calculate phantom atlas histogram
  vector<long int> phantomHistogram(labels.size());
  for (int z = 0; z < hdr.voxels.z; z++)
    for (int y = 0; y < hdr.voxels.y; y++)
      for (int x = 0; x < hdr.voxels.x; x++)
        for (size_t l = 0; l < labels.size(); l++)
          if (phantomImage[z][y][x] == labels[l])
            { phantomHistogram[l]++; break; }
  // 4. Get total activity of input phantom activity range
  double   inputActivityBq = 0.0;
  long int activityVoxels  = 0;
  for (size_t l = 0; l < labels.size(); l++)
    {
    inputActivityBq += activities[l] * phantomHistogram[l];
    activityVoxels  += phantomHistogram[l];
    }
  const double inputActivityMBq = inputActivityBq * 0.000001;
  const double inputActivitymCi = inputActivityMBq * 0.027027027;
  cout << "Total input activity  = " << inputActivityMBq << " MBq (= " << inputActivitymCi << " mCi)\n";
  // 5. Calclate phantom activity range values which yields required total activity
  if (hypot(inputActivityMBq, outputActivityMBqRequired) <= 0.001)
    ECHO_ERROR("hypot(inputActivityMBq, outputActivityMBqRequired) is less than 0.001.");
  double outputActivityMBq, outputActivityMBqCalculated;
  double activityScaling = outputActivityMBqRequired / inputActivityMBq;
  while (true)
    {
    outputActivityMBq = activityScaling * inputActivityMBq / activityVoxels;
    outputActivityMBqCalculated = 0.0;
    for (size_t l = 0; l < labels.size(); l++)
      outputActivityMBqCalculated += activities[l] * outputActivityMBq * phantomHistogram[l];
    if (fabs(outputActivityMBqRequired - outputActivityMBqCalculated) < 0.001)
      break;
    activityScaling = (outputActivityMBqCalculated > outputActivityMBqRequired) ? activityScaling - 1.0 / activityVoxels :
                                                                                  activityScaling + 1.0 / activityVoxels;
    }
  for (size_t l = 0; l < labels.size(); l++)
    activities[l] = activities[l] * outputActivityMBq / 0.000001; // in Bq
  const double outputActivitymCiCalculated = outputActivityMBqCalculated  * 0.027027027;
  cout << "Total output activity = " << outputActivityMBqCalculated << " MBq (= " << outputActivitymCiCalculated << " mCi)\n";
  // 6. Write output activity range file
  ofstream outputFile(outputPhantomActivityRangeDatFilename);
  outputFile << labels.size() << "\n";
  cout       << labels.size() << "\n";
  for (size_t l = 0; l < labels.size(); l++)
    {
    outputFile << fixed << labels[l] << "  " << labels[l] << "  " << activities[l] << "\n";
    cout       << fixed << labels[l] << "  " << labels[l] << "  " << activities[l] << "\n";
    }
  outputFile.close();
  cout << "create-activity-dat-for-total-activity-in-phantom-mhd: written into " << outputPhantomActivityRangeDatFilename << endl;
  return 0;
  }
