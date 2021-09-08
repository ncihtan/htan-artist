#!/usr/bin/env nextflow

params.outdir = '.'
params.input = '/home/ubuntu/htan-dcc-image-prep/test_data/*.ome.tif'

Channel
  .fromPath(params.input)
  .into {input_ch, view_ch}

view_ch.view()

bf_convert_ch = input_ch
  .filter(~ /^(?!.*(\.ome\.tif{1,2}$))/)
  .map { file -> tuple(file.simpleName, file) }

ome_ch = input_ch
  .filter(~ /.*\.ome\.tif{1,2}$/)
  .map { file -> tuple(file.simpleName, file) }

process make_ometiff{
  input:
    set name, file(ome) from bf_convert_ch

  output:
    set name, file "${name}.ome.tiff" into converted_ch

  script:
  """
  bioformats2raw {$not_ome} 'raw_dir'
  raw2bioformats 'raw_dir' "${name}.ome.tiff"
  """
}

ome_ch.
  .mix(converted_ch)
  .into { ome_story_ch; ome_pyramid_ch }

process make_story{
  conda '/home/ubuntu/anaconda3/envs/auto-minerva-author'
  publishDir "$params.outdir", saveAs: {filname -> "$name/story.json"}
  echo true
  input:
    set name, file(ome) from ome_story_ch
  output:
    set name, file('story.json') into story_ch
  """
  python $projectDir/auto-minerva/story.py $ome > 'story.json'
  """
}

process render_pyramid{
  publishDir "$params.outdir", saveAs: {filname -> "$name/minerva-story"}
  echo true
  conda '/home/ubuntu/anaconda3/envs/auto-minerva-author'
  input:
    set name, file(ome) from ome_pyramid_ch
    set story_name, file(story) from story_ch
  output:
    file '*'

    """
    python  $projectDir/minerva-author/src/save_exhibit_pyramid.py $ome $story 'minerva'
    cp $projectDir/resources/index.html minerva
    """
}
