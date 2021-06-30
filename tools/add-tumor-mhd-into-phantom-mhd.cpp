#include "misc.h"
#include "cxxopts.hpp"

using namespace std;

int main(int argc, char *argv[])
  {
  // 1. Read in args
  filesystem::path phantomAtlasMhdFilename, tumorInsertMhdFilename;
  doublexyz      tumorCenterOffset = { 0.0, 0.0, 0.0 };
  try
    {
    cxxopts::Options options(argv[0], 
"  PURPOSE: This program will add a (downsampled) mhd output image at a specified position into a phantom atlas mhd image.\n"
"  USAGE:   add-tumor-mhd-into-phantom-mhd -a, --phantomAtlasMhdFilename <%s>\n"
"                                          -t, --tumorInsertMhdFilename <%s>\n"
"                                          -o, --tumorCenterOffset <%f,%f,%f> [mm]\n"
"  OUTPUT:  A new phantom atlas file will be created with the input phantom atlas labels first, and then off-setting tumor values\n"
"           on top of the first. As the tumor values are likely be created by downsample-tg-simulation-output-mdh, these represent\n"
"           cell numbers per voxel. Hence, these can be, e.g., assigned all with the same label representing tumor tissue, or as\n"
"           individual labels representing activity dirstribution.\n");
    options.add_options()
      ("a,phantomAtlasMhdFilename", "", cxxopts::value<filesystem::path>(), " ")
      ("t,tumorInsertMhdFilename", "",  cxxopts::value<filesystem::path>(), " ")
      ("o,tumorCenterOffset", "",       cxxopts::value<vector<double>>(), "{x,y,z} [mm]");
    auto result = options.parse(argc, argv);
    if (result.count("phantomAtlasMhdFilename")) 
      phantomAtlasMhdFilename.assign(result["phantomAtlasMhdFilename"].as<filesystem::path>());
    if (result.count("tumorInsertMhdFilename")) 
      tumorInsertMhdFilename.assign(result["tumorInsertMhdFilename"].as<filesystem::path>());
    if (result.count("tumorCenterOffset"))
      {
      vector<double> offset = result["tumorCenterOffset"].as<vector<double>>();
      tumorCenterOffset = { offset[0], offset[1], offset[2] };
      }
    }
  catch (const cxxopts::OptionException& e)
    {
    ECHO_ERROR("error parsing options: %s", e.what());
    }
  // Read phantomAtlasMhdFilename
  if (!filesystem::exists(phantomAtlasMhdFilename))
    ECHO_ERROR("phantomAtlasMhdFilename %s does not exist", phantomAtlasMhdFilename.c_str());
  mhdHdr3D phantomAtlasHdr = ReadMhdHeader3D(phantomAtlasMhdFilename);
//  string phantomAtlasDirectory = phantomAtlasMhdFilename.parent_path();
//  phantomAtlasHdr.filenameRaw = phantomAtlasDirectory.append("/").append(phantomAtlasHdr.filenameRaw);
  // Read phantomAtlas image data
  rarray<uint64_t,3> phantomAtlasImage(phantomAtlasHdr.voxels.z, phantomAtlasHdr.voxels.y, 
                                       phantomAtlasHdr.voxels.x);
  if      (phantomAtlasHdr.elementType == MET_UCHAR)  READ_IMAGE(uint8_t,  phantomAtlasHdr, phantomAtlasImage)
  else if (phantomAtlasHdr.elementType == MET_USHORT) READ_IMAGE(uint16_t, phantomAtlasHdr, phantomAtlasImage)
  else if (phantomAtlasHdr.elementType == MET_ULONG)  READ_IMAGE(uint32_t, phantomAtlasHdr, phantomAtlasImage)
  // Read tumorInsertMhdFilename
  if (!filesystem::exists(tumorInsertMhdFilename))
    ECHO_ERROR("tumorInsertMhdFilename %s does not exist", tumorInsertMhdFilename.c_str());
  mhdHdr3D tumorHdr = ReadMhdHeader3D(tumorInsertMhdFilename);
//  string tumorDirectory = tumorInsertMhdFilename.parent_path();
//  tumorHdr.filenameRaw = tumorDirectory.append("/").append(tumorHdr.filenameRaw);
  rarray<uint64_t,3> tumorImage(tumorHdr.voxels.z, tumorHdr.voxels.y, tumorHdr.voxels.x);
  if      (tumorHdr.elementType == MET_UCHAR)  READ_IMAGE(uint8_t,  tumorHdr, tumorImage)
  else if (tumorHdr.elementType == MET_USHORT) READ_IMAGE(uint16_t, tumorHdr, tumorImage)
  else if (tumorHdr.elementType == MET_ULONG)  READ_IMAGE(uint32_t, tumorHdr, tumorImage)
  // Check that voxelSize is the same in both mhd images
  if (phantomAtlasHdr.voxelSize.x != tumorHdr.voxelSize.x ||
      phantomAtlasHdr.voxelSize.y != tumorHdr.voxelSize.z ||
      phantomAtlasHdr.voxelSize.y != tumorHdr.voxelSize.z)
    ECHO_WARNING("phantomAtlasHdr.voxelSize != tumorHdr.voxelSize");
  // Get max label in phantomAtlasImage
  uint64_t maxPhantomAtlas = 0;
  for (int z = 0; z < phantomAtlasHdr.voxels.z; z++)
    for (int y = 0; y < phantomAtlasHdr.voxels.y; y++)
      for (int x = 0; x < phantomAtlasHdr.voxels.x; x++)
        if (phantomAtlasImage[z][y][x] > maxPhantomAtlas)
          maxPhantomAtlas = phantomAtlasImage[z][y][x];
  // Prepare outputImage and set it to phantomAtlasImage
  rarray<uint64_t,3> outputImage(phantomAtlasHdr.voxels.z, phantomAtlasHdr.voxels.y, phantomAtlasHdr.voxels.x);
  for (int z = 0; z < phantomAtlasHdr.voxels.z; z++)
    for (int y = 0; y < phantomAtlasHdr.voxels.y; y++)
      for (int x = 0; x < phantomAtlasHdr.voxels.x; x++)
        outputImage[z][y][x] = phantomAtlasImage[z][y][x];
  // Get center voxels of both input Images and place tumorImage into the outputImage
  intxyz tumorCenterVoxel = 
    { 
    (int)(phantomAtlasHdr.voxels.x / 2 + round(tumorCenterOffset.x / phantomAtlasHdr.voxelSize.x)),
    (int)(phantomAtlasHdr.voxels.y / 2 + round(tumorCenterOffset.y / phantomAtlasHdr.voxelSize.y)),
    (int)(phantomAtlasHdr.voxels.z / 2 + round(tumorCenterOffset.z / phantomAtlasHdr.voxelSize.z))
    };
  for (int z = 0; z < tumorHdr.voxels.z; z++)
    for (int y = 0; y < tumorHdr.voxels.y; y++)
      for (int x = 0; x < tumorHdr.voxels.x; x++)
        if (tumorImage[z][y][x] > 0)
          {
          const int xx = tumorCenterVoxel.x - tumorHdr.voxels.x / 2 + x;
          const int yy = tumorCenterVoxel.y - tumorHdr.voxels.y / 2 + y;
          const int zz = tumorCenterVoxel.z - tumorHdr.voxels.z / 2 + z;
          if (xx >= 0 && xx < phantomAtlasHdr.voxels.x &&
              yy >= 0 && yy < phantomAtlasHdr.voxels.y &&
              zz >= 0 && zz < phantomAtlasHdr.voxels.z)
            outputImage[zz][yy][xx] = maxPhantomAtlas + tumorImage[z][y][x];
          }
  // Get max (label) value of outputImage (so we save with the right type)
  uint64_t maxOutput = 0;
  for (int z = 0; z < phantomAtlasHdr.voxels.z; z++)
    for (int y = 0; y < phantomAtlasHdr.voxels.y; y++)
      for (int x = 0; x < phantomAtlasHdr.voxels.x; x++)
        if (outputImage[z][y][x] > maxOutput)
          maxOutput = outputImage[z][y][x];
//  // 7. Change into the tumorInsertMhdFilename directory and write to outputImage into it
//  filesystem::current_path(tumorInsertMhdFilename.parent_path());
  const uint64_t tumorLabelMin = maxPhantomAtlas + 1;
  const uint64_t tumorLabelMax = maxOutput;
  filesystem::path outputMhdFilename = phantomAtlasMhdFilename.filename().stem().concat("-")
                                      .concat(tumorInsertMhdFilename.filename().stem().string()).concat("-at");
  if (tumorCenterVoxel.x >= 0) outputMhdFilename.concat("+").concat(to_string(tumorCenterVoxel.x));
  else                       outputMhdFilename.concat(to_string(tumorCenterVoxel.x));
  if (tumorCenterVoxel.y >= 0) outputMhdFilename.concat("+").concat(to_string(tumorCenterVoxel.y));
  else                       outputMhdFilename.concat(to_string(tumorCenterVoxel.y));
  if (tumorCenterVoxel.z >= 0) outputMhdFilename.concat("+").concat(to_string(tumorCenterVoxel.z)).concat(".mhd");
  else                       outputMhdFilename.concat(to_string(tumorCenterVoxel.z)).concat(".mhd");
  if      (maxOutput < UINT8_MAX)
    WRITE_IMAGE(uint8_t, phantomAtlasHdr.voxels, phantomAtlasHdr.voxelSize, outputImage, 
                outputMhdFilename.string())
  else if (maxOutput < UINT16_MAX)
    WRITE_IMAGE(uint16_t, phantomAtlasHdr.voxels, phantomAtlasHdr.voxelSize, outputImage, 
                outputMhdFilename.string())
  else if (maxOutput < UINT32_MAX)
    WRITE_IMAGE(uint32_t, phantomAtlasHdr.voxels, phantomAtlasHdr.voxelSize, outputImage, 
                outputMhdFilename.string())
  else if (maxOutput < UINT64_MAX)
    WRITE_IMAGE(uint64_t, phantomAtlasHdr.voxels, phantomAtlasHdr.voxelSize, outputImage, 
                outputMhdFilename.string())
  // the following string is used in musire.sh
  cout << outputMhdFilename.string() << " " << tumorLabelMin << " " << tumorLabelMax << endl;
  return 0;
  }
