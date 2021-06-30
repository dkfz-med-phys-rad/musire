#ifndef MISC
#define MISC

#  include <algorithm>
#  include <chrono>
#  include <math.h>
#  include <cmath>
#  include <cstdarg>
#  include <cstdint>
#  include <cstdio>
#  include <cstdlib>
#  include <filesystem>
#  include <fstream>
#  include <iostream>
#  include <thread>
#  include <mutex>
#  include <filesystem>
#  include <memory>
#  include <sstream>
#  include <string>
#  include <string.h>
#  include <sstream>
#  include <utility>
#  include <vector>
#  include <unistd.h>
#  include <sys/sysinfo.h>
#  include <sys/stat.h>
#  include <limits.h>
#  include <float.h>
#  include <iomanip>
#  include "rarray"
#  include "rarrayio"

inline void EchoExit(const std::string &msg)
  { std::cerr << "\033[1;31m" << msg << "\033[0m" << std::endl; exit(EXIT_FAILURE); }

#define ECHO_WARNING(args...) \
  { \
  fprintf(stderr, "\033[1m\033[33mWARNING:\033[0m\033[37m %s() line %d: \033[1m", __FUNCTION__, __LINE__); \
  fprintf(stderr, args); \
  fprintf(stderr, "\033[0m\n"); \
  }

#define ECHO_ERROR(args...) \
  { \
  fprintf(stderr, "\033[1m\033[31mERROR:\033[0m\033[37m %s() line %d: \033[1m", __FUNCTION__, __LINE__); \
  fprintf(stderr, args); \
  fprintf(stderr, "\033[0m\n"); \
  exit(EXIT_FAILURE); \
  }


typedef uint8_t  byte;
typedef uint16_t word;
typedef uint32_t dword;
typedef uint64_t qword;

template<typename T> class VectorXYZ
  {
  public:
    VectorXYZ()                 : x(T(0)), y(T(0)), z(T(0)) {}
    VectorXYZ(T xx)             : x(xx), y(xx), z(xx) {}
    VectorXYZ(T xx, T yy, T zz) : x(xx), y(yy), z(zz) {}
    VectorXYZ operator + (const VectorXYZ &v) const { return VectorXYZ(x + v.x, y + v.y, z + v.z); }
    VectorXYZ operator - (const VectorXYZ &v) const { return VectorXYZ(x - v.x, y - v.y, z - v.z); }
    VectorXYZ operator - ()                   const { return VectorXYZ(-x, -y, -z); }
    VectorXYZ operator * (const T &r)         const { return VectorXYZ(x * r, y * r, z * r); }
    VectorXYZ operator / (const T &r)         const { return VectorXYZ(x / r, y / r, z / r); }
    VectorXYZ operator * (const VectorXYZ &v) const { return VectorXYZ(x * v.x, y * v.y, z * v.z); }
    T dotProduct(const VectorXYZ<T> &v)       const { return x * v.x + y * v.y + z * v.z; }
    T distance(const VectorXYZ<T> &v)         const { return sqrt((x-v.x) * (x-v.x) + (y-v.y) * (y-v.y) + (z-v.z) * (z-v.z)); }
    T sqDistance(const VectorXYZ<T> &v) 
      const { return (x - v.x) * (x - v.x) + (y - v.y) * (y - v.y) + (z - v.z) * (z - v.z); }
    VectorXYZ& operator -= (const VectorXYZ &v) { x -= v.x, y -= v.y, z -= v.z; return *this; }
    VectorXYZ& operator += (const VectorXYZ &v) { x += v.x, y += v.y, z += v.z; return *this; }
    VectorXYZ& operator *= (const T &r) { x *= r, y *= r, z *= r; return *this; }
    VectorXYZ& operator /= (const T &r) { x /= r, y /= r, z /= r; return *this; }
    VectorXYZ crossProduct(const VectorXYZ<T> &v) 
      const { return VectorXYZ<T>(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x); }
    T norm()   const { return x * x + y * y + z * z; }
    T length() const { return sqrt(x * x + y * y + z * z); }
    const T& operator [] (uint8_t i) const { return (&x)[i]; }
          T& operator [] (uint8_t i)       { return (&x)[i]; }
    VectorXYZ& normalize() 
      { 
      T n = norm(); 
      if (n > 0) { T factor = 1 / sqrt(n); x *= factor, y *= factor, z *= factor; } 
      return *this; 
      }
    friend VectorXYZ operator * (const T &r, const VectorXYZ &v) 
      { return VectorXYZ<T>(v.x * r, v.y * r, v.z * r); }
    friend VectorXYZ operator / (const T &r, const VectorXYZ &v) 
      { return VectorXYZ<T>(r / v.x, r / v.y, r / v.z); }
    friend std::ostream& operator << (std::ostream &s, const VectorXYZ<T> &v) 
      { return s << '[' << v.x << ' ' << v.y << ' ' << v.z << ']'; }
    T x, y, z;
  };

typedef VectorXYZ<byte>   bytexyz;
typedef VectorXYZ<int>    intxyz;
typedef VectorXYZ<long>   longxyz;
typedef VectorXYZ<word>   wordxyz;
typedef VectorXYZ<dword>  dwordxyz;
typedef VectorXYZ<qword>  qwordxyz;
typedef VectorXYZ<float>  floatxyz;
typedef VectorXYZ<double> doublexyz;

enum   elementTypes { MET_UCHAR, MET_SHORT, MET_USHORT, MET_LONG, MET_ULONG, MET_LONG_LONG, MET_ULONG_LONG,
                      MET_FLOAT, MET_DOUBLE, MET_NONE };
static size_t elementTypeSize[] = { 1, 2, 2, 4, 4, 8, 8, 4, 8, 0 };

static void CheckObjectType(std::stringstream &linestream, std::string &item)
  {
  while (getline(linestream, item, ' '));
  if (item.compare("Image") != 0) EchoExit(" ObjectType needs to be 'Image'");
  }
static void CheckBinaryData(std::stringstream &linestream, std::string &item)
  {
  while (getline(linestream, item, ' '));
  if (item.compare("True") != 0) EchoExit(" inaryData needs to be 'True'");
  }
static void CheckBinaryDataByteOrderMSB(std::stringstream &linestream, std::string &item)
  {
  while (getline(linestream, item, ' '));
  if (item.compare("False") != 0) EchoExit(" BinaryDataByteOrderMSB needs to be 'False'"); // TODO what if true?
  }
static void CheckCompressedData(std::stringstream &linestream, std::string &item)
  {
  while (getline(linestream, item, ' '));
  if (item.compare("False") != 0) EchoExit(" CompressedData needs to be 'False'"); // TODO what if true?
  }
static void CheckNdims(std::stringstream &linestream, std::string &item, int dim)
  {
  while (getline(linestream, item, ' '));
  if (stoi(item) != dim) EchoExit(" NDims needs to be '" + std::to_string(dim) + "'");
  }
//static std::string GetModalityString(std::stringstream &linestream, std::string &item)
//  {
//  while (getline(linestream, item, ' '));
//  // no checking at this time
//  return item;
//  }
static std::string GetElementDataFile(std::stringstream &linestream, std::string &item)
  {
  while (getline(linestream, item, ' '));
  return item;
  }
static elementTypes GetElementType(std::stringstream &linestream, std::string &item)
  {
  while (getline(linestream, item, ' '));
  elementTypes elementType;
  if      (item.compare("MET_UCHAR") == 0)          elementType = MET_UCHAR;
  else if (item.compare("MET_SHORT") == 0)          elementType = MET_SHORT;
  else if (item.compare("MET_USHORT") == 0)         elementType = MET_USHORT;
  else if (item.compare("MET_LONG") == 0)           elementType = MET_LONG;
  else if (item.compare("MET_ULONG") == 0)          elementType = MET_ULONG;
  else if (item.compare("MET_MET_LONG_LONG") == 0)  elementType = MET_LONG_LONG;
  else if (item.compare("MET_ULONG_LONG") == 0)     elementType = MET_ULONG_LONG;
  else if (item.compare("MET_FLOAT") == 0)          elementType = MET_FLOAT;
  else if (item.compare("MET_DOUBLE") == 0)         elementType = MET_DOUBLE;
  else EchoExit(" ElementType cannot be '" + item + "'");
  return elementType;
  }

struct mhdHdr3D
  {
  std::string   filenameMhd;
  std::string   filenameRaw;
  elementTypes  elementType;
  intxyz        voxels;
  doublexyz     voxelSize;
  std::string   modality; // "MET_MOD_CT", "MET_MOD_MR", "MET_MOD_NM", "MET_MOD_PET", "MET_MOD_SPECT",
                          // "MET_MOD_ATLAS", "MET_MOD_OTHER"
  };

// type defined in MetaIO/src/metaTypes.h
template<typename T> inline const char *GetElementTypeString() // called when no template specialization is found
  { EchoExit("Wrong image type in WriteMhdImage"); return ""; }
template<> inline const char *GetElementTypeString<uint8_t>()  { return "MET_UCHAR\n"; }
template<> inline const char *GetElementTypeString<int16_t>()  { return "MET_SHORT\n"; }
template<> inline const char *GetElementTypeString<uint16_t>() { return "MET_USHORT\n"; }
template<> inline const char *GetElementTypeString<int32_t>()  { return "MET_LONG\n"; }
template<> inline const char *GetElementTypeString<uint32_t>() { return "MET_ULONG\n"; }
template<> inline const char *GetElementTypeString<int64_t>()  { return "MET_LONG_LONG\n"; }
template<> inline const char *GetElementTypeString<uint64_t>() { return "MET_ULONG_LONG\n"; }
template<> inline const char *GetElementTypeString<float>()    { return "MET_FLOAT\n"; }
template<> inline const char *GetElementTypeString<double>()   { return "MET_DOUBLE\n"; }

template <typename T> void WriteMhdHeaderAndImage3D(const mhdHdr3D &hdr, rarray<T,3> image)
  {
  // write header
  std::ofstream ofFile;
  ofFile.open(hdr.filenameMhd);
  if (!ofFile) EchoExit("Could not open raw file '" + hdr.filenameMhd + "' for writing");
  ofFile << "ObjectType = Image\n";
  ofFile << "BinaryData = True\n";
  ofFile << "BinaryDataByteOrderMSB = False\n";
  ofFile << "CompressedData = False\n";
  ofFile << "Modality = " << hdr.modality << "\n";
  ofFile << "NDims = 3\n";
  ofFile << "DimSize = " << hdr.voxels.x << " " << hdr.voxels.y << " " << hdr.voxels.z << "\n";
  ofFile << "ElementType = " << GetElementTypeString<T>();
  ofFile << "ElementSize = " << hdr.voxelSize.x << " " << hdr.voxelSize.y << " " << hdr.voxelSize.z << "\n";
  ofFile << "ElementSpacing = " << hdr.voxelSize.x << " " << hdr.voxelSize.y << " " << hdr.voxelSize.z << "\n";
  ofFile << "ElementDataFile = " << hdr.filenameRaw << "\n";
  ofFile.close();
  // write data
  ofFile.open(hdr.filenameRaw, std::ios::binary);
  if (!ofFile) 
    EchoExit("Could not raw open file '" + hdr.filenameRaw + "' for writing");
  const uint32_t numberOfBytes = sizeof(T) * hdr.voxels.x * hdr.voxels.y * hdr.voxels.z;
  ofFile.write(reinterpret_cast<char*>(image.data()), image.size() * sizeof(T));
  if (ofFile.tellp() != numberOfBytes)
    EchoExit("Number of bytes written does not match header number of voxels");
  ofFile.close();
  }

static mhdHdr3D ReadMhdHeader3D(const std::string &filenameMhd)
  {
  mhdHdr3D hdr;
  std::ifstream ifFile;
  ifFile.open(filenameMhd);
  if (!ifFile.is_open()) EchoExit(" Could not open file '" + filenameMhd + "' for reading");
  hdr.filenameMhd = filenameMhd;
  hdr.elementType = MET_NONE;
  std::string lineOfFile;
  while(getline(ifFile, lineOfFile)) 
    {
    std::stringstream linestream(lineOfFile);
    std::string item;
    getline(linestream, item, ' ');
      {
      if      (item.compare("ObjectType") == 0)             CheckObjectType(linestream, item);
      else if (item.compare("BinaryData") == 0)             CheckBinaryData(linestream, item);
      else if (item.compare("BinaryDataByteOrderMSB") == 0) CheckBinaryDataByteOrderMSB(linestream, item);
      else if (item.compare("CompressedData") == 0)         CheckCompressedData(linestream, item);
      else if (item.compare("Modality") == 0)
        {
        getline(linestream, item, ' '); // '='
        getline(linestream, item, ' '); hdr.modality = item;
        }
      else if (item.compare("NDims") == 0)                  CheckNdims(linestream, item, 3);
      else if (item.compare("ElementDataFile") == 0)      hdr.filenameRaw = GetElementDataFile(linestream, item);
      else if (item.compare("ElementType") == 0)            hdr.elementType = GetElementType(linestream, item);
      else if (item.compare("DimSize") == 0)
        {
        getline(linestream, item, ' '); // '='
        getline(linestream, item, ' '); hdr.voxels.x = stoi(item);
        getline(linestream, item, ' '); hdr.voxels.y = stoi(item);
        getline(linestream, item, ' '); hdr.voxels.z = stoi(item);
        }
      else if (item.compare("ElementSize") == 0)
        {
        getline(linestream, item, ' '); // '='
        getline(linestream, item, ' '); hdr.voxelSize.x = stod(item);
        getline(linestream, item, ' '); hdr.voxelSize.y = stod(item);
        getline(linestream, item, ' '); hdr.voxelSize.z = stod(item);
        }
      else if (item.compare("ElementSpacing") == 0)
        {
        getline(linestream, item, ' '); // '='
        getline(linestream, item, ' '); hdr.voxelSize.x = stod(item);
        getline(linestream, item, ' '); hdr.voxelSize.y = stod(item);
        getline(linestream, item, ' '); hdr.voxelSize.z = stod(item);
        }
      //else ECHO_WARNING("%s is not handled (yet)", item.c_str());
      }
    }
  if (ifFile.bad()) EchoExit(" Error while reading file");
  ifFile.close();
  return hdr;
  }

#define READ_3DIMAGE(TYPE) \
  { \
  rarray<TYPE,1> tempImage((*image).size()); \
  ifFile.read(reinterpret_cast<char*>(tempImage.data()), (*image).size() * sizeof(T)); \
  u_int64_t i = 0; \
  for (int z = 0; z < hdr.voxels.z; z++) \
    for (int y = 0; y < hdr.voxels.y; y++) \
      for (int x = 0; x < hdr.voxels.x; x++) \
        (*image)[z][y][x] = static_cast<T>(tempImage[i++]); \
  tempImage.clear(); \
  }

template <typename T> void ReadMhdImage3D(const mhdHdr3D &hdr, rarray<T,3> *image)
  {
  // check data file
  if (!std::filesystem::exists(hdr.filenameRaw)) EchoExit(" Data file '" + hdr.filenameRaw + "' does not exist");
  if (std::filesystem::file_size(hdr.filenameRaw) != (*image).size() * elementTypeSize[hdr.elementType])
    EchoExit(" File size of '" + hdr.filenameRaw + " does not fit Mhd image size");
  if (elementTypeSize[hdr.elementType] > sizeof(T))
    EchoExit(" Data type size of raw data file '" + hdr.filenameRaw + "' is larger than rarray type");
  // read data file (data type can be any of elementTypes as long as it can be converted into rarray type)
  std::ifstream ifFile;
  ifFile.open(hdr.filenameRaw, std::ios::binary);
  if (!ifFile.is_open()) EchoExit(" Could not open file '" + hdr.filenameRaw + "' for reading");
  switch (hdr.elementType)
    {
    case MET_UCHAR:      READ_3DIMAGE(uint8_t); break;
    case MET_SHORT:      READ_3DIMAGE(int16_t); break;
    case MET_USHORT:     READ_3DIMAGE(uint16_t); break;
    case MET_LONG:       READ_3DIMAGE(int32_t); break;
    case MET_ULONG:      READ_3DIMAGE(uint32_t); break;
    case MET_LONG_LONG:  READ_3DIMAGE(int64_t); break;
    case MET_ULONG_LONG: READ_3DIMAGE(uint64_t); break;
    case MET_FLOAT:      READ_3DIMAGE(float); break;
    case MET_DOUBLE:     READ_3DIMAGE(double); break;
    default: EchoExit(" Element type of file '" + hdr.filenameRaw + "' not supported for reading");
    }
  ifFile.close();
  }

#define READ_IMAGE(TYPE, HDR, IMAGE) \
  { \
  rarray<TYPE,3> t(HDR.voxels.z, HDR.voxels.y, HDR.voxels.x); \
  ReadMhdImage3D(HDR, &t); \
  for (int z = 0; z < HDR.voxels.z; z++) \
    for (int y = 0; y < HDR.voxels.y; y++) \
      for (int x = 0; x < HDR.voxels.x; x++) \
        IMAGE[z][y][x] = t[z][y][x]; \
  t.clear(); \
  }

template <typename T>
void WriteMhd3DImage(const std::string &filenameMhd, rarray<T,3> image, intxyz voxels, doublexyz voxelSize,
                     const std::string &modalityString = "MET_MOD_OTHER")
  {
  const std::string filenameRaw = filenameMhd.substr(0, filenameMhd.find_last_of('.')) + ".raw";
   // write header
  std::ofstream ofFile;
  ofFile.open(filenameMhd);
  if (!ofFile) EchoExit("Could not open raw file '" + filenameMhd + "' for writing");
  ofFile << "ObjectType = Image\n";
  ofFile << "BinaryData = True\n";
  ofFile << "BinaryDataByteOrderMSB = False\n";
  ofFile << "CompressedData = False\n";
  ofFile << "Modality = " << modalityString << "\n";
  ofFile << "NDims = 3\n";
  ofFile << "DimSize = " << voxels.x << " " << voxels.y << " " << voxels.z << "\n";
  ofFile << "ElementType = " << GetElementTypeString<T>();
  ofFile << "ElementSize = " << voxelSize.x << " " << voxelSize.y << " " << voxelSize.z << "\n";
  ofFile << "ElementSpacing = " << voxelSize.x << " " << voxelSize.y << " " << voxelSize.z << "\n";
  ofFile << "ElementDataFile = " << filenameRaw << "\n";
  ofFile.close();
  // write data
  ofFile.open(filenameRaw, std::ios::binary);
  if (!ofFile) EchoExit("Could not raw file '" + filenameRaw + "' for writing");
  ofFile.write(reinterpret_cast<char*>(image.data()), image.size() * sizeof(T));
  ofFile.close();
  }

template <typename T> void WriteMhd3DImage(const mhdHdr3D hdr, rarray<T,3> image)
  {
  // write header
  std::ofstream ofFile;
  ofFile.open(hdr.filenameMhd);
  if (!ofFile) EchoExit("Could not open raw file '" + hdr.filenameMhd + "' for writing");
  ofFile << "ObjectType = Image\n";
  ofFile << "BinaryData = True\n";
  ofFile << "BinaryDataByteOrderMSB = False\n";
  ofFile << "CompressedData = False\n";
  ofFile << "Modality = " << hdr.modality << "\n";
  ofFile << "NDims = 3\n";
  ofFile << "DimSize = " << hdr.voxels.x << " " << hdr.voxels.y << " " << hdr.voxels.z << "\n";
  ofFile << "ElementType = " << GetElementTypeString<T>();
  ofFile << "ElementSize = " << hdr.voxelSize.x << " " << hdr.voxelSize.y << " " << hdr.voxelSize.z << "\n";
  ofFile << "ElementSpacing = " << hdr.voxelSize.x << " " << hdr.voxelSize.y << " " << hdr.voxelSize.z << "\n";
  ofFile << "ElementDataFile = " << hdr.filenameRaw << "\n";
  ofFile.close();
  // write data
  ofFile.open(hdr.filenameRaw, std::ios::binary);
  if (!ofFile) 
    EchoExit("Could not raw open file '" + hdr.filenameRaw + "' for writing");
  const uint32_t numberOfBytes = sizeof(T) * hdr.voxels.x * hdr.voxels.y * hdr.voxels.z;
  ofFile.write(reinterpret_cast<char*>(image.data()), image.size() * sizeof(T));
  if (ofFile.tellp() != numberOfBytes)
    EchoExit("Number of bytes written does not match header number of voxels");
  ofFile.close();
  }

#define WRITE_IMAGE(TYPE, VOXELS, VOXELSIZE, IMAGE, HDR_FILENAME) \
  { \
  rarray<TYPE,3> t(VOXELS.z, VOXELS.y, VOXELS.x); \
  for (int z = 0; z < VOXELS.z; z++) \
    for (int y = 0; y < VOXELS.y; y++) \
      for (int x = 0; x < VOXELS.x; x++) \
        t[z][y][x] = (TYPE)IMAGE[z][y][x]; \
  WriteMhd3DImage(HDR_FILENAME, t, VOXELS, VOXELSIZE); \
  t.clear(); \
  }

#endif // MISC
