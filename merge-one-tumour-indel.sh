#!/bin/bash 
## merges indel files together
## requires mergevcf, bgzip, tabix

readonly REFERENCE=${USE_REFERENCE:-"/reference/genome.fa.gz"}
readonly TMPDIR=${USE_TMPDIR:-"/tmp"}

function usage {
    >&2 echo "usage: $0 -b [/path/to/broad.indel.vcf.gz] -d [dkfz] -m [smufin] -s [sanger] -o [outfile: defaults to merged.vcf]"
    >&2 echo "       merges indel VCFs for sample"
    >&2 echo "       Input VCFs must be bgzip-ed and tabix-ed"
    exit 1
}

function add_header_and_sort {
    local file=$1
    local header=$2
    local grep_or_zgrep=grep
    if [[ $file == *.gz ]]
    then
        local grep_or_zgrep=zgrep
    fi

    ${grep_or_zgrep} "^##" "$file"
    if [[ ! -z "$header" ]] 
    then
        echo $header
    fi
    ${grep_or_zgrep} -v "^##" "$file" \
        | sort -k1,1 -k2,2n
}

readonly TAB=$'\t'

function cleanup {
    # normalize, and get rid of known broad and sanger weirdnesses
    local file=$1
    vt decompose -s "$file" \
        | vt normalize -r "$REFERENCE" - \
        | sed -e "s/${TAB}${TAB}${TAB}$/${TAB}.${TAB}.${TAB}./" \
        | grep -v '=$' 
}

function make_cleaned {
    local file=$1
    local outfile=$2
    if [[ -f "$file" ]] 
    then
        cleanup $1 \
            | bgzip > ${outfile}
        tabix -p vcf ${outfile}
    fi
}

outfile=merged.indel.vcf

while getopts "b:d:m:s:o:h" OPTION 
do
    case $OPTION in
        b) readonly broadfile=${OPTARG}
            ;;
        d) readonly dkfzfile=${OPTARG}
            ;;
        m) readonly smufinfile=${OPTARG}
            ;;
        s) readonly sangerfile=${OPTARG}
            ;;
        h) usage
            ;;
        o) outfile=${OPTARG}
            ;;
    esac
done

if [[ -z "$dkfzfile" ]] || [[ -z "$sangerfile" ]]
then
    >&2 echo "required argument missing: need dkfz (-d) and sanger (-s) files"
    usage
fi

if [[ -z "${outfile}" ]]
then
    >&2 echo "Invalid empty output filename"
    usage
fi

if [[ ! -f "$dkfzfile" ]] || [[ ! -f "$sangerfile" ]]
then
    >&2 echo "files missing: one of -b ${broadfile} -d ${dkfzfile} not found"
    usage
fi

for file in "$smufinfile" "$broadfile" "$dkfzfile" "$sangerfile"
do
    if [[ -f $file ]]  
    then
        if [[ $file != *.gz ]] || [[ ! -f ${file}.tbi ]]
        then
            >&2 echo "Input VCF files must be bgziped and tabixed."
            usage
        fi
    fi
done

newest=$dkfzfile
if [[ $sangerfile -nt $newest ]]; then newest=$sangerfile; fi
if [[ -f "${broadfile}" ]] && [[ $broadfile -nt $newest ]]; then newest=$broadfile; fi
if [[ -f "${smufinfile}" ]] && [[ $smufinfile -nt $newest ]]; then newest=$smufinfile; fi

if [[ -f "${outfile}.gz" ]] && [[ "${outfile}.gz" -nt "${newest}" ]]
then
    >&2 echo "$0: ${outfile} exists and is newer than inputs; cowardly refusing to overwrite."
    exit 1
fi

for caller in "broad" "dkfz" "sanger" "smufin"
do
    declare oldfilename=${caller}file
    declare newfilename=cleaned_${caller}file
    declare $newfilename=${TMPDIR}/${caller}.indel.vcf.gz
    make_cleaned ${!oldfilename} ${!newfilename}
done

##
## merge input files into one VCF
##
readonly MERGEDFILE=${TMPDIR}/merged.vcf
readonly MERGEDSORTEDFILE=${TMPDIR}/merged.sorted.vcf
if [[ -f "${broadfile}" ]] && [[ -f "${smufinfile}" ]] 
then
    mergevcf -l broad,dkfz,smufin,sanger \
            "$cleaned_broadfile" \
            "$cleaned_dkfzfile" \
            "$cleaned_smufinfile" \
            "$cleaned_sangerfile" \
            --ncallers \
        > "${MERGEDFILE}"
elif [[ -f "${broadfile}" ]] 
then
    mergevcf -l broad,dkfz,sanger \
            "$cleaned_broadfile" \
            "$cleaned_dkfzfile" \
            "$cleaned_sangerfile" \
            --ncallers \
        > "${MERGEDFILE}"
else 
    mergevcf -l dkfz,smufin,sanger \
            "$cleaned_dkfzfile" \
            "$cleaned_sangerfile" \
            "$cleaned_smufinfile" \
            --ncallers \
        > "${MERGEDFILE}"
fi

add_header_and_sort ${MERGEDFILE} \
    | grep -v "Callers=broad;" \
    | bgzip > ${MERGEDSORTEDFILE}.gz
tabix -p vcf ${MERGEDSORTEDFILE}.gz
rm -f ${MERGEDFILE}

## 
## Annotate with the SGA annotations 
##

readonly TEMPLATE="${TMPDIR}/vaf.annotate.single.conf"

cat > "${TEMPLATE}" << EOF
[[annotation]]
file="@@FILE@@"
fields = ["TumorVAF", "NormalVAF", "TumorVarDepth", "TumorTotalDepth", "NormalVarDepth", "NormalTotalDepth", "RepeatRefCount"]
names = ["TumorVAF", "NormalVAF", "TumorVarDepth", "TumorTotalDepth", "NormalVarDepth", "NormalTotalDepth", "RepeatRefCount"]
ops = ["self", "self", "self", "self", "self", "self", "self"]
EOF

readonly ANNOTATION_CONF="${TMPDIR}/vaf.indel.$$.conf"
rm -f "${ANNOTATION_CONF}"
for input_file in "$cleaned_broadfile" "$cleaned_dkfzfile" "$cleaned_sangerfile" "$cleaned_smufinfile"
do
    if [[ -f "$input_file" ]]
    then
        sed -e "s#@@FILE@@#$input_file#" "${TEMPLATE}" >> "${ANNOTATION_CONF}"
        echo " " >> "${ANNOTATION_CONF}"
    fi
done

rm -f ${TEMPLATE}

vcfanno -p 1 ${ANNOTATION_CONF} ${MERGEDSORTEDFILE}.gz \
    | sed -e 's/\tFORMAT.*$//' \
    | sed -e 's/^##INFO=<ID=TumorVAF,.*$/##INFO=<ID=TumorVAF,Number=1,Type=Float,Description="VAF of variant in tumor from sga">/' \
    | sed -e 's/^##INFO=<ID=TumorVarDepth,.*$/##INFO=<ID=TumorVarDepth,Number=1,Type=Integer,Description="Tumor alt count from sga">/' \
    | sed -e 's/^##INFO=<ID=TumorTotalDepth,.*$/##INFO=<ID=TumorTotalDepth,Number=1,Type=Integer,Description="Tumor total read depth from sga">/' \
    | sed -e 's/^##INFO=<ID=NormalVAF,.*$/##INFO=<ID=NormalVAF,Number=1,Type=Float,Description="VAF of variant in normal from sga">/' \
    | sed -e 's/^##INFO=<ID=NormalVarDepth,.*$/##INFO=<ID=NormalVarDepth,Number=1,Type=Integer,Description="Normal alt count from sga">/' \
    | sed -e 's/^##INFO=<ID=NormalTotalDepth,.*$/##INFO=<ID=NormalTotalDepth,Number=1,Type=Integer,Description="Normal total read depth from sga">/' \
    > ${outfile}

rm -f "$cleaned_broadfile" "$cleaned_dkfzfile" "$cleaned_sangerfile" "$cleaned_smufinfile"
rm -f "${cleaned_broadfile}.tbi" "${cleaned_dkfzfile}.tbi" "${cleaned_sangerfile}.tbi" "${cleaned_smufinfile}.tbi"

rm -f ${ANNOTATION_CONF}
rm -f ${MERGEDSORTEDFILE}.gz
rm -f ${MERGEDSORTEDFILE}.gz.tbi

bgzip -f ${outfile}
tabix -p vcf ${outfile}.gz
