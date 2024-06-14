#!/bin/bash

set -x
cd /workspace/capicxx-core-tools/org.genivi.commonapi.core.releng || exit 1

# This fails a lot
count=0
while (( ++count <= 10 )); do
  echo -e "\ncapicxx-core-tools build attempt $count"
  mvn -Dtarget.id=org.genivi.commonapi.core.target clean verify && break
done
test_file=/workspace/capicxx-core-tools/org.genivi.commonapi.core.cli.product/target/products/org.genivi.commonapi.core.cli.product/all/commonapi-core-generator-linux-x86_64
if [[ ! -e "${test_file}" ]]; then
  echo "Failed to build org.genivi.commonapi.core.target after many retries.  Giving up."
  exit 1
fi

cd /workspace/capicxx-someip-tools/org.genivi.commonapi.someip.releng || exit 1
COREPATH=/workspace/capicxx-core-tools
mvn -DCOREPATH=${COREPATH} -Dtarget.id=org.genivi.commonapi.someip.target clean verify
