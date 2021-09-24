#!/usr/bin/env nextflow

params.outdir = 'default-outdir'
params.all = false
params.minerva = false
params.miniature = false
params.metadata = false
params.errorStrategy = 'ignore'
params.input = 's3://htan-imaging-example-datasets/HTA9_1_BA_L_ROI04.ome.tif'
params.echo = false
params.miniature-keep-background = false

if(params.miniature-keep-background == false) { 
  remove_bg == true
} else {
  remove_bg = false
}

if (params.input =~ /.+\.csv$/) {
  Channel
      .from(file(params.input, checkIfExists: true))
      .splitCsv(header:false, sep:'', strip:true)
      .map { it[0] }
      .unique()
      .map { it -> file(it) }
      .into { input_ch_ome; view_ch }
} else {
    Channel
    .fromPath(params.input)
    .into {input_ch_ome; input_ch_notome; view_ch}
}

if (params.echo) { view_ch.view() }

input_ch_ome
  .branch {
      ome: it =~ /.+\.ome\.tif{1,2}$/
      other: true
    }
    .set { input_groups }

input_groups.ome
  .map { file -> tuple(file.simpleName, file) }
  .into {ome_ch; ome_view_ch}

if (params.echo) {  ome_view_ch.view { "$it is an ometiff" } }

input_groups.other
  .map { file -> tuple(file.simpleName, file) }
  .into {bf_convert_ch; bf_view_ch}

if (params.echo) {  bf_view_ch.view { "$it is NOT an ometiff" } }

process make_ometiff{
  errorStrategy params.errorStrategy
  echo params.echo
  input:
    set name, file(input) from bf_convert_ch

  output:
    set name, file("${name}.ome.tiff") into converted_ch

  script:
  """
  bioformats2raw $input 'raw_dir'
  raw2ometiff 'raw_dir' "${name}.ome.tiff"
  """
}

ome_ch
  .mix(converted_ch)
  .into { ome_story_ch; ome_pyramid_ch; ome_miniature_ch; ome_metadata_ch }

process make_story{
  errorStrategy params.errorStrategy
  publishDir "$params.outdir", saveAs: {filname -> "$name/story.json"}
  echo params.echo
  when:
    params.minerva == true || params.all == true
  input:
    set name, file(ome) from ome_story_ch
  output:
    set name, file('story.json') into story_ch
  script:
  """
  python3 /auto-minerva/story.py $ome > 'story.json'
  """
}

story_ch
  .join(ome_pyramid_ch)
  .set{story_ome_paired_ch}

process render_pyramid{
  errorStrategy params.errorStrategy
  publishDir "$params.outdir", saveAs: {filname -> "$name/minerva-story"}
  echo params.echo
   when:
    params.minerva == true || params.all == true
  input:
    set name, file(story), file(ome) from story_ome_paired_ch
  output:
    file '*'
  script:
  """
  python3  /minerva-author/src/save_exhibit_pyramid.py $ome $story 'minerva'
  cp /index.html minerva
  """
}

process render_miniature{
  errorStrategy params.errorStrategy
  publishDir "$params.outdir", saveAs: {filname -> "$name/miniature.png"}
  echo params.echo
  when:
    params.miniature == true || params.all == true
  input:
    set name, file(ome) from ome_miniature_ch
  output:
    file '*'
  script:
  """
  mkdir data
  python3 /miniature/docker/paint_miniature.py $ome 'miniature.png' --remove_bg $remove_bg
  """
}

process get_metadata{
  publishDir "$params.outdir", saveAs: {filname -> "$name/metadata.json"}
  errorStrategy params.errorStrategy
  echo params.echo
  when:
    params.metadata == true || params.all == true
  input:
    set name, file(ome) from ome_metadata_ch
  output:
    file "*"
  script:
  """
  python /image-header-validation/image-tags2json.py $ome > 'tags.json'
  """

}
