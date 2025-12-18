
#!/bin/usr/bash

printf "\n\n${CYAN}Check that directory Endeavouros-arm/test-images is empty${NC}\n\n"
read -n 1 z

./script-image-build.sh -p rpi4
./script-image-build.sh -p rpi5
./script-image-build.sh -p pbp
# ./script-image-build.sh -p odn
./script-image-build.sh -p srpi
./script-image-build.sh -p sodn

