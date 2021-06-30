#include "/home/jpeter/cpp/include/jp.h"
#include "/home/jpeter/cpp/include/jp-mhd.h"

using namespace std;

#define MIRROR_IMAGE(TYPE) \
  { \
  rarray<TYPE,3> inImage(inHdr.voxels.z, inHdr.voxels.y, inHdr.voxels.x); \
  ReadMhdImage3D(inHdr, &inImage); \
  outHdr.filenameMhd = inMhdFilename.substr(0, inMhdFilename.find_last_of('.')) + str + ".mhd"; \
  outHdr.filenameRaw = inHdr.filenameRaw.substr(0, inHdr.filenameRaw.find_last_of('.')) + str + \
                       filesystem::path(inHdr.filenameRaw).extension().string(); \
  outHdr.elementType = inHdr.elementType; \
  outHdr.modality    = inHdr.modality; \
  outHdr.voxels      = { inHdr.voxels.x,       inHdr.voxels.y,       inHdr.voxels.z }; \
  outHdr.voxelSize   = { inHdr.voxelSize.x,    inHdr.voxelSize.y,    inHdr.voxelSize.z }; \
  rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
  switch (mirror) \
    { \
    case X: \
      { \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[z][y][outHdr.voxels.x-1-x]; \
      } \
    break; \
    case Y: \
      { \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[z][outHdr.voxels.y-1-y][x]; \
      } \
    break; \
    case Z: \
      { \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[outHdr.voxels.z-1-z][y][x]; \
      } \
    break; \
    } \
  WriteMhd3DImage(outHdr, outImage); \
  cout << "Wrote ' " << outHdr.filenameMhd << " '\n"; \
  }

enum mirrorEnum { X, Y, Z };

int main(int argc, char *argv[])
  {
  if (argc != 3) 
    ECHO_ERROR("$ mirror-mhd-image <in.mhd> < -x | -y | -z >");

  const string inMhdFilename = argv[1];
  if (!filesystem::exists(inMhdFilename)) 
    ECHO_ERROR("'%s' does not exist", inMhdFilename.c_str());

  mirrorEnum mirror;
  string str;
  if      (strcmp( "-x", argv[2]) == 0) { mirror = X;  str = "-x-mirrored"; }
  else if (strcmp( "-y", argv[2]) == 0) { mirror = Y;  str = "-y-mirrored"; }
  else if (strcmp( "-z", argv[2]) == 0) { mirror = Z;  str = "-z-mirrored"; }
  else
    ECHO_ERROR("$ mirror-mhd-image <in.mhd> < -x | -y | -z >");

  mhdHdr3D inHdr = ReadMhdHeader3D(inMhdFilename);
  mhdHdr3D outHdr;
  switch (inHdr.elementType)
    {
    case MET_UCHAR:      MIRROR_IMAGE(unsigned char); break;
    case MET_SHORT:      MIRROR_IMAGE(short); break;
    case MET_USHORT:     MIRROR_IMAGE(unsigned short); break;
    case MET_LONG:       MIRROR_IMAGE(long); break;
    case MET_ULONG:      MIRROR_IMAGE(unsigned long); break;
    case MET_LONG_LONG:  MIRROR_IMAGE(long long); break;
    case MET_ULONG_LONG: MIRROR_IMAGE(unsigned long long); break;
    case MET_FLOAT:      MIRROR_IMAGE(float); break;
    case MET_DOUBLE:     MIRROR_IMAGE(double); break;
    default: EchoExit(" Element type of file '" + inHdr.filenameRaw + "' not supported");
    }
  // the following string is used in musire.sh
  cout << outHdr.filenameMhd << endl; // can use return value in bash
  return 0;
  }
