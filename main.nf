#!/usr/bin/env nextflow

params.outdir = '.'
params.all = false
params.minerva = false
params.miniature = false
params.metadata = false
params.he = false
params.input = 's3://htan-imaging-example-datasets/HTA9_1_BA_L_ROI04.ome.tif'
params.echo = false
params.keepBg = false
params.bucket = false
params.level = -1
params.bioformats2ometiff = true
params.synapseconfig = false

heStory = 'https://gist.githubusercontent.com/adamjtaylor/3494d806563d71c34c3ab45d75794dde/raw/d72e922bc8be3298ebe8717ad2b95eef26e0837b/unscaled.story.json'
heScript = 'https://gist.githubusercontent.com/adamjtaylor/bbadf5aa4beef9aa1d1a50d76e2c5bec/raw/1f6e79ab94419e27988777343fa2c345a18c5b1b/fix_he_exhibit.py'

if(params.keepBg == false) { 
  remove_bg = true
} else {
  remove_bg = false
}

if(params.bucket == false){
  bucket = ""
} else {
  bucket = "$params.bucket/"
}

if (params.input =~ /.+\.csv$/) {
  Channel
      .from(file(params.input, checkIfExists: true))
      .splitCsv(header:false, sep:'', strip:true)
      .map { it[0] }
      .unique()
      .into { input_ch; view_ch }
} else if (params.synapseconfig) {
    Channel
    .of(params.input)
    .into {input_ch; view_ch}
} else {
    Channel
    .fromPath(params.input)
    .into {input_ch; view_ch}
}

if (params.echo) { view_ch.view() }

input_ch
  .branch {
      syn: it =~ /^syn\d{8}/
      other: true
    }
    .set { input_ch_groups }

input_ch_groups.syn
//  .map { file -> tuple(file.parent, file.simpleName, file) }
  .into {synapse_ch; synapse_ch2}

input_ch_groups.other
    .map { it -> tuple(it.simpleName, file(it)) }
    .set{file_ch}

process synapse_get {
  label "process_low"
  errorStrategy params.errorStrategy
  echo params.echo
  when:
    params.synapseconfig != false
  input:
    val synid from synapse_ch
    file synapseconfig from params.synapseconfig
  output:
    set synid, file('*') into syn_out
  stub:
  """
  touch "${synid}.ome.tiff"
  """
  script:
    """
    echo "synapse -c $synapseconfig get $synid"
    synapse -c $synapseconfig get $synid
    """
}

process get_annotations {
  label "process_low"
  errorStrategy params.errorStrategy
  echo params.echo
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/annotations.json"}
  input:
    val synid from synapse_ch2
    file synapseconfig from params.synapseconfig
  output:
    file 'annotations.json'
  stub:
  """
  touch "annotations.json"
  """
  script:
    """
    echo "synapse -c $synapseconfig get-annotations --id $synid"
    synapse -c $synapseconfig get-annotations --id $synid > annotations.json
    """
}

file_ch
   .mix(syn_out)
  .branch {
      ome: it[1] =~ /.+\.ome\.tif{1,2}$/ || params.bioformats2ometiff == false
      other: true
    }
    .set { input_groups }

input_groups.ome
//  .map { file -> tuple(file.parent, file.simpleName, file) }
  .into {ome_ch; ome_view_ch}

if (params.echo) {  ome_view_ch.view { "$it is an ometiff" } }

input_groups.other
  .map { file -> tuple(file.parent, file.simpleName, file) }
  .into {bf_convert_ch; bf_view_ch}

if (params.echo) {  bf_view_ch.view { "$it is NOT an ometiff" } }

process make_ometiff{
  label "process_medium"
  echo params.echo
  input:
    set synid, file(input) from bf_convert_ch
  output:
    set synid, file("${input.simpleName}.ome.tiff") into converted_ch
  stub:
  """
  touch raw_dir
  touch "test.ome.tiff"
  """
  script:
  """
  bioformats2raw $input 'raw_dir'
  raw2ometiff 'raw_dir' "${input.simpleName}.ome.tiff"
  """
}

ome_ch
  .mix(converted_ch)
  .into { ome_story_ch; ome_miniature_ch; ome_metadata_ch }

process make_story{
  label "process_medium"
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/minerva/story.json"}
  echo params.echo
  when:
    params.minerva == true || params.all == true
  input:
    set synid, file(ome) from ome_story_ch
  output:
    set synid, file('story.json'), file(ome) into ome_pyramid_ch
  stub:
  """
  touch story.json
  """
  script:
  if(params.he == true)
    """
    wget -O story.json $heStory
    """
  else
    """
    python3 /auto-minerva/story.py $ome > 'story.json'
    """
}

process render_pyramid{
  label "process_medium"
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}}/minerva/"}
  echo params.echo
   when:
    params.minerva == true || params.all == true
  input:
    set synid, file(story), file(ome) from ome_pyramid_ch
  output:
    file 'minerva'
  stub:
  """
  mkdir minerva
  touch minerva/index.html
  touch minerva/exhibit.json
  """
  script:
  if(params.he = true)
    """
    python3  /minerva-author/src/save_exhibit_pyramid.py $ome $story 'minerva'
    cp /index.html minerva
    wget -O fix_he_exhibit.py $heScript
    python3 fix_he_exhibit.py minerva/exhibit.json
    """
  else
    """
    python3  /minerva-author/src/save_exhibit_pyramid.py $ome $story 'minerva'
    cp /index.html minerva
  """
}

process render_miniature{
  label "process_high"
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/thumbnail.png"}
  echo params.echo
  when:
    params.miniature == true || params.all == true
  input:
    set synid, file(ome) from ome_miniature_ch
  output:
    file 'data/miniature.png'
  stub:
  """
  mkdir data
  touch data/miniature.png
  """
  script:
  """
  mkdir data
  python3 /miniature/docker/paint_miniature.py $ome 'miniature.png' --remove_bg $remove_bg --level $params.level
  """
}

process get_metadata{
  label "process_low"
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/headers.json"}
  echo params.echo
  when:
    params.metadata == true || params.all == true
  input:
    set synid, file(ome) from ome_metadata_ch
  output:
    file "tifftags.json"
  stub:
  """
  touch tifftags.json
  """
  script:
  """
  python /image-header-validation/image-tags2json.py $ome > "tifftags.json"
  """

}
