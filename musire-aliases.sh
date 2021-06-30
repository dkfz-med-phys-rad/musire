#!/bin/bash
# vim: nospell

# This file defines aliases for musire.sh

# PET systems

export HUMAN_BRAIN_PET="Modality=PET \
                        PETblockCrystalSizeZmm=3.5 \
                        PETblockCrystalSizeYmm=3.5 \
                        PETblockCrystalThicknessXmm=30.0 \
                        PETblockCrystalsZ=8 \
                        PETblockCrystalsY=8 \
                        PETblockCrystalGapZYmm=0.5 \
                        PETaspiredMinRingDiameterXYmm=500 \
                        PETaspiredMinAxialFOVZmm=100"

export MOUSE_TOTAL_BODY_PET="Modality=PET \
                             PETblockCrystalSizeZmm=1.5 \
                             PETblockCrystalSizeYmm=1.5 \
                             PETblockCrystalThicknessXmm=10.0 \
                             PETblockCrystalsZ=20 \
                             PETblockCrystalsY=20 \
                             PETblockCrystalGapZYmm=0.2 \
                             PETaspiredMinRingDiameterXYmm=180.0 \
                             PETaspiredMinAxialFOVZmm=100"

# CBCT systems

export HUMAN_BRAIN_CBCT="Modality=CBCT \
                         CBCTsourceVoltageKVp=120 \
                         CBCTsourceAlFilterThicknessZmm=15.0 \
                         CBCTsourceToCORDistanceZmm=1995.0 \
                         CBCTsourceToDetectorDistanceZmm=2275.0 \
                         CBCTdetectorSizeXmm=175.0 \
                         CBCTdetectorSizeYmm=250.0 \
                         CBCTdetectorPixelSizeXmm=0.5 \
                         CBCTdetectorPixelSizeYmm=0.5"

export MOUSE_TOTAL_BODY_CBCT="Modality=CBCT \
                              CBCTsourceVoltageKVp=40 \
                              CBCTsourceAlFilterThicknessZmm=1.0 \
                              CBCTsourceToCORDistanceZmm=285.0 \
                              CBCTsourceToDetectorDistanceZmm=325.0 \
                              CBCTdetectorSizeXmm=120.0 \
                              CBCTdetectorSizeYmm=100.0 \
                              CBCTdetectorPixelSizeXmm=0.2 \
                              CBCTdetectorPixelSizeYmm=0.2"

# SPECT systems

export HUMAN_BRAIN_SPECT="Modality=SPECT \
                          SPECTcameras=4 \
                          SPECTgantryProjections=30 \
                          SPECTcameraRadiusOfRotationXYmm=150.0 \
                          SPECTcameraSizeZmm=180.0 \
                          SPECTcameraSizeYmm=250.0 \
                          SPECTcrystalMaterial=NaI \
                          SPECTcrystalThicknessXmm=10.0"

export HUMAN_BRAIN_SCINTIGRAPHY="Modality=SPECT \
                                 SPECTcameras=1 \
                                 SPECTgantryProjections=1 \
                                 SimulationOnly \
                                 SPECTcameraRadiusOfRotationXYmm=150.0 \
                                 SPECTcameraSizeZmm=180.0 \
                                 SPECTcameraSizeYmm=250.0 \
                                 SPECTcrystalMaterial=NaI \
                                 SPECTcrystalThicknessXmm=10.0"

export TRIONIX_LEHR_PB_COLLIMATOR="SPECTcollimatorType=PB \
                                   SPECTcollimatorThicknessXmm=27.6 \
                                   SPECTcollimatorSeptaThicknessZYmm=0.182 \
                                   SPECTcollimatorHoleDiameterZYmm=1.38 \
                                   SPECTcollimatorMaterial=Lead \
                                   SPECTcollimatorHoleType=hexagone"

export TRIONIX_LEUR_PB_COLLIMATOR="SPECTcollimatorType=PB \
                                   PECTcollimatorThicknessXmm=35.7 \
                                   SPECTcollimatorSeptaThicknessZYmm=0.156 \
                                   SPECTcollimatorHoleDiameterZYmm=1.38 \
                                   SPECTcollimatorMaterial=Lead \
                                   SPECTcollimatorHoleType=hexagone"

export TRIONIX_LESR_PB_COLLIMATOR="SPECTcollimatorType=PB \
                                   SPECTcollimatorThicknessXmm=45.5 \
                                   SPECTcollimatorSeptaThicknessZYmm=0.156 \
                                   SPECTcollimatorHoleDiameterZYmm=1.38 \
                                   SPECTcollimatorMaterial=Lead \
                                   SPECTcollimatorHoleType=hexagone"

export TRIONIX_MEDE_PB_COLLIMATOR="SPECTcollimatorType=PB \
                                   SPECTcollimatorThicknessXmm=59.0 \
                                   SPECTcollimatorSeptaThicknessZYmm=1.170 \
                                   SPECTcollimatorHoleDiameterZYmm=3.25 \
                                   SPECTcollimatorMaterial=Lead \
                                   SPECTcollimatorHoleType=hexagone"

export SIEMENS_LEAP_PB_COLLIMATOR="SPECTcollimatorType=PB \
                                   SPECTcollimatorThicknessXmm=23.6 \
                                   SPECTcollimatorSeptaThicknessZYmm=0.200 \
                                   SPECTcollimatorHoleDiameterZYmm=1.43 \
                                   SPECTcollimatorMaterial=Lead \
                                   SPECTcollimatorHoleType=hexagone"

export SIEMENS_HRES_PB_COLLIMATOR="SPECTcollimatorType=PB \
                                   SPECTcollimatorThicknessXmm=23.6 \
                                   SPECTcollimatorSeptaThicknessZYmm=0.160 \
                                   SPECTcollimatorHoleDiameterZYmm=1.11 \
                                   SPECTcollimatorMaterial=Lead \
                                   SPECTcollimatorHoleType=hexagone"

export SIEMENS_UHRS_PB_COLLIMATOR="SPECTcollimatorType=PB \
                                   SPECTcollimatorThicknessXmm=35.6 \
                                   SPECTcollimatorSeptaThicknessZYmm=0.150 \
                                   SPECTcollimatorHoleDiameterZYmm=1.08 \
                                   SPECTcollimatorMaterial=Lead \
                                   SPECTcollimatorHoleType=hexagone"

export SIEMENS_MEDE_PB_COLLIMATOR="SPECTcollimatorType=PB \
                                   SPECTcollimatorThicknessXmm=40.6 \
                                   SPECTcollimatorSeptaThicknessZYmm=1.140 \
                                   SPECTcollimatorHoleDiameterZYmm=3.03 \
                                   SPECTcollimatorMaterial=Lead \
                                   SPECTcollimatorHoleType=hexagone"

# MRI systems

export HUMAN_BRAIN_3T_MRI="Modality=MRI \
                           MRIB0T=3 \
                           MRImaxGradientAmplitudeTm=40 \
                           MRImaxGradientSlewRateTms=200 \
                           MRIpulseWidth90us=5 \
                           MRIfieldOfViewXYmm=240 \
                           MRIimageVoxelsXY=256"

export MRI_T1_WEIGHTED="MRITRms=500  MRITEms=15"
export MRI_T2_WEIGHTED="MRITRms=5000 MRITEms=100"
export MRI_PD_WEIGHTED="MRITRms=5000 MRITEms=15"

# BLI system

# In TumorCellsMhdFile, ElementSize and ElementSpacing will be overwritten by TumorCellDiametermm. So, they should be 
# preassigned by the tumor growth program with e.g. 1.0 1.0 1.0

# TumorShiftXmm=11.2 TumorShiftYmm=-3.5 TumorShiftZmm=-32.0
export DIGIMOUSE_7372="PhantomAtlasMlpFile=$HOME/musire/phantoms/digimouse-mesh-skin-7372faces.mlp"
export TUMOR_NECROTIC="TumorCellsMhdFile=$HOME/musire/phantoms/tg-image-at-day-0200-with-0003064960-cells-0025.mhd \
                       TumorCellDiametermm=0.01 \
                       TumorShiftXmm=0.0 \
                       TumorShiftYmm=0.0 \
                       TumorShiftZmm=20.0"

# Phantoms

export MIDA_BRAIN_ATLAS="PhantomAtlasMhdFile=$HOME/musire/phantoms/mida-head-atlas-05mm-z225.mhd \
                         PhantomMaterialsDatFile=$HOME/musire/phantoms/mida-head-atlas-gate-materials.dat"

# Tumors

export TUMOR_A="TumorCellsMhdFile=$HOME/musire/phantoms/tg-image-at-day-0400-with-0000004850-cells.mhd \
                TumorShiftXmm=25.0 \
                TumorShiftYmm=35.0"

export MIDA_BRAIN_F18_FDG="PETisotope=F18 \
                           PhantomActivitiesDatFile=$HOME/musire/phantoms/mida-head-gate-activities-f18-fdg.dat \
                           PhantomTotalActivityMBq=5 \
                           PETtimeStopSec=60"

export MIDA_BRAIN_Tc99m_TC="SPECTisotope=Tc99m \
                            PhantomActivitiesDatFile=$HOME/musire/phantoms/mida-head-gate-activities-Tc99m-tc.dat \
                            PhantomTotalActivityMBq=5 \
                            SPECTtimePerProjectionSec=120"

