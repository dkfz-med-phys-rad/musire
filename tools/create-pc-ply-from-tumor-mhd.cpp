#include "misc.h"

using namespace std;

int main(int argc, char *argv[])
  {
  if (!(argc == 2 || argc == 3 || argc == 6 || argc == 7))
    {
    cout << "PURPOSE: This program tages a mhd file (where voxels are just tested for being 0 or >0)"
            "         and generates a ply point cloud.\n"
            "If cellDiamater is not provided as argc 7, then it is taken from the ElementSize = fiels in the mhd file."
            "REASON:  The (tumor) ply file can be included in a (phantom) mlp file for visualisation.\n"
            "USAGE: create-pc-ply-from-tumor-mhd <inputTumorGrowthSimulationMhdFilename.mhd>\n"
            "                                    [<outputTumorGrowthSimulationPlyFilename.ply>]\n"
            "                                    [shiftXmm shiftYmm shiftZmm]\n"
            "                                    [cellDiameter]\n";
    exit(1);
    }
  // 1. Read command line args
  const string     inputMhdFilename = argv[1];
  filesystem::path p(inputMhdFilename);
  const string     outputPlyFilename = (argc >= 3) ? argv[2] : p.stem().string().append(".ply");
  doublexyz shift = { 0.0, 0.0, 0.0 };
  if (argc == 6) shift = { atof(argv[3]), atof(argv[4]), atof(argv[5]) };
  // 2. Read input image header
  mhdHdr3D hdr = ReadMhdHeader3D(inputMhdFilename);
  // 3. Check input image header
  if (hdr.voxelSize.x != hdr.voxelSize.y || hdr.voxelSize.x != hdr.voxelSize.z)
    ECHO_ERROR("Input image ElementSize must be same for x, y and z");
  const double cellDiamater = (argc == 7) ? atof(argv[6]) : hdr.voxelSize.x;
  if (hdr.elementType != MET_UCHAR && hdr.elementType != MET_USHORT && 
      hdr.elementType != MET_ULONG && hdr.elementType != MET_ULONG_LONG)
    ECHO_ERROR("Input image elementType must be MET_UCHAR, MET_USHORT, MET_ULONG, or MET_ULONG_LONG");
  const doublexyz halfSize = { 0.5 * hdr.voxelSize.x * hdr.voxels.x, 
                               0.5 * hdr.voxelSize.y * hdr.voxels.y, 
                               0.5 * hdr.voxelSize.z * hdr.voxels.z };
  // 4. Read input image data
  rarray<uint64_t,3> inputImage(hdr.voxels.z, hdr.voxels.y, hdr.voxels.x);
  if      (hdr.elementType == MET_UCHAR)      READ_IMAGE(uint8_t,  hdr, inputImage)
  else if (hdr.elementType == MET_USHORT)     READ_IMAGE(uint16_t, hdr, inputImage)
  else if (hdr.elementType == MET_ULONG)      READ_IMAGE(uint32_t, hdr, inputImage)
  else if (hdr.elementType == MET_ULONG_LONG) READ_IMAGE(uint64_t, hdr, inputImage)
  // 5. get number of cells (=vertex number)
  uint64_t cells = 0;
  for (int z = 0; z < hdr.voxels.z; z++)
    for (int y = 0; y < hdr.voxels.y; y++)
      for (int x = 0; x < hdr.voxels.x; x++)
        if (inputImage[z][y][x] > 0)
          cells++;
  // 6. write ply header (this is very basic, cell color ist fixed red)
  ofstream plyFile;
  plyFile.open (outputPlyFilename);
  plyFile << "ply\n";
  plyFile << "format ascii 1.0\n";
  plyFile << "comment generated from " << inputMhdFilename << "\n";
  plyFile << "element vertex " << cells << "\n";
  plyFile << "property float x\n";
  plyFile << "property float y\n";
  plyFile << "property float z\n";
  plyFile << "property uchar red\n";
  plyFile << "property uchar green\n";
  plyFile << "property uchar blue\n";
  plyFile << "end_header\n";
  // 7. write vertex list
  for (int z = 0; z < hdr.voxels.z; z++)
    {
    const double zPos = z * cellDiamater - halfSize.z + shift.z;
    for (int y = 0; y < hdr.voxels.y; y++)
      {
      const double yPos = y * cellDiamater - halfSize.y + shift.y;
      for (int x = 0; x < hdr.voxels.x; x++)
        if (inputImage[z][y][x] > 0)
          {
          const double xPos = x * cellDiamater - halfSize.x + shift.x;
          plyFile << xPos << " " << yPos << " " << zPos << " 255 0 0 \n";
          }
      }
    }
  plyFile.close();
  inputImage.clear();
  return 0;
  }
