# TODO: Switch to something else
# TODO: Pin version
FROM ubuntu:latest AS build

# TODO: Add ARG for which compiler to use and install?
	# Or maybe just which version

RUN apt update
RUN apt install ldc dub -y
