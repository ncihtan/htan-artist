#!/usr/bin/env nextflow

params.outdir = '.'
params.input = '/home/ubuntu/htan-dcc-image-prep/test_data/*.ome.tif'
params.miniature = false


Channel
  .fromPath(params.input)
  .map { file -> tuple(file.simpleName, file) }
  .into { ome_story_ch; ome_view; ome_pyramid_ch; ome_miniature_ch }

ome_view.view()
//not_ome_ch = Channel.fromPath('~/miniature/data/*{.svs,.tif,.tiff}')


//process make_ometiff{
//  input:
//    path not_ome from not_ome_ch
//
//  output:
//    path 'converted.ome.tiff' into ome_ch
//
//  script:
//  """
//  bioformats2raw {$not_ome} 'raw_dir'
//  raw2bioformats 'raw_dir' 'converted.ome.tiff'
//
//  """
//}

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

process render_miniature{
  publishDir "$params.outdir", saveAs: {filname -> "$name/miniature.png"}
  echo true
  conda '/home/ubuntu/anaconda3/envs/miniature'
  when:
    params.miniature == true
  input:
    set name, file(ome) from ome_miniature_ch
  output:
    file 'data/*'

    """
    mkdir data
    python  $projectDir/miniature/docker/paint_miniature.py $ome 'miniature.png'
    """
}
