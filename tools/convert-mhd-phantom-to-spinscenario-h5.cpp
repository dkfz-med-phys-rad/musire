// This example shows how to create a dataset and write it to a new HDF5 file
// compile with: $ h5c++ -o h5_create h5_create.cpp
#include <string>
#include <fstream>
#include <filesystem>

#include "rarray"
#include "rarrayio"

#include "H5Cpp.h"

//#include <jp-xyz_t.hpp>
//#include <jp-echo.hpp>
//#include <jp-mhd-3d.hpp>
#include "misc.h"

using namespace std;
using namespace H5;

int main (int argc, char *argv[])
  {
  if (argc != 2) EchoExit("convert-mhd-phantom-to-spinscenario-h5 <file>.mhd");
  // 1. Read input mhd phantom data
  const string  inputMhdFilename = argv[1];
  mhdHdr3D hdr = ReadMhdHeader3D(inputMhdFilename);
  if (!(hdr.elementType == MET_UCHAR || hdr.elementType == MET_USHORT))
    EchoExit("Phantom ElementTypes compatiple with SpinScenario are MET_UCHAR or MET_USHORT!");
  rarray<uint16_t,3> inputImage(hdr.voxels.z, hdr.voxels.y, hdr.voxels.x);
  ReadMhdImage3D(hdr, &inputImage);
  // !! matrix order seems [x][y][z] !!
  rarray<uint16_t,3> outputImage(hdr.voxels.x, hdr.voxels.y, hdr.voxels.z);
  for (uint16_t z = 0; z < hdr.voxels.z; z++)
    for (uint16_t y = 0; y < hdr.voxels.y; y++)
      for (uint16_t x = 0; x < hdr.voxels.x; x++)
        outputImage[x][y][z] = inputImage[z][y][x];
  // 2. Write h5 phantom file
  try
    {
    Exception::dontPrint();
    size_t lastindex = inputMhdFilename.find_last_of("."); 
    const string outputH5Filename = inputMhdFilename.substr(0, lastindex) + ".h5"; 
    H5File file(outputH5Filename, H5F_ACC_TRUNC);
    Group phantomGroup(file.createGroup("phantom"));
    IntType   uintDataType(PredType::NATIVE_USHORT); uintDataType.setOrder(H5T_ORDER_LE);
    FloatType doubleDataType(PredType::NATIVE_DOUBLE); doubleDataType.setOrder(H5T_ORDER_LE);
    // create and write dataset "dimension"
    hsize_t   dimensionDataSize[2] = { 3, 1 };
    DataSpace dimensionDataSpace(2, dimensionDataSize);
    DataSet   dimensionDataSet = DataSet(phantomGroup.createDataSet("dimension", uintDataType, dimensionDataSpace));
    uint16_t  dimensionData[3] = { (uint16_t)hdr.voxels.x, (uint16_t)hdr.voxels.y, (uint16_t)hdr.voxels.z };
    dimensionDataSet.write(dimensionData, uintDataType);
    dimensionDataSpace.close();
    dimensionDataSet.close();
    // create and write dataset "resolution"
    hsize_t   resolutionDataSize[2] = { 3, 1 };
    DataSpace resolutionDataSpace(2, resolutionDataSize);
    DataSet   resolutionDataSet = DataSet(phantomGroup.createDataSet("resolution", doubleDataType, resolutionDataSpace));
    double    resolutionData[3] = { hdr.voxelSize.x / 1000.0, hdr.voxelSize.y / 1000.0, hdr.voxelSize.z / 1000.0 }; // Units are m
    resolutionDataSet.write(resolutionData, doubleDataType);
    resolutionDataSpace.close();
    resolutionDataSet.close();
    // create and write dataset "tissue_dist"
    hsize_t   tissue_distDataSize[3] = { (uint16_t)hdr.voxels.x, (uint16_t)hdr.voxels.y , (uint16_t)hdr.voxels.z };
    DataSpace tissue_distDataspace(3, tissue_distDataSize);
    DataSet   tissue_distDataset = DataSet(phantomGroup.createDataSet("tissue_dist", uintDataType, tissue_distDataspace));
    tissue_distDataset.write(&outputImage[0][0][0], uintDataType); // rarray is contiguous memory
    tissue_distDataspace.close();
    tissue_distDataset.close();
    }
  catch (FileIException error)      { error.printErrorStack(); return EXIT_FAILURE; }
  catch (DataSetIException error)   { error.printErrorStack(); return EXIT_FAILURE; }
  catch (DataSpaceIException error) { error.printErrorStack(); return EXIT_FAILURE; }
  catch (DataTypeIException error)  { error.printErrorStack(); return EXIT_FAILURE; }
  return EXIT_SUCCESS;
  }

