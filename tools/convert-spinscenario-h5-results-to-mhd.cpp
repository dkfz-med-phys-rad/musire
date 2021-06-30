// This example reads hyperslab from the SDS.h5 file into two-dimensional plane of a three-dimensional array.
// Various information about the dataset in the SDS.h5 file is obtained.

#include <iostream>
#include <string>
#include <vector>
#include <fstream>
#include <filesystem>

#include <rarray>
#include <rarrayio>

#include "H5Cpp.h"

#include <jp-echo.hpp>
#include <jp-mhd-3d.hpp>

using namespace std;
using namespace H5;

void ReadAndWriteDataset(const string inputH5Filename, const string groupStr, const string datasetStr, 
                         float elementSizeXYZmm)
  {
  try
    {
    Exception::dontPrint();
    H5File  *file    = new H5File(inputH5Filename, H5F_ACC_RDONLY);
    Group   *group   = new Group(file->openGroup(groupStr));
    DataSet *dataset = new DataSet(group->openDataSet(groupStr + ":" + datasetStr));
    if (dataset->getTypeClass() != H5T_FLOAT) EchoExit("dataset is expected to be of H5T_FLOAT type");
    DataSpace dataspace = dataset->getSpace();
    const int rank = dataspace.getSimpleExtentNdims();
    if (rank < 2 || rank > 3) EchoExit("dataset is expected to be either 2D or 3D");
    hsize_t dims[3] = { 1, 1, 1 };
    int ndims = dataspace.getSimpleExtentDims(dims, NULL);
    float data[dims[0] * dims[1] * dims[2]];
    dataset->read(data, PredType::NATIVE_FLOAT);
    rarray<float,3> image(data, dims[0], dims[1], dims[2]);
    size_t lastindex = inputH5Filename.find_last_of(".");
    mhdHdr3D hdr = { .filenameMhd = inputH5Filename.substr(0, lastindex) + "-" + groupStr + "-" + datasetStr + ".mhd",
                     .filenameRaw = inputH5Filename.substr(0, lastindex) + "-" + groupStr + "-" + datasetStr + ".raw",
                     .elementType = MET_FLOAT,
                     .voxels = { (int)dims[0], (int)dims[1], (int)dims[2] },
                     .voxelSize = { elementSizeXYZmm, elementSizeXYZmm, elementSizeXYZmm },
                     .modality =  "MET_MOD_MR" };
    WriteMhdHeaderAndImage3D(hdr, image);
    }
  catch (FileIException error)      { error.printErrorStack(); exit(EXIT_FAILURE); }
  catch (DataSetIException error)   { error.printErrorStack(); exit(EXIT_FAILURE); }
  catch (DataSpaceIException error) { error.printErrorStack(); exit(EXIT_FAILURE); }
  catch (DataTypeIException error)  { error.printErrorStack(); exit(EXIT_FAILURE); }
  }

int main(int argc, char *argv[])
  {
  if (argc != 2 && argc != 3) EchoExit("convert-spinscenario-h5-results-to-mhd <file.h5> [elementSizeXYZmm]");
  const float elementSizeXYZmm = (argc == 3) ? atof(argv[2]) : 1.0;
  ReadAndWriteDataset(argv[1], "FID", "abs", elementSizeXYZmm);
  ReadAndWriteDataset(argv[1], "FID", "im", elementSizeXYZmm);
  ReadAndWriteDataset(argv[1], "FID", "re", elementSizeXYZmm);
  ReadAndWriteDataset(argv[1], "IMG", "abs", elementSizeXYZmm);
  ReadAndWriteDataset(argv[1], "IMG", "im", elementSizeXYZmm);
  ReadAndWriteDataset(argv[1], "IMG", "re", elementSizeXYZmm);
  ReadAndWriteDataset(argv[1], "SPEC", "abs", elementSizeXYZmm);
  ReadAndWriteDataset(argv[1], "SPEC", "im", elementSizeXYZmm);
  ReadAndWriteDataset(argv[1], "SPEC", "re", elementSizeXYZmm);
  return EXIT_SUCCESS;
  }
