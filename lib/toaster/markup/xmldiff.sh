#!/bin/bash

dir=.

java -cp $dir/vmtools-utils-0.5.jar:$dir/jdom-b7.jar:$dir/jdom-1.1.jar XmlDiff $*
