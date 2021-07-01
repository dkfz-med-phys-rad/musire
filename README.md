# *Musiré* ─ multimodal simulation and reconstruction framework for the radiological imaging sciences

Copyright © German Cancer Research Center (DKFZ), <a href="https://www.dkfz.de/en/medphysrad/index.php">Division of Medical Physics in Radiology</a>.<br>

## Author

<a href="./musire.sh">Musire.sh</a> along with its <a href="./tools">helper programs</a> has been developed and written by J. Peter (j.peter@dkfz.de).

## Disclaimer and copyright

Please make sure that your usage of this code is in compliance with the code <a href="./LICENSE">license</a>.

## Overview

Musiré is proposed for managing the execution of simulation and image reconstruction for SPECT, PET, CBCT, MRI, BLI, and FMI packages in single and multimodal biomedical imaging applications.

<p align="center"><img src="./workflow.png"  width="480"></p>

The workflow is composed of a Bash script, the purpose of which being to provide an interface to the user, and to organise data flow between dedicated programs for simulation and reconstruction.

The currently incorporated simulation programs comprise of <a href="http://www.opengatecollaboration.org/">Gate</a> for Monte Carlo simulation of SPECT, PET and CBCT, <a href="https://github.com/spin-scenario/spin-scenario">Spin-Scenario</a> for simulating MRI, and <a href="https://github.com/dkfz-med-phys-rad/lipros">Lipros</a> for Monte Carlo simulation of BLI and FMI.
Currently incorporated image reconstruction programs include <a href="https://www.castor-project.org/">CASToR</a> for SPECT and PET as well as <a href="https://www.openrtk.org/">RTK</a> for CBCT.

MetaImage (mhd) standard is used for voxelized phantom and image data format.
Meshlab project (mlp) containers incorporating polygon meshes and point clouds defined by the Stanford triangle format (ply) are employed to represent anatomical structures for optical simulation, and to represent tumour cell inserts.

A number of auxiliary programs have been developed for data transformation and adaptive parameter assignment.

The software workflow utilizes fully automatic distribution to, and consolidation from, any number of Linux workstations and CPU cores.

<p align="center"><img src="./results-example.png"  width="480"></p>

## Installation

The main script, *musire.sh*, is a Bash script and runs under Linux.

After cloning into some directory, change into ./musire/tools and do
```
make all && make -f makefile-h5 all
```
This compiles all the helper programs in this directory needed by musire.sh.

Make sure that <a href="http://www.opengatecollaboration.org/">Gate</a>, <a href="https://github.com/spin-scenario/spin-scenario">Spin-Scenario</a>, <a href="https://github.com/dkfz-med-phys-rad/lipros">Lipros</a>, <a href="https://www.openrtk.org/">RTK</a> and <a href="https://www.castor-project.org/">CASToR</a> are properly installed depending on your needs.

<a href="https://www.aliza-dicom-viewer.com/">Aliza</a> (mhd), <a href="https://www.meshlab.net">Meshlab</a> (ply) and <a href="https://github.com/derf/feh">feh</a> (png) are called by default in musire.sh for image display. Alternative programs (such as <a href="https://mitk.org">MITK</a> or <a href="http://www.itksnap.org">itksnap</a> for mhd display) might be used (in which case search and replace these binaries in the main function of musire.sh).

## Usage

musire.sh can be called with the following command line arguments:
```
      GateVisualisationOnly
      SimulationOnly
      ReconstructionOnly
      ForwardProjectionSimulation
      NoDisplay
      RemoteHosts=<hosts>
      CpuCores=<int>
      Modality={PET SPECT CBCT MRI BLI FMI}
      GateUserMacFile=<file.mac>
      SpinScenarioUserLuaFile=<file.lua>
      SPECTcameras=<int>
      SPECTcameraRadiusOfRotationXYmm=<float>
      SPECTcameraSizeZmm=<float>
      SPECTcameraSizeYmm=<float>
      SPECTcollimatorType={PB FB CB PH}
      SPECTcollimatorMaterial={Lead Tungsten}
      SPECTcollimatorThicknessXmm=<float>
      SPECTcollimatorHoleType={box cylinder hexagone}
      SPECTcollimatorHoleDiameterZYmm=<float>
      SPECTcollimatorSeptaThicknessZYmm=<float>
      SPECTcrystalThicknessXmm=<float>
      SPECTcrystalMaterial={NaI PWO BGO LSO GSO LuAP YAP Scinti-C9H10 LuYAP-70 LuYAP-80 LYSO}
      SPECTenergyResolutionFWHM=<float>
      SPECTenergyWindowMinKeV=<float>
      SPECTenergyWindowMaxKeV=<float>*<float>
      SPECTtimeResolutionFWHMns=<float>
      SPECTpileupTimens=<float>
      SPECTdeadTimens=<float>
      SPECTlightCrosstalkFraction=<float>
      SPECTreadoutPolicy={BLOCK_PMT_DETECTOR APD_DETECTOR}
      SPECTisotope={Ce139 Co57 Ga67 Gd153 I123 I131 In111 Xe133 Tc99m Te123m Tl201}
      SPECTtimeStartSec=<float>
      SPECTgantryProjections=<int>
      SPECTdetectorPixelSizeX=<float>
      SPECTdetectorPixelSizeY=<float>
      SPECTtimePerProjectionSec=<float>
      PETblockCrystalSizeZmm=<float>
      PETblockCrystalSizeYmm=<float>
      PETblockCrystalThicknessXmm=<float>
      PETblockCrystalsZ=<int>
      PETblockCrystalsY=<int>
      PETblockCrystalGapZYmm=<float>
      PETaspiredMinRingDiameterXYmm=<float>
      PETaspiredMinAxialFOVZmm=<float>
      PETcrystalMaterial={NaI PWO BGO LSO GSO LuAP YAP Scinti-C9H10 LuYAP-70 LuYAP-80 LYSO}
      PETisotope={F18 O15 C11 I124}
      PETtimeStartSec=<float>
      PETtimeStopSec=<float>
      PETcoincidencesPolicy={takeAllGoods takeWinnerOfGoods takeWinnerIfIsGood takeWinnerIfAllAreGoods killAll keepIfOnlyOneGood keepIfAnyIsGood keepIfAllAreGoods killAllIfMultipleGoods}
      PETcoincidencesWindowns=<float>
      PETcoincidencesOffsetns=<float>
      PETcoincidencesMinSectorDifference=<int>
      PETenergyResolutionFWHM=<float>
      PETenergyWindowMinKeV=<float>
      PETenergyWindowMaxKeV=<float>
      PETtimeResolutionFWHMns=<float>
      PETpileupTimens=<float>
      PETdeadTimens=<float>
      PETlightCrosstalkFraction=<float>
      PETreadoutPolicy={BLOCK_PMT_DETECTOR APD_DETECTOR}
      CBCTphotonsPerProjectionBq=<int>
      CBCTsourceVoltageKVp=<int>
      CBCTsourceAlFilterThicknessZmm=<float>
      CBCTsourceToDetectorDistanceZmm=<float>
      CBCTsourceToCORDistanceZmm=<float>
      CBCTdetectorSizeXmm=<float>
      CBCTdetectorSizeYmm=<float>
      CBCTdetectorPixelSizeXmm=<float>
      CBCTdetectorPixelSizeYmm=<float>
      CBCTprojections=<int>
      CBCTprojectionStartDeg=<float>
      CBCTprojectionStopDeg=<float>
      MRIB0T=*<float>
      MRITRms=<float>
      MRITEms=<float>
      MRImaxGradientAmplitudeTm=<float>
      MRImaxGradientSlewRateTms=<float>
      MRIpulseWidth90us=<float>
      MRIfieldOfViewXYmm=<float>
      MRIimageVoxelsXY=<int>
      BLIluciferaseType={GREEN_RLUC WT_FLUC LUC2 RED_FLUC}
      BLIphotonsPerTumorCell=<float>
      BLIfluenceVoxelSizeXYZmm=<float>
      FMIfluorophoreType={Cy55 IRDYE800CW}
      FMIexcitationType={CIRCULAR_UNIFORM CIRCULAR_GAUSSIAN LINEAR_UNIFORM}
      FMIexcitationWavelengthCenternm=<float>
      FMIexcitationWavelengthFwhm=<float>
      FMIexcitationPhotonsPerPosition=<int>
      FMIexcitationPulseDurationps=<int>
      FMIexcitationBeamRadiusmm=<float>
      FMIexcitationBeamLengthmm=<float>
      FMIexcitationBeamWidthmm=<float>
      FMIexcitationAxialPositionsZ=<int>
      FMIexcitationAxialStartPositionZ=<float>
      FMIexcitationAxialStopPositionZ=<float>
      FMIexcitationProjections=<int>
      FMIexcitationProjectionStartDeg=<float>
      FMIexcitationProjectionStopDeg=<float>
      FMItimeFrames=<int>
      FMItimeFrameDurationps=<int>
      FMIfluenceVoxelSizeXYZmm=<float>
      PhantomAtlasMhdFile=<file.mhd>
      PhantomAtlasMlpFile=<file.mlp>
      PhantomMaterialsDatFile=<file.dat>
      PhantomActivitiesDatFile=<file.dat>
      PhantomTotalActivityMBq=<float>
      PhantomSpinMaterialsDatFile=<file.dat>
      PhantomShiftXmm=<float>
      PhantomShiftYmm=<float>
      PhantomShiftZmm=<float>
      PhantomCropMinZ=<int>
      PhantomCropMaxZ=<int>
      PhantomRotateXdeg=<float>
      TumorCellsMhdFile=<file.mhd>
      TumorShiftXmm=<float>
      TumorShiftYmm=<float>
      TumorShiftZmm=<float>
      TumorCellDiametermm=<float>
      TumorMinRelActivity=<float>
      TumorMaxRelActivity=<float>
      TumorMinT1Relaxation=<float>
      TumorMaxT1Relaxation=<float>
      TumorMinT2Relaxation=<float>
      TumorMaxT2Relaxation=<float>
      TumorMaxRelatesToCells=<int>
      ReconOptimizer=<string>
      ReconIterations=<int>
      ReconSubsets=<int>
      ReconIntersectMethod={joseph siddon}
      ReconConvolution=<string>
```

Since this argument list is quite long, aliases might be defined to simplify the use of musire.sh.
Examples are provided in <a href="./musire-aliases.sh">musire-aliases.sh</a>.

### Calling examples

Most of the following calling examples need phantoms and source distribution / tissue parameter files.
These must be provided by the user.

```
musire.sh $HUMAN_BRAIN_PET GateVisualisationOnly # visualisation of cylindrical PET
musire.sh $HUMAN_BRAIN_PET $MIDA_BRAIN_ATLAS GateVisualisationOnly # visualisation of cylindrical PET and phantom
musire.sh $HUMAN_BRAIN_PET $MIDA_BRAIN_ATLAS $TUMOR_A $MIDA_BRAIN_F18_FDG PETtimeStopSec=20
musire.sh Modality=PET GateUserMacFile=$HOME/cate-contrib/imaging/PET/PET_CylindricalPET_System.mac CpuCores=1 # user defined macro
musire.sh $HUMAN_BRAIN_SPECT $TRIONIX_LEHR_PB_COLLIMATOR $MIDA_BRAIN_ATLAS $TUMOR_A $MIDA_BRAIN_Tc99m_TC SPECTtimePerProjectionSec=120
musire.sh Modality=BLI $DIGIMOUSE_7372 $TUMOR_NECROTIC BLIphotonsPerTumorCell=0.1
musire.sh Modality=FMI $DIGIMOUSE_7372 $TUMOR_NECROTIC FMIfluorophoreType=Cy55 FMIexcitationWavelengthCenternm=600 FMIexcitationPhotonsPerPosition=10000 FMIexcitationAxialStartPositionZ=20.0
musire.sh $HUMAN_BRAIN_CBCT $MIDA_BRAIN_ATLAS CBCTphotonsPerProjectionBq=1000000
```

## How to cite this code
Please cite the following publication:

        @article{PETER2021,
        author = "J Peter"
        title = "Musiré: multimodal simulation and reconstruction framework for the radiological imaging sciences",
        journal = "Philosophical Transactions of the Royal Society A",
        issue = "Synergistic tomographic image reconstruction: part 2"
        volume = "379",
        year = "2021",
        issn = "",
        doi = "https://doi.org/",
        url = "http://www.sciencedirect.com/science/article/",
        }





