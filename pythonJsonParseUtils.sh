#!/bin/bash
#Written by Andrea Di Iorio
parseStdinJsonFields(){
    python3 -c $'import sys, json; print(json.load(sys.stdin)['name'])'
}

parseJsonFileFields(){
	#parse file given in arg 1 and print each field fiven in arg 2,3,4,....
	python3 -c $'from sys import argv\nfrom json import load\n\
	trgt=load(open(argv[1]).read())\nfor i in range(2,len(argv)): print(argv[i],trgt[argv[i]],sep="\t-->\t")' $@
}
