# Cellpose

This folder has the script and tools to run cellpose to identify cell centers. The output is consolidated into a single tsv file.

## How to use

The script `run_cellpose.py` takes the following arguments:

* plate path, a folder on the local file system containing the images of one plate
* channel filter, a substring of filename to identify DNA channel (e.g., -ch5)
* number of processes, if you run the script in parallel
* process index, the index of this script (0, 1, ..., number of proccesses - 1)

If you do not run this script in parallel, the last two arguments should be  1 0.

Running multiple instances in parallel on the same machine can help saturate the GPU. For example, to launch four processes with the convenient utility [moreutils](https://joeyh.name/code/moreutils/) parallel:

```
parallel -j 4 python3 run_cellpose.py plate_path dna_channel_substring 4 -- 0 1 2 3
```

## Output format
The output is a tsv file with one line per file containing the filename, and i,j coordinates of cell centers:

```
file	i	j
r01c01f01p01-ch2sk1fk1fl1.jxl	[156, 468]	[8, 11]
r01c01f09p01-ch2sk1fk1fl1.jxl	[291, 953, 527, 175]	[11, 21, 42, 46]
```

If the number of processes is larger than one, each process will generate one output file without a header line. These files can be combined via:

```
echo -e "file\\ti\\tj" > file.tsv
cat cellpose_* >> file.tsv
```

The output file can be read with Pandas via:

```
import pandas as pd
from ast import literal_eval
df = pd.read_csv('file.tsv', sep='\t', converters={'i':literal_eval, 'j':literal_eval})
```