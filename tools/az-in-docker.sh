#!/bin/bash

docker run -it --mount type=bind,src="$HOME"/.ssh,dst=/root/.ssh mcr.microsoft.com/azure-cli:azurelinux3.0
