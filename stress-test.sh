#!/bin/bash

# Install stress package if not installed
sudo apt-get update -y
sudo apt-get install stress -y

# Run stress for 5 minutes (300 seconds)
stress --cpu 4 --timeout 300

