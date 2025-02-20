#!/bin/bash

set -e

# Define a cleanup function to be executed upon receiving a SIGINT
cleanup() {
    echo -e "\n\e[1;33m[ThirdReality] INFO: Script interrupted. Cleaning up...\e[0m"
    # Add any cleanup commands you might need here, like removing temporary files
    exit 1
}

# Trap SIGINT (Ctrl+C) to run the cleanup function
trap cleanup SIGINT

print_info() { echo -e "\e[1;34m[ThirdReality] INFO:\e[0m $1"; }
print_error() { echo -e "\e[1;31m[ThirdReality] ERROR:\e[0m $1"; }

# Record start time
start_time=$(date +%s)

check_command() {
  if ! command -v "$1" > /dev/null 2>&1; then
    sudo apt update && sudo apt install "$2" -y
  fi
}

initialize_git_repo() {
  local repo_dir=$1
  local git_url=$2
  local branch=$3

  if [ ! -d "$repo_dir" ]; then
    /usr/bin/git clone --branch $branch $git_url $repo_dir
    cd $repo_dir
    git config --local gc.auto 0
    git sparse-checkout disable
    git config --local --unset-all extensions.worktreeConfig
    git log -1 --format=%H
  fi
}



# Directories setup
current_dir=$(pwd)
print_info "Working directory is '$current_dir'"

# Check Git installation
print_info "$(/usr/bin/git version)"
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000

# User patches setup
#cd "$work_dir/armbian-os"
if [ ! -d "userpatches" ]; then
  print_info "Init userpatches ..."
  mkdir -pv userpatches
  rsync -av os.repo/userpatches-jethub/. userpatches/
fi

echo "24.11" > userpatches/VERSION

print_info "ImageOS: ${ImageOS}"

# Determine loop device if needed
if [ -z "${ImageOS}" ]; then
  USE_FIXED_LOOP_DEVICE=$(echo ${RUNNER_NAME} | rev | cut -d"-" -f1 | rev | sed 's/^0*//' | sed -e 's/^/\/dev\/loop/')
fi

print_info "param: ${USE_FIXED_LOOP_DEVICE}"

print_info "Start building ..."
./compile.sh 'BETA=no' 'BOARD=jethubj100' 'BRANCH=current' 'BUILD_DESKTOP=no' 'BUILD_MINIMAL=no' 'RELEASE=bookworm' \
  'REVISION=24.11' jethome-images REVISION="24.11" USE_FIXED_LOOP_DEVICE="$USE_FIXED_LOOP_DEVICE" \
  MAKE_FOLDERS="archive" IMAGE_VERSION=24.11 SHOW_DEBIAN=yes SHARE_LOG=no ALLOW_ROOT=yes KERNEL_GIT=shallow \
  UPLOAD_TO_OCI_ONLY=no NETWORKING_STACK="network-manager" ARTIFACT_IGNORE_CACHE=yes

#ARTIFACT_IGNORE_CACHE=yes

print_info "Armbian build finished."

# Check required tools installation
check_command "dtc" "device-tree-compiler"
check_command "cc" "build-essential cpp"
check_command "zip" "zip"

# Find output files
UBOOTDEB=$(find output | grep linux-u-boot | head -n 1)
IMG=$(find output | grep -e  ".*images.*Armbian.*img.xz$" | head -n 1)

print_info "Uboot.deb: ${UBOOTDEB}"
print_info "Image: ${IMG}"

cd "$current_dir/tools.repo"

DEB="../${UBOOTDEB}"
dpkg -x "$DEB" output
UBOOT=$(find output/usr/lib -name u-boot.nosd.bin | head -n 1)
print_info "UBOOT: ${UBOOT}"

print_info "Start convert image ..."
EVALCMD='BETA=no BOARD=jethubj100 BRANCH=current BUILD_DESKTOP=no BUILD_MINIMAL=no RELEASE=jammy REVISION=24.11'
eval "$EVALCMD"

case ${BOARD} in
  jethubj100)
    ./convert.sh ../${IMG} d1 armbian compress output/usr/lib/linux*/u-boot.nosd.bin
    SUPPORTED="D1,D1P"
    ;;
  jethubj200)
    ./convert.sh ../${IMG} d2 armbian compress output/usr/lib/linux*/u-boot.nosd.bin
    SUPPORTED="D2"
    ;;
  jethubj80)
    ./convert.sh ../${IMG} h1 armbian compress output/usr/lib/linux*/u-boot.nosd.bin
    SUPPORTED="H1"
    ;;
  *)
    print_error "Unsupported board ${BOARD}"
    print_error "Error in convert: Unsupported board ${BOARD}" >> GITHUB_STEP_SUMMARY
    exit 200
    ;;
esac

rm -rf output/usr

IMGBURN=$(find output | grep -e  "Armbian.*burn.img.zip$" | head -n 1)
print_info "IMGBURN: ${IMGBURN}"

[ -z "${IMGBURN}" ] && exit 50

CHANNEL="release"

print_info "board=${BOARD} brd=${BOARD:6} branch=${BRANCH} channel=${CHANNEL} release=${RELEASE} supported=${SUPPORTED}"
print_info "image=${IMG}"
print_info "imageburn=tools/${IMGBURN}"

# Record end time
end_time=$(date +%s)

# Calculate elapsed time in seconds
elapsed_time=$((end_time - start_time))

# Convert elapsed time to a more readable format
minutes=$(( (elapsed_time % 3600) / 60))
seconds=$((elapsed_time % 60))

print_info "Armbian build finished."
print_info "Build completed in ${minutes} minutes, and ${seconds} seconds."



