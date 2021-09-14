# HTAN Artist

A NextFlow piepline to run image rendering process to generate resources for the [HTAN Portal](https://github.com/ncihtan/htan-portal).

- Converts bioformats files into OME-TIFF
- Generates a `story.json` file using [Auto-Minerva](https://github.com/jmuhlich/auto-minerva)
- Renders a Minerva story using [Minerva Author](https://github.com/labsyspharm/minerva-author)
- If the `--miniature` parameter is set, renders a thumbnail image using [Miniature](https://github.com/adamjtaylor/miniature)

A Docker container ([adamjtaylor/htan-artist](https://hub.docker.com/repository/docker/adamjtaylor/htan-artist)) is used to ensure reproducibility.

Example usage:

```
nextflow run adamjtaylor/htan-artist --input <path-to-image> --outdir <output-directory>
```
