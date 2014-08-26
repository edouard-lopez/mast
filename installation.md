# Step by step Installation

First we need to specify the branch we are working with
```bash
# Development
branch=dev 
# Stable
branch=master
```
### Fetching sources

#### Download sources
Start by fetching sources from official repository and extract them on stable directory (_i.e._ your user's `$HOME`).

```bash
wget https://github.com/edouard-lopez/mast/archive/$branch.tar.gz
```
![wget](docs/screenshots/installation-00-fetch.png)

#### Extract sources
Then extract them with `tar`
```bash
tar xvzf $branch.tar.gz
cd mast-$branch
```
![tar xvzf](docs/screenshots/installation-01-extract.png)

## Installing

We will use the makefile script to install the service and related components:
```bash
sudo make install
```
![sudo make install](docs/screenshots/installation-02-make-install.png)

We can see two errors related to the web UI. If you want to use the web UI, you will have to refer to it's project. Otherwise, you can just ignore both errors.

## Screenshots

```bash
screenshotDir="$PWD/docs/screenshots"; height=200; width=675; lineHeight=13;
export n i
function shot() { \
	height=$((${1:-15}*$lineHeight)) ; \
	n=$(printf "%0.2d" $((i++))); \
	fn="$screenshotDir/installation-$n-$task.png"; \
	dimensions=$(($width+1)),$(($height+1)); \
	shutter --output="$fn" \
		--select=1,1,$dimensions \
		--exit_after_capture \
		--no_session; \
	printf "%s: %s" "$n" "$fn"; \
}

```