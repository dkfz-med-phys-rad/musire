// Increase hadd max file size; https://root-forum.cern.ch/t/root-6-04-14-hadd-100gb-and-rootlogon/24581
// compile into shared library with: $ /home/jpeter/opt/root/install/bin/root -b -l -q startup.c+
#include "TTree.h"
int startup() { TTree::SetMaxTreeSize( 1000000000000LL ); return 0; } // set to 1 T
namespace { static int i = startup(); }
// run hadd with: $ LD_PRELOAD=startup_c.so $ROOTSYS/bin/hadd <main.root> <partial???.root>
