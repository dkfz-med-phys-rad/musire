#include "misc.h"

using namespace std;

int main(int argc, char *argv[])
  {
  if (argc != 3)
    {
    cerr << " This program generates a 3D density mhd for a 3D atlas mhd which is accompanied by a "
         << " Gate-compatible material range list .dat file as well as a gate-materials.db file\n";
    cerr << "  USAGE: create-density-mhd-from-phantom-mhd <phantomAtlasImage.mhd>\n" 
         << "                                             <phantomMaterialRange.dat>\n";
         //<< "                                           <gate-materials.db>\n";
    exit(0);
    }
  const filesystem::path phantomMhdImageFilename = argv[1];
  const filesystem::path phantomMaterialRangeFilename = argv[2];
  //const filesystem::path gateMaterialsFilename = argv[3];
  // 1. Read mhd phantom image
  mhdHdr3D hdr = ReadMhdHeader3D(phantomMhdImageFilename);
  if (hdr.elementType != MET_UCHAR && hdr.elementType != MET_USHORT)
    ECHO_ERROR("Voxelized phantom must be (for the time being) MET_UCHAR or MET_USHORT"); // TODO: include more if needed
  rarray<uint16_t,3> phantomImage(hdr.voxels.z, hdr.voxels.y, hdr.voxels.x);
  ReadMhdImage3D(hdr, &phantomImage);
  // 2. Read phantom material range (.dat) and assign density
  ifstream      inputFile(phantomMaterialRangeFilename);
  string        line;
  int           labelStart, labelEnd;
  float         density/*mg/cm3*/;
  string        materialStr;
  vector<int>   labels;
  vector<float> densities;
  while (getline(inputFile, line))
    {
    stringstream lineStream(line);
    if (line.length() < 3 || (line[0] == '#')) continue; // line is too short or starts with '#'
    lineStream >> labelStart;
    lineStream >> labelEnd;
    lineStream >> materialStr;
    //if (labelStart < 0 || labelStart > 255 || labelEnd < 0 || labelEnd > 255 || labelStart > labelEnd)
    //  continue; // line does not start with listing two labels (or label is invalid)
    // in the following, Gate materials are read from range files and matched against gate-materials.db
    // that was last checkt 2020-10-07; TODO: read from gate-materials.db directly
         if (materialStr.compare("Vacuum") == 0)        density = 0.000001;
    else if (materialStr.compare("Air") == 0)           density = 0.00129;
    else if (materialStr.compare("Lung") == 0)          density = 0.26;
    else if (materialStr.compare("LungMoby") == 0)      density = 0.3;
    else if (materialStr.compare("Adipose") == 0)       density = 0.92;
    else if (materialStr.compare("Epidermis") == 0)     density = 0.92;
    else if (materialStr.compare("Hypodermis") == 0)    density = 0.92;
    else if (materialStr.compare("Polyethylene") == 0)  density = 0.96;
    else if (materialStr.compare("Water") == 0)         density = 1.0;
    else if (materialStr.compare("FITC") == 0)          density = 1.0;
    else if (materialStr.compare("RhB") == 0)           density = 1.0;
    else if (materialStr.compare("ICG") == 0)           density = 1.0;
    else if (materialStr.compare("Body") == 0)          density = 1.0;
    else if (materialStr.compare("Epoxy") == 0)         density = 1.0;
    else if (materialStr.compare("Breast") == 0)        density = 1.02;
    else if (materialStr.compare("Intestine") == 0)     density = 1.03;
    else if (materialStr.compare("Lymph") == 0)         density = 1.03;
    else if (materialStr.compare("Scinti-C9H10") == 0)  density = 1.032;
    else if (materialStr.compare("Pancreas") == 0)      density = 1.04;
    else if (materialStr.compare("Brain") == 0)         density = 1.04;
    else if (materialStr.compare("Testis") == 0)        density = 1.04;
    else if (materialStr.compare("Heart") == 0)         density = 1.05;
    else if (materialStr.compare("Tumor") == 0)         density = 1.05;
    else if (materialStr.compare("Kidney") == 0)        density = 1.05;
    else if (materialStr.compare("Muscle") == 0)        density = 1.05;
    else if (materialStr.compare("Biomimic") == 0)      density = 1.05;
    else if (materialStr.compare("Blood") == 0)         density = 1.06;
    else if (materialStr.compare("Liver") == 0)         density = 1.06;
    else if (materialStr.compare("Spleen") == 0)        density = 1.06;
    else if (materialStr.compare("Cartilage") == 0)     density = 1.1;
    else if (materialStr.compare("Nylon") == 0)         density = 1.15;
    else if (materialStr.compare("Plastic") == 0)       density = 1.18;
    else if (materialStr.compare("Plexiglass") == 0)    density = 1.19;
    else if (materialStr.compare("PMMA") == 0)          density = 1.195;
    else if (materialStr.compare("SpineBone") == 0)     density = 1.42;
    else if (materialStr.compare("Skull") == 0)         density = 1.61;
    else if (materialStr.compare("PVC") == 0)           density = 1.65;
    else if (materialStr.compare("RibBone") == 0)       density = 1.92;
    else if (materialStr.compare("PTFE") == 0)          density = 2.18;
    else if (materialStr.compare("Quartz") == 0)        density = 2.2;
    else if (materialStr.compare("Silicon") == 0)       density = 2.33;
    else if (materialStr.compare("Glass") == 0)         density = 2.5;
    else if (materialStr.compare("Aluminium") == 0)     density = 2.7;
    else if (materialStr.compare("NaI") == 0)           density = 3.67;
    else if (materialStr.compare("Yttrium") == 0)       density = 4.47;
    else if (materialStr.compare("Germanium") == 0)     density = 5.32;
    else if (materialStr.compare("LYSO") == 0)          density = 5.37;
    else if (materialStr.compare("YAP") == 0)           density = 5.55;
    else if (materialStr.compare("CZT") == 0)           density = 5.68;
    else if (materialStr.compare("GSO") == 0)           density = 6.7;
    else if (materialStr.compare("LuYAP-70") == 0)      density = 7.1;
    else if (materialStr.compare("BGO") == 0)           density = 7.13;
    else if (materialStr.compare("LYSOalbira") == 0)    density = 7.2525;
    else if (materialStr.compare("LSO") == 0)           density = 7.4;
    else if (materialStr.compare("LuYAP-80") == 0)      density = 7.5;
    else if (materialStr.compare("Gadolinium") == 0)    density = 7.9;
    else if (materialStr.compare("SS304") == 0)         density = 7.92;
    else if (materialStr.compare("PWO") == 0)           density = 8.28;
    else if (materialStr.compare("LuAP") == 0)          density = 8.34;
    else if (materialStr.compare("Copper") == 0)        density = 8.96;
    else if (materialStr.compare("Bismuth") == 0)       density = 9.75;
    else if (materialStr.compare("Lutetium") == 0)      density = 9.84;
    else if (materialStr.compare("Lead") == 0)          density = 11.4;
    else if (materialStr.compare("Carbide") == 0)       density = 15.8;
    else if (materialStr.compare("Uranium") == 0)       density = 18.9;
    else if (materialStr.compare("Tungsten") == 0)      density = 19.3;
    else ECHO_ERROR("Material %s not (yet) implemented!", materialStr.c_str());
    for (long int label = labelStart; label <= labelEnd; label++)
      {
      labels.push_back(label);
      densities.push_back(density);
      }
    }
  float *densityDistributionPtr;
  densityDistributionPtr = new float[hdr.voxels.x * hdr.voxels.y * hdr.voxels.z];
  rarray<float,3> densityDistribution;
  densityDistribution = rarray<float,3>(densityDistributionPtr, hdr.voxels.z, hdr.voxels.y, hdr.voxels.x);
  for (int z = 0; z < hdr.voxels.z; z++)
    for (int y = 0; y < hdr.voxels.y; y++)
      for (int x = 0; x < hdr.voxels.x; x++)
        {
        size_t l;
        for (l = 0; l < labels.size(); l++)
          if (phantomImage[z][y][x] == labels[l])
            { densityDistribution[z][y][x] = densities[l]; break; }
        if (l == labels.size())
          ECHO_ERROR("There is a label (%d) in the atlas image at [%d][%d][%d] that is not listed in the range file!",
                     phantomImage[z][y][x], z, y, x);
        }
  // 3. Write density mhd image
  filesystem::path densityMhdImageFilename = phantomMhdImageFilename.stem();
  densityMhdImageFilename += "-density.mhd";
  filesystem::path densityRawImageFilename = densityMhdImageFilename.stem();
  densityRawImageFilename += ".raw";
  std::ofstream ofFile;
  ofFile.open(densityMhdImageFilename);
  if (!ofFile) EchoExit("Could not open '" + densityMhdImageFilename.string() + "' for writing");
  ofFile << "ObjectType = Image\n";
  ofFile << "BinaryData = True\n";
  ofFile << "BinaryDataByteOrderMSB = False\n";
  ofFile << "CompressedData = False\n";
  ofFile << "Modality = MET_MOD_CT\n";
  ofFile << "NDims = 3\n";
  ofFile << "DimSize = " << hdr.voxels.x << " " << hdr.voxels.y << " " << hdr.voxels.z << "\n";
  ofFile << "ElementType = MET_FLOAT\n";
  ofFile << "ElementSize = " << hdr.voxelSize.x << " " << hdr.voxelSize.y << " " << hdr.voxelSize.z << "\n";
  ofFile << "ElementSpacing = " << hdr.voxelSize.x << " " << hdr.voxelSize.y << " " << hdr.voxelSize.z << "\n";
  ofFile << "ElementDataFile = " << densityRawImageFilename.string() << "\n";
  ofFile.close();
  float *floatdata;
  if (!(floatdata = (float*)calloc(hdr.voxels.x, sizeof(float)))) ECHO_ERROR("Not enough memory!");
  char *chardata = (char*)floatdata;
  FILE *file;
  if (!(file = fopen(densityRawImageFilename.c_str(), "wb")))
    ECHO_ERROR("Unable to open %s for writing!", densityRawImageFilename.c_str());
  for (int z = 0; z < hdr.voxels.z; z++)
    for (int y = 0; y < hdr.voxels.y; y++)
      {
      for (int x = 0; x < hdr.voxels.x; x++)
        floatdata[x] = densityDistribution[z][y][x];
      if (fwrite(chardata, sizeof(float), hdr.voxels.x, file) != (size_t)hdr.voxels.x)
        ECHO_ERROR("Unable to write data into %s!", densityRawImageFilename.c_str());
      }
  fclose(file);
  // the following string is used in musire.sh
  cout << densityMhdImageFilename.string() << endl;
  return 0;
  }
