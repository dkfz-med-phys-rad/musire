#!/bin/bash
# shellcheck disable=SC2102 disable=SC1090 disable=SC2155 disable=SC1091 disable=SC2129

# +---------------------------------------------------------------------------------------------------------+
# | Musire:  Multimodal Simulation & Reconstruction Framework for Biomedical Imaging                        |
# | Author:  J. Peter (j.peter@dkfz.de)                                                                     |
# | Version: 2021-03-26                                                                                     |
# +---------------------------------------------------------------------------------------------------------+

# misc settings and functions #{{{
set -euTEo pipefail # stricter Bash; prints EchoAbort() information if things go wrong
exec 2>&1           # redirect standard error to standard out (and into a log file)
EchoRd()     { echo -en "\e[1;38;5;124;82m\e[47m$1\e[0m"; }
EchoGn()     { echo -en "\e[38;5;40;82m$1\e[0m"; }
EchoMa()     { echo -en "\e[38;5;207;82m$1\e[0m"; }
EchoYe()     { echo -en "\e[38;5;227;82m$1\e[0m"; }
EchoBl()     { echo -en "\e[38;5;38;82m$1\e[0m"; }
EchoErr()    { >&2 echo -e "\e[1;38;5;124;82m\e[47mERROR: $1\e[0m"; exit 1; }
Log()        { echo "$1" >> "${Script[logFile]}"; }
EchoLog()    { echo "$1" | tee -a "${Script[logFile]}"; }
EchoGnLog()  { EchoGn "$1\n"; echo "$1" >> "${Script[logFile]}"; }
EchoBlLog()  { EchoBl "$1\n"; echo "$1" >> "${Script[logFile]}"; }
EchoWngLog() { EchoYe "WARNING: $1\n"; echo "WARNING: $1" >> "${Script[logFile]}"; }
EchoAbort()  { EchoErr "Aborted at line $1: $2"; }
EchoArray()  { local -n a="$1"; for k in "${!a[@]}"; do printf "$1[%s]=%s\n" "$k" "${a[$k]}" ; done ; }
Bcf()        { printf '%.8f\n' "$(echo "scale=8; $1" | bc -l)"; }
Bci()        { printf '%d\n' "$(echo "scale=0; $1" | bc)"; }
declare -r Pi=$(Bcf "4*a(1)")
GetFloorToInt() { echo "${1%.*}" ; }
GetRoundToInt() { if (( $(echo "$1 >= 0" | bc) )); then GetFloorToInt "$(bc <<< "($1 + .5) / 1")"
                                                   else GetFloorToInt "$(bc <<< "($1 - .5) / 1")"; fi ; }
trap 'EchoAbort ${LINENO} "$BASH_COMMAND"' ERR
[[ "${BASH_VERSINFO[0]}" -lt 5 ]] && EchoErr "Script needs bash >= 5"
#}}}

main() #{{{
  {
  [[ "$(whoami)" != jpeter ]] && AskDisclaimerAndCopyright
  DeclareGlobalVariables "$@"
  ReadCommandLineArgs "$@"
  if [[ -v Script[reconstructionOnly] ]]; then
    ReAssignGlobalVariablesFromPrimalRun
  else
    CheckScriptVars
    [[ -n ${Script[remoteHosts]} ]] && CheckRemoteHosts
    if [[ ! -v Script[gateUserMacFile] && ! -v Script[spinScenarioUserLuaFile] ]]; then
      case "${Script[modality]}" in
        SPECT) CheckSPECTVars;;
        PET)   CheckPETVars;;
        CBCT)  CheckCBCTVars;;
        MRI)   CheckMRIVars;;
        BLI)   CheckBLIVars;;
        FMI)   CheckFMIVars;;
      esac
      CheckPhantomVars
      CheckTumorVars
    fi
    PrepareResources
    if [[ -v Script[gateVisualisationOnly] ]]; then
      WriteGateInterfaceFile
      Gate --qt "${Script[gateInterfaceFile]}" >> /dev/null & disown
    else
      if [[ -v Script[CBCTforwardProjectionSimulation] ]]; then
        RtkCBCTforwardProjectionSimulation
      else
        [[ -v Script[usesGate] && ! -v Script[gateUserMacFile] ]] && WriteGateInterfaceFile
        [[ -n ${Script[remoteHosts]} ]] && DistributeSimulationsToRemoteHosts
        case "${Script[modality]}" in
          SPECT) SPECTGateMonteCarloSimulation;;
          PET)   PETGateMonteCarloSimulation;;
          CBCT)  CBCTGateMonteCarloSimulation;;
          MRI)   MRISpinScenarioSimulation;;
          BLI)   BLILiprosOpticalSimulation;;
          FMI)   FMILiprosOpticalSimulation;;
        esac
        [[ -n ${Script[remoteHosts]} ]] && MergeOutputOfRemoteHostsWithOutputOfLocalHost
      fi
    fi
  fi
  EchoArray Script | sort > Script.vars
  EchoArray "${Script[modality]}" | sort > "${Script[modality]}.vars"
  [[ -v Phantom[atlasMhdFile] || -v Phantom[atlasMlpFile] ]] && { EchoArray Phantom | sort > Phantom.vars; }
  [[ -v Tumor[cellsMhdFile] ]] && { EchoArray Tumor | sort > Tumor.vars; }
  if [[ ("${Script[modality]}" == SPECT || "${Script[modality]}" == PET || "${Script[modality]}" == CBCT) && ! -v Script[gateVisualisationOnly] && ! -v Script[simulationOnly] ]]; then
      CheckReconVars
      EchoArray Recon | sort > Recon.vars
      case "${Script[modality]}" in
        SPECT) SPECTCastorImageReconstruction;;
        PET)   PETCastorImageReconstruction;;
        CBCT)  CBCTRtkImageReconstruction;;
      esac
    fi
  if [[ ! -v Script[noDisplay] ]]; then
    if [[ "$(whoami)" == jpeter ]]; then jp-amide ./*.mhd & disown
                                    else aliza ./*.mhd    & disown; fi
    if [[ ${Script[modality]} =~ BLI|FMI ]]; then
      meshlab "${Phantom[atlasMlpFile]}" 2> /dev/null & disown
      local files="$(ls -tr -- *.png)"
      #shellcheck disable=SC2086
      [[ -z "$files" ]] || feh $files & disown
    fi
  fi
  exit 0
  } #}}}

DeclareGlobalVariables() #{{{
  {
  EchoBl "${FUNCNAME[0]}() ...\n"
  declare -gA Script SPECT PET CBCT MRI BLI FMI Phantom Tumor Recon # all global variables are organized
                                                                    # within these arrays
  # shellcheck disable=SC2124
  Script[invocation]="\"${BASH_SOURCE[0]} ${@}\""
  Script[user]="$(whoami)"
  Script[logFile]=/dev/null # a filename will be assigned once the working dir is known; for now, don't log
  Script[rootDir]="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
  Script[toolsDir]="${Script[rootDir]}/tools"
  Script[remoteHosts]=""
  #Script[remoteHosts]="193.174.63.184"
  } #}}}

ReadCommandLineArgs() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  function GetArg() # helper function to read in command line arguments
    { # $1: 'arg=val'
      # $2: (INT FLOAT STRING FILEIN)
      # optional: if $2 == STRING then $3: string array, else $3, $4: value margins
    local val="${1#*=}" # get val part of 'arg=val'
    # shellcheck disable=SC2199
    case "$2" in
      INT)       [[ ! "$val" =~ ^[+-]?[0-9]+?$ ]] && EchoErr "$1 must be an integer number" ;;
      FLOAT)     [[ ! "$val" =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]] && EchoErr "$1 must be a float number" ;;
      STRING)    [[ $# -eq 3 ]] && { local arr=("$3"); [[ ! " ${arr[@]} " =~ " $val " ]] && EchoErr "$1 must be one of ${arr[*]}"; } ;;
      STRINGADD) [[ -n ${3} ]] && val="$val $3" ;;
      FILEIN)    [[ ! -f "$val" ]] && EchoErr "$1 not found for reading" ;;
    esac
    if [[ "$2" =~ (INT|FLOAT) ]]; then
      for ((i = 3; i <= $#; i++ )); do
        local term
        eval term='$'"$i"
        if [[ "$term" =~ ^\>\=[+-]?[0-9]+([.][0-9]+)?$ ]]; then 
          (( ! $(echo "$val >= ${term:2}" | bc) )) && EchoErr "$1 must be $term"; fi
        if [[ "$term" =~ ^\>[+-]?[0-9]+([.][0-9]+)?$ ]]; then 
          (( ! $(echo "$val >  ${term:1}" | bc) )) && EchoErr "$1 must be $term"; fi
        if [[ "$term" =~ ^\<\=[+-]?[0-9]+([.][0-9]+)?$ ]]; then 
          (( ! $(echo "$val <= ${term:2}" | bc) )) && EchoErr "$1 must be $term"; fi
        if [[ "$term" =~ ^\<[+-]?[0-9]+([.][0-9]+)?$ ]]; then 
          (( ! $(echo "$val <  ${term:1}" | bc) )) && EchoErr "$1 must be $term"; fi
      done
    fi
    echo "$val"
    }
  # Pre-defined resources
  local -ra modalities=( PET SPECT CBCT MRI BLI FMI )
  #local -ra tissueMaterials=( Breast Body Muscle Lung LungMoby SpineBone RibBone Adipose Epidermis
  #                            Hypodermis Blood Heart Tumor Kidney Liver Lymph Pancreas Intestine Skull
  #                            Cartilage Brain Spleen Testis )
  local -ra photonEmittingIsotopes=( Ce139 Co57 Ga67 Gd153 I123 I131 In111 Xe133 Tc99m Te123m Tl201 )
  local -ra positronEmittingIsotopes=( F18 O15 C11 I124 )
  local -ra collimatorTypes=( PB FB CB PH )
  local -ra collimatorMaterials=( Lead Tungsten )
  local -ra scintillatorMaterials=( NaI PWO BGO LSO GSO LuAP YAP Scinti-C9H10 LuYAP-70 LuYAP-80 LYSO )
  local -ra gateReadoutPolicies=( BLOCK_PMT_DETECTOR APD_DETECTOR )
  local -ra gateCoincidencesPolicies=( takeAllGoods takeWinnerOfGoods takeWinnerIfIsGood
                                       takeWinnerIfAllAreGoods killAll keepIfOnlyOneGood keepIfAnyIsGood
                                       keepIfAllAreGoods killAllIfMultipleGoods )
  local -ra gateVolumeShapes=( box sphere cylinder ellipsoid cone hexagone trap trpd wedge tessellated
                               TetMeshBox )
  local -ra fluorophoreTypes=( Cy55 IRDYE800CW )
  local -ra luciferaseTypes=( GREEN_RLUC WT_FLUC LUC2 RED_FLUC )
  local -ra fmiSourceTypes=( CIRCULAR_UNIFORM CIRCULAR_GAUSSIAN LINEAR_UNIFORM )
  local -ra intersectMethods=( joseph siddon )
  # Read command line arguments
  for arg in "$@"; do
    case $arg in
      -v|GateVisualisationOnly*) Script[gateVisualisationOnly]=true;;
      -s|SimulationOnly*) Script[simulationOnly]=true;;
      -r|ReconstructionOnly*) Script[reconstructionOnly]=true;;
      -f|ForwardProjectionSimulation*) Script[CBCTforwardProjectionSimulation]=true;;
      -d|NoDisplay*) Script[noDisplay]=true;;
      RemoteHosts=*) Script[remoteHosts]="$(GetArg "$arg" STRINGADD "${Script[remoteHosts]}")";;
      CpuCores=*) Script[cpuCores]="$(GetArg "$arg" INT ">0")";;
      Modality=*) Script[modality]="$(GetArg "$arg" STRING "${modalities[*]}")";;
      GateUserMacFile=*) Script[gateUserMacFile]="$(GetArg "$arg" FILEIN)";;
      SpinScenarioUserLuaFile=*) Script[spinScenarioUserLuaFile]="$(GetArg "$arg" FILEIN)";;
      SPECTcameras=*) SPECT[cameras]="$(GetArg "$arg" INT ">0")";;
      SPECTcameraRadiusOfRotationXYmm=*) SPECT[cameraRadiusOfRotationXYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTcameraSizeZmm=*) SPECT[cameraSizeZmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTcameraSizeYmm=*) SPECT[cameraSizeYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTcollimatorType=*) SPECT[collimatorType]="$(GetArg "$arg" STRING "${collimatorTypes[*]}")";;
      SPECTcollimatorMaterial=*) SPECT[collimatorMaterial]="$(GetArg "$arg" STRING "${collimatorMaterials[*]}")";;
      SPECTcollimatorThicknessXmm=*) SPECT[collimatorThicknessXmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTcollimatorHoleType=*) SPECT[collimatorHoleType]="$(GetArg "$arg" STRING "${gateVolumeShapes[*]}")";;
      SPECTcollimatorHoleDiameterZYmm=*) SPECT[collimatorHoleDiameterZYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTcollimatorSeptaThicknessZYmm=*) SPECT[collimatorSeptaThicknessZYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTcrystalThicknessXmm=*) SPECT[crystalThicknessXmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTcrystalMaterial=*) SPECT[crystalMaterial]="$(GetArg "$arg" STRING "${scintillatorMaterials[*]}")";;
      SPECTenergyResolutionFWHM=*) SPECT[energyResolutionFWHM]="$(GetArg "$arg" FLOAT ">=0.0" "<=1.0")";;
      SPECTenergyWindowMinKeV=*) SPECT[energyWindowMinKeV]="$(GetArg "$arg" FLOAT ">=0.0")";;
      SPECTenergyWindowMaxKeV=*) SPECT[energyWindowMaxKeV]="$(GetArg "$arg" FLOAT ">=0.0")";;
      SPECTtimeResolutionFWHMns=*) SPECT[timeResolutionFWHMns]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTpileupTimens=*) SPECT[pileupTimens]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTdeadTimens=*) SPECT[deadTimens]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTlightCrosstalkFraction=*) SPECT[lightCrosstalkFraction]="$(GetArg "$arg" FLOAT ">=0.0" "<=1.0")";;
      SPECTreadoutPolicy=*) SPECT[readoutPolicy]="$(GetArg "$arg" STRING "${gateReadoutPolicies[*]}")";;
      SPECTisotope=*) SPECT[isotope]="$(GetArg "$arg" STRING "${photonEmittingIsotopes[*]}")";;
      SPECTtimeStartSec=*) SPECT[timeStartSec]="$(GetArg "$arg" FLOAT ">=0.0")";;
      SPECTgantryProjections=*) SPECT[gantryProjections]="$(GetArg "$arg" INT ">0")";; # *cameras=total projections
      SPECTdetectorPixelSizeX=*) SPECT[detectorPixelSizeX]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTdetectorPixelSizeY=*) SPECT[detectorPixelSizeY]="$(GetArg "$arg" FLOAT ">0.0")";;
      SPECTtimePerProjectionSec=*) SPECT[timePerProjectionSec]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETblockCrystalSizeZmm=*) PET[crystalSizeZmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETblockCrystalSizeYmm=*) PET[crystalSizeYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETblockCrystalThicknessXmm=*) PET[crystalThicknessXmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETblockCrystalsZ=*) PET[crystalsPerBlockZ]="$(GetArg "$arg" INT ">0")";;
      PETblockCrystalsY=*) PET[crystalsPerBlockY]="$(GetArg "$arg" INT ">0")";;
      PETblockCrystalGapZYmm=*) PET[crystalGapZYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETaspiredMinRingDiameterXYmm=*) PET[aspiredMinRingDiameterXYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETaspiredMinAxialFOVZmm=*) PET[aspiredMinAxialFOVZmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETcrystalMaterial=*) PET[crystalMaterial]="$(GetArg "$arg" STRING "${scintillatorMaterials[*]}")";;
      PETisotope=*) PET[isotope]="$(GetArg "$arg" STRING "${positronEmittingIsotopes[*]}")";;
      PETtimeStartSec=*) PET[timeStartSec]="$(GetArg "$arg" FLOAT ">=0.0")";;
      PETtimeStopSec=*) PET[timeStopSec]="$(GetArg "$arg" FLOAT ">=0.0")";;
      PETcoincidencesPolicy=*) PET[coincidencesPolicy]="$(GetArg "$arg" STRING "${gateCoincidencesPolicies[*]}")";;
      PETcoincidencesWindowns=*) PET[coincidencesWindowns]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETcoincidencesOffsetns=*) PET[coincidencesOffsetns]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETcoincidencesMinSectorDifference=*) PET[coincidencesMinSectorDifference]="$(GetArg "$arg" INT ">=2")";;
      PETenergyResolutionFWHM=*) PET[energyResolutionFWHM]="$(GetArg "$arg" FLOAT ">=0.0" "<=1.0")";;
      PETenergyWindowMinKeV=*) PET[energyWindowMinKeV]="$(GetArg "$arg" FLOAT ">=0.0")";;
      PETenergyWindowMaxKeV=*) PET[energyWindowMaxKeV]="$(GetArg "$arg" FLOAT ">=0.0")";;
      PETtimeResolutionFWHMns=*) PET[timeResolutionFWHMns]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETpileupTimens=*) PET[pileupTimens]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETdeadTimens=*) PET[deadTimens]="$(GetArg "$arg" FLOAT ">0.0")";;
      PETlightCrosstalkFraction=*) PET[lightCrosstalkFraction]="$(GetArg "$arg" FLOAT ">=0.0" "<=1.0")";;
      PETreadoutPolicy=*) PET[readoutPolicy]="$(GetArg "$arg" STRING "${gateReadoutPolicies[*]}")";;
      CBCTphotonsPerProjectionBq=*) CBCT[photonsPerProjectionBq]="$(GetArg "$arg" INT ">=0")";;
      CBCTsourceVoltageKVp=*) CBCT[sourceVoltageKVp]="$(GetArg "$arg" INT ">=10" "<=120")";;
      CBCTsourceAlFilterThicknessZmm=*) CBCT[sourceAlFilterThicknessZmm]="$(GetArg "$arg" FLOAT ">=0.0")";;
      CBCTsourceToDetectorDistanceZmm=*) CBCT[sourceToDetectorDistanceZmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      CBCTsourceToCORDistanceZmm=*) CBCT[sourceToCenterOfRotationDistanceZmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      CBCTdetectorSizeXmm=*) CBCT[detectorSizeXmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      CBCTdetectorSizeYmm=*) CBCT[detectorSizeYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      CBCTdetectorPixelSizeXmm=*) CBCT[detectorPixelSizeXmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      CBCTdetectorPixelSizeYmm=*) CBCT[detectorPixelSizeYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      CBCTprojections=*) CBCT[projections]="$(GetArg "$arg" INT ">0")";;
      CBCTprojectionStartDeg=*) CBCT[projectionStartDeg]="$(GetArg "$arg" FLOAT ">=0.0" "<360.0")";;
      CBCTprojectionStopDeg=*) CBCT[projectionStopDeg]="$(GetArg "$arg" FLOAT ">=0.0" "<=360")";;
      MRIB0T=*) MRI[B0T]="$(GetArg "$arg" FLOAT ">0.0")";;
      MRITRms=*) MRI[TRms]="$(GetArg "$arg" FLOAT ">0.0")";;
      MRITEms=*) MRI[TEms]="$(GetArg "$arg" FLOAT ">0.0")";;
      MRImaxGradientAmplitudeTm=*) MRI[MaxGradientAmplitudeTm]="$(GetArg "$arg" FLOAT ">0.0")";;
      MRImaxGradientSlewRateTms=*) MRI[MaxGradientSlewRateTms]="$(GetArg "$arg" FLOAT ">0.0")";;
      MRIpulseWidth90us=*) MRI[pulseWidth90us]="$(GetArg "$arg" FLOAT ">0.0")";;
      MRIfieldOfViewXYmm=*) MRI[fieldOfViewXYmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      MRIimageVoxelsXY=*) MRI[imageVoxelsXY]="$(GetArg "$arg" INT ">0")";;
      BLIluciferaseType=*) BLI[luciferaseType]="$(GetArg "$arg" STRING "${luciferaseTypes[*]}")";;
      BLIphotonsPerTumorCell=*) BLI[photonsPerTumorCell]="$(GetArg "$arg" FLOAT ">0.0")";;
      BLIfluenceVoxelSizeXYZmm=*) BLI[fluenceVoxelSizeXYZmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      FMIfluorophoreType=*) FMI[fluorophoreType]="$(GetArg "$arg" STRING "${fluorophoreTypes[*]}")";;
      FMIexcitationType=*) FMI[excitationType]="$(GetArg "$arg" STRING "${fmiSourceTypes[*]}")";;
      FMIexcitationWavelengthCenternm=*) FMI[excitationWavelengthCenternm]="$(GetArg "$arg" FLOAT ">=600.0" "<=900.0")";;
      FMIexcitationWavelengthFwhm=*) FMI[excitationWavelengthFwhm]="$(GetArg "$arg" FLOAT ">=0.0")";;
      FMIexcitationPhotonsPerPosition=*) FMI[excitationPhotonsPerPosition]="$(GetArg "$arg" INT ">0")";;
      FMIexcitationPulseDurationps=*) FMI[excitationPulseDurationps]="$(GetArg "$arg" INT ">0")";;
      FMIexcitationBeamRadiusmm=*) FMI[excitationBeamRadiusmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      FMIexcitationBeamLengthmm=*) FMI[excitationBeamLengthmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      FMIexcitationBeamWidthmm=*) FMI[excitationBeamWidthmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      FMIexcitationAxialPositionsZ=*) FMI[excitationAxialPositionsZ]="$(GetArg "$arg" INT ">0")";;
      FMIexcitationAxialStartPositionZ=*) FMI[excitationAxialStartPositionZ]="$(GetArg "$arg" FLOAT ">0.0")";;
      FMIexcitationAxialStopPositionZ=*) FMI[excitationAxialStopPositionZ]="$(GetArg "$arg" FLOAT ">0.0")";;
      FMIexcitationProjections=*) FMI[excitationProjections]="$(GetArg "$arg" INT ">0")";;
      FMIexcitationProjectionStartDeg=*) FMI[excitationProjectionStartDeg]="$(GetArg "$arg" FLOAT ">=0.0" "<360.0")";;
      FMIexcitationProjectionStopDeg=*) FMI[excitationProjectionStopDeg]="$(GetArg "$arg" FLOAT ">=0.0" "<360.0")";;
      FMItimeFrames=*) FMI[timeFrames]="$(GetArg "$arg" INT ">0")";;
      FMItimeFrameDurationps=*) FMI[timeFrameDurationps]="$(GetArg "$arg" INT ">0")";;
      FMIfluenceVoxelSizeXYZmm=*) FMI[fluenceVoxelSizeXYZmm]="$(GetArg "$arg" FLOAT ">0.0")";;
      PhantomAtlasMhdFile=*) Phantom[atlasMhdFile]="$(GetArg "$arg" FILEIN)";;
      PhantomAtlasMlpFile=*) Phantom[atlasMlpFile]="$(GetArg "$arg" FILEIN)";;
      PhantomMaterialsDatFile=*) Phantom[materialsDatFile]="$(GetArg "$arg" FILEIN)";;
      PhantomActivitiesDatFile=*) Phantom[activitiesDatFile]="$(GetArg "$arg" FILEIN)";;
      PhantomTotalActivityMBq=*) Phantom[totalActivityMBq]="$(GetArg "$arg" FLOAT ">0.0")";;
      PhantomSpinMaterialsDatFile=*) Phantom[spinMaterialsDatFile]="$(GetArg "$arg" FILEIN)";;
      PhantomShiftXmm=*) Phantom[shiftXmm]="$(GetArg "$arg" FLOAT)";;
      PhantomShiftYmm=*) Phantom[shiftYmm]="$(GetArg "$arg" FLOAT)";;
      PhantomShiftZmm=*) Phantom[shiftZmm]="$(GetArg "$arg" FLOAT)";;
      PhantomCropMinZ=*) Phantom[cropMinZ]="$(GetArg "$arg" INT ">0")";;
      PhantomCropMaxZ=*) Phantom[cropMaxZ]="$(GetArg "$arg" INT ">0")";;
      PhantomRotateXdeg=*) Phantom[rotateXdeg]="$(GetArg "$arg" FLOAT)";;
      TumorCellsMhdFile=*) Tumor[cellsMhdFile]="$(GetArg "$arg" FILEIN)";;
      TumorShiftXmm=*) Tumor[shiftXmm]="$(GetArg "$arg" FLOAT)";;
      TumorShiftYmm=*) Tumor[shiftYmm]="$(GetArg "$arg" FLOAT)";;
      TumorShiftZmm=*) Tumor[shiftZmm]="$(GetArg "$arg" FLOAT)";;
      TumorCellDiametermm=*) Tumor[cellDiametermm]="$(GetArg "$arg" FLOAT ">0.0")";;
      TumorMinRelActivity=*) Tumor[minRelActivity]="$(GetArg "$arg" FLOAT ">0.0")";;
      TumorMaxRelActivity=*) Tumor[maxRelActivity]="$(GetArg "$arg" FLOAT ">0.0")";;
      TumorMinT1Relaxation=*) Tumor[minT1Relaxation]="$(GetArg "$arg" FLOAT ">0.0")";;
      TumorMaxT1Relaxation=*) Tumor[maxT1Relaxation]="$(GetArg "$arg" FLOAT ">0.0")";;
      TumorMinT2Relaxation=*) Tumor[minT2Relaxation]="$(GetArg "$arg" FLOAT ">0.0")";;
      TumorMaxT2Relaxation=*) Tumor[maxT2Relaxation]="$(GetArg "$arg" FLOAT ">0.0")";;
      TumorMaxRelatesToCells=*) Tumor[maxRelatesToCells]="$(GetArg "$arg" INT ">0")";;
      ReconOptimizer=*) Recon[optimizer]="$(GetArg "$arg" STRING)";;
      ReconIterations=*) Recon[iterations]="$(GetArg "$arg" INT ">0")";;
      ReconSubsets=*) Recon[subsets]="$(GetArg "$arg" INT ">0")";;
      ReconIntersectMethod=*) Recon[intersectMethod]="$(GetArg "$arg" STRING "${intersectMethods[*]}")";;
      ReconConvolution=*) Recon[convolution]="$(GetArg "$arg" STRING)";;
      *) EchoErr "Wrong argument '${arg%=*}'";;
    esac
  done
  } #}}}

ReAssignGlobalVariablesFromPrimalRun() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  source Script.vars
  Script[reconstructionOnly]=true
  [[ ! "${Script[modality]}" =~ SPECT|PET|CBCT ]] &&EchoError "No ReconstructionOnly for ${Script[modality]}"
  : "${Script[cpuCores]:=$(grep -c processor /proc/cpuinfo)}"
  [[ "${Script[modality]}" =~ SPECT ]] && source SPECT.vars
  [[ "${Script[modality]}" =~ PET ]]   && source PET.vars
  [[ "${Script[modality]}" =~ CBCT ]]  && source CBCT.vars
  source Phantom.vars
  [[ -v Tumor[cellsMhdFile] ]] && source Tumor.vars
  # create a directory and save previous reconstruction results into it
  local oldReconDir=reco-results-$(date '+%Y-%m-%d-%H-%M-%S')
  mkdir "$oldReconDir"
  mv reco-output* Recon.vars "$oldReconDir"
  # source Recon.vars   <-- Recon is not sourced; so defaults are used if not given as options
  } #}}}

CheckScriptVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  [[ ! -v Script[modality] ]] && EchoErr "Modality is needed"
  [[ -v Script[gateVisualisationOnly] && ! "${Script[modality]}" =~ SPECT|PET|CBCT ]] && EchoErr "GateVisualisationOnly valid only for SPECT|PET|CBCT"
  [[ -v Script[CBCTforwardProjectionSimulation] && "${Script[modality]}" != CBCT ]] && EchoErr "ForwardProjectionSimulation valid only for CBCT"
  : "${Script[cpuCores]:=$(grep -c processor /proc/cpuinfo)}"
  Script[totalThreads]=${Script[cpuCores]}
  [[ -n "${Script[remoteHosts]}" ]] && Script[remoteScript]="$(basename -- "${BASH_SOURCE[0]%.*}")-remote.sh"
  #Script[simulateScatteredPhotonsInPhantomSD]=true # un-comment if scattered physics in the phantom
  #Script[simulateScatteredPhotonsInCrystal]=true   # is to be simulated
  [[ -v Script[gateUserMacFile] && ! "${Script[modality]}" =~ SPECT|PET|CBCT ]] && EchoErr "GateUserMacFile valid only for SPECT|PET|CBCT"
  [[ -v Script[spinScenarioUserLuaFile] && ! "${Script[modality]}" =~ MRI ]] && EchoErr "SpinScenarioUserLuaFile valid only for MRI"
  if [[ "${Script[modality]}" =~ CBCT && ! -v Script[CBCTforwardProjectionSimulation] || "${Script[modality]}" =~ SPECT|PET ]]; then
    Script[usesGate]=true
    Script[gateInterfaceFile]=gate-interface.mac
    Script[gateOutputBaseFile]=gate-output
  elif [[ "${Script[modality]}" =~ MRI ]]; then
    Script[usesSpinScenario]=true
    Script[spinScenarioInterfaceFile]="spinScenario-interface.lua"
  fi
  } #}}}

CheckSPECTVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  [[ ! -v SPECT[cameraRadiusOfRotationXYmm] ]] && EchoErr "SPECTcameraRadiusOfRotationXYmm is needed"
  [[ ! -v SPECT[cameraSizeZmm] ]] && EchoErr "SPECTcameraSizeZmm is needed"
  [[ ! -v SPECT[cameraSizeYmm] ]] && EchoErr "SPECTcameraSizeYmm is needed"
  [[ ! -v SPECT[collimatorType] ]] && EchoErr "SPECTcollimatorType is needed"
  [[ ! ${SPECT[collimatorType]} =~ PB ]] && EchoErr "SPECTcollimatorType must be PB" # TODO: FB, CB, PH
  [[ ! -v SPECT[collimatorThicknessXmm] ]] && EchoErr "SPECTcollimatorThicknessXmm is needed"
  [[ ! -v SPECT[collimatorHoleDiameterZYmm] ]] && EchoErr "SPECTcollimatorHoleDiameterZYmm is needed"
  [[ ! -v SPECT[collimatorSeptaThicknessZYmm] ]] && EchoErr "SPECTcollimatorSeptaThicknessZYmm is needed"
  [[ ! -v SPECT[crystalThicknessXmm] ]] && EchoErr "SPECTcrystalThicknessXmm is needed"
  [[ ! -v SPECT[timePerProjectionSec] ]] && EchoErr "SPECTtimePerProjectionSec is needed"
  [[ ! -v SPECT[isotope] && ! -v Script[gateVisualisationOnly] ]] && EchoErr "SPECTisotope is needed"
  case ${SPECT[isotope]} in             # significant energy lines keV(p)
    "Ce139")  SPECT[isotopeEnergyKeV]=165.85
             : "${SPECT[energyWindowMinKeV]:=158}"
             : "${SPECT[energyWindowMaxKeV]:=182}" ;;
    "Co57")   SPECT[isotopeEnergyKeV]=122.06
             : "${SPECT[energyWindowMinKeV]:=116}"
             : "${SPECT[energyWindowMaxKeV]:=134}" ;;
    "Ga67")   SPECT[isotopeEnergyKeV]=93.31
             : "${SPECT[energyWindowMinKeV]:=89}"
             : "${SPECT[energyWindowMaxKeV]:=102}" ;;
    "Gd153")  SPECT[isotopeEnergyKeV]=97.43
             : "${SPECT[energyWindowMinKeV]:=93}"
             : "${SPECT[energyWindowMaxKeV]:=107}" ;;
    "I123")   SPECT[isotopeEnergyKeV]=158.97
             : "${SPECT[energyWindowMinKeV]:=151}"
             : "${SPECT[energyWindowMaxKeV]:=175}" ;;
    "I131")   SPECT[isotopeEnergyKeV]=364.48
             : "${SPECT[energyWindowMinKeV]:=346}"
             : "${SPECT[energyWindowMaxKeV]:=400}" ;;
    "In111")  SPECT[isotopeEnergyKeV]=245.35
             : "${SPECT[energyWindowMinKeV]:=233}"
             : "${SPECT[energyWindowMaxKeV]:=269}" ;;
    "Xe133")  SPECT[isotopeEnergyKeV]=81.0
             : "${SPECT[energyWindowMinKeV]:=77}"
             : "${SPECT[energyWindowMaxKeV]:=89}" ;;
    "Tc99m")  SPECT[isotopeEnergyKeV]=140.51
             : "${SPECT[energyWindowMinKeV]:=100}"    # 133
             : "${SPECT[energyWindowMaxKeV]:=160}" ;; #154
    "Te123m") SPECT[isotopeEnergyKeV]=159.0
             : "${SPECT[energyWindowMinKeV]:=151}"
             : "${SPECT[energyWindowMaxKeV]:=175}" ;;
    "Tl201")  SPECT[isotopeEnergyKeV]=167.43
             : "${SPECT[energyWindowMinKeV]:=163}"
             : "${SPECT[energyWindowMaxKeV]:=184}" ;;
  esac
  : "${SPECT[cameras]:=4}"
  : "${SPECT[collimatorMaterial]:=Lead}"
  : "${SPECT[collimatorHoleType]:=hexagone}"
  : "${SPECT[crystalMaterial]:=NaI}"
  : "${SPECT[energyResolutionFWHM]:=10.0}" # TODO: dep. on ${SPECT[crystalMaterial]}
  : "${SPECT[readoutPolicy]:=APD_DETECTOR}"
  : "${SPECT[timeStartSec]:=0.0}"
  : "${SPECT[gantryProjections]:=$(Bcf "120 / ${SPECT[cameras]}")}"
  : "${SPECT[detectorPixelSizeX]:=1.0}"
  : "${SPECT[detectorPixelSizeY]:=${SPECT[detectorPixelSizeX]}}"
  # SPECT[timeResolutionFWHMns]=
  # SPECT[pileupTimens]=
  # SPECT[deadTimens]=
  # SPECT[lightCrosstalkFraction]=
  SPECT[detectorPixelsX]=$(GetRoundToInt "$(Bcf "${SPECT[cameraSizeYmm]} / ${SPECT[detectorPixelSizeX]}")")
  SPECT[detectorPixelsY]=$(GetRoundToInt "$(Bcf "${SPECT[cameraSizeZmm]} / ${SPECT[detectorPixelSizeY]}")")
  } #}}}

CheckPETVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  [[ ! -v PET[crystalSizeZmm] ]] && EchoErr "PETblockCrystalSizeZmm is needed"
  [[ ! -v PET[crystalSizeYmm] ]] && EchoErr "PETblockCrystalSizeYmm is needed"
  [[ ! -v PET[crystalThicknessXmm] ]] && EchoErr "PETblockCrystalThicknessXmm is needed"
  [[ ! -v PET[crystalsPerBlockZ] ]] && EchoErr "PETblockCrystalsZ is needed"
  [[ ! -v PET[crystalsPerBlockY] ]] && EchoErr "PETblockCrystalsY is needed"
  [[ ! -v PET[aspiredMinRingDiameterXYmm] ]] && EchoErr "PETaspiredMinRingDiameterXYmm is needed"
  [[ ! -v PET[aspiredMinAxialFOVZmm] ]] && EchoErr "PETaspiredMinAxialFOVZmm is needed"
  [[ ! -v PET[isotope] && ! -v Script[gateVisualisationOnly] ]] && EchoErr "PETisotope is needed"
  [[ ! -v PET[timeStopSec] && ! -v Script[gateVisualisationOnly] ]] && EchoErr "PETtimeStopSec is needed"
  : "${PET[crystalGapZYmm]:=$(Bcf "${PET[crystalSizeZmm] / 10.0}")}"
  : "${PET[crystalMaterial]:=LSO}"
  : "${PET[energyResolutionFWHM]:=15.0}"  # TODO: dep. on ${PET[crystalMaterial]
  : "${PET[timeStartSec]:=0.0}"
  : "${PET[coincidencesPolicy]:=takeWinnerOfGoods}"
  : "${PET[coincidencesOffsetns]:=500.0}"
  : "${PET[coincidencesWindowns]:=10.0}"
  : "${PET[coincidencesMinSectorDifference]:=2}"
  : "${PET[energyWindowMinKeV]:=350.0}"
  : "${PET[energyWindowMaxKeV]:=650.0}"
  : "${PET[readoutPolicy]:=APD_DETECTOR}"
  : "${PET[isotopeEnergyKeV]:=511.0}"
  # PET[timeResolutionFWHMns]=
  # PET[pileupTimens]=
  # PET[deadTimens]=
  # PET[lightCrosstalkFraction]=
  PET[blockSizeZmm]=$(Bcf "${PET[crystalsPerBlockZ]} * (${PET[crystalSizeZmm]} + ${PET[crystalGapZYmm]})")
  PET[blockSizeYmm]=$(Bcf "${PET[crystalsPerBlockY]} * (${PET[crystalSizeYmm]} + ${PET[crystalGapZYmm]})")
  PET[blockSizeXmm]=$(Bcf "${PET[crystalThicknessXmm]} + ${PET[crystalGapZYmm]}")
  local -i blocksPerRingXY=3
  while true; do
    local t=$(Bcf "$Pi / $blocksPerRingXY")
    PET[ringDiameterXYmm]=$(Bcf "${PET[blockSizeYmm]} / (s($t)/c($t))")
    PET[ringCircumDiameterXYmm]=$(Bcf "2 * ((0.5 * ${PET[ringDiameterXYmm]} + ${PET[blockSizeXmm]}) / c($t))")
    (( $(echo "${PET[ringDiameterXYmm]} >= ${PET[aspiredMinRingDiameterXYmm]}" | bc) )) && break
    blocksPerRingXY+=1
  done
  local -i axialBlocksZ=1
  while true; do
    PET[axialFOVZmm]=$(Bcf "$axialBlocksZ * ${PET[blockSizeZmm]}")
    (( $(echo "${PET[axialFOVZmm]} >= ${PET[aspiredMinAxialFOVZmm]}" | bc) )) && break
    axialBlocksZ+=1
  done
  PET[blocksPerRingXY]=$blocksPerRingXY
  PET[axialBlocksZ]=$axialBlocksZ
  } #}}}

CheckCBCTVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  [[ ! -v CBCT[detectorSizeXmm] ]] && EchoErr "CBCTdetectorSizeXmm is needed"
  [[ ! -v CBCT[detectorSizeYmm] ]] && EchoErr "CBCTdetectorSizeYmm is needed"
  [[ ! -v CBCT[detectorPixelSizeXmm] ]] && EchoErr "CBCTdetectorPixelSizeXmm is needed"
  [[ ! -v CBCT[detectorPixelSizeYmm] ]] && EchoErr "CBCTdetectorPixelSizeYmm is needed"
  [[ ! -v CBCT[sourceToDetectorDistanceZmm] ]] && EchoErr "CBCTsourceT; fioDetectorDistanceZmm is needed"
  [[ ! -v CBCT[sourceToCenterOfRotationDistanceZmm] ]] && EchoErr "CBCTsourceToCORDistanceZmm is needed"
  [[ ! -v CBCT[sourceVoltageKVp] && ! -v Script[gateVisualisationOnly] ]] && EchoErr "CBCTsourceVoltageKVp is needed"
  [[ ! -v CBCT[sourceAlFilterThicknessZmm] && ! -v Script[gateVisualisationOnly] ]] && EchoErr "CBCTsourceAlFilter...Zmm is needed"
  [[ ! -v CBCT[photonsPerProjectionBq] && ! -v Script[gateVisualisationOnly] ]] && EchoErr "CBCTphotonsPerProjectionBq is needed"
  : "${CBCT[projections]:=400}"
  : "${CBCT[projectionStartDeg]:=0.0}"
  : "${CBCT[projectionStopDeg]:=360.0}"
  if [[ ! -v Script[CBCTforwardProjectionSimulation] ]]; then
    CBCT[photonsPerProjectionBq]=$(GetRoundToInt "$(Bcf "${CBCT[photonsPerProjectionBq]} * ${CBCT[projections]}")")
    CBCT[projectionsMhdFile]=gate-simulation-projections.mhd # TODO should be Script[gateOutputBaseFile]
  else
    CBCT[projectionsMhdFile]=ftk-forward-projections.mhd
  fi
  CBCT[detectorPixelsX]=$(GetRoundToInt "$(Bcf "${CBCT[detectorSizeXmm]} / ${CBCT[detectorPixelSizeXmm]}")")
  CBCT[detectorPixelsY]=$(GetRoundToInt "$(Bcf "${CBCT[detectorSizeYmm]} / ${CBCT[detectorPixelSizeYmm]}")")
  CBCT[projectionAngleStepDeg]=$(Bcf "(${CBCT[projectionStopDeg]} - ${CBCT[projectionStartDeg]}) / ${CBCT[projections]}")/
  } #}}}

CheckMRIVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  [[ ! -v MRI[B0T] ]]             && EchoErr "MRIB0T is needed"
  [[ ! -v MRI[TRms] ]]            && EchoErr "MRITRms is needed"
  [[ ! -v MRI[TEms] ]]            && EchoErr "MRITEms is needed"
  [[ ! -v MRI[fieldOfViewXYmm] ]] && EchoErr "MRIfieldOfViewXYmm is needed" # 240 for MIDA phantom
  : "${MRI[MaxGradientAmplitudeTm]:=40}"
  : "${MRI[MaxGradientSlewRateTms]:=200}"
  : "${MRI[pulseWidth90us]:=5}"
  : "${MRI[imageVoxelsXY]:=256}"
  } #}}}

CheckBLIVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  : "${BLI[luciferaseType]:=RED_FLUC}"
  : "${BLI[photonsPerTumorCell]:=1}"
  : "${BLI[fluenceVoxelSizeXYZmm]:=0.2}"
  } #}}}

CheckFMIVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  [[ ! -v FMI[fluorophoreType] ]] && EchoErr "FMIfluorophoreType is needed"
  : "${FMI[excitationType]:=CIRCULAR_UNIFORM}"
  [[ ! -v FMI[excitationWavelengthCenternm] ]] && EchoErr "FMIexcitationWavelengthCenternm is needed"
  : "${FMI[excitationWavelengthFwhm]:=10}"
  : "${FMI[excitationPhotonsPerPosition]:=1000000}"
  : "${FMI[excitationPulseDurationps]:=1}"
  [[ "${FMI[excitationType]}" != LINEAR_UNIFORM ]] && : "${FMI[excitationBeamRadiusmm]:=0.5}"
  [[ "${FMI[excitationType]}" != LINEAR_UNIFORM ]] && : "${FMI[excitationBeamLengthmm]:=100.0}"
  [[ "${FMI[excitationType]}" != LINEAR_UNIFORM ]] && : "${FMI[excitationBeamWidthmm]:=5.0}"
  : "${FMI[excitationAxialPositionsZ]:=1}"
  : "${FMI[excitationAxialStartPositionZ]:=0.0}"
  : "${FMI[excitationAxialStopPositionZ]:=${FMI[excitationAxialStartPositionZ]}}"
  : "${FMI[excitationProjections]:=30}"
  : "${FMI[excitationProjectionStartDeg]:=0}"
  : "${FMI[excitationProjectionStopDeg]:=360}"
  : "${FMI[timeFrames]:=5}"
  : "${FMI[timeFrameDurationps]:=100}"
  : "${FMI[fluenceVoxelSizeXYZmm]:=0.2}" # crashes when set to 0.1
  } #}}}

CheckPhantomVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  [[ -v Script[gateVisualisationOnly] && ! -v Phantom[atlasMhdFile] ]] && return
  [[ "${Script[modality]}" =~ SPECT|PET|CBCT && ! -v Phantom[atlasMhdFile] ]] && EchoErr "PhantomAtlasMhdFile is needed"
  [[ "${Script[modality]}" =~ BLI|FMI        && ! -v Phantom[atlasMlpFile] ]] && EchoErr "PhantomAtlasMlpFile is needed"
  case "${Script[modality]}" in
    SPECT|PET|CBCT)
      [[ ! -v Phantom[materialsDatFile] && ! -v Script[CBCTforwardProjectionSimulation] ]] &&
        EchoErr "PhantomMaterialsDatFile is needed"
      if [[ ! -v Script[gateVisualisationOnly] && "${Script[modality]}" =~ SPECT|PET ]]; then
        [[ ! -v Phantom[activitiesDatFile] ]] && EchoErr "PhantomActivitiesDatFile is needed"
        [[ ! -v Phantom[totalActivityMBq] ]]  && EchoErr "PhantomTotalActivityMBq is needed"
      fi
    ;;
    MRI)
      [[ -v Phantom[atlasMhdFile] && ! -v Phantom[spinMaterialsDatFile] ]] && EchoErr "PhantomSpinMaterialsDatFile is needed"
    ;;
    BLI|FMI)
      :
    ;;
  esac
  : "${Phantom[shiftXmm]:=0.0}"
  : "${Phantom[shiftYmm]:=0.0}"
  : "${Phantom[shiftZmm]:=0.0}"
  : "${Phantom[rotateXdeg]:=0.0}"
  } #}}}

CheckTumorVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  [[ "${Script[modality]}" =~ BLI && ! -v Tumor[cellsMhdFile] ]] && EchoErr "TumorCellsMhdFile is needed for BLI"
  if [[ -v Tumor[cellsMhdFile] ]]; then
    : "${Tumor[cellDiametermm]:=0.05}"
    : "${Tumor[shiftXmm]:=0.0}"
    : "${Tumor[shiftYmm]:=0.0}"
    : "${Tumor[shiftZmm]:=0.0}"
    case "${Script[modality]}" in
      SPECT|PET)
        : "${Tumor[minRelActivity]:=100.0}"
        : "${Tumor[maxRelActivity]:=200.0}"
        : "${Tumor[maxRelatesToCells]:=350}"
      ;;
      CBCT) :
      ;;
      MRI)
        : "${Tumor[minT1Relaxation]:=1300.0}"
        : "${Tumor[maxT1Relaxation]:=1500.0}"
        : "${Tumor[minT2Relaxation]:=120.0}"
        : "${Tumor[maxT2Relaxation]:=170.0}"
        : "${Tumor[maxRelatesToCells]:=350}"
      ;;
      BLI|FMI)
        : "${Tumor[minRelFluorophoreConcentration]:=100.0}"
        : "${Tumor[maxRelFluorophoreConcentration]:=200.0}"
        : "${Tumor[maxRelatesToCells]:=350}"
      ;;
    esac
  fi
  } #}}}

CheckReconVars() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  #local -ra castorOptimizers=( MLEM AML BSREM DEPIERRO95 MLTR NEGML OSL PPGML )
  #local -ra rtkOptimizers=( FDK TVR DWR ICG SART )
  : "${Recon[optimizer]:=MLEM}"
  [[ "${Script[modality]}" =~ SPECT|PET && ! ${Recon[optimizer]} =~ MLEM|AML|BSREM|DEPIERRO95|MLTR|NEGML|OSL|PPGML ]] && EchoErr "ReconOptimizer= must be one out of MLEM|AML|BSREM|DEPIERRO95|MLTR|NEGML|OSL|PPGML"
  [[ "${Script[modality]}" =~ CBCT && ! ${Recon[optimizer]} =~ FDK|TVR|DWR|ICG|SART ]] && EchoErr "ReconOptimizer= must be one out of FDK|TVR|DWR|ICG|SART"
  : "${Recon[iterations]:=10}"
  : "${Recon[subsets]:=8}"
  : "${Recon[intersectMethod]:=joseph}"
  } #}}}

CheckRemoteHosts() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  if [[ -v Script[usesGate] ]]; then
    for host in ${Script[remoteHosts]}; do
      [[ $(ssh -q ${Script[user]}@$host exit) -ne 0 ]] && EchoErr "ssh unsuccessful to ${Script[user]}@$host"
      local -i remoteThreads=$(ssh -o StrictHostKeyChecking=no ${Script[user]}@$host echo '$(grep -c processor /proc/cpuinfo)')
      Script[totalThreads]=$(GetFloorToInt "$(Bcf "${Script[totalThreads]} + $remoteThreads")")
    done
  else
    EchoWngLog "'RemoteHosts=' unset; only used for Gate simulations (TODO)"
    Script[remoteHosts]=""
  fi
  } #}}}

CropMhdPhantomZ() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  if [[ "$(awk '$1~/^ElementType/{print $3}' "${Phantom[atlasMhdFile]}")" =~ MET_UCHAR ]]; then 
    local -i bytesPerVoxel=1
  else 
    local -i bytesPerVoxel=2; fi
  local -i dimX=$(awk '$1~/^DimSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local -i dimY=$(awk '$1~/^DimSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local -i croppedDimZ=$(Bci "${Phantom[cropMaxZ]} - ${Phantom[cropMinZ]} + 1")
  local -i bytesPerSliceZ=$(Bci "$dimX * $dimY * $bytesPerVoxel")
  local -i headBytes=$(Bci "${Phantom[cropMinZ]} * $bytesPerSliceZ")
  local -i copyBytes=$(Bci "$croppedDimZ * $bytesPerSliceZ")
  local file="${Phantom[atlasMhdFile]%.*}-cropped"
  dd if="${Phantom[atlasMhdFile]%.*}.raw" of="$file.raw" bs=1 skip="$headBytes" count="$copyBytes" status=noxfer
  cp "${Phantom[atlasMhdFile]}" "$file.mhd"
  gawk -i inplace -v var="$croppedDimZ" '$1~/^DimSize/{$5=var}1' "$file.mhd"
  gawk -i inplace -v var="$file.raw" '$1~/^ElementDataFile/{$3=var}1' "$file.mhd"
  Phantom[atlasMhdFile]="$file.mhd"
  } #}}}

FetchPhantomFilesAndPreprocess() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  if [[ -v Phantom[atlasMhdFile] ]]; then
    [[ "$(awk '$1~/^ElementType/{print $3}' "${Phantom[atlasMhdFile]}")" =~ MET_UCHAR|MET_USHORT ]] ||
      EchoErr "${Phantom[atlasMhdFile]} is not of type MET_UCHAR or MET_USHORT"
    cp "${Phantom[atlasMhdFile]}" .
    cp "$(dirname -- "${Phantom[atlasMhdFile]}")/$(awk '$1~/^ElementDataFile/{print $3}' "${Phantom[atlasMhdFile]}")" .
    Phantom[atlasMhdFile]=$(basename -- "${Phantom[atlasMhdFile]}")
    # If CBCT tilt the phantom
    [[ -v Script[usesGate] && "${Script[modality]}" =~ CBCT ]] && Phantom[atlasMhdFile]=$("${Script[toolsDir]}"/tilt-mhd "${Phantom[atlasMhdFile]}" +y)
    # Fetch phantom material and source files
    if [[ -v Phantom[materialsDatFile] ]]; then 
      cp "${Phantom[materialsDatFile]}" .
      Phantom[materialsDatFile]=$(basename -- "${Phantom[materialsDatFile]}")
    fi
    if [[ -v Phantom[activitiesDatFile] ]]; then 
      cp "${Phantom[activitiesDatFile]}" .
      Phantom[activitiesDatFile]=$(basename -- "${Phantom[activitiesDatFile]}")
    fi
    if [[ -v Phantom[spinMaterialsDatFile] ]]; then 
      cp "${Phantom[spinMaterialsDatFile]}" .
      Phantom[spinMaterialsDatFile]=$(basename -- "${Phantom[spinMaterialsDatFile]}")
    fi
    if [[ -v Tumor[cellsMhdFile] ]]; then
      # Fetch tumor cells insert mhd/raw files
      [[ "$(awk '$1~/^ElementType/{print $3}' "${Tumor[cellsMhdFile]}")" =~ MET_UCHAR|MET_USHORT ]] ||
        EchoErr "${Tumor[cellsMhdFile]} is not of type MET_UCHAR or MET_USHORT"
      cp "${Tumor[cellsMhdFile]}" .
      cp "$(dirname -- "${Tumor[cellsMhdFile]}")/$(awk '$1~/^ElementDataFile/{print $3}' "${Tumor[cellsMhdFile]}")" .
      Tumor[cellsMhdFile]=$(basename -- "${Tumor[cellsMhdFile]}")
      # Down-sample tumor cells to phantom atlas resolution
      EchoGnLog "create-downsampled-tumor-mhd ..."
      # shellcheck disable=SC2046
      local tumorMhdFile=$("${Script[toolsDir]}"/create-downsampled-tumor-mhd "${Tumor[cellsMhdFile]}" "${Tumor[cellDiametermm]}" $(awk '$1~/^ElementSize/{print $3, $4, $5}' "${Phantom[atlasMhdFile]}"))
      # Add tumor cells insert into phantom atlas
      EchoGnLog "add-tumor-mhd-into-phantom-mhd ..."
      local returnStr=$("${Script[toolsDir]}"/add-tumor-mhd-into-phantom-mhd -a "${Phantom[atlasMhdFile]}" -t "$tumorMhdFile" -o "${Tumor[shiftXmm]},${Tumor[shiftYmm]},${Tumor[shiftZmm]}")
      IFS=" " read -r -a returnArray <<< "$returnStr"
      Phantom[atlasMhdFile]="${returnArray[0]}"
      local -i tumorLabelMin="${returnArray[1]}"
      local -i tumorLabelMax="${returnArray[2]}"
      [[ -f "${Phantom[atlasMhdFile]}" ]] || EchoErr "add-tumor-mhd-into-phantom-mhd returned '${Phantom[atlasMhdFile]}'"
      [[ "$(awk '$1~/^ElementType/{print $3}' "${Phantom[atlasMhdFile]}")" =~ MET_UCHAR|MET_USHORT ]] ||
        EchoErr "${Phantom[atlasMhdFile]} (after adding tumor insert) is not of type MET_UCHAR or MET_USHORT"
      if [[ -v Script[usesGate] ]]; then
        # Modify material and source files; the label value in tumorMhdFile corresponds to number of cells per voxel
        cp "${Phantom[materialsDatFile]}" "${Phantom[materialsDatFile]%.*}-incl-tumor.dat"
        Phantom[materialsDatFile]="${Phantom[materialsDatFile]%.*}-incl-tumor.dat"
        echo "$tumorLabelMin $tumorLabelMax Tumor" >> "${Phantom[materialsDatFile]}"
        local -i tissueLines=$(( $(< "${Phantom[materialsDatFile]}" wc -l) - 1 ))
        sed -i "1s/.*/$tissueLines/" "${Phantom[materialsDatFile]}"
        if [[ -v Phantom[activitiesDatFile] ]]; then
          cp "${Phantom[activitiesDatFile]}" "${Phantom[activitiesDatFile]%.*}-incl-tumor.dat"
          Phantom[activitiesDatFile]="${Phantom[activitiesDatFile]%.*}-incl-tumor.dat"
          local actConst=$(Bcf "(${Tumor[maxRelActivity]} - ${Tumor[minRelActivity]}) / ${Tumor[maxRelatesToCells]}")
          for (( label="$tumorLabelMin"; label<="$tumorLabelMax"; label++ )); do
            local -i cells=$(( label - tumorLabelMin ))
            local labelActivity=$(Bcf "${Tumor[minRelActivity]} + $cells * $actConst")
            echo "$label $label $labelActivity" >> "${Phantom[activitiesDatFile]}"
          done
          local -i labelLines=$(( $(< "${Phantom[activitiesDatFile]}" wc -l) - 1 ))
          sed -i "1s/.*/$labelLines/" "${Phantom[activitiesDatFile]}"
        fi
      elif [[ -v Script[usesSpinScenario] ]]; then
        cp "${Phantom[spinMaterialsDatFile]}" "${Phantom[spinMaterialsDatFile]%.*}-incl-tumor.dat"
        Phantom[spinMaterialsDatFile]="${Phantom[spinMaterialsDatFile]%.*}-incl-tumor.dat"
        local t1const=$(Bcf "(${Tumor[maxT1Relaxation]} - ${Tumor[minT1Relaxation]}) / ${Tumor[maxRelatesToCells]}")
        local t2const=$(Bcf "(${Tumor[maxT2Relaxation]} - ${Tumor[minT2Relaxation]}) / ${Tumor[maxRelatesToCells]}")
        for (( label="$tumorLabelMin"; label<="$tumorLabelMax"; label++ )); do
          local -i cells=$(( label - tumorLabelMin ))
          local labelT1Relaxation=$(Bcf "${Tumor[minT1Relaxation]} + $cells * $t1const")
          local labelT2Relaxation=$(Bcf "${Tumor[minT2Relaxation]} + $cells * $t2const")
          echo "$label $labelT1Relaxation $labelT2Relaxation" >> "${Phantom[spinMaterialsDatFile]}"
        done
      fi
    fi
    [[ -v Phantom[cropMinZ] || -v Phantom[cropMaxZ] ]] && CropMhdPhantomZ
    if [[ -v Phantom[activitiesDatFile] ]]; then
      # Scale activity into absolute values
      Phantom[scaledActivitiesDatFile]="${Phantom[activitiesDatFile]%.*}-scaled.dat"
      EchoGnLog "create-activity-dat-for-total-activity-in-phantom-mhd ..."
      "${Script[toolsDir]}"/create-activity-dat-for-total-activity-in-phantom-mhd "${Phantom[atlasMhdFile]}" "${Phantom[activitiesDatFile]}" "$(Bcf "${Phantom[totalActivityMBq]} / ${Script[totalThreads]}")" "${Phantom[scaledActivitiesDatFile]}" >> "${Script[logFile]}"
    fi
    # if MRI (spin-scenario) tilt phantom and convert to h5
    if [[ -v Script[usesSpinScenario] ]]; then
      Phantom[atlasMhdFile]=$("${Script[toolsDir]}"/tilt-mhd "${Phantom[atlasMhdFile]}" -y)
      "${Script[toolsDir]}"/convert-mhd-phantom-to-spinscenario-h5 "${Phantom[atlasMhdFile]}"
      Phantom[atlasH5File]="${Phantom[atlasMhdFile]%.*}.h5"
    fi
  fi # [[ -v Phantom[atlasMhdFile] ]]
  if [[ -v Phantom[atlasMlpFile] ]]; then
    EchoBlLog "${FUNCNAME[0]}() ..."
    cp "${Phantom[atlasMlpFile]}" .
    local mlpdir=$(dirname "${Phantom[atlasMlpFile]}")
    Phantom[atlasMlpFile]=$(basename -- "${Phantom[atlasMlpFile]}")
    # Fetch ply files included in the meshlab project file
    awk 'match($0,/filename[^ ]*/){ print substr($0, RSTART+10,RLENGTH-12)}' "${Phantom[atlasMlpFile]}" | while read -r plyfile; do cp "$mlpdir"/"$plyfile" . ; done
    # TODO ...
    # Fetch phantom material and source files
    if [[ -v Phantom[materialsDatFile] ]]; then 
      cp "${Phantom[materialsDatFile]}" .
      Phantom[materialsDatFile]=$(basename -- "${Phantom[materialsDatFile]}")
    fi
    if [[ -v Phantom[activitiesDatFile] ]]; then 
      cp "${Phantom[activitiesDatFile]}" .
      Phantom[activitiesDatFile]=$(basename -- "${Phantom[activitiesDatFile]}")
    fi
    if [[ -v Tumor[cellsMhdFile] ]]; then
      # Fetch tumor cells insert mhd/raw files
      [[ "$(awk '$1~/^ElementType/{print $3}' "${Tumor[cellsMhdFile]}")" =~ MET_UCHAR|MET_USHORT ]] ||
        EchoErr "${Tumor[cellsMhdFile]} is not of type MET_UCHAR or MET_USHORT"
      cp "${Tumor[cellsMhdFile]}" .
      cp "$(dirname -- "${Tumor[cellsMhdFile]}")/$(awk '$1~/^ElementDataFile/{print $3}' "${Tumor[cellsMhdFile]}")" .
      Tumor[cellsMhdFile]=$(basename -- "${Tumor[cellsMhdFile]}")
      # reassign ElementSize depending on TumorCellDiametermm
      sed -i "s/^ElementSize.*/ElementSize = ${Tumor[cellDiametermm]} ${Tumor[cellDiametermm]} ${Tumor[cellDiametermm]}/" "${Tumor[cellsMhdFile]}"
      sed -i "s/^ElementSpacing.*/ElementSpacing = ${Tumor[cellDiametermm]} ${Tumor[cellDiametermm]} ${Tumor[cellDiametermm]}/" "${Tumor[cellsMhdFile]}"
    fi
    # Generate ini file for lipros
    # TODO: this reads just the skin mesh, no other internal organ meshs, and assigns muscle tissue to it
    Phantom[iniFile]=phantom-tumor.ini
    {
    echo "[tissue]"
    echo "SHAPE=PLY"
    echo "FILENAME_PLY=$(find . -iname "skin*" -exec basename {} \;)"
    echo "CENTER_XYZ=${Phantom[shiftXmm]},${Phantom[shiftYmm]},${Phantom[shiftZmm]}"
    echo "TYPE=MUSCLE"
    echo ""
    echo "[tissue]"
    echo "SHAPE=MHD"
    echo "FILENAME_MHD=${Tumor[cellsMhdFile]}"
    echo "CENTER_XYZ=${Tumor[shiftXmm]},${Tumor[shiftYmm]},${Tumor[shiftZmm]}"
    echo "TYPE=TUMOR"
    } > "${Phantom[iniFile]}"
    case "${Script[modality]}" in
      BLI)
        {
        echo "BIOLUMINESCENCE=${BLI[luciferaseType]}"
        echo "BIOLUMINESCENCE_PHOTONS_PER_CELL=${BLI[photonsPerTumorCell]}"
        } >> "${Phantom[iniFile]}"
      ;;
      FMI)
        {
        echo "FLUOROPHORE=${FMI[fluorophoreType]}"
        echo "FLUOROPHORE_CONCENTRATION=1.0" # TODO
        } >> "${Phantom[iniFile]}"
      ;;
    esac
    # Generate <tumor>.ply file from <tumor>.mhd (for the time being, this is for visualisation, only)
    Tumor[cellsPlyFile]="${Tumor[cellsMhdFile]%.*}".ply
    "${Script[toolsDir]}"/create-pc-ply-from-tumor-mhd "${Tumor[cellsMhdFile]}" "${Tumor[cellsPlyFile]}" "${Tumor[shiftXmm]}" "${Tumor[shiftYmm]}" "${Tumor[shiftZmm]}"
    # Add <tumor>.ply file to <phantom>.mlp file (just before <\/MeshGroup>) (for the time being, this is for visualisation, only)
    local meshEntry="  <MLMesh visible=\"1\" label=\"${Tumor[cellsPlyFile]}\" filename=\"${Tumor[cellsPlyFile]}\">\n"
          meshEntry+="  <MLMatrix44>\n1 0 0 0 \n0 1 0 0 \n0 0 1 0 \n0 0 0 1 \n</MLMatrix44>\n"
          meshEntry+="  <RenderingOption solidColor=\"192 192 192 255\" boxColor=\"234 234 234 255\" pointSize=\"3\" "
          meshEntry+="pointColor=\"131 149 69 255\" wireWidth=\"1\" wireColor=\"64 64 64 255\""
          meshEntry+=">000111010000000000000000000000000000000010100000000100111010110000001101</RenderingOption>\n  </MLMesh>"
    local lineNumber=$(awk '/<\/MeshGroup>/ {print FNR}' "${Phantom[atlasMlpFile]}")
    sed -i "${lineNumber}i $meshEntry" "${Phantom[atlasMlpFile]}"
  fi # [[ -v Phantom[atlasMlpFile] ]]
  } #}}}

FetchGateMacFile() #{{{
  {
  EchoBlLog "  ${FUNCNAME[0]}() ..."
  Script[usesGate]=true
  Script[gateInterfaceFile]=gate-interface.mac
  # create a single gateInterfaceFile from the supplied gateUserMacFile which might have /control/execute <file> lines
  local userInterfaceDir=$(dirname -- "${Script[gateUserMacFile]}")
  cp "${Script[gateUserMacFile]}" .
  cp "${Script[gateUserMacFile]}" "${Script[gateInterfaceFile]}"
  while true; do
    local line=$(awk '/^\/control\/execute/{ print NR; exit }' "${Script[gateInterfaceFile]}")
    [[ -z "$line" ]] && break
    sed -i "${line}s/^\/control\/execute/#\/control\/execute/" "${Script[gateInterfaceFile]}"
    local macFile=$(gawk -v l="$line" 'NR==l { print $2 }' "${Script[gateInterfaceFile]}")
    [[ -f "$macFile" ]] || macFile="$userInterfaceDir/$macFile"
    [[ -f "$macFile" ]] || EchoErr "Could not find $macFile, called from ${Script[gateUserMacFile]}"
    cp "$macFile" .
    sed -i "${line}r $macFile" "${Script[gateInterfaceFile]}"
  done
  # copy the GateMaterials.db into the working dir
  local matFile=$(awk '/^\/gate\/geometry\/setMaterialDatabase/{ print $2; exit }' "${Script[gateInterfaceFile]}")
  [[ -f "$matFile" ]] || matFile="$userInterfaceDir/$matFile"
  [[ -f "$matFile" ]] || EchoErr "Could not find $matFile, called from ${Script[gateUserMacFile]}"
  cp "$matFile" .
  local matFile=$(basename -- "$matFile")
  cp "${Script[rootDir]}"/gate/materials/Materials.xml . # TODO: check user mac file for Materials.xml
  sed -i "s/^\/gate\/geometry\/setMaterialDatabase.*/\/gate\/geometry\/setMaterialDatabase $matFile/" "${Script[gateInterfaceFile]}"
  # check system modality
  local gateSystem=$(awk '/^\/gate\/world\/daughters\/name/{print $2}' "${Script[gateInterfaceFile]}")
  case "$gateSystem" in
    SPECThead)      : ;;
    cylindricalPET) : ;;
    *)              EchoErr "Found modality $gateSystem in user mac file which is not yet implemented, please contact author" ;;
  esac
  # set some global vars
  Script[gateOutputBaseFile]=$(awk '/^\/gate\/output\/root\/setFileName/{print $2}' "${Script[gateInterfaceFile]}")
  if [[ ${Script[modality]} =~ SPECT ]]; then
    SPECT[detectorPixelsX]=$(awk '/^\/gate\/output\/projection\/pixelNumberX/{ print $2; exit }' "${Script[gateInterfaceFile]}")
    SPECT[detectorPixelsY]=$(awk '/^\/gate\/output\/projection\/pixelNumberY/{ print $2; exit }' "${Script[gateInterfaceFile]}")
    SPECT[detectorPixelSizeX]=$(awk '/^\/gate\/output\/projection\/pixelSizeX/{ print $2; exit }' "${Script[gateInterfaceFile]}")
    SPECT[detectorPixelSizeY]=$(awk '/^\/gate\/output\/projection\/pixelSizeY/{ print $2; exit }' "${Script[gateInterfaceFile]}")
    local timeStop=$(awk '/^\/gate\/application\/setTimeStop/{ print $2; exit }' "${Script[gateInterfaceFile]}")
    local timeSlice=$(awk '/^\/gate\/application\/setTimeSlice/{ print $2; exit }' "${Script[gateInterfaceFile]}")
    SPECT[gantryProjections]=$(Bci "$timeStop / $timeSlice")
  fi
  } #}}}

FetchSpinscenarioLuaFile() #{{{
  {
  EchoBlLog "  ${FUNCNAME[0]}() ..."
  Script[usesSpinScenario]=true
  cp "${Script[spinScenarioUserLuaFile]}" .
  Script[spinScenarioUserLuaFile]=$(dirname -- "${Script[spinScenarioUserLuaFile]}")
  } #}}}

PrepareResources() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  # Create working dir and change into it; copy this script into it for reference
  Script[workingDir]="${Script[rootDir]}/output/$(date '+%Y-%m-%d-%H-%M-%S')-${Script[modality]}"
  mkdir -p "${Script[workingDir]}"
  cp "${BASH_SOURCE[0]}" "${Script[workingDir]}"
  cd "${Script[workingDir]}"
  EchoYe "  ${Script[workingDir]}\n"
  # Create log file
  Script[logFile]="$(basename -- "${BASH_SOURCE[0]%.*}").log"
  touch "${Script[logFile]}"
  echo "${Script[invocation]}" >> "${Script[logFile]}"
  # If a Gate or Lua interface file is provided, read that in
  if   [[ -v Script[gateUserMacFile] ]]; then
    FetchGateMacFile
  elif [[ -v Script[spinScenarioUserLuaFile] ]]; then
    FetchSpinscenarioLuaFile
  else # Fetch material and phantom files
    if [[ -v Script[usesGate] ]]     ; then cp "${Script[rootDir]}/gate/materials/"{gate-materials.db,Materials.xml} .; fi
    if [[ -v Phantom[atlasMhdFile] || -v Phantom[atlasMlpFile] ]]; then FetchPhantomFilesAndPreprocess; fi
    :
  fi
  } #}}}

EchoGateVerbose() #{{{
  {
  local verbosity=0 # 0, 1, 2
  echo "# 1.  V E R B O S I T Y"
  echo "/run/verbose              $verbosity" # Geant4
  echo "/event/verbose            $verbosity"
  echo "/tracking/verbose         $verbosity"
  echo "/process/verbose          $verbosity"
  echo "/control/verbose          $verbosity"
  echo "/gate/verbose Physic      $verbosity" # Gate
  echo "/gate/verbose Cuts        $verbosity"
  echo "/gate/verbose SD          $verbosity"
  echo "/gate/verbose Actions     $verbosity"
  echo "/gate/verbose Actor       $verbosity"
  echo "/gate/verbose Step        $verbosity"
  echo "/gate/verbose Error       $verbosity"
  echo "/gate/verbose Warning     $verbosity"
  echo "/gate/verbose Output      $verbosity"
  echo "/gate/verbose Beam        $verbosity"
  echo "/gate/verbose Volume      $verbosity"
  echo "/gate/verbose Image       $verbosity"
  echo "/gate/verbose Geometry    $verbosity"
  echo "/gate/verbose Core        $verbosity"
  echo "/gate/output/verbose      $verbosity"
  echo "/gate/random/verbose      $verbosity"
  echo "/gate/digitizer/verbose   $verbosity"
  } #}}}

EchoGateVisualisation() #{{{
  {
  echo "# 2.  V I S U A L I S A T I O N"
  if [[ -v Script[gateVisualisationOnly] ]]; then 
    echo "/vis/open                             OGLIQt"
    echo "/vis/viewer/set/projection            orthogonal"
    echo "/vis/viewer/set/lineSegmentsPerCircle 72"
    echo "/vis/viewer/set/background            white"
    echo "/vis/viewer/set/style                 wireframe"
    echo "/vis/drawVolume"
    echo "/vis/viewer/flush"
  else
    echo "/vis/disable"
  fi
  } #}}}

EchoGateMaterial() #{{{
  {
  echo "# 3.  M A T E R I A L"
  echo "/gate/geometry/setMaterialDatabase gate-materials.db"
  } #}}}

EchoGateSPECTScanner() #{{{
  {
  # TODO: this is for parallel-beam collimator
  echo "# 4.  S C A N N E R"
  local shieldingThickness=10.0 # mm
  local backCompartmentThicknessX=25.0 # mm
  local headThicknessX=$(Bcf "${SPECT[collimatorThicknessXmm]} + ${SPECT[crystalThicknessXmm]} + $backCompartmentThicknessX + $shieldingThickness")
  local headX=$(Bcf "${SPECT[cameraRadiusOfRotationXYmm]} + $headThicknessX/2")
  local colX=$(Bcf "-$headThicknessX/2 + ${SPECT[collimatorThicknessXmm]}/2")
  local crystalX=$(Bcf "-$headThicknessX/2 + ${SPECT[collimatorThicknessXmm]} + ${SPECT[crystalThicknessXmm]}/2")
  local backX=$(Bcf "-$headThicknessX/2 + ${SPECT[collimatorThicknessXmm]} + ${SPECT[crystalThicknessXmm]} + $backCompartmentThicknessX/2")
  local headSizeY=$(Bcf "${SPECT[cameraSizeYmm]} + 2 * $shieldingThickness")
  local headSizeZ=$(Bcf "${SPECT[cameraSizeZmm]} + 2 * $shieldingThickness")
  local holeOffsetY=$(Bcf "${SPECT[collimatorHoleDiameterZYmm]} + ${SPECT[collimatorSeptaThicknessZYmm]}")
  local holesY=$(GetFloorToInt "$(Bcf "${SPECT[cameraSizeYmm]} / $holeOffsetY")")
  local holeOffsetZ=$(Bcf "sqrt(3)/2 * $holeOffsetY")
  local halfHolesZ=$(GetFloorToInt "$(Bcf "${SPECT[cameraSizeZmm]} / $holeOffsetZ / 2")")
  echo "# world"
  echo "/gate/world/geometry/setXLength             $(Bcf "2.1*(${SPECT[cameraRadiusOfRotationXYmm]}+$headThicknessX)") mm"
  echo "/gate/world/geometry/setYLength             $(Bcf "2.1*(${SPECT[cameraRadiusOfRotationXYmm]}+$headThicknessX)") mm"
  echo "/gate/world/geometry/setZLength             $(Bcf "1.1 * $headSizeZ") mm"
  echo "/gate/world/vis/setColor                    gray"
  echo "# SPECThead"
  echo "/gate/world/daughters/name                  SPECThead"
  echo "/gate/world/daughters/insert                box"
  echo "/gate/SPECThead/geometry/setXLength         $headThicknessX mm"
  echo "/gate/SPECThead/geometry/setYLength         $headSizeY mm"
  echo "/gate/SPECThead/geometry/setZLength         $headSizeZ mm"
  echo "/gate/SPECThead/placement/setTranslation    $headX 0 0 mm"
  echo "# head shielding"
  echo "/gate/SPECThead/daughters/name              shielding"
  echo "/gate/SPECThead/daughters/insert            box"
  echo "/gate/shielding/geometry/setXLength         $headThicknessX mm"
  echo "/gate/shielding/geometry/setYLength         $headSizeY mm"
  echo "/gate/shielding/geometry/setZLength         $headSizeZ mm"
  echo "/gate/shielding/setMaterial                 Lead"
  echo "#/gate/shielding/vis/forceSolid"
  echo "/gate/shielding/vis/setColor                black"
  echo "/gate/shielding/vis/setLineWidth            2"
  echo "# collimator"
  echo "/gate/SPECThead/daughters/name              collimator"
  echo "/gate/SPECThead/daughters/insert            box"
  echo "/gate/collimator/geometry/setXLength        ${SPECT[collimatorThicknessXmm]} mm"
  echo "/gate/collimator/geometry/setYLength        ${SPECT[cameraSizeYmm]} mm"
  echo "/gate/collimator/geometry/setZLength        ${SPECT[cameraSizeZmm]} mm"
  echo "/gate/collimator/placement/setTranslation   $colX 0 0 mm"
  echo "/gate/collimator/setMaterial                ${SPECT[collimatorMaterial]}"
  echo "/gate/collimator/vis/forceSolid"
  echo "/gate/collimator/vis/setColor               black"
  echo "# collimator hole"
  echo "/gate/collimator/daughters/name             hole"
  echo "/gate/collimator/daughters/insert           ${SPECT[collimatorHoleType]}"
  echo "/gate/hole/geometry/setRadius               $(Bcf "${SPECT[collimatorHoleDiameterZYmm]}/2") mm"
  echo "/gate/hole/geometry/setHeight               ${SPECT[collimatorThicknessXmm]} mm"
  echo "/gate/hole/placement/setRotationAxis        0 1 0"
  echo "/gate/hole/placement/setRotationAngle       90 deg"
  echo "/gate/hole/vis/forceSolid"
  echo "/gate/hole/vis/setColor                     white"
  echo "# collimator hole repeaters to form hexagonal array"
  echo "/gate/hole/repeaters/insert                 cubicArray"
  echo "/gate/hole/cubicArray/setRepeatNumberX      1"
  echo "/gate/hole/cubicArray/setRepeatNumberY      $holesY"
  echo "/gate/hole/cubicArray/setRepeatNumberZ      $halfHolesZ"
  echo "/gate/hole/cubicArray/setRepeatVector       0 $holeOffsetY $(Bcf "$holeOffsetZ*2") mm"
  echo "/gate/hole/repeaters/insert                 linear"
  echo "/gate/hole/linear/setRepeatNumber           2"
  echo "/gate/hole/linear/setRepeatVector           0 $(Bcf "$holeOffsetY/2") $holeOffsetZ mm"
  echo "# crystal"
  echo "/gate/SPECThead/daughters/name              crystal"
  echo "/gate/SPECThead/daughters/insert            box"
  echo "/gate/crystal/geometry/setXLength           ${SPECT[crystalThicknessXmm]} mm"
  echo "/gate/crystal/geometry/setYLength           ${SPECT[cameraSizeYmm]} mm"
  echo "/gate/crystal/geometry/setZLength           ${SPECT[cameraSizeZmm]} mm"
  echo "/gate/crystal/placement/setTranslation      $crystalX 0 0 mm"
  echo "/gate/crystal/setMaterial                   ${SPECT[crystalMaterial]}"
  echo "/gate/crystal/vis/forceSolid"
  echo "/gate/crystal/vis/setColor                  green"
  echo "# backcompartment"
  echo "/gate/SPECThead/daughters/name              backcompartment"
  echo "/gate/SPECThead/daughters/insert            box"
  echo "/gate/backcompartment/geometry/setXLength       $backCompartmentThicknessX mm"
  echo "/gate/backcompartment/geometry/setYLength       ${SPECT[cameraSizeYmm]} mm"
  echo "/gate/backcompartment/geometry/setZLength       ${SPECT[cameraSizeZmm]} mm"
  echo "/gate/backcompartment/placement/setTranslation  $backX 0 0 mm"
  echo "/gate/backcompartment/setMaterial               Glass"
  echo "/gate/backcompartment/vis/setColor              blue"
  echo "# SPECThead repeater"
  echo "/gate/SPECThead/repeaters/insert            ring"
  echo "/gate/SPECThead/ring/setRepeatNumber        ${SPECT[cameras]}"
  echo "/gate/SPECThead/moves/insert                orbiting"
  echo "/gate/SPECThead/orbiting/setSpeed      $(Bcf "360 / ${SPECT[gantryProjections]} / ${SPECT[timePerProjectionSec]}") deg/s"
  echo "/gate/SPECThead/orbiting/setPoint1          0 0 0 cm"
  echo "/gate/SPECThead/orbiting/setPoint2          0 0 1 cm"
  echo "# system attachement (connect the geometry with the system)"
  echo "/gate/systems/SPECThead/crystal/attach crystal"
  echo "# crystalSD attachement (store hits in volumes belonging to the scanner)"
  echo "/gate/crystal/attachCrystalSD"
  echo "# phantomSD attachment (store information regarding Compton and Rayleigh interactions)"
  #echo "/gate/shielding/attachPhantomSD"
  #echo "/gate/SPECThead/attachPhantomSD"
  #echo "/gate/collimator/attachPhantomSD"
  #echo "/gate/backcompartment/attachPhantomSD"
  } #}}}

EchoGatePETScanner() #{{{
  {
  # TODO: include 3D slats
  echo "# 4.  S C A N N E R"
  echo "# world"
  echo "/gate/world/geometry/setXLength             $(Bcf "1.1 * ${PET[ringCircumDiameterXYmm]}") mm"
  echo "/gate/world/geometry/setYLength             $(Bcf "1.1 * ${PET[ringCircumDiameterXYmm]}") mm"
  echo "/gate/world/geometry/setZLength             $(Bcf "1.1 * ${PET[axialFOVZmm]}") mm"
  echo "/gate/world/vis/setColor                    gray"
  echo "# cylindricalPET"
  echo "/gate/world/daughters/name                  cylindricalPET"
  echo "/gate/world/daughters/insert                cylinder"
  echo "/gate/cylindricalPET/geometry/setRmin       $(Bcf "0.5 * ${PET[ringDiameterXYmm]}") mm"
  echo "/gate/cylindricalPET/geometry/setRmax       $(Bcf "0.5 * ${PET[ringCircumDiameterXYmm]}") mm"
  echo "/gate/cylindricalPET/geometry/setHeight     ${PET[axialFOVZmm]} mm"
  echo "/gate/cylindricalPET/setMaterial            Air"
  echo "/gate/cylindricalPET/vis/setColor           gray"
  echo "# rsector shape"
  echo "/gate/cylindricalPET/daughters/name         rsector"
  echo "/gate/cylindricalPET/daughters/insert       box"
  echo "/gate/rsector/geometry/setXLength           ${PET[blockSizeXmm]} mm"
  echo "/gate/rsector/geometry/setYLength           ${PET[blockSizeYmm]} mm"
  echo "/gate/rsector/geometry/setZLength           $(Bcf "${PET[axialBlocksZ]} * ${PET[blockSizeZmm]}") mm"
  echo "/gate/rsector/placement/setTranslation      $(Bcf "0.5 * (${PET[ringDiameterXYmm]} + ${PET[blockSizeXmm]})") 0 0 mm"
  echo "/gate/rsector/setMaterial                   Air"
  echo "/gate/rsector/vis/setColor                  cyan"
  echo "# module shape"
  echo "/gate/rsector/daughters/name                module"
  echo "/gate/rsector/daughters/insert              box"
  echo "/gate/module/geometry/setXLength            ${PET[blockSizeXmm]} mm"
  echo "/gate/module/geometry/setYLength            ${PET[blockSizeYmm]} mm"
  echo "/gate/module/geometry/setZLength            ${PET[blockSizeZmm]} mm"
  echo "/gate/module/setMaterial                    PTFE"
  echo "/gate/module/vis/setColor                   magenta"
  echo "# crystal"
  echo "/gate/module/daughters/name                 crystal"
  echo "/gate/module/daughters/insert               box"
  echo "/gate/crystal/geometry/setXLength           ${PET[crystalThicknessXmm]} mm"
  echo "/gate/crystal/geometry/setYLength           ${PET[crystalSizeYmm]} mm"
  echo "/gate/crystal/geometry/setZLength           ${PET[crystalSizeZmm]} mm"
  echo "/gate/crystal/setMaterial                   LSO"
  echo "/gate/crystal/vis/forceSolid"
  echo "/gate/crystal/vis/setColor                  green"
  echo "# crystal repeater"
  echo "/gate/crystal/repeaters/insert              cubicArray"
  echo "/gate/crystal/cubicArray/setRepeatNumberX   1"
  echo "/gate/crystal/cubicArray/setRepeatNumberY   ${PET[crystalsPerBlockY]}"
  echo "/gate/crystal/cubicArray/setRepeatNumberZ   ${PET[crystalsPerBlockZ]}"
  echo "/gate/crystal/cubicArray/setRepeatVector    0 $(Bcf "${PET[crystalSizeZmm]} + ${PET[crystalGapZYmm]}")" "$(Bcf "${PET[crystalSizeYmm]} + ${PET[crystalGapZYmm]}") mm"
  echo "# module repeater"
  echo "/gate/module/repeaters/insert               cubicArray"
  echo "/gate/module/cubicArray/setRepeatNumberX    1"
  echo "/gate/module/cubicArray/setRepeatNumberY    1"
  echo "/gate/module/cubicArray/setRepeatNumberZ    ${PET[axialBlocksZ]}"
  echo "/gate/module/cubicArray/setRepeatVector     0 0 ${PET[blockSizeZmm]} mm"
  echo "# rsector repeater"
  echo "/gate/rsector/repeaters/insert              ring"
  echo "/gate/rsector/ring/setRepeatNumber          ${PET[blocksPerRingXY]}"
  echo "# system attachement (connect the geometry with the system)"
  echo "/gate/systems/cylindricalPET/rsector/attach rsector"
  echo "/gate/systems/cylindricalPET/module/attach  module"
  echo "/gate/systems/cylindricalPET/crystal/attach crystal"
  echo "# crystalSD attachment (store hits in volumes belonging to the scanner)"
  echo "/gate/crystal/attachCrystalSD"
  echo "# phantomSD attachment (store information regarding Compton and Rayleigh interactions)"
  } #}}}

EchoGateCBCTScanner() #{{{
  {
  local detectorPosZ=$(Bcf "${CBCT[sourceToDetectorDistanceZmm]} - ${CBCT[sourceToCenterOfRotationDistanceZmm]}")
  local clusterPixelsX=$(GetRoundToInt "$(Bcf "${CBCT[detectorPixelsX]} / 3")")
  CBCT[detectorPixelsX]=$(GetRoundToInt "$(Bcf "$clusterPixelsX * 3")")
  echo "# 4.  S C A N N E R"
  echo "# world"
  echo "/gate/world/geometry/setXLength           $(Bcf "1.1 * ${CBCT[detectorSizeXmm]}") mm"
  echo "/gate/world/geometry/setYLength           $(Bcf "1.1 * ${CBCT[detectorSizeYmm]}") mm"
  echo "/gate/world/geometry/setZLength           $(Bcf "2.1 * ${CBCT[sourceToCenterOfRotationDistanceZmm]}") mm"
  echo "/gate/world/vis/setColor                  gray"
  echo "# CTscanner"
  echo "/gate/world/daughters/name                CTscanner"
  echo "/gate/world/daughters/insert              box"
  echo "/gate/CTscanner/geometry/setXLength       ${CBCT[detectorSizeXmm]} mm"
  echo "/gate/CTscanner/geometry/setYLength       ${CBCT[detectorSizeYmm]} mm"
  echo "/gate/CTscanner/geometry/setZLength       3. mm"
  echo "/gate/CTscanner/placement/setTranslation  0 0 $detectorPosZ mm"
  echo "/gate/CTscanner/vis/setColor              black"
  echo "# module (component, containing up to 3 clusters, that can be linearly placed along the Y axis)"
  echo "/gate/CTscanner/daughters/name            module"
  echo "/gate/CTscanner/daughters/insert          box"
  echo "/gate/module/geometry/setXLength          ${CBCT[detectorSizeXmm]} mm"
  echo "/gate/module/geometry/setYLength          ${CBCT[detectorSizeYmm]} mm"
  echo "/gate/module/geometry/setZLength          3. mm"
  echo "/gate/module/vis/setColor                 gray"
  echo "# cluster0 (component containing pixels; the center cluster in the module)"
  echo "/gate/module/daughters/name               cluster0"
  echo "/gate/module/daughters/insert             box"
  echo "/gate/cluster0/geometry/setXLength        $(Bcf "${CBCT[detectorSizeXmm]} / 3") mm"
  echo "/gate/cluster0/geometry/setYLength        ${CBCT[detectorSizeYmm]} mm"
  echo "/gate/cluster0/geometry/setZLength        3. mm"
  echo "/gate/cluster0/placement/setTranslation   -$(Bcf "${CBCT[detectorSizeXmm]} / 3") 0 0 mm"
  echo "/gate/cluster0/vis/setColor               gray"
  echo "# pixel0 (array component, placed inside the center cluster)"
  echo "/gate/cluster0/daughters/name             pixel0"
  echo "/gate/cluster0/daughters/insert           box"
  echo "/gate/pixel0/geometry/setXLength          ${CBCT[detectorPixelSizeXmm]} mm"
  echo "/gate/pixel0/geometry/setYLength          ${CBCT[detectorPixelSizeYmm]} mm"
  echo "/gate/pixel0/geometry/setZLength          3. mm"
  echo "/gate/pixel0/setMaterial                  Silicon"
  echo "/gate/pixel0/vis/setColor                 green"
  echo "/gate/pixel0/repeaters/insert             cubicArray"
  echo "/gate/pixel0/cubicArray/setRepeatNumberX  $clusterPixelsX"
  echo "/gate/pixel0/cubicArray/setRepeatNumberY  ${CBCT[detectorPixelsY]}"
  echo "/gate/pixel0/cubicArray/setRepeatNumberZ  1"
  echo "/gate/pixel0/cubicArray/setRepeatVector   ${CBCT[detectorPixelSizeXmm]} ${CBCT[detectorPixelSizeYmm]} 0 mm"
  echo "# cluster1 (component containing pixels; the left cluster in the module)"
  echo "/gate/module/daughters/name               cluster1"
  echo "/gate/module/daughters/insert             box"
  echo "/gate/cluster1/geometry/setXLength        $(Bcf "${CBCT[detectorSizeXmm]} / 3") mm"
  echo "/gate/cluster1/geometry/setYLength        ${CBCT[detectorSizeYmm]} mm"
  echo "/gate/cluster1/geometry/setZLength        3. mm"
  echo "/gate/cluster1/placement/setTranslation   0 0 0 mm"
  echo "/gate/cluster1/vis/setColor               gray"
  echo "# pixel1 (array component, placed inside the left cluster)"
  echo "/gate/cluster1/daughters/name             pixel1"
  echo "/gate/cluster1/daughters/insert           box"
  echo "/gate/pixel1/geometry/setXLength          ${CBCT[detectorPixelSizeXmm]} mm"
  echo "/gate/pixel1/geometry/setYLength          ${CBCT[detectorPixelSizeYmm]} mm"
  echo "/gate/pixel1/geometry/setZLength          3. mm"
  echo "/gate/pixel1/setMaterial                  Silicon"
  echo "/gate/pixel1/vis/setColor                 green"
  echo "/gate/pixel1/repeaters/insert             cubicArray"
  echo "/gate/pixel1/cubicArray/setRepeatNumberX  $clusterPixelsX"
  echo "/gate/pixel1/cubicArray/setRepeatNumberY  ${CBCT[detectorPixelsY]}"
  echo "/gate/pixel1/cubicArray/setRepeatNumberZ  1"
  echo "/gate/pixel1/cubicArray/setRepeatVector   ${CBCT[detectorPixelSizeXmm]} ${CBCT[detectorPixelSizeYmm]} 0 mm"
  echo "# module (component containing pixels; the right cluster in the module)"
  echo "/gate/module/daughters/name               cluster2"
  echo "/gate/module/daughters/insert             box"
  echo "/gate/cluster2/geometry/setXLength        $(Bcf "${CBCT[detectorSizeXmm]} / 3") mm"
  echo "/gate/cluster2/geometry/setYLength        ${CBCT[detectorSizeYmm]} mm"
  echo "/gate/cluster2/geometry/setZLength        3. mm"
  echo "/gate/cluster2/placement/setTranslation   $(Bcf "${CBCT[detectorSizeXmm]} / 3") 0 0 mm"
  echo "/gate/cluster2/vis/setColor               gray"
  echo "# pixel2 (array component, placed inside the right cluster)"
  echo "/gate/cluster2/daughters/name             pixel2"
  echo "/gate/cluster2/daughters/insert           box"
  echo "/gate/pixel2/geometry/setXLength          ${CBCT[detectorPixelSizeXmm]} mm"
  echo "/gate/pixel2/geometry/setYLength          ${CBCT[detectorPixelSizeYmm]} mm"
  echo "/gate/pixel2/geometry/setZLength          3. mm"
  echo "/gate/pixel2/setMaterial                  Silicon"
  echo "/gate/pixel2/vis/setColor                 green"
  echo "/gate/pixel2/repeaters/insert             cubicArray"
  echo "/gate/pixel2/cubicArray/setRepeatNumberX  $clusterPixelsX"
  echo "/gate/pixel2/cubicArray/setRepeatNumberY  ${CBCT[detectorPixelsY]}"
  echo "/gate/pixel2/cubicArray/setRepeatNumberZ  1"
  echo "/gate/pixel2/cubicArray/setRepeatVector   ${CBCT[detectorPixelSizeXmm]} ${CBCT[detectorPixelSizeYmm]} 0 mm"
  echo "# system attachement (connect the geometry with the system)"
  echo "/gate/systems/CTscanner/module/attach     module"
  echo "/gate/systems/CTscanner/cluster_0/attach  cluster0"
  echo "/gate/systems/CTscanner/cluster_1/attach  cluster1"
  echo "/gate/systems/CTscanner/cluster_2/attach  cluster2"
  echo "/gate/systems/CTscanner/pixel_0/attach    pixel0"
  echo "/gate/systems/CTscanner/pixel_1/attach    pixel1"
  echo "/gate/systems/CTscanner/pixel_2/attach    pixel2"
  echo "# crystalSD attachement (store hits in volumes belonging to the scanner)"
  echo "/gate/pixel0/attachCrystalSD"
  echo "/gate/pixel1/attachCrystalSD"
  echo "/gate/pixel2/attachCrystalSD"
  echo "# phantomSD attachment (store information regarding Compton and Rayleigh interactions)"
  } #}}}

EchoGatePhantom() #{{{
  {
  local -i dimX=$(awk '$1~/^DimSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local -i dimY=$(awk '$1~/^DimSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local -i dimZ=$(awk '$1~/^DimSize/{print $5}' "${Phantom[atlasMhdFile]}")
  local sizeX=$(awk '$1~/^ElementSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local sizeY=$(awk '$1~/^ElementSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local sizeZ=$(awk '$1~/^ElementSize/{print $5}' "${Phantom[atlasMhdFile]}")
  local halfSizeX=$(Bcf "0.5 * $dimX * $sizeX")
  local halfSizeY=$(Bcf "0.5 * $dimY * $sizeY")
  local halfSizeZ=$(Bcf "0.5 * $dimZ * $sizeZ")
  echo "# 5.  P H A N T O M"
  echo "/gate/world/daughters/name                      myPhantom"
  if [[ "${Script[modality]}" =~ PET && ! -v Script[simulateScatteredPhotonsInPhantomSD] ]]; then
    echo "# fast simulation, physics might not be correct"
    echo "/gate/world/daughters/insert                  ImageRegularParametrisedVolume"
    echo "/gate/myPhantom/setSkipEqualMaterials         1"
  else 
    echo "/gate/world/daughters/insert                  ImageNestedParametrisedVolume"
  fi
  echo "/gate/myPhantom/geometry/setImage               ${Phantom[atlasMhdFile]}"
  echo "/gate/myPhantom/geometry/setRangeToMaterialFile ${Phantom[materialsDatFile]}"
  echo "/gate/myPhantom/placement/setTranslation        ${Phantom[shiftXmm]} ${Phantom[shiftYmm]} ${Phantom[shiftZmm]} mm"
  echo "/gate/myPhantom/placement/setRotationAxis       1 0 0"
  echo "/gate/myPhantom/placement/setRotationAngle      ${Phantom[rotateXdeg]} deg"
  if [[ "${Script[modality]}" =~ CBCT ]]; then
    echo "# Rotate phantom for CT data acquisition"
    echo "/gate/myPhantom/moves/insert                  rotation"
    echo "/gate/myPhantom/rotation/setSpeed             1 deg/s"
    echo "/gate/myPhantom/rotation/setAxis              1 0 0"
  fi
  echo "# phantomSD attachment (store information regarding Compton and Rayleigh interactions)"
  echo "/gate/myPhantom/attachPhantomSD"
  } #}}}

EchoGatePhysics() #{{{
  {
  echo "# 6.  P H Y S I C S"
  echo "/gate/physics/addPhysicsList          emstandard_opt1"
  # Charged particles processes (ionization and bremsstrahlung) require a threshold below which no secondary particles will be
  # generated. Hence, gammas, electrons and positrons require production thresholds which can be defined for any volume [1 mm]
  echo "/gate/physics/Gamma/SetCutInRegion    world 1 mm"
  echo "/gate/physics/Electron/SetCutInRegion world 1 mm"
  echo "/gate/physics/Positron/SetCutInRegion world 1 mm"
  } #}}}

EchoGateActors() #{{{
  {
  local -i dimX=$(awk '$1~/^DimSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local -i dimY=$(awk '$1~/^DimSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local -i dimZ=$(awk '$1~/^DimSize/{print $5}' "${Phantom[atlasMhdFile]}")
  local sizeX=$(awk '$1~/^ElementSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local sizeY=$(awk '$1~/^ElementSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local sizeZ=$(awk '$1~/^ElementSize/{print $5}' "${Phantom[atlasMhdFile]}")
  echo "# 7. A C T O R S"
  echo "/gate/actor/addActor   SimulationStatisticActor stat"
  echo "/gate/actor/stat/save  Gate-statistics.txt"
  if [[ "${Script[modality]}" =~ SPECT|PET ]]; then
    echo "# create attenuation map (*-MuMap.mhd) (--> image reconstruction); also creates *-SourceMap.mhd"
    echo "/gate/actor/addActor MuMapActor     getMuMap"
    echo "/gate/actor/getMuMap/attachTo       myPhantom"
    [[ "${Script[modality]}" =~ SPECT ]] && echo "/gate/actor/getMuMap/setEnergy      ${SPECT[isotopeEnergyKeV]} keV"
    [[ "${Script[modality]}" =~ PET ]]   && echo "/gate/actor/getMuMap/setEnergy      ${PET[isotopeEnergyKeV]} keV"
    echo "/gate/actor/getMuMap/setMuUnit      1 1/cm"
    echo "/gate/actor/getMuMap/save           ${Phantom[atlasMhdFile]%.*}.mhd"
    echo "/gate/actor/getMuMap/setResolution  $dimX $dimY $dimZ"
    echo "/gate/actor/getMuMap/setVoxelSize   $sizeX $sizeY $sizeZ mm"
    echo "/gate/actor/getMuMap/setPosition    0 0 0 mm"
  fi
  } #}}}

EchoGateInitialisation() #{{{
  {
  echo "# 8.  I N I T I A L I Z E"
  echo "/gate/run/initialize"
  # echo "/gate/timing/setTime 0 s # 0 degree"
  } #}}}

EchoGateSPECTDigitizer() #{{{
  {
  echo "# 9.  D I G I T I Z E R"
  echo "/gate/digitizer/Singles/insert                        adder"
  echo "/gate/digitizer/Singles/insert                        blurring"
  echo "/gate/digitizer/Singles/blurring/setResolution        ${SPECT[energyResolutionFWHM]}"
  echo "/gate/digitizer/Singles/blurring/setEnergyOfReference ${SPECT[isotopeEnergyKeV]} keV"
  echo "/gate/digitizer/Singles/insert                        spblurring"
  echo "/gate/digitizer/Singles/spblurring/setSpresolution    2.0 mm"
  echo "/gate/digitizer/Singles/spblurring/verbose            0"
  echo "/gate/digitizer/Singles/insert                        thresholder"
  echo "/gate/digitizer/Singles/thresholder/setThreshold      ${SPECT[energyWindowMinKeV]} keV"
  echo "/gate/digitizer/Singles/insert                        upholder"
  echo "/gate/digitizer/Singles/upholder/setUphold            ${SPECT[energyWindowMaxKeV]} keV"
  } #}}}

EchoGatePETDigitizer() #{{{
  {
  echo "# 9.  D I G I T I Z E R"
  echo "/gate/digitizer/Singles/insert                                      adder"
  echo "/gate/digitizer/Singles/insert                                      readout"
  echo "/gate/digitizer/Singles/readout/setDepth                            2"
  #echo "/gate/digitizer/Singles/insert                                      blurring"
  #echo "/gate/digitizer/Singles/blurring/setEnergyOfReference               ${PET[isotopeEnergyKeV]} keV"
  #echo "/gate/digitizer/Singles/blurring/setResolution                      ${PET[energyResolutionFWHM]}"
  echo "/gate/digitizer/Singles/insert                                      crystalblurring"
  echo "/gate/digitizer/Singles/crystalblurring/setCrystalResolutionMin     0.15" # TODO: ${PET[energyResolutionFWHM]}
  echo "/gate/digitizer/Singles/crystalblurring/setCrystalResolutionMax     0.35" # TODO: ${PET[energyResolutionFWHM]}
  echo "/gate/digitizer/Singles/crystalblurring/setCrystalQE                0.9"
  echo "/gate/digitizer/Singles/crystalblurring/setCrystalEnergyOfReference ${PET[isotopeEnergyKeV]} keV"
  echo "/gate/digitizer/Singles/insert                                      thresholder"
  echo "/gate/digitizer/Singles/thresholder/setThreshold                    ${PET[energyWindowMinKeV]} keV"
  echo "/gate/digitizer/Singles/insert                                      upholder"
  echo "/gate/digitizer/Singles/upholder/setUphold                          ${PET[energyWindowMaxKeV]} keV"
  echo "/gate/digitizer/Coincidences/setWindow                              ${PET[coincidencesWindowns]} ns"
  echo "/gate/digitizer/Coincidences/MultiplesPolicy                        takeWinnerOfGoods"
  echo "/gate/digitizer/name                                                delay"
  echo "/gate/digitizer/insert                                              coincidenceSorter"
  echo "/gate/digitizer/delay/setWindow                                     ${PET[coincidencesWindowns]} ns"
  echo "/gate/digitizer/delay/setOffset                                     ${PET[coincidencesOffsetns]} ns"
  echo "/gate/digitizer/delay/MultiplesPolicy                               ${PET[coincidencesPolicy]}"
  if [[ -v PET[lightCrosstalkFraction] ]]; then
    echo "/gate/digitizer/Singles/insert                           crosstalk"
    echo "/gate/digitizer/Singles/crosstalk/chooseCrosstalkVolume  crystal"
    echo "/gate/digitizer/Singles/crosstalk/setEdgesFraction       ${PET[lightCrosstalkFraction]}"
    echo "/gate/digitizer/Singles/crosstalk/setCornersFraction     $(Bcf "0.5 * ${PET[lightCrosstalkFraction]}")"
  fi
  if [[ -v PET[timeResolutionFWHMns] ]]; then
    echo "/gate/digitizer/Singles/insert                            timeResolution"
    echo "/gate/digitizer/Singles/timeResolution/setTimeResolution  ${PET[timeResolutionFWHMns]} ns"
  fi
  if [[ -v PET[pileupTimens] ]]; then
    echo "/gate/digitizer/Singles/insert           pileup"
    #echo "/gate/digitizer/Singles/pileup/setDepth  4" # TODO
    echo "/gate/digitizer/Singles/pileup/setPileup ${PET[pileupTimens]} ns"
  fi
  if [[ -v PET[deadTimens] ]]; then
    echo "/gate/digitizer/Singles/insert                  deadtime"
    echo "/gate/digitizer/Singles/deadtime/setDeadTime    ${PET[deadTimens]}"
    echo "/gate/digitizer/Singles/deadtime/setMode        paralysable"
    echo "/gate/digitizer/Singles/deadtime/chooseDTVolume block" # THIS MUST BE THE NAME OF THE module / submodule BLOCK
  fi
  } #}}}

EchoGateCBCTDigitizer() #{{{
  {
  echo "# 9.  D I G I T I Z E R"
  echo "/gate/digitizer/Singles/insert                    adder"
  echo "/gate/digitizer/Singles/insert                    readout"
  #echo "/gate/digitizer/Singles/readout/setDepth          2" # TODO
  echo "/gate/digitizer/Singles/insert                    thresholder"
  echo "/gate/digitizer/Singles/thresholder/setThreshold  10 keV"
  echo "/gate/digitizer/convertor/verbose                 0"
  } #}}}

EchoGateSPECTSource() #{{{
  {
  local -i dimX=$(awk '$1~/^DimSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local -i dimY=$(awk '$1~/^DimSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local -i dimZ=$(awk '$1~/^DimSize/{print $5}' "${Phantom[atlasMhdFile]}")
  local sizeX=$(awk '$1~/^ElementSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local sizeY=$(awk '$1~/^ElementSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local sizeZ=$(awk '$1~/^ElementSize/{print $5}' "${Phantom[atlasMhdFile]}")
  local halfSizeX=$(Bcf "0.5 * $dimX * $sizeX")
  local halfSizeY=$(Bcf "0.5 * $dimY * $sizeY")
  local halfSizeZ=$(Bcf "0.5 * $dimZ * $sizeZ")
  echo "# 10.  S O U R C E"
  echo "/gate/source/addSource                                      mySource voxel"
  echo "/gate/source/mySource/reader/insert                         image"
  echo "/gate/source/mySource/imageReader/translator/insert         range"
  echo "/gate/source/mySource/imageReader/rangeTranslator/readTable ${Phantom[scaledActivitiesDatFile]}"
  echo "/gate/source/mySource/imageReader/rangeTranslator/describe  1"
  echo "/gate/source/mySource/imageReader/readFile                  ${Phantom[atlasMhdFile]}"
  echo "/gate/source/mySource/imageReader/verbose                   1"
  echo "/gate/source/mySource/setPosition                           -$halfSizeX -$halfSizeY -$halfSizeZ mm"
  echo "/gate/source/mySource/gps/particle                          gamma"
  echo "/gate/source/mySource/gps/energy                            ${SPECT[isotopeEnergyKeV]} keV"
  echo "/gate/source/mySource/gps/angtype                           iso"
  echo "/gate/source/mySource/gps/confine                           NULL"
  echo "/gate/source/mySource/dump                                  1"
  echo "/gate/source/list"
  } #}}}

EchoGatePETSource() #{{{
  {
  local -i dimX=$(awk '$1~/^DimSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local -i dimY=$(awk '$1~/^DimSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local -i dimZ=$(awk '$1~/^DimSize/{print $5}' "${Phantom[atlasMhdFile]}")
  local sizeX=$(awk '$1~/^ElementSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local sizeY=$(awk '$1~/^ElementSize/{print $4}' "${Phantom[atlasMhdFile]}")
  local sizeZ=$(awk '$1~/^ElementSize/{print $5}' "${Phantom[atlasMhdFile]}")
  local halfSizeX=$(Bcf "0.5 * $dimX * $sizeX")
  local halfSizeY=$(Bcf "0.5 * $dimY * $sizeY")
  local halfSizeZ=$(Bcf "0.5 * $dimZ * $sizeZ")
  echo "# 10.  S O U R C E"
  case ${PET[isotope]} in
    "F18")  local energyType=Fluor18;   local halfLifeSec=6586; ;;
    "I124") local energyType=fastI124;  local halfLifeSec=360806; ;;
    "C11")  local energyType=Carbon11;  local halfLifeSec=1223; ;;
    "O15")  local energyType=Oxygen15;  local halfLifeSec=176.3; ;; # lifetime (tau) = 176.3 s, halflife (T_1/2) = 122.2 s
  esac
  echo "/gate/source/addSource                                      mySource voxel"
  echo "/gate/source/mySource/reader/insert                         image"
  echo "/gate/source/mySource/imageReader/translator/insert         range"
  echo "/gate/source/mySource/imageReader/rangeTranslator/readTable ${Phantom[scaledActivitiesDatFile]}"
  echo "/gate/source/mySource/imageReader/rangeTranslator/describe  1"
  echo "/gate/source/mySource/imageReader/readFile                  ${Phantom[atlasMhdFile]}"
  echo "/gate/source/mySource/imageReader/verbose                   1"
  echo "/gate/source/mySource/setPosition                           -$halfSizeX -$halfSizeY -$halfSizeZ mm"

  echo "/gate/source/mySource/gps/particle                          e+"
  echo "/gate/source/mySource/gps/energytype                        $energyType"
  echo "/gate/source/mySource/setType                               backtoback"
  echo "/gate/source/mySource/gps/particle                          gamma"
  #echo "/gate/source/mySource/gps/energytype                        Mono"
  #echo "/gate/source/mySource/gps/monoenergy                        511.0 keV"
  echo "/gate/source/mySource/gps/angtype                           iso"
  echo "/gate/source/mySource/gps/confine                           NULL"
  echo "/gate/source/mySource/setForcedUnstableFlag                 true"
  echo "/gate/source/mySource/setForcedHalfLife                     $halfLifeSec s"
  echo "/gate/source/mySource/dump                                  1"
  echo "/gate/source/list"
  } #}}}

EchoGateSPECTOutput() #{{{
  {
  echo "# 11.  O U T P U T"
  echo "/gate/output/root/enable"
  echo "/gate/output/root/setFileName                   ${Script[gateOutputBaseFile]}"
  echo "/gate/output/root/setRootSinglesAdderFlag       1"
  echo "/gate/output/root/setRootSinglesBlurringFlag    1"
  echo "/gate/output/root/setRootSinglesSpblurringFlag  1"
  echo "/gate/output/root/setRootSinglesThresholderFlag 1"
  echo "/gate/output/root/setRootSinglesUpholderFlag    1"
  echo "#"
  echo "/gate/output/projection/enable"
  echo "/gate/output/projection/setFileName     ${Script[gateOutputBaseFile]}"
  echo "/gate/output/projection/pixelSizeX      ${SPECT[detectorPixelSizeX]} mm"
  echo "/gate/output/projection/pixelSizeY      ${SPECT[detectorPixelSizeY]} mm"
  echo "/gate/output/projection/pixelNumberX    ${SPECT[detectorPixelsX]}"
  echo "/gate/output/projection/pixelNumberY    ${SPECT[detectorPixelsY]}"
  echo "/gate/output/projection/projectionPlane YZ"
  } #}}}

EchoGatePETSOutput() #{{{
  {
  echo "# 11.  O U T P U T"
  echo "/gate/output/root/enable"
  echo "/gate/output/root/setFileName             ${Script[gateOutputBaseFile]}"
  echo "/gate/output/root/setRootHitFlag          1"
  echo "/gate/output/root/setRootSinglesFlag      1"
  echo "/gate/output/root/setRootCoincidencesFlag 1"
  echo "/gate/output/root/setRootNtupleFlag       1"
  } #}}}

EchoGateCBCTOutput() #{{{
  {
  echo "# 11.  O U T P U T"
  echo "#/gate/output/root/disable" # disable / enable
  echo "#/gate/output/root/setFileName        ${Script[gateOutputBaseFile]}"
  echo "#/gate/output/root/setRootHitFlag     0"
  echo "#/gate/output/root/setRootSinglesFlag 1"
  echo "#/gate/output/root/setRootNtupleFlag  0"
  echo "#"
  echo "/gate/output/imageCT/enable"
  echo "/gate/output/imageCT/setFileName  ${Script[gateOutputBaseFile]}"
  echo "/gate/output/imageCT/verbose      0"
  } #}}}

EchoGateRNG() #{{{
  {
  echo "# 12.  R N G"
  echo "/gate/random/setEngineName MersenneTwister"
  echo "/gate/random/setEngineSeed auto"
  } #}}}

EchoGateSPECTMeasurement() #{{{
  {
  echo "# 13.  M E A S U R E M E N T"
  echo "/gate/application/setTimeStart ${SPECT[timeStartSec]} s"
  echo "/gate/application/setTimeStop  $(Bcf "${SPECT[timeStartSec]} + ${SPECT[gantryProjections]} *${SPECT[timePerProjectionSec]}") s"
  echo "/gate/application/setTimeSlice ${SPECT[timePerProjectionSec]} s"
  } #}}}

EchoGatePETMeasurement() #{{{
  {
  echo "# 13.  M E A S U R E M E N T"
  echo "/gate/application/setTimeStart ${PET[timeStartSec]} s"
  echo "/gate/application/setTimeStop  $(Bcf "${PET[timeStartSec]} + ${PET[timeStopSec]}") s"
  echo "/gate/application/setTimeSlice $(Bcf "${PET[timeStopSec]} - ${PET[timeStartSec]}") s"
  } #}}}

EchoGateCBCTMeasurement() #{{{
  {
  echo "# 13.  M E A S U R E M E N T"
  echo "/gate/application/setTimeStart ${CBCT[projectionStartDeg]} s"
  echo "/gate/application/setTimeStop  ${CBCT[projectionStopDeg]} s"
  echo "/gate/application/setTimeSlice ${CBCT[projectionAngleStepDeg]} s"
  } #}}}

EchoGateDAQ() #{{{
  {
  echo "# 14.  D A Q"
  echo "/gate/application/startDAQ"
  } #}}}

WriteGateInterfaceFile() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  touch "${Script[gateInterfaceFile]}"
  if [[ -v Script[gateVisualisationOnly] ]]; then 
                                            EchoGateVerbose          >> "${Script[gateInterfaceFile]}"
                                            EchoGateVisualisation    >> "${Script[gateInterfaceFile]}"
                                            EchoGateMaterial         >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ SPECT ]] && EchoGateSPECTScanner     >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ PET   ]] && EchoGatePETScanner       >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ CBCT  ]] && EchoGateCBCTScanner      >> "${Script[gateInterfaceFile]}"
    [[ -v Phantom[atlasMhdFile] ]]       && EchoGatePhantom          >> "${Script[gateInterfaceFile]}"
                                            EchoGateInitialisation   >> "${Script[gateInterfaceFile]}"
  else
                                            EchoGateVerbose          >> "${Script[gateInterfaceFile]}"
                                            EchoGateVisualisation    >> "${Script[gateInterfaceFile]}"
                                            EchoGateMaterial         >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ SPECT ]] && EchoGateSPECTScanner     >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ PET   ]] && EchoGatePETScanner       >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ CBCT  ]] && EchoGateCBCTScanner      >> "${Script[gateInterfaceFile]}"
    [[ -v Phantom[atlasMhdFile] ]]       && EchoGatePhantom          >> "${Script[gateInterfaceFile]}"
                                            EchoGatePhysics          >> "${Script[gateInterfaceFile]}"
                                            EchoGateActors           >> "${Script[gateInterfaceFile]}"
                                            EchoGateInitialisation   >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ SPECT ]] && EchoGateSPECTDigitizer   >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ PET   ]] && EchoGatePETDigitizer     >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ CBCT  ]] && EchoGateCBCTDigitizer    >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ SPECT ]] && EchoGateSPECTSource      >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ PET   ]] && EchoGatePETSource        >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ SPECT ]] && EchoGateSPECTOutput      >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ PET   ]] && EchoGatePETSOutput       >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ CBCT  ]] && EchoGateCBCTOutput       >> "${Script[gateInterfaceFile]}"
                                            EchoGateRNG              >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ SPECT ]] && EchoGateSPECTMeasurement >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ PET   ]] && EchoGatePETMeasurement   >> "${Script[gateInterfaceFile]}"
    [[ "${Script[modality]}" =~ CBCT  ]] && EchoGateCBCTMeasurement  >> "${Script[gateInterfaceFile]}"
                                            EchoGateDAQ              >> "${Script[gateInterfaceFile]}"
  fi
  } #}}}

DistributeSimulationsToRemoteHosts() #{{{
  {
  # $ ssh-agent $SHELL; ssh-add
  EchoBlLog "${FUNCNAME[0]}() ..."
  # 1. Create remote script
  echo -e "#!/bin/bash\nset -euTEo pipefail\nexec 2>&1\n"                                 >  "${Script[remoteScript]}"
  declare -pf Bcf Bci EchoRd EchoGn EchoYe EchoBl EchoErr Log EchoLog EchoGnLog EchoBlLog EchoWngLog EchoAbort GenerateThreadedGateInterfaceFiles AddThreadedRootFiles AddThreadedSinFiles MergeThreadedMuSourceMaps >> "${Script[remoteScript]}"
  [[ "${Script[modality]}" =~ SPECT ]] && declare -pf SPECTGateMonteCarloSimulation >> "${Script[remoteScript]}"
  [[ "${Script[modality]}" =~ PET   ]] && declare -pf PETGateMonteCarloSimulation >> "${Script[remoteScript]}"
  [[ "${Script[modality]}" =~ CBCT  ]] && declare -pf CBCTGateMonteCarloSimulation >> "${Script[remoteScript]}"
  # shellcheck disable=SC2129
  echo -e "\ntrap 'EchoAbort \${LINENO} \"\$BASH_COMMAND\"' ERR" >> "${Script[remoteScript]}"
  echo -e "[[ \"\${BASH_VERSINFO[0]}\" -lt 5 ]] && EchoErr \"Script needs bash >= 5\"" >> "${Script[remoteScript]}"
  echo -e "main()" >> "${Script[remoteScript]}"
  echo -e "  {" >> "${Script[remoteScript]}"
  echo -e "  declare -gA Script SPECT PET CBCT MRI Phantom Tumor" >> "${Script[remoteScript]}"
  echo -e "  source Script.vars" >> "${Script[remoteScript]}"
  echo -e "  Script[cpuCores]=\$(grep -c processor /proc/cpuinfo)" >> "${Script[remoteScript]}"
  echo -e "  source ${Script[modality]}.vars" >> "${Script[remoteScript]}"
  echo -e "  source Phantom.vars" >> "${Script[remoteScript]}"
  [[ -v Tumor[cellsMhdFile] ]] && echo "  source Tumor.vars" >> "${Script[remoteScript]}"
  [[ "${Script[modality]}" =~ SPECT ]] && echo "  SPECTGateMonteCarloSimulation" >> "${Script[remoteScript]}"
  [[ "${Script[modality]}" =~ PET ]]   && echo "  PETGateMonteCarloSimulation" >> "${Script[remoteScript]}"
  [[ "${Script[modality]}" =~ CBCT ]]  && echo "  CBCTGateMonteCarloSimulation" >> "${Script[remoteScript]}"
  echo -e "  }" >> "${Script[remoteScript]}"
  echo -e "\nmain" >> "${Script[remoteScript]}"
  # 2. Distribute and start simulations remotely
  cp "${Script[rootDir]}"/musire-paths.sh .
  for host in ${Script[remoteHosts]}; do
    EchoMa "${Script[workingDir]}/${Script[remoteScript]} at $host "
    scp -rpq "${Script[workingDir]}" "${Script[user]}@$host:${Script[workingDir]}"
    ssh -f "${Script[user]}@$host" "bash -c 'cd ${Script[workingDir]}; source ./musire-paths.sh; bash ./musire-remote.sh &'"
    EchoMa "...\n"
  done
  } #}}}

MergeOutputOfRemoteHostsWithOutputOfLocalHost() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  # 1. collect simulations from remote hosts
  local -i seconds=0
  while true; do
    local runningHost=false
    EchoMa "\r"
    for host in ${Script[remoteHosts]}; do
      if [[ -n $(ssh -f "${Script[user]}@$host" pgrep -fa "musire-remote.sh") ]]; then EchoMa "$host "; runningHost=true; fi
    done
    if [[ "$runningHost" =~ true ]]; then EchoMa "still running after $seconds seconds"
                                     else { EchoMa "\n"; break; }; fi
    sleep 10; ((seconds+=10))
  done                                            # ... continues here when simulations on remote-hosts are done
  # 2. Merge output data of remote hosts with local host
  for host in ${Script[remoteHosts]}; do
    scp -rpq "${Script[user]}@$host:${Script[workingDir]}" ./"$host"/
    ssh -f "${Script[user]}@$host" "bash -c 'rm -r ${Script[workingDir]}'"
    case "${Script[modality]}" in                 # Integrate data from remote-host simulations into local-host results
      SPECT)
        [[ -f "./$host/${Script[gateOutputBaseFile]}.root" ]] && AddHostRootFiles "$host"
        if [[ -f "./$host/${Script[gateOutputBaseFile]}.sin" ]]; then
          "${Script[toolsDir]}"/add-ushort-raw-into-second "./$host/${Script[gateOutputBaseFile]}.sin" "${Script[gateOutputBaseFile]}.sin"
        fi
        "${Script[toolsDir]}"/add-ushort-raw-into-second "./$host/${Phantom[atlasMhdFile]%.*}-SourceMap.raw" "${Phantom[atlasMhdFile]%.*}-SourceMap.raw"
        ;;
      PET)
        [[ -f "./$host/${Script[gateOutputBaseFile]}.root" ]] && AddHostRootFiles "$host"
        "${Script[toolsDir]}"/add-ushort-raw-into-second "./$host/${Phantom[atlasMhdFile]%.*}-SourceMap.raw" "${Phantom[atlasMhdFile]%.*}-SourceMap.raw"
        ;;
      CBCT)
        "${Script[toolsDir]}"/add-float-raw-into-second "./$host/${CBCT[projectionsMhdFile]%.*}.raw" "${CBCT[projectionsMhdFile]%.*}.raw"
        ;;
      MRI)
        # TODO
        ;;
    esac
  done
  } #}}}

WriteSpinScenarioInterfaceFile() #{{{
  {
  # TODO: this generated lua script closely matches 'examples/seq/se.lua' from the authors of spin-scenario
  #       it serves as a first starting point and might be optimized further
  EchoBlLog "${FUNCNAME[0]}() ..."
  local luaFile=$1
  local sliceZ=$2
  {
  echo "-- run spin echo imaging"
  echo "B0{\"${MRI[B0T]} T\"}"
  echo "peak_grad{${MRI[MaxGradientAmplitudeTm]}}"
  echo "slew_rate{${MRI[MaxGradientSlewRateTms]}}"
  echo "pw90{${MRI[pulseWidth90us]}}"
  echo "seq_parm{fov='${MRI[fieldOfViewXYmm]}*${MRI[fieldOfViewXYmm]}', matrix='${MRI[imageVoxelsXY]}*${MRI[imageVoxelsXY]}'}"
  echo "reduce_phantom{z0=$sliceZ, z1=$sliceZ}"
  echo "-- pulse sequence assembly"
  echo "local adc     = acq{np =${MRI[imageVoxelsXY]}, sw =32000}"
  echo "local gx      = trapGrad{axis=\"X\", func=\"read_out\"}"
  echo "local gxPre   = trapGrad{axis=\"X\", area=0.5*area(gx), width =2}"
  echo "local gy      = trapGrad{axis=\"Y\", func=\"phase_encode\", width =2}"
  echo "local gyspoil = trapGrad{axis=\"Y\", area=math.pi*2*1e3/42.57/(${MRI[fieldOfViewXYmm]}/64), width=3}"
  echo "local rf90  = hardRF{beta=90, width=0.002}"
  echo "local rf180 = hardRF{beta=180, width=0.002}"
  echo "local TR = ${MRI[TRms]}"
  echo "local TE = ${MRI[TEms]}"
  echo "d1 = delay{width=TE/2-rf90.tau/2-gy.tau-rf180.tau/2}"
  echo "d2 = delay{width=TE/2-gx.tau/2-rf180.tau/2}"
  echo "d3 = delay{width=TR-TE-gx.tau/2-rf90.tau/2-gyspoil.tau}"
  echo "local se = seq{rf90, d1, gxPre + gy#, rf180, d2, gx + adc, d3, gyspoil}"
  echo "result = run{exp=se, phantom=\"${Phantom[atlasH5File]}\", supp=\"${Phantom[spinMaterialsDatFile]}\"}"
  } > "$luaFile"
  } #}}}

GenerateThreadedGateInterfaceFiles() #{{{
  {
  [[ "$1" == *"000"* ]] && EchoBlLog "  ${FUNCNAME[0]}() (${Script[cpuCores]} cpuCores) ..."
  local macFile=$1
  local outBaseFile="${Script[gateOutputBaseFile]}-$(printf "%03d\n" "$thread")"
  [[ -v Phantom[atlasMhdFile] ]] && { local muMapFile="${Phantom[atlasMhdFile]%.*}-$(printf "%03d\n" "$thread").mhd"; }
  cp "${Script[gateInterfaceFile]}" "$macFile"
  case "${Script[modality]}" in
    SPECT)
      # gawk -i inplace -v var="$outBaseFile" '$1~/^root\/setFileName/{$2=var}1' "$macFile"    # TODO replace sed by gawk
      sed -i "s/root\/setFileName.*/root\/setFileName $outBaseFile/" "$macFile"
      sed -i "s/projection\/setFileName.*/projection\/setFileName $outBaseFile/" "$macFile"
    ;;
    PET)
      sed -i "s/root\/setFileName.*/root\/setFileName $outBaseFile/" "$macFile"
    ;;
    esac
  [[ -v Phantom[atlasMhdFile] ]] && { sed -i "s/actor\/getMuMap\/save.*/actor\/getMuMap\/save $muMapFile/" "$macFile"; } || :
  } #}}}

MergeThreadedMuSourceMaps() #{{{
  {
  EchoBlLog "  ${FUNCNAME[0]}() ..."
  # add *SourceMap files into a single one
  for (( thread=0; thread<Script[cpuCores]; thread++ )); do
    local rawFile="${Phantom[atlasMhdFile]%.*}-$(printf "%03d\n" "$thread")-SourceMap.raw"
    if [[ -f "$rawFile" ]]; then 
      "${Script[toolsDir]}"/add-ushort-raw-into-second "$rawFile" "${Phantom[atlasMhdFile]%.*}-SourceMap.raw"
    else
      EchoWngLog "Gate output file '$rawFile' does not exsist!"
    fi
  done
  cp "${Phantom[atlasMhdFile]%.*}-000-SourceMap.mhd" "${Phantom[atlasMhdFile]%.*}-SourceMap.mhd"
  sed -i "s/ElementSpacing/ElementSize/" "${Phantom[atlasMhdFile]%.*}-SourceMap.mhd"
  sed -i "s/ElementDataFile = .*/ElementDataFile = ${Phantom[atlasMhdFile]%.*}-SourceMap.raw/" "${Phantom[atlasMhdFile]%.*}-SourceMap.mhd"
  # the *MuMap files are all identical
  cp "${Phantom[atlasMhdFile]%.*}-000-MuMap.mhd" "${Phantom[atlasMhdFile]%.*}-MuMap.mhd"
  cp "${Phantom[atlasMhdFile]%.*}-000-MuMap.raw" "${Phantom[atlasMhdFile]%.*}-MuMap.raw"
  sed -i "s/ElementSpacing/ElementSize/" "${Phantom[atlasMhdFile]%.*}-MuMap.mhd"
  sed -i "s/ElementDataFile = .*/ElementDataFile = ${Phantom[atlasMhdFile]%.*}-MuMap.raw/" "${Phantom[atlasMhdFile]%.*}-MuMap.mhd"
  } #}}}

AddThreadedRootFiles() #{{{
  {
  EchoGnLog "  hadd ${Script[gateOutputBaseFile]}.root ..."
  local -a rootFiles
  for (( thread=0; thread<Script[cpuCores]; thread++ )); do
    rootFiles=("${rootFiles[@]}" "${Script[gateOutputBaseFile]}-$(printf "%03d\n" "$thread").root")
  done
  LD_PRELOAD="${Script[rootDir]}/gate/tools/startup_c.so" "$ROOTSYS/bin/hadd" -k -n 0 "${Script[gateOutputBaseFile]}.root" "${rootFiles[@]}" >> hadd.log
  } #}}}

AddHostRootFiles() #{{{
  {
  EchoBlLog "  ${FUNCNAME[0]}() ..."
  local host=$1
  LD_PRELOAD="${Script[rootDir]}/gate/tools/startup_c.so" "$ROOTSYS/bin/hadd" -k -n 0 -a "${Script[gateOutputBaseFile]}.root" "./$host/${Script[gateOutputBaseFile]}.root" >> hadd.log
  } #}}}

AddThreadedSinFiles() #{{{
  {
  EchoBlLog "  ${FUNCNAME[0]}() ..."
  for (( thread=0; thread<Script[cpuCores]; thread++ )); do
    local sinFile="${Script[gateOutputBaseFile]}-$(printf "%03d\n" "$thread").sin"
    if [[ -f "$sinFile" ]]
      then "${Script[toolsDir]}"/add-ushort-raw-into-second "$sinFile" "${Script[gateOutputBaseFile]}.sin"
      else EchoWngLog "Gate output file '$sinFile' does not exsist!"
    fi
  done
  {
  echo -e "ObjectType = Image\nBinaryData = True\nBinaryDataByteOrderMSB = False\nCompressedData = False\nModality = MET_MOD_NM"
  echo -e "NDims = 3\nElementType = MET_USHORT"
  echo "DimSize = ${SPECT[detectorPixelsX]} ${SPECT[detectorPixelsY]} ${SPECT[gantryProjections]}"
  echo "ElementSize = ${SPECT[detectorPixelSizeX]} ${SPECT[detectorPixelSizeY]} 1"
  echo "ElementSpacing = ${SPECT[detectorPixelSizeX]} ${SPECT[detectorPixelSizeY]} 1"
  echo "Offset = 0.5 0.5 0.5" # TODO: why?
  echo -e "CenterOfRotation = 0 0 0\nTransformMatrix = 1 0 0 0 1 0 0 0 1"
  echo "ElementDataFile = ${Script[gateOutputBaseFile]}.sin"
  } > "${Script[gateOutputBaseFile]}.mhd"
  cp "${Script[gateOutputBaseFile]}-000.hdr" "${Script[gateOutputBaseFile]}.hdr"
  sed -i "s/${Script[gateOutputBaseFile]}-000.sin/${Script[gateOutputBaseFile]}.sin/" "${Script[gateOutputBaseFile]}.hdr"
  } #}}}

SPECTGateMonteCarloSimulation() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local time0=$(date)
  if [[ "${Script[cpuCores]}" -eq 1 ]]; then
    EchoGnLog "Gate ${Script[gateInterfaceFile]} ... "
    Gate "${Script[gateInterfaceFile]}"
  else
    for (( thread=0; thread<Script[cpuCores]; thread++ )); do
      local macFile="${Script[gateInterfaceFile]%.*}-$(printf "%03d\n" "$thread").mac"
      GenerateThreadedGateInterfaceFiles "$macFile"
      Log "Gate $macFile >> Gate-$(printf "%03d\n" "$thread").log"
      Gate "$macFile" >> "Gate-$(printf "%03d\n" "$thread").log" &
    done
    EchoGn "  Gate ${Script[gateInterfaceFile]} ($thread cpuCores) ...\n"
    wait
    AddThreadedRootFiles
    AddThreadedSinFiles
    [[ -v Phantom[atlasMhdFile] ]] && MergeThreadedMuSourceMaps
    cat ./Gate-???.log > Gate.log
    rm -f ./*-???.{log,mac,sin,hdr,mhd,root} ./*-???-{MuMap,SourceMap}.{mhd,raw}
  fi
  if [[ -v Phantom[atlasMhdFile] ]]; then
    # the created attenuation and source maps need some finishing
    echo "Modality = MET_MOD_CT" >> "${Phantom[atlasMhdFile]%.*}-MuMap.mhd"
    sed -i "s/ElementSpacing/ElementSize/" "${Phantom[atlasMhdFile]%.*}-SourceMap.mhd"
    echo "Modality = MET_MOD_NM" >> "${Phantom[atlasMhdFile]%.*}-SourceMap.mhd"
  fi
  EchoLog "  $(Bcf "(($(date -d "$(date)" "+%s") - $(date -d "$time0" "+%s")) / 60)") min."
  } #}}}

PETGateMonteCarloSimulation() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local time0=$(date)
  if [[ "${Script[cpuCores]}" -eq 1 ]]; then
    EchoGnLog "Gate ${Script[gateInterfaceFile]} ... "
    Gate "${Script[gateInterfaceFile]}"
  else
    for (( thread=0; thread<Script[cpuCores]; thread++ )); do
      local macFile="${Script[gateInterfaceFile]%.*}-$(printf "%03d\n" "$thread").mac"
      GenerateThreadedGateInterfaceFiles "$macFile"
      Log "Gate $macFile >> Gate-$(printf "%03d\n" "$thread").log"
      Gate "$macFile" >> "Gate-$(printf "%03d\n" "$thread").log" &
    done
    EchoGn "  Gate ${Script[gateInterfaceFile]} ($thread cpuCores) ...\n"
    wait
    AddThreadedRootFiles
    [[ -v Phantom[atlasMhdFile] ]] && MergeThreadedMuSourceMaps
    cat ./Gate-???.log > Gate.log
    rm -f ./*-???.{log,mac,sin,hdr,mhd,root} ./*-???-{MuMap,SourceMap}.{mhd,raw}
  fi
  if [[ -v Phantom[atlasMhdFile] ]]; then
    # the created attenuation and source maps need some finishing
    echo "Modality = MET_MOD_CT" >> "${Phantom[atlasMhdFile]%.*}-MuMap.mhd"
    sed -i "s/ElementSpacing/ElementSize/" "${Phantom[atlasMhdFile]%.*}-SourceMap.mhd"
    echo "Modality = MET_MOD_NM" >> "${Phantom[atlasMhdFile]%.*}-SourceMap.mhd"
    #sed -i "/^ElementSpacing/a ElementSize = $(awk '$1~/^ElementSize/{print $3}' "${Phantom[atlasMhdFile]%.*}-MuMap.mhd") $(awk '$1~/^ElementSize/{print $4}' "${Phantom[atlasMhdFile]%.*}-MuMap.mhd") $(awk '$1~/^ElementSize/{print $5}' "${Phantom[atlasMhdFile]%.*}-MuMap.mhd")" "${Phantom[atlasMhdFile]%.*}-SourceMap.mhd"
  fi
  EchoLog "  $(Bcf "(($(date -d "$(date)" "+%s") - $(date -d "$time0" "+%s")) / 60)") min."
  } #}}}

CBCTGateMonteCarloSimulation() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local time0=$(date)
  if [[ "${Script[cpuCores]}" -eq 1 ]]; then
    EchoGnLog "Gate  ${Script[gateInterfaceFile]} ... "
    Gate "${Script[gateInterfaceFile]}"
  else
    local photonsPerProjectionPerThread=$(Bcf "${CBCT[photonsPerProjectionBq]} / ${Script[totalThreads]}")
    for (( thread=0; thread<Script[cpuCores]; thread++ )); do
      # generate and adjust mac files per thread
      local macFile="${Script[gateInterfaceFile]%.*}-$(printf "%03d\n" "$thread").mac"
      cp "${Script[gateInterfaceFile]}" "$macFile"
      sed -i "s/xraygun\/setActivity.*/xraygun\/setActivity $photonsPerProjectionPerThread becquerel/" "$macFile"
      sed -i "s/imageCT\/setFileName.*/imageCT\/setFileName gate-simulation-$(printf "%03d\n" "$thread")/" "$macFile"
      Log "Gate  $macFile >> Gate-$(printf "%03d\n" "$thread").log"
      Gate "$macFile" >> "Gate-$(printf "%03d\n" "$thread").log" &
      sleep 0.5 # TODO: this is here because if this goes to fast, the PC did crash
    done
    EchoGn "Gate ${Script[gateInterfaceFile]} ($thread cpuCores) ...\n"
    wait
    # add projection files into a single one
    for (( proj=0; proj<CBCT[Projections]; proj++ )); do
      local rawFile=${CBCT[projectionsMhdFile]%.*}-$(printf "%03d\n" "$proj").raw
      for (( thread=0; thread<Script[cpuCores]; thread++ )); do
        local datFile="gate-simulation-$(printf "%03d\n" "$thread")_$(printf "%03d\n" "$proj").dat"
        if [[ -f "$datFile" ]]; then "${Script[toolsDir]}"/add-float-raw-into-second "$datFile" "$rawFile"
                                else EchoWngLog "Gate output file '$datFile' does not exsist!"; fi
      done
      cat "$rawFile" >> "${CBCT[projectionsMhdFile]%.*}.raw"
    done
    # create a mhd header for the 3D projection file
    {
    echo -e "ObjectType = Image\nBinaryData = True\nBinaryDataByteOrderMSB = False\nCompressedData = False\nModality = MET_MOD_CT"
    echo -e "NDims = 3\nElementType = MET_FLOAT"
    echo "DimSize = ${CBCT[detectorPixelsX]} ${CBCT[detectorPixelsY]} ${CBCT[projections]}"
    echo "ElementSize = 1 1 1"
    echo -e "CenterOfRotation = 0 0 0\nTransformMatrix = 1 0 0 0 1 0 0 0 1"
    echo "ElementDataFile = ${CBCT[projectionsMhdFile]%.*}.raw"
    } > "${CBCT[projectionsMhdFile]}"
    # cleanup
    cat ./Gate-???.log > Gate.log
    rm -f ./*-???.{log,mac,mhd,dac,raw,root}
  fi
  EchoLog "  $(Bcf "(($(date -d "$(date)" "+%s") - $(date -d "$time0" "+%s")) / 60)") min."
  } #}}}

RtkCBCTforwardProjectionSimulation() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local time0=$(date)
  # 1. Create phantom density map from phantom atlas
  local phantomAtlasDensityMhdFile=$("${Script[toolsDir]}"/create-density-mhd-from-phantom-mhd "${Phantom[atlasMhdFile]}" "${Phantom[materialsDatFile]}")
  # 2. Tilt phantom density map to align in the transversal plane as if one would see it from the detector
  local phantomAtlasDensityMhdFile=$("${Script[toolsDir]}"/tilt-mhd "$phantomAtlasDensityMhdFile" -x)
  # make mhd haeader RTK compatible
  local dimX=$(awk '$1~/^DimSize/{print $3}' "$phantomAtlasDensityMhdFile")
  local dimY=$(awk '$1~/^DimSize/{print $4}' "$phantomAtlasDensityMhdFile")
  local dimZ=$(awk '$1~/^DimSize/{print $5}' "$phantomAtlasDensityMhdFile")
  sed -i "/^Offset/d; /^ElementSize/d; /^ElementSpacing/d; /^Modality/d" "$phantomAtlasDensityMhdFile"
  sed -i "/^ElementDataFile.*/i Offset = -$(Bcf "$dimX/2") -$(Bcf "$dimY/2") -$(Bcf "$dimZ/2")\nElementSize = 1 1 1\nModality = MET_MOD_CT" "$phantomAtlasDensityMhdFile"
  # 3. Create an RTK geometry file
  local args=()
        args+=(--nproj="${CBCT[projections]}")
        args+=(--first_angle="${CBCT[projectionStartDeg]}")
        args+=(--arc="${CBCT[projectionStopDeg]}")
        args+=(--sdd="${CBCT[sourceToDetectorDistanceZmm]}")
        args+=(--sid="${CBCT[sourceToCenterOfRotationDistanceZmm]}")
        args+=(-o geometry.xml)
  EchoGnLog "rtksimulatedgeometry  ${args[*]}  >> rtksimulatedgeometry.log"
             rtksimulatedgeometry "${args[@]}" >> rtksimulatedgeometry.log
  # 4. Create the forward projections
  local args=()
        args+=(-g geometry.xml)
        args+=(-i "$phantomAtlasDensityMhdFile")
        args+=(-o "${CBCT[projectionsMhdFile]}")
        args+=(--dimension="${CBCT[detectorPixelsY]}")
  EchoGnLog "rtkforwardprojections  ${args[*]}  >> rtkforwardprojections.log"
             rtkforwardprojections "${args[@]}" >> rtkforwardprojections.log
  # make mhd haeader RTK compatible
  local dimX=$(awk '$1~/^DimSize/{print $3}' "${CBCT[projectionsMhdFile]}")
  local dimY=$(awk '$1~/^DimSize/{print $4}' "${CBCT[projectionsMhdFile]}")
  local dimZ=$(awk '$1~/^DimSize/{print $5}' "${CBCT[projectionsMhdFile]}")
  sed -i "/^Offset/d; /^ElementSize/d; /^ElementSpacing/d; /^Modality/d" "${CBCT[projectionsMhdFile]}"
  sed -i "/^ElementDataFile.*/i Offset = -$(Bcf "$dimX/2") -$(Bcf "$dimY/2") -$(Bcf "$dimZ/2")\nElementSize = 1 1 1\nModality = MET_MOD_CT" "${CBCT[projectionsMhdFile]}"
  EchoLog "$(Bcf "(($(date -d "$(date)" "+%s") - $(date -d "$time0" "+%s")) / 60)") min."
  } #}}}

MRISpinScenarioSimulation() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local startTime=$(date)
  local elementSizeXYmm=$(Bcf "${MRI[fieldOfViewXYmm]} / ${MRI[imageVoxelsXY]}")
  if [[ -v Script[spinScenarioUserLuaFile] ]]; then
    spin-scenario "${Script[spinScenarioUserLuaFile]}"
  else
    #local -i phantomVoxelsZ=$(awk '$1~/^DimSize/{print $5}' "${Phantom[atlasMhdFile]}")
    local -i phantomVoxelsZ=$(awk '$1~/^DimSize/{print $3}' "${Phantom[atlasMhdFile]}") # because of y-tilt !
    set +e # spin-scenario returns error for slices with no material TODO: this might be fixed already
    for (( sliceZ=0; sliceZ<phantomVoxelsZ; sliceZ++ )); do # run spin-scenario per slice
      local luaFile___="${Script[spinScenarioInterfaceFile]%.*}-$(printf "%03d\n" "$sliceZ").lua"
      WriteSpinScenarioInterfaceFile "$luaFile___" "$sliceZ"
      EchoGn "\rspin-scenario $luaFile___ ...\n"
      spin-scenario "$luaFile___" >> "${Script[logFile]}"
      local output_dir___=raw-data-$(printf "%03d\n" "$sliceZ")
      mv raw_data_????????_?????? "$output_dir___"
      cd "$output_dir___" && "${Script[toolsDir]}"/convert-spinscenario-h5-results-to-mhd raw.h5 "$elementSizeXYmm" && cd ..
      if [[ $sliceZ -eq 0 ]]; then
        cp "$output_dir___"/*.{mhd,raw} .
      else
        cat "$output_dir___"/raw-IMG-abs.raw  >> raw-IMG-abs.raw
        cat "$output_dir___"/raw-IMG-re.raw   >> raw-IMG-re.raw
        cat "$output_dir___"/raw-IMG-im.raw   >> raw-IMG-im.raw
        cat "$output_dir___"/raw-FID-abs.raw  >> raw-FID-abs.raw
        cat "$output_dir___"/raw-FID-re.raw   >> raw-FID-re.raw
        cat "$output_dir___"/raw-FID-im.raw   >> raw-FID-im.raw
        cat "$output_dir___"/raw-SPEC-abs.raw >> raw-SPEC-abs.raw
        cat "$output_dir___"/raw-SPEC-re.raw  >> raw-SPEC-re.raw
        cat "$output_dir___"/raw-SPEC-im.raw  >> raw-SPEC-im.raw
      fi
      rm -rf "$luaFile___" "$output_dir___" # clean up
    done
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-IMG-abs.mhd
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-IMG-re.mhd
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-IMG-im.mhd
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-FID-abs.mhd
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-FID-re.mhd
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-FID-im.mhd
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-SPEC-abs.mhd
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-SPEC-re.mhd
    gawk -i inplace -v var="$sliceZ" '$1~/^DimSize/{$5=var}1' raw-SPEC-im.mhd
    "${Script[toolsDir]}"/tilt-mhd raw-IMG-abs.mhd  ++z
    "${Script[toolsDir]}"/tilt-mhd raw-IMG-re.mhd   ++z
    "${Script[toolsDir]}"/tilt-mhd raw-IMG-im.mhd   ++z
    "${Script[toolsDir]}"/tilt-mhd raw-FID-abs.mhd  ++z
    "${Script[toolsDir]}"/tilt-mhd raw-FID-re.mhd   ++z
    "${Script[toolsDir]}"/tilt-mhd raw-FID-im.mhd   ++z
    "${Script[toolsDir]}"/tilt-mhd raw-SPEC-abs.mhd ++z
    "${Script[toolsDir]}"/tilt-mhd raw-SPEC-re.mhd  ++z
    "${Script[toolsDir]}"/tilt-mhd raw-SPEC-im.mhd  ++z
    "${Script[toolsDir]}"/mirror-mhd raw-IMG-abs+zz-tilted.mhd  -x
    "${Script[toolsDir]}"/mirror-mhd raw-IMG-re+zz-tilted.mhd   -x
    "${Script[toolsDir]}"/mirror-mhd raw-IMG-im+zz-tilted.mhd   -x
    "${Script[toolsDir]}"/mirror-mhd raw-FID-abs+zz-tilted.mhd  -x
    "${Script[toolsDir]}"/mirror-mhd raw-FID-re+zz-tilted.mhd   -x
    "${Script[toolsDir]}"/mirror-mhd raw-FID-im+zz-tilted.mhd   -x
    "${Script[toolsDir]}"/mirror-mhd raw-SPEC-abs+zz-tilted.mhd -x
    "${Script[toolsDir]}"/mirror-mhd raw-SPEC-re+zz-tilted.mhd  -x
    "${Script[toolsDir]}"/mirror-mhd raw-SPEC-im+zz-tilted.mhd  -x
  fi
  local endTime=$(date)
  local time=$(( $(date -d "$endTime" "+%s") - $(date -d "$startTime" "+%s") ))
  EchoLog "Computational time: $(Bcf "($time / 60.)") min."
  } #}}}

BLILiprosOpticalSimulation() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local time0=$(date)
  EchoGn "  lipros --cpuCores=${Script[cpuCores]} --phantomIniFilename=${Phantom[iniFile]} --fluenceVoxelSize=${BLI[fluenceVoxelSizeXYZmm]}\n"
  lipros --cpuCores="${Script[cpuCores]}" \
         --phantomIniFilename="${Phantom[iniFile]}" \
         --fluenceVoxelSize="${BLI[fluenceVoxelSizeXYZmm]}"
  EchoLog "$(Bcf "(($(date -d "$(date)" "+%s") - $(date -d "$time0" "+%s")) / 60)") min."
  } #}}}

FMILiprosOpticalSimulation() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local time0=$(date)
  local zOffset=$(Bcf "(${FMI[excitationAxialStopPositionZ]} - ${FMI[excitationAxialStartPositionZ]}) / ${FMI[excitationAxialPositionsZ]}")
  for (( z=0; z<"${FMI[excitationAxialPositionsZ]}"; z++ )); do # TODO: not yet implemented in lipros - filenames for output 
    lipros --cpuCores="${Script[cpuCores]}" \
           --phantomIniFilename="${Phantom[iniFile]}" \
           --fluenceVoxelSize="${FMI[fluenceVoxelSizeXYZmm]}" \
           --fluenceTimeFrames="${FMI[timeFrames]}" \
           --fluenceFrameDuration="${FMI[timeFrameDurationps]}" \
           --excitationSourceType="${FMI[excitationType]}" \
           --excitationSourceWavelengthCenter="${FMI[excitationWavelengthCenternm]}" \
           --excitationSourceWavelengthFwhm="${FMI[excitationWavelengthFwhm]}" \
           --excitationSourcePhotonsPerPos="${FMI[excitationPhotonsPerPosition]}" \
           --excitationSourcePulseDuration="${FMI[excitationPulseDurationps]}" \
           --excitationSourceBeamRadius="${FMI[excitationBeamRadiusmm]}" \
           --excitationSourceBeamLength="${FMI[excitationBeamLengthmm]}" \
           --excitationSourceBeamWidth="${FMI[excitationBeamWidthmm]}" \
           --excitationSourceAxialPositionZ="$(Bcf "${FMI[excitationAxialStartPositionZ]} + $z * $zOffset")" \
           --excitationSourceNumberOfAngles="${FMI[excitationProjections]}" \
           --excitationSourceStartAngle="${FMI[excitationProjectionStartDeg]}" \
           --excitationSourceStopAngle="${FMI[excitationProjectionStopDeg]}"
  done
  EchoLog "$(Bcf "(($(date -d "$(date)" "+%s") - $(date -d "$time0" "+%s")) / 60)") min."
  } #}}}

EchoH33FromMhd_3Dfloat() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local mhdFile="$1"
  echo "INTERFILE :="
  echo "version of keys := CASToRv1.0"
  echo "name of data file := $(awk '$1~/^ElementDataFile/{print $3}' "$mhdFile")"
  echo "data offset in bytes := 0"
  echo "number format := float"
  echo "number of bytes per pixel := 4"
  echo "matrix size [1] := $(awk '$1~/^DimSize/{print $3}' "$mhdFile")"
  echo "matrix size [2] := $(awk '$1~/^DimSize/{print $4}' "$mhdFile")"
  echo "matrix size [3] := $(awk '$1~/^DimSize/{print $5}' "$mhdFile")"
  echo "scaling factor (mm/pixel) [1] := $(awk '$1~/^ElementSize/{print $3}' "$mhdFile")"
  echo "scaling factor (mm/pixel) [2] := $(awk '$1~/^ElementSize/{print $4}' "$mhdFile")"
  echo "scaling factor (mm/pixel) [3] := $(awk '$1~/^ElementSize/{print $5}' "$mhdFile")"
  echo "number of time frames := 1"
  } #}}}

ConvertGateRootToCastorInput() #{{{
  {
  EchoBlLog "  ${FUNCNAME[0]}() ..."
  local args=()
  args+=(-i "${Script[gateOutputBaseFile]}.root")
  args+=(-m "${Script[gateInterfaceFile]}")
  args+=(-o "castor-input")
  args+=(-s "${Script[modality]}-$(date '+%Y-%m-%d-%H-%M-%S')")
  args+=(-geo)
  if [[ "${Script[modality]}" =~ SPECT ]]; then
    # TODO: castor-GATERootToCastor aborts 'corrupted size vs. prev_size'; workaround
    SPECT[detectorPixelsX]=$(Bcf "${SPECT[detectorPixelsX]} + 1")
    SPECT[detectorPixelsY]=$(Bcf "${SPECT[detectorPixelsY]} + 1")
    args+=(-sp_bins "${SPECT[detectorPixelsY]},${SPECT[detectorPixelsX]}")
  elif [[ "${Script[modality]}" =~ PET ]]; then
    [[ -v PET[isotope] && "${PET[isotope]}" =~ F18 ]] && args+=(-ist GATE_F-18)
  fi
  [[ "${Recon[optimizer]}" =~ AML|BSREM|MLTR|NEGML|PPGML ]] && args+=(-oh)
  EchoGnLog "  castor-GATERootToCastor  ${args[*]}  >> castor-GATERootToCastor.log"
               castor-GATERootToCastor "${args[@]}" >> castor-GATERootToCastor.log
  } #}}}

CastorImageReconstruction() #{{{
  {
  EchoBlLog "  ${FUNCNAME[0]}() ..."
  local args=()
  args+=(-df   castor-input_df.Cdh)
  args+=(-fout reco-output)
  args+=(-opti "${Recon[optimizer]}")
  args+=(-proj "${Recon[intersectMethod]}")
  args+=(-it   "${Recon[iterations]}:${Recon[subsets]}")
  if [[ -v Phantom[atlasMhdFile] ]]; then
    local fovDimX=$(awk '$1~/^DimSize/{print $3}' "${Phantom[atlasMhdFile]}")
    local fovDimY=$(awk '$1~/^DimSize/{print $4}' "${Phantom[atlasMhdFile]}")
    local fovDimZ=$(awk '$1~/^DimSize/{print $5}' "${Phantom[atlasMhdFile]}")
    local fovPixdimX=$(awk '$1~/^ElementSize/{print $3}' "${Phantom[atlasMhdFile]}")
    local fovPixdimY=$(awk '$1~/^ElementSize/{print $4}' "${Phantom[atlasMhdFile]}")
    local fovPixdimZ=$(awk '$1~/^ElementSize/{print $5}' "${Phantom[atlasMhdFile]}")
    local fovX=$(Bcf "$fovDimX * $fovPixdimX")
    local fovY=$(Bcf "$fovDimY * $fovPixdimY")
    local fovZ=$(Bcf "$fovDimZ * $fovPixdimZ")
    args+=(-fov  "$fovX , $fovY , $fovZ")
    [[ "${Script[modality]}" =~ PET ]] && args+=(-atn  "${Phantom[atlasMhdFile]%.*}-MuMap.h33")
  fi
  #args+=(-th   "${Script[cpuCores]}")
  args+=(-th 64)
  [[ -v Recon[convolution] ]] && args+=(-conv "${Recon[convolution]}")
  EchoGnLog "  castor-recon  ${args[*]}  >> castor-recon.log"
               castor-recon "${args[@]}" >> castor-recon.log
  } #}}}

EchoMhdFromHdr_3Dfloat() #{{{
  {
  local hdrFile="$1"
  local dimX=$(grep -i '!matrix size \[1\]' "$hdrFile" | awk '{print $5}')
  local dimY=$(grep -i '!matrix size \[2\]' "$hdrFile" | awk '{print $5}')
  local dimZ=$(grep -i '!matrix size \[3\]' "$hdrFile" | awk '{print $5}')
  local pixdimX=$(grep -i 'scaling factor (mm/pixel) \[1\]' "$hdrFile" | awk '{print $6}')
  local pixdimY=$(grep -i 'scaling factor (mm/pixel) \[2\]' "$hdrFile" | awk '{print $6}')
  local pixdimZ=$(grep -i 'scaling factor (mm/pixel) \[3\]' "$hdrFile" | awk '{print $6}')
  local rawFilename=$(grep -i '!name of data file' "$hdrFile" | awk '{print $6}')
  echo "ObjectType = Image"
  echo "BinaryData = True"
  echo "BinaryDataByteOrderMSB = False"
  echo "CompressedData = False"
  echo "Modality = MET_MOD_NM"
  echo "NDims = 3"
  echo "ElementType = MET_FLOAT"
  echo "DimSize = $dimX $dimY $dimZ"
  echo "ElementSize = $pixdimX $pixdimY $pixdimZ"
  echo "ElementSpacing = $pixdimX $pixdimY $pixdimZ"
  echo "ElementDataFile = $rawFilename"
  } #}}}

SPECTCastorImageReconstruction() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local startTime=$(date)
  [[ -v Phantom[atlasMhdFile] ]] && EchoH33FromMhd_3Dfloat "${Phantom[atlasMhdFile]%.*}-MuMap.mhd" > "${Phantom[atlasMhdFile]%.*}-MuMap.h33"
  ConvertGateRootToCastorInput
  CastorImageReconstruction
  local hdrFiles="$(ls reco-output*.hdr)"
  for hdrFile in $hdrFiles; do
    EchoMhdFromHdr_3Dfloat "$hdrFile" > "${hdrFile%.*}.mhd"
    "${Script[toolsDir]}"/tilt-mhd "${hdrFile%.*}.mhd" -z
    rm "$hdrFile"
  done
  [[ -v Phantom[atlasMhdFile] ]] && rm "${Phantom[atlasMhdFile]%.*}-MuMap.h33"
  local endTime=$(date)
  local time=$(( $(date -d "$endTime" "+%s") - $(date -d "$startTime" "+%s") ))
  EchoLog "Computational time: $(Bcf "($time / 60.)") min."
  } #}}}

PETCastorImageReconstruction() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local startTime=$(date)
  [[ -v Phantom[atlasMhdFile] ]] && EchoH33FromMhd_3Dfloat "${Phantom[atlasMhdFile]%.*}-MuMap.mhd" > "${Phantom[atlasMhdFile]%.*}-MuMap.h33"
  ConvertGateRootToCastorInput
  CastorImageReconstruction
  local hdrFiles="$(ls reco-output*.hdr)"
  for hdrFile in $hdrFiles; do
    EchoMhdFromHdr_3Dfloat "$hdrFile" > "${hdrFile%.*}.mhd"
    rm "$hdrFile"
  done
  [[ -v Phantom[atlasMhdFile] ]] && rm "${Phantom[atlasMhdFile]%.*}-MuMap.h33"
  local endTime=$(date)
  local time=$(( $(date -d "$endTime" "+%s") - $(date -d "$startTime" "+%s") ))
  EchoLog "Computational time: $(Bcf "($time / 60.)") min."
  } #}}}

CBCTRtkImageReconstruction() #{{{
  {
  EchoBlLog "${FUNCNAME[0]}() ..."
  local startTime=$(date)
  if [[ ! -v Script[CBCTforwardProjectionSimulation] ]]; then
    # 1. Tilt Gate projection output and make filename (no '+'), header (offset) compatible with RTK
    CBCT[projectionsMhdFile]=$("${Script[toolsDir]}"/tilt-mhd "${CBCT[projectionsMhdFile]}" +z)
    sed -i '/^ElementDataFile/d' "${CBCT[projectionsMhdFile]}"
    # rtk cannot deal with '+' in file names TODO !!! must be ...
    mv gate-simulation-projections+z-tilted.mhd gate-simulation-projections-z-tilted.mhd
    mv gate-simulation-projections+z-tilted.raw gate-simulation-projections-z-tilted.raw
    CBCT[projectionsMhdFile]=gate-simulation-projections-z-tilted.mhd
    projectionsRawFile=gate-simulation-projections-z-tilted.raw
    {
    echo "Offset = -$(Bcf "0.5*${CBCT[detectorPixelsY]}") -$(Bcf "0.5*${CBCT[detectorPixelsX]}") -$(Bcf "0.5*${CBCT[projections]}")"
    echo "ElementDataFile = $projectionsRawFile"
    } >> "${CBCT[projectionsMhdFile]}"
    # 2. Create RTK geometry file
    local args=()
          args+=(--nproj="${CBCT[projections]}")
          args+=(--first_angle="${CBCT[projectionStartDeg]}")
          args+=(--arc="${CBCT[projectionStopDeg]}")
          args+=(--sdd="${CBCT[sourceToDetectorDistanceZmm]}")
          args+=(--sid="${CBCT[sourceToCenterOfRotationDistanceZmm]}")
          args+=(-o geometry.xml)
    EchoGnLog "rtksimulatedgeometry  ${args[*]}  >> rtksimulatedgeometry.log"
               rtksimulatedgeometry "${args[@]}" >> rtksimulatedgeometry.log
  fi
  # 3. perform RTK image reconstruction
  local reconstructionMhdFile=reco-out-${Recon[optimizer]}.mhd
  local cmd args=()
  case "${Recon[optimizer]}" in        # TODO: parameters could become command lne parameters
    "FDK")
      cmd=rtkfdk
    ;;
    "TVR")
      cmd=rtkadmmtotalvariation
      args+=(--niterations="${Recon[iterations]}") # <1>
      ;;
    "DWR")
      cmd=rtkadmmwavelets
      args+=(--niterations="${Recon[iterations]}") # <1>
    ;;
    "ICG")
      cmd=rtkconjugategradient
      args+=(--niterations="${Recon[iterations]}") # <5>
      #args+=(--mask=<Filename>) # Apply a support binary mask: reconstruction kept null outside the mask
    ;;
    "SART")
      cmd=rtksart
      args+=(--niterations="${Recon[iterations]}") # <5>
      args+=(--nprojpersubset="${Recon[subsets]}") # 1 --> SART, >1 && <CTAngleProjections --> OSSART,  TODO: this is proj/angle
                                 # CTAngleProjections --> SIRT
      args+=(--divisionthreshold=0.1) # Threshold below which pixels in the denominator
                                      # in the projection space are considered zero
    ;;
  esac
  args+=(-p .)
  args+=(-r "${CBCT[projectionsMhdFile]}")
  args+=(-o "$reconstructionMhdFile")
  args+=(-g geometry.xml)
  args+=(--dimension="${CBCT[detectorPixelsY]}")
  args+=(--spacing="$(Bcf "${CBCT[sourceToCenterOfRotationDistanceZmm]} / ${CBCT[sourceToDetectorDistanceZmm]}")")
  EchoGnLog "$cmd  ${args[*]}  >> $cmd.log"
             $cmd "${args[@]}" >> $cmd.log
   # 4. Adjust header and scale and tilt reconstruction output to align with the phantom atlas
  local sizeX=$(awk '$1~/^ElementSize/{print $3}' "${Phantom[atlasMhdFile]}")
  local voxelSize=$(Bcf "$sizeX * ${CBCT[sourceToCenterOfRotationDistanceZmm]} / ${CBCT[sourceToDetectorDistanceZmm]}")
  sed -i "/^Offset/d; /^ElementSize/d; /^ElementSpacing/d; /^Modality/d" "$reconstructionMhdFile"
  sed -i "/^ElementDataFile.*/i ElementSize = $voxelSize $voxelSize $voxelSize\nModality = MET_MOD_CT" "$reconstructionMhdFile"
  reconstructionMhdFile=$("${Script[toolsDir]}"/tilt-mhd "$reconstructionMhdFile" +x)
  [[ ! -v Script[CBCTforwardProjectionSimulation] ]] && reconstructionMhdFile=$("${Script[toolsDir]}"/tilt-mhd "$reconstructionMhdFile" +z)
  local endTime=$(date)
  local time=$(( $(date -d "$endTime" "+%s") - $(date -d "$startTime" "+%s") ))
  EchoLog "Computational time: $(Bcf "($time / 60.)") min."
  } #}}}

AskDisclaimerAndCopyright() #{{{
  {
  EchoGn "Multimodal Simulation & Reconstruction Framework for Biomedical Imaging (Musire¨)\n"
  EchoBl "  Author & Developer:\n"
  echo "    Joerg Peter, German Cancer Research Center <j.peter@dkfz-heidelberg.de>"
  EchoBl "  Disclaimer & Copyright:\n"
  echo "    The purpose of this program is only for academic research excluding any clinical study."
  echo "    Usage of this code is in compliance with the Apache License 2.0 (cf. ./LICENSE)"
  EchoYe "  Do you accept this Disclaimer & Copyright? "
  read -r -p " <y/n> " -n1 answer
  [[ "$answer" != "y" ]] && { echo -e "\n\e[1;38;5;124;82m\e[47mNot accepted!\e[0m"; exit; } || echo -e "\n";
  } #}}}

# ===========================================================================================================
main "$@"
