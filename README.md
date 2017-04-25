[![Docker Repository on Quay](https://quay.io/repository/pancancer/pcawg-consensus-caller/status "Docker Repository on Quay")](https://quay.io/repository/pancancer/pcawg-consensus-caller)

# PCAWG Consensus call image

This repo contains a docker image which encapsulates the final consensus-calling pipeline 
for SNVs and Indels for the PCAWG project.

The docker image can be built using:
```
docker build -t consensus_call .
```

## Downloading auxiliary files

The consensus calling process requires the downloading and preprocessing of several 
large standard annotation files (the reference, 1000 genomes VCF, dbSNP, repeat masker);
this is done with the following invocations:

```
mkdir dbs
docker run -it -v "${PWD}/dbs":/dbs consensus_call download reference /dbs
docker run -it -v "${PWD}/dbs":/dbs consensus_call download annotations /dbs
docker run -it -v "${PWD}/dbs":/dbs consensus_call download cosmic /dbs
```

where the cosmic downloads are optional for SNV calling (but required for indels) and
requires registration at: https://cancer.sanger.ac.uk/cosmic/register.

## Consensus ensemble calling

The step aboves creates a directory structure under `${PWD}/dbs` which the consensus pipeline
expects to be mounted at `/dbs`.  To run the conensus pipeline, invoke the docker as, eg:

```
docker run -v "${PWD}/dbs":/dbs -v "/path/to/data/files":/data consensus_call consensus snv \
    -b /data/broad_snv_file.vcf.gz \
    -d /data/dkfz_snv_file.vcf.gz \
    -m /data/muse_snv_file.vcf.gz \
    -s /data/sanger_snv_file.vcf.gz \
    -o /data/consensus_snv.vcf
```

and similarly with indels (although -m is smufin). These VCFs are expected to have gone through
the PCAWG annotation pipelines (for OxoG calling and minibam-based annotation).

## Additional filtering

As the final step of the PCAWG consensus calling, external filters (and annotations) are added
to the final calls.  Those can be added with:

```
... consensus_call filter presence_in_maf [--info] -d description /path/to/input.maf sample_ID filter_name -i /path/to/input.vcf -o output.vcf
    - adds filter/info to VCF entry if sample_ID and variant present in input.maf
... consensus_call filter column_of_maf [--info] -c column_name -d description /path/to/input.maf sample_ID filter_name -i /path/to/input.vcf -o output.vcf
    - adds filter/info to VCF entry from column name column_name in input.maf if present
... consensus_call filter sex -s {male|female} -i /path/to/input.vcf -o output.vcf
    - filters Y-chrom calls if female
... consensus_call filter header_from_tsv -n header_name -I sample_ID -c column_number -t /path/to/input.tsv -i /path/to/input.vcf 
    - adds annotation to VCF header entry based on the row containing sample_ID and the column column_number in input.tsv
```

For instance, for SNVs, the equivalent of the following steps are run, for sample `${ID}`:

```
docker... consensus_call filter presence_in_maf -d "1000Genome variant with insufficient somatic evidence" Broad_germline_site_filter_failed_mutations.tsv ${ID} GERM1000G 
docker... consensus_call filter presence_in_maf -d "Overlaps germline Haplotype call" somatic_germline_overlap_by_patient.tsv ${ID} GERMOVLP 
docker... consensus_call filter presence_in_maf -d "Presence in Panel of Normals" panel_of_normals/${ID}.snv_mnv.maf ${ID} NORMALPANEL 
docker... consensus_call filter presence_in_maf --info -d "Sanger Tower: Possible Artifact" pcawg7_artifacts/R1.tsv ${ID} signature_R1 
docker... consensus_call filter presence_in_maf --info -d "Suspected C>A oxo-guanine signature in some samples" pcawg7_artifacts/R2.tsv ${ID} signature_R2 
docker... consensus_call filter presence_in_maf --info -d "T>A mutation often in bleed through context" pcawg7_artifacts/N3.tsv ${ID} signature_N3 
docker... consensus_call filter presence_in_maf --info -d "SNV is located near indel" somaticSnv_at_sameSampleSomaticAndGermlineIndels.tab ${ID} snv_near_indel 
docker... consensus_call filter column_of_maf --info -c Variant_Classification -d "Variant Classification" classification/${ID}.snv_mnv.maf Variant_Classification 
docker... consensus_call filter column_of_maf -d "Variant no longer seen under remapping" realignment/${ID}.snv_mnv.maf REMAPFAIL 
docker... consensus_call filter sex "${SEX}"
docker... consensus_call filter header_from_tsv -c 11 -i ${ID} -n TumourInNormalEstimate -t release_may2016.v1.1.TiN__donor.TiNsorted.20Jul2016.tsv
docker... consensus_call filter header_from_tsv -c 3 -i ${ID} -n BAMQCStars -t release/by_tumour_id.tsv
docker... consensus_call filter header_from_tsv -c 2 -i ${ID} -n ContEST -t release/by_tumour_id.tsv
```
