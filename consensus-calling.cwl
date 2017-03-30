#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
id: "ConsensusCalling"
label: "ConsensusCalling"

description: |
    This is the ConsensusCalling tool used in the PCAWG project.
    ConsensusCalling was created by Jonathan Dursi (jonathan.dursi@sickkids.ca).
    This CWL wrapper was created by Solomon Shorser.
    For more information about ConsensusCalling, see: https://github.com/ljdursi/consensus_call_docker

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
