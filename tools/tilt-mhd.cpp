#include "misc.h"

using namespace std;

#define TILT_IMAGE(TYPE) \
  { \
  rarray<TYPE,3> inImage(inHdr.voxels.z, inHdr.voxels.y, inHdr.voxels.x); \
  ReadMhdImage3D(inHdr, &inImage); \
  outHdr.filenameMhd = inMhdFilename.substr(0, inMhdFilename.find_last_of('.')) + str + ".mhd"; \
  outHdr.filenameRaw = inHdr.filenameRaw.substr(0, inHdr.filenameRaw.find_last_of('.')) + str + \
                       filesystem::path(inHdr.filenameRaw).extension().string(); \
  outHdr.elementType = inHdr.elementType; \
  outHdr.modality    = inHdr.modality; \
  switch (tilt) \
    { \
    case XP: \
      { \
      outHdr.voxels       = { inHdr.voxels.x,       inHdr.voxels.z,       inHdr.voxels.y }; \
      outHdr.voxelSize    = { inHdr.voxelSize.x,    inHdr.voxelSize.z,    inHdr.voxelSize.y }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[y][outHdr.voxels.z-1-z][x]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    case XM: \
      { \
      outHdr.voxels       = { inHdr.voxels.x,       inHdr.voxels.z,       inHdr.voxels.y }; \
      outHdr.voxelSize    = { inHdr.voxelSize.x,    inHdr.voxelSize.z,    inHdr.voxelSize.y }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[outHdr.voxels.y-1-y][z][x]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    case YP: \
      { \
      outHdr.voxels       = { inHdr.voxels.z,       inHdr.voxels.y,       inHdr.voxels.x }; \
      outHdr.voxelSize    = { inHdr.voxelSize.z,    inHdr.voxelSize.y,    inHdr.voxelSize.x }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[x][y][outHdr.voxels.z-1-z]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    case YM: \
      { \
      outHdr.voxels       = { inHdr.voxels.z,       inHdr.voxels.y,       inHdr.voxels.x }; \
      outHdr.voxelSize    = { inHdr.voxelSize.z,    inHdr.voxelSize.y,    inHdr.voxelSize.x }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[outHdr.voxels.x-1-x][y][z]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    case ZP: \
      { \
      outHdr.voxels       = { inHdr.voxels.y,       inHdr.voxels.x,       inHdr.voxels.z }; \
      outHdr.voxelSize    = { inHdr.voxelSize.y,    inHdr.voxelSize.x,    inHdr.voxelSize.z }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[z][x][outHdr.voxels.y-1-y]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    case ZM: \
      { \
      outHdr.voxels       = { inHdr.voxels.y,       inHdr.voxels.x,       inHdr.voxels.z }; \
      outHdr.voxelSize    = { inHdr.voxelSize.y,    inHdr.voxelSize.x,    inHdr.voxelSize.z }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[z][outHdr.voxels.x-1-x][y]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    case XPP: \
    case XMM: \
      { \
      outHdr.voxels       = { inHdr.voxels.x,       inHdr.voxels.y,       inHdr.voxels.z }; \
      outHdr.voxelSize    = { inHdr.voxelSize.x,    inHdr.voxelSize.y,    inHdr.voxelSize.z }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[outHdr.voxels.z-1-z][outHdr.voxels.y-1-y][x]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    case YPP: \
    case YMM: \
      { \
      outHdr.voxels       = { inHdr.voxels.x,       inHdr.voxels.y,       inHdr.voxels.z }; \
      outHdr.voxelSize    = { inHdr.voxelSize.x,    inHdr.voxelSize.y,    inHdr.voxelSize.z }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[outHdr.voxels.z-1-z][y][outHdr.voxels.x-1-x]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    case ZPP: \
    case ZMM: \
      { \
      outHdr.voxels       = { inHdr.voxels.x,       inHdr.voxels.y,       inHdr.voxels.z }; \
      outHdr.voxelSize    = { inHdr.voxelSize.x,    inHdr.voxelSize.y,    inHdr.voxelSize.z }; \
      rarray<TYPE,3> outImage(outHdr.voxels.z, outHdr.voxels.y, outHdr.voxels.x); \
      for (int z = 0; z < outHdr.voxels.z; z++) \
        for (int y = 0; y < outHdr.voxels.y; y++) \
          for (int x = 0; x < outHdr.voxels.x; x++) \
            outImage[z][y][x] = inImage[z][outHdr.voxels.y-1-y][outHdr.voxels.x-1-x]; \
      WriteMhd3DImage(outHdr, outImage); \
      } \
    break; \
    } \
  }

enum tiltEnum { XM, XMM, XP, XPP, YM, YMM, YP, YPP, ZM, ZMM, ZP, ZPP };

int main(int argc, char *argv[])
  {
  if (argc != 3) ECHO_ERROR("$ tilt-mhd-image <in.mhd> <-x|--x|+x|++x|-y|--y|+y|++y|-z|--z|+z|++z>");

  const string inMhdFilename = argv[1];
  if (!filesystem::exists(inMhdFilename)) 
    ECHO_ERROR("tilt-mhd-image: '%s' does not exist", inMhdFilename.c_str());

  tiltEnum tilt;
  string str;
  if      (strcmp( "-x", argv[2]) == 0) { tilt = XM;  str = "-x-tilted"; }
  else if (strcmp("--x", argv[2]) == 0) { tilt = XMM; str = "-xx-tilted"; }
  else if (strcmp( "+x", argv[2]) == 0) { tilt = XP;  str = "+x-tilted"; }
  else if (strcmp("++x", argv[2]) == 0) { tilt = XPP; str = "+xx-tilted"; }
  else if (strcmp( "-y", argv[2]) == 0) { tilt = YM;  str = "-y-tilted"; }
  else if (strcmp("--y", argv[2]) == 0) { tilt = YMM; str = "-yy-tilted"; }
  else if (strcmp( "+y", argv[2]) == 0) { tilt = YP;  str = "+y-tilted"; }
  else if (strcmp("++y", argv[2]) == 0) { tilt = YPP; str = "+yy-tilted"; }
  else if (strcmp( "-z", argv[2]) == 0) { tilt = ZM;  str = "-z-tilted"; }
  else if (strcmp("--z", argv[2]) == 0) { tilt = ZMM; str = "-zz-tilted"; }
  else if (strcmp( "+z", argv[2]) == 0) { tilt = ZP;  str = "+z-tilted"; }
  else if (strcmp("++z", argv[2]) == 0) { tilt = ZPP; str = "+zz-tilted"; }
  else ECHO_ERROR("$ tilt-mhd-image <in.mhd> <-x|--x|+x|++x|-y|--y|+y|++y|-z|--z|+z|++z>");

  mhdHdr3D inHdr = ReadMhdHeader3D(inMhdFilename);
  mhdHdr3D outHdr;
  switch (inHdr.elementType)
    {
    case MET_UCHAR:      TILT_IMAGE(unsigned char); break;
    case MET_SHORT:      TILT_IMAGE(short); break;
    case MET_USHORT:     TILT_IMAGE(unsigned short); break;
    case MET_LONG:       TILT_IMAGE(long); break;
    case MET_ULONG:      TILT_IMAGE(unsigned long); break;
    case MET_LONG_LONG:  TILT_IMAGE(long long); break;
    case MET_ULONG_LONG: TILT_IMAGE(unsigned long long); break;
    case MET_FLOAT:      TILT_IMAGE(float); break;
    case MET_DOUBLE:     TILT_IMAGE(double); break;
    default: EchoExit(" Element type of file '" + inHdr.filenameRaw + "' not supported");
    }
  // the following string is used in musire.sh
  cout << outHdr.filenameMhd << endl; // can use return value in bash
  return 0;
  }
