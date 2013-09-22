#!/bin/bash
cat $* | grep '##' | sed -e 's:##://!:' | tee junk.output


