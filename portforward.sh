#!/bin/sh

kubectl port-forward deployment/demoapp-deployment 8089:8080 &
echo "Demoapp is now running at http://localhost:8089"
echo "To stop the port-forwarding, run: kill %1"
x-www-browser http://localhost:8089