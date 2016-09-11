#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Packaging citac..."

rm -f citac/tar.gz
tar -C $SCRIPT_DIR -czf citac.tar.gz ../../../lib ../../../bin

types=("base" "puppet")
oss=("debian-7" "ubuntu-14.04" "centos-7")

for type in ${types[@]}
do
    for os in ${oss[@]}
    do
        echo "Generating test image for $type/$os"...
        rm -f $SCRIPT_DIR/environments_$type/$os/citac.tar.gz
        cp $SCRIPT_DIR/citac.tar.gz $SCRIPT_DIR/environments_$type/$os/citac.tar.gz
        docker rmi citac/environments_$type:$os >> ${type}_${os}.log
        docker build -t citac/environments:${type}_${os} $SCRIPT_DIR/environments_$type/$os | tee ${type}_${os}.log && echo "success" || echo "failed"
    done
done

echo "Generating main image..."

cp $SCRIPT_DIR/citac.tar.gz $SCRIPT_DIR/main/citac.tar.gz
docker build -t citac/environments:main $SCRIPT_DIR/main | tee main.log && echo "success" || echo "failed"