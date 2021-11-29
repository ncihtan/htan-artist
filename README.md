# HTAN Artist

A NextFlow piepline to run image rendering process to generate resources for the [HTAN Portal](https://github.com/ncihtan/htan-portal).

- Converts bioformats files into OME-TIFF
- Generates a `story.json` file using [Auto-Minerva](https://github.com/jmuhlich/auto-minerva)
- Renders a Minerva story using [Minerva Author](https://github.com/labsyspharm/minerva-author)
- If the `--all` parameter is set, renders a thumbnail, an autominerva story and gets the metadata
- If the `--miniature` parameter is set, renders a thumbnail image using [Miniature](https://github.com/adamjtaylor/miniature)

A Docker container ([adamjtaylor/htan-artist](https://hub.docker.com/repository/docker/adamjtaylor/htan-artist)) is used to ensure reproducibility.

## Example usage

```
nextflow run adamjtaylor/htan-artist --input <path-to-image> --outdir <output-directory> --all
```

## Options

`--miniature` - Renders a thumbnail image using [Miniature](https://github.com/adamjtaylor/miniature)  
`--metadata` - Extract tags from the image header and save to a json file

## Example flow diagram:

![image](https://user-images.githubusercontent.com/14945787/133272620-18223615-ce22-41c3-807b-3f3007b8f080.png)

## Docker pointers

### Test docker container

`docker run -ti adamjtaylor/htan-artist`

## Build docker container

`docker build -t adamjtaylor/htan-artist docker/`
