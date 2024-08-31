
#!/bin/usr/bash

printf "\n\n${CYAN}Check that directory Endeavouros-arm/test-images is empty${NC}\n\n"
read -n 1 z

./script-image-build.sh -p rpi4 -c y
./script-image-build.sh -p rpi5 -c y
./script-image-build.sh -p pbp  -c y
./script-image-build.sh -p odn  -c y
./script-image-build.sh -p srpi -c y
./script-image-build.sh -p sodn -c y

