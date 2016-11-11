#!/bin/bash
#$ -S /bin/bash
#$ -cwd

. /etc/profile.d/modules.sh
MODULEPATH=$MODULEPATH:/exports/igmm/software/etc/el7/modules

module load igmm/apps/tabix/0.2.5
module load igmm/apps/perl/5.24.0
module load igmm/apps/vep/86

NAME=$1
ASSEMBLY=$2

vep --cache --offline -i $NAME.vcf.gz -o $NAME.vep.86.txt --everything --assembly $ASSEMBLY &> $NAME.vep.86.log
