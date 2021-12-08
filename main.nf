#!/usr/bin/env nextflow

params.outdir = '.'
params.all = false
params.minerva = false
params.miniature = false
params.metadata = false
params.he = false
params.input_csv = false
params.input_synid = false
params.input_path = false
params.watch_path = false
params.watch_csv = false
params.echo = false
params.keepBg = false
params.level = -1
params.bioformats2ometiff = true
params.synapseconfig = false
params.watch_file = false

heStory = 'https://gist.githubusercontent.com/adamjtaylor/3494d806563d71c34c3ab45d75794dde/raw/d72e922bc8be3298ebe8717ad2b95eef26e0837b/unscaled.story.json'
heScript = 'https://gist.githubusercontent.com/adamjtaylor/bbadf5aa4beef9aa1d1a50d76e2c5bec/raw/1f6e79ab94419e27988777343fa2c345a18c5b1b/fix_he_exhibit.py'
minerva_description_script = 'https://gist.githubusercontent.com/adamjtaylor/e51873a801fee39f1f1efa978e2b5e44/raw/c03d0e09ec58e4c391f5ce4ca4183abca790f2a2/inject_description.py'

if (params.synapseconfig!= false){
  synapseconfig = file(params.synapseconfig)
}

if(params.keepBg == false) { 
  remove_bg = true
} else {
  remove_bg = false
}

  // Make a channel for inputing a csv which splits into rows - this could by synids, or paths
if (params.input_csv != false) {
    Channel
        .from(file(params.input_csv, checkIfExists: true))
        .splitCsv(header:false, sep:'', strip:true)
        .map { it[0] }
        .unique()
        .set { input_csv }
  } else {
    Channel.empty().set{input_csv}
  }


// A channel to take a single imput synid
if (params.input_synid != false) {
    Channel
        .of(params.input_synid)
        .set {input_synid}
} else {
    Channel.empty().set{input_synid}
}

// Channel taking a single input_path (works with wildcards)
if (params.input_path != false) {
    Channel
        .fromPath(params.input_path)
        .set {input_path}
} else {
    Channel.empty().set{input_path}
}

if (params.watch_csv != false) {
    Channel
        .watchPath(params.watch_csv, 'create,modify')
        .splitCsv(header:false, sep:'', strip:true)
        .map { it[0] }
        .unique()
        .set {watch_csv}
} else {
    Channel.empty().set{watch_csv}
}

if (params.watch_path != false) {
    Channel
        .watchPath(params.watch_path)
        .set {watch_path}
} else {
    Channel.empty().set{watch_path}
}

// Mix the csv inputs and split into those that are synids and those that are ne not
input_csv 
    .mix( watch_csv)
    .branch {
        syn: it =~ /^syn\d{8}/
        other: true
    }
    .set { input_csv_branch }

// Mix the synids
input_synid
    .mix(input_csv_branch.syn)
    .into {synids_toget; synids_togetannotations}

// Mix the files
input_csv_branch.other
    .map { it -> file(it) }
    .mix( input_path, watch_path )
    .map { it -> tuple(it.simpleName, it)}
    .set {files}


process synapse_get {
  label "process_low"
  echo params.echo
  when:
    params.synapseconfig != false
  input:
    val synid from synids_toget
    file synapseconfig from synapseconfig
  output:
    set synid, file('*') into syn_out
  stub:
  """
  touch "test.tif"
  """
  script:
    """
    echo "synapse -c $synapseconfig get $synid"
    synapse -c $synapseconfig get $synid
    """
}

process get_annotations {
  label "process_low"
  echo params.echo
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/$workflow.runName/annotations.json"}
  input:
    val synid from synids_togetannotations
    file synapseconfig from synapseconfig
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

files
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
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/$workflow.runName/minerva/story.json"}
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
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/$workflow.runName/minerva/"}
  echo params.echo
   when:
    params.minerva == true || params.all == true
  input:
    set synid, file(story), file(ome) from ome_pyramid_ch
    file synapseconfig from synapseconfig
  output:
    file 'minerva'
  stub:
  """
  mkdir minerva
  touch minerva/index.html
  touch minerva/exhibit.json
  """
  script:
  if(params.he == true)
    """
    python3  /minerva-author/src/save_exhibit_pyramid.py $ome $story 'minerva'
    cp /index.html minerva
    wget -O fix_he_exhibit.py $heScript
    python3 fix_he_exhibit.py minerva/exhibit.json
    wget -O inject_description.py $minerva_description_script
    python3 inject_description.py minerva/exhibit.json -synid$synid --synapseconfig $synapseconfig
    """
  else
    """
    python3  /minerva-author/src/save_exhibit_pyramid.py $ome $story 'minerva'
    cp /index.html minerva
    wget -O inject_description.py $minerva_description_script
    python3 inject_description.py minerva/exhibit.json --synid $synid --output minerva/exhibit.json --synapseconfig $synapseconfig
  """
}

process render_miniature{
  label "process_high"
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/$workflow.runName/thumbnail.png"}
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
  publishDir "$params.outdir/$workflow.runName", saveAs: {filename -> "${synid}/$workflow.runName/headers.json"}
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
