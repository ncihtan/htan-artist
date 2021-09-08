#!/usr/bin/env nextflow

ome_ch = Channel.fromPath('~/miniature/data/*{.ome.tiff,.ome.tif,svs,.tif,.tiff}')
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
  input:
    path ome from ome_ch
  output:
    path '*.story.json' into story_ch
  script:
  """
  python auto-minerva/story.py {$ome} > 'story.json'
  """
}

process render_pyramid{
  conda 'minerva-author/requirements.yml scikit-image zarr'
  input:
    path ome from ome_ch
    path story from story_ch
  output:
    path '*_minerva' into ch_final
  script:
    """
    python  minerva-author/src/save_exhibit_pyramid.py" $ome $story
    """
}
