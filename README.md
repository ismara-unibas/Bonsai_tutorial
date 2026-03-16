# Bonsai tutorial: using docker image

## Install Docker

Please follow the instructions from https://docs.docker.com/get-started/get-docker/ and install "Docker Desktop" on your computer.

## Clone this "Bonsai_tutorial"-repository 

Go to https://github.com/ismara-unibas/Bonsai_tutorial and use the green "Code"-button to either download the code as a Zip-folder, or clone the repository using standard Git-commands. 

## Get the Bonsai Docker-image

Go to the "DockerHub" in the "Docker Desktop"-app and search for "pachkov/bonsai"; click on the corresponding search result. In that folder, click Pull. After DockerHub is done with downloading, one should be able to find an entry "pachkov/bonsai" under Images. 
Alternatively, the "Bonsai_tutorial"-repository also includes a Dockerfile so that one can re-build the Docker image, rather than downloading it from DockerHub. We here do not provide detailed instructions for that.

## Running tools

In the Bonsai_tutorial-repository and the Docker-image, we provide all you need to run `sanity`, `cellstates`, `bonsai`, and `bonsai-scout`. Please see the links below for more information on these individual steps:
* Bonsai: https://github.com/dhdegroot/Bonsai-data-representation
* Sanity: https://github.com/jmbreda/Sanity
* Cellstates: https://github.com/nimwegenLab/cellstates

To run the scripts on a dataset, please create a dedicated directory for that dataset. The programs from the Docker image will use this directory to read and write data. The utilities from the Docker image will not have access to your data outside of this directory. Therefore, you have to move the input-matrix (containing the scRNA-seq counts) into this directory. In addition, one can add cell-annotation in a sub-folder called "annotation" (see the Bonsai-data-representation GitHub-repo for requirements on these annotation-files).

To illustrate the execution of the scripts, we already created a directory called "test_run" within the "Bonsai_tutorial"-repository. In this ReadMe, we will assume that we run all methods on this example dataset, so one should change the commands accordingly for another dataset.

**Note on running methods in parallel:** Currently, it is only possible to run one script at a time. Although in principle, the Sanity- and Cellstates-calculations are independent and could therefore be run simultaneously, this is currently not compatible with running these scripts from the Docker image. If you would like to run these computations simultaneously, please install these tools directly (not using Docker).

#### Running Sanity

Open a terminal (PowerShell on Windows), navigate to the directory for your dataset (in our case the: "Bonsai_tutorial/test_run"-directory), and execute the following command to run sanity (OSX, Linux):

```bash
bash ../run_sanity.sh -n 4 -e 1 -max_v 1 -f example_data.tsv
```

One can see that there are a few options that one needs to set correctly to get the correct input files for Bonsai (please see the Sanity and Bonsai documentation for an explanation). The Sanity-results are always saved in a newly-created sub-directory called `sanity_results`. You can change the number of threads used with the `-n` option. You can change the name of the input file with the `-f` option. 

Finally, note that the above command assumes that the count table is a .tsv-file with as its first row the cell-IDs, and its first column the gene-IDs. Alternatively, one can run Sanity on data in the sparse .mtx-format. In that case, the user has to supply .tsv-files containing the gene- and cell-IDs. For example:

```bash
bash ../run_sanity.sh -n 4 -e 1 -max_v 1 -f example_data.mtx -mtx_genes example_data_genes.tsv --mtx_cells example_data_cellIDs.tsv
```

**For WIndows users:** instead of .sh scripts run .ps1 scripts:
```bash
..\run_sanity.ps1 "-n 4 -e 1 -max_v 1 -f example_data.tsv"
```
Perhaps you need to execute `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted` in the PowerShell before running .ps1 scripts.

#### Running Cellstates

**Note: Cellstates is optional.** Running Cellstates is not strictly necessary for reconstructing a Bonsai-tree, but the Cellstates-results can be used to create an initial tree for _Bonsai_'s reconstruction algorithm, and the Cellstates-results may be of interest in their own right. It usually takes some time, however, so it is possible to skip this step. The script `run_bonsai.sh` will automatically detect whether a Cellstates-run was finished, and then determine whether to use these results or not.

Execute the following command to run Cellstates (OSX, Linux):

```bash
bash ../run_cellstates.sh -t 8 --save-intermediates example_data.tsv
```

Again, we have some command-line options (please see the Cellstates documentation). You can change the number of threads used with the `-t` option. Importantly, one can change the input file that is used by changing the path at the end of the command, i.e., by replacing "example_data.tsv" by a path to your input file. Results are always saved in the sub-directory `cellstates_results`. 

If you want to use input data in the `.mtx`-format then the command should look like:

```bash
bash ../run_cellstates.sh -t 8 --save-intermediates -g example_data_genes.tsv -c example_data_cellIDs.tsv example_data.mtx"
```

**For Windows users** instead of .sh scripts run .ps1 scripts:
```bash
..\run_cellstates.ps1 "-t 8 --save-intermediates example_data.tsv"
```
Perhaps you need to execute `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted` in the PowerShell before running .ps1 scripts.

#### Running Bonsai

Once Sanity (and optionally Cellstates) are finished, you can execute the following command to run Bonsai (OSX, Linux):

```bash
bash ../run_bonsai.sh -n 8
```

In this command, the user can only change the number of threads for the bonsai execution. The input data for Bonsai is taken from the directories `sanity_results` and `cellstates_results` (optional). The Bonsai-results are saved in the directory `bonsai_results`.


**For Windows users** instead of .sh scripts run .ps1 scripts:
```bash
..\run_bonsai.ps1 "-n 8"
```
Perhaps you need to execute `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted` in the PowerShell before running .ps1 scripts.

#### Running Bonsai-scout

Given the Bonsai-results, we can now visualize the tree using Bonsai-scout. Execute the following command to run Bonsai-scout (OSX, Linux):

```bash
bash ../run_bonsai_scout.sh
```

**Possible error message**: We have noted that the Bonsai-scout run can sometimes fail. In this case, try to restart Docker and try again.

This will start the bonsai-scout app, which you can then access with a simple internet browser (Chrome, Edge, Safari) using the URL http://localhost:9000. For more information on how to use Bonsai-scout, one could view our YouTube tutorial, which covers most of the current features of the dashboard: https://www.youtube.com/watch?v=JDHZhf_gMmU&t=6s, or one could read the Instructions hidden under the light-blue buttons in the app.

When you finish your work with the app, please press CTRL-C in the terminal to stop the application. The bonsai-scout app uses data directly from the directory `bonsai_results`. If one uses the app to download results, for example clustering- or marker-gene-results, these will be downloaded to your standard Downloads-folder.


**For WIndows users** instead of .sh scripts run .ps1 scripts:
```bash
..\run_bonsai_scout.ps1 "-n 8"
```
Perhaps you need to execute `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted` in the PowerShell before running .ps1 scripts.
