#include "misc.h"

using namespace std;

int main(int argc, char *argv[])
  {
  if (argc != 6)
    {
    cout << "PURPOSE: This program downsampes mhd images.\n"
            "USAGE: create-downsampled-tumor-mhd <inputTumorGrowthSimulationMhdFilename.mhd>\n"
            "                                    <inputCellSize>\n"
            "                                    <outputVoxelSizeX> <outputVoxelSizeY> <outputVoxelSizeZ>\n"
            "whereby <outputVoxelSize> (%f [mm]) must be a multiple of ElementSize in the input mhd image. "
            "The input image voxel values might be binary (cell/no cell) or might have LESION or GENOTYPE information."
            "ElementType of the input image might be MET_UCHAR, MET_USHORT, MET_ULONG, or MET_ULONG_LONG."
            "The downsampled output mhd image voxels are being assigned with the accumulated numbers of corresponding"
            "non-zero voxels in the input image, disregarding LESION or GENOTYPE information.\n";
    exit(1);
    }
  // 1. Read command line args
  const string     inputMhdFilename = argv[1];
  const double     inputCellSize    = atof(argv[2]);
  const doublexyz  outputVoxelSize  = { atof(argv[3]), atof(argv[4]), atof(argv[5]) };
  // 3. Read input image header
  mhdHdr3D hdr = ReadMhdHeader3D(inputMhdFilename);
  // 4. Check input image header
  if (hdr.voxelSize.x != hdr.voxelSize.y || hdr.voxelSize.x != hdr.voxelSize.z)
    ECHO_ERROR("Input image ElementSize must be same for x, y and z");
  if (hdr.elementType != MET_UCHAR && hdr.elementType != MET_USHORT && 
      hdr.elementType != MET_ULONG && hdr.elementType != MET_ULONG_LONG)
    ECHO_ERROR("Input image elementType must be MET_UCHAR, MET_USHORT, MET_ULONG, or MET_ULONG_LONG");
  if (fmod(outputVoxelSize.x * 100000, inputCellSize * 100000) != 0.0) //  * 100000 wg. rounding error
    ECHO_ERROR("<outputVoxelSize.x> (%f [mm]) must be a multiple of ElementSize %f in the input mhd image",
                outputVoxelSize.x, inputCellSize);
  if (fmod(outputVoxelSize.y * 100000, inputCellSize * 100000) != 0.0) //  * 100000 wg. rounding error
    ECHO_ERROR("<outputVoxelSize.y> (%f [mm]) must be a multiple of ElementSize %f in the input mhd image",
                outputVoxelSize.y, inputCellSize);
  if (fmod(outputVoxelSize.z * 100000, inputCellSize * 100000) != 0.0) //  * 100000 wg. rounding error
    ECHO_ERROR("<outputVoxelSize.z> (%f [mm]) must be a multiple of ElementSize %f in the input mhd image",
                outputVoxelSize.z, inputCellSize);
  // 5. Read input image data
  rarray<uint64_t,3> inputImage(hdr.voxels.z, hdr.voxels.y, hdr.voxels.x);
  if      (hdr.elementType == MET_UCHAR)      READ_IMAGE(uint8_t,  hdr, inputImage)
  else if (hdr.elementType == MET_USHORT)     READ_IMAGE(uint16_t, hdr, inputImage)
  else if (hdr.elementType == MET_ULONG)      READ_IMAGE(uint32_t, hdr, inputImage)
  else if (hdr.elementType == MET_ULONG_LONG) READ_IMAGE(uint64_t, hdr, inputImage)
  // 6. Prepare output image
  const uint16_t inputVoxelsPerOutputVoxelX = (uint16_t)(outputVoxelSize.x / inputCellSize);
  const uint16_t inputVoxelsPerOutputVoxelY = (uint16_t)(outputVoxelSize.y / inputCellSize);
  const uint16_t inputVoxelsPerOutputVoxelZ = (uint16_t)(outputVoxelSize.z / inputCellSize);
  const intxyz outputVoxels = { (int)(ceil)(hdr.voxels.x / (outputVoxelSize.x / inputCellSize)),
                                (int)(ceil)(hdr.voxels.y / (outputVoxelSize.y / inputCellSize)),
                                (int)(ceil)(hdr.voxels.z / (outputVoxelSize.z / inputCellSize)) };
  rarray<uint64_t,3> outputImage(outputVoxels.z, outputVoxels.y, outputVoxels.x);
  outputImage.fill(0);
  // 7. Calc output image
  uint64_t max = 0;
  for (int oz = 0; oz < outputVoxels.z; oz++)
    for (int oy = 0; oy < outputVoxels.y; oy++)
      for (int ox = 0; ox < outputVoxels.x; ox++)
        {
        uint64_t sum = 0;
        const int ix0 = ox * inputVoxelsPerOutputVoxelX,
                  iy0 = oy * inputVoxelsPerOutputVoxelY,
                  iz0 = oz * inputVoxelsPerOutputVoxelZ;
        for (int iz = 0; iz < inputVoxelsPerOutputVoxelZ; iz++)
          for (int iy = 0; iy < inputVoxelsPerOutputVoxelY; iy++)
            for (int ix = 0; ix < inputVoxelsPerOutputVoxelX; ix++)
              if (ix0 + ix < hdr.voxels.x && iy0 + iy < hdr.voxels.y && iz0 + iz < hdr.voxels.z)
                if (inputImage[iz0 + iz][iy0 + iy][ix0 + ix] > 0)
                  ++sum;
        outputImage[oz][oy][ox] = sum;
        if (sum > max)
          max = sum;
        }
  // 8. Write output image
  const string outputMhdFilename = inputMhdFilename.substr(0, inputMhdFilename.find_last_of(".")) + "-downsampled-" + argv[2] + ".mhd";
  hdr.filenameRaw = outputMhdFilename.substr(0, inputMhdFilename.find_last_of(".")) + ".raw";
  if      (max < UINT8_MAX)  WRITE_IMAGE(uint8_t,  outputVoxels, outputVoxelSize, outputImage, outputMhdFilename)
  else if (max < UINT16_MAX) WRITE_IMAGE(uint16_t, outputVoxels, outputVoxelSize, outputImage, outputMhdFilename)
  else if (max < UINT32_MAX) WRITE_IMAGE(uint32_t, outputVoxels, outputVoxelSize, outputImage, outputMhdFilename)
  else if (max < UINT64_MAX) WRITE_IMAGE(uint64_t, outputVoxels, outputVoxelSize, outputImage, outputMhdFilename)
  cout << outputMhdFilename << endl;
  return 0;
  }
