#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
id: "ConsensusCalling"
label: "ConsensusCalling"

dct:creator:
    foaf:name: "Solomon Shorser"
    foaf:mbox: "solomon.shorser@oicr.on.ca"

dct:contributor:
    foaf:name: "Jonathan Dursi"
    foaf:mbox: "jonathan.dursi@sickkids.ca"

requirements:
    DockerRequirement:
      dockerPull: quay.io/pancancer/pcawg-consensus-caller
    EnvVarRequirement:
      envDef:
        USE_DB_PATH: $(inputs.dbs_dir.path)/annotation_databases

doc: |

    This is the ConsensusCalling tool used in the PCAWG project.
    ConsensusCalling was created by Jonathan Dursi (jonathan.dursi@sickkids.ca).
    This CWL wrapper was created by Solomon Shorser.
    For more information about ConsensusCalling, see: https://github.com/ljdursi/consensus_call_docker

    ## Run the workflow with your own data
    ### Prepare compute environment and install software packages
    The workflow has been tested in Ubuntu 16.04 Linux environment with the following hardware
    and software settings.

    #### Hardware requirement (assuming 30X coverage whole genome sequence)
    - CPU core: 16
    - Memory: 64GB
    - Disk space: 1TB

    #### Software installation
    - Docker (1.12.6): follow instructions to install Docker https://docs.docker.com/engine/installation
    - CWL tool
    ```
    pip install cwltool==1.0.20170217172322
    ```

    ### Prepare input data
    #### Input unaligned BAM files

    #The workflow uses lane-level unaligned BAM files as input, one BAM per lane (aka read group).
    #Please ensure *@RG* field is populated properly in the BAM header, the following is a
    #valid *@RG* entry. *ID* field has to be unique among your dataset.
    #```
    #@RG	ID:WTSI:9399_7	CN:WTSI	PL:ILLUMINA	PM:Illumina HiSeq 2000	LB:WGS:WTSI:28085	PI:453	SM:f393ba16-9361-5df4-e040-11ac0d4844e8	PU:WTSI:9399_7	DT:2013-03-18T00:00:00+00:00
    #```
    #Multiple unaligned BAMs from the same sample (with same *SM* value) should be run together. *SM* is
    #globally unique UUID for the sample. Put the input BAM files in a subfolder. In this example,
    #we have two BAMs in a folder named *bams*.


    #### Reference genome sequence files

    #The reference genome files can be downloaded from the ICGC Data Portal at
    #under https://dcc.icgc.org/releases/PCAWG/reference_data/pcawg-bwa-mem. Please download all
    #reference files and put them under a subfolder called *reference*.

    #### Job JSON file for CWL

    Finally, we need to prepare a JSON file with input, reference and output files specified. Please
    replace the *reads* parameter with your real BAM file name.

    Name the JSON file: *pcawg-consensus-caller.job.json*
    ```
    {Example Job json needed}
    ```

    ### Run the workflow
    #### Option 1: Run with CWL tool
    - Download CWL workflow definition file
    ```
    wget -O pcawg-bwa-mem-aligner.cwl "https://raw.githubusercontent.com/ICGC-TCGA-PanCancer/Seqware-BWA-Workflow/2.6.8_1.3/Dockstore.cwl"
    ```

    - Run *cwltool* to execute the workflow
    ```
    nohup cwltool --debug --non-strict consensus-calling.cwl pcawg-consensus-caller.job.json > pcawg-consensus-caller.log 2>&1 &
    ```

    #### Option 2: Run with the Dockstore CLI
    See the *Launch with* section below for details

inputs:
    variant_type:
      type: string
      inputBinding:
        position: 1
      secondaryFiles:
        - .tbi

    broad_input_file:
      type: File
      inputBinding:
        position: 2
        prefix: "-b"
      secondaryFiles:
        - .tbi

    dkfz_embl_input_file:
      type: File
      inputBinding:
        position: 3
        prefix: "-d"
      secondaryFiles:
        - .tbi

    muse_input_file:
      type: File
      inputBinding:
        position: 4
        prefix: "-m"
      secondaryFiles:
        - .tbi

    sanger_input_file:
      type: File
      inputBinding:
        position: 5
        prefix: "-s"
      secondaryFiles:
        - .tbi

    dbs_dir:
      type: Directory

arguments:
    - prefix: -o
      valueFrom: $(runtime.outdir)/$(inputs.output_file_name)
      position: 6

outputs:
    consensus_zipped_vcf:
      type: File
      outputBinding:
          glob: "$(inputs.output_file_name).gz"
    consensus_vcf_index:
      type: File
      outputBinding:
          glob: "$(inputs.output_file_name).gz.tbi"



baseCommand: consensus
