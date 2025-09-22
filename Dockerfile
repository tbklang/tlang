# TODO: Switch to something else
# TODO: Pin version
FROM ubuntu:latest AS build

# TODO: Add ARG for which compiler to use and install?
	# Or maybe just which version

RUN apt update
RUN apt install ldc dub -y

# Copy source files across
WORKDIR /tmp
RUN mkdir build
WORKDIR build
COPY . .

# Perform build
RUN dub build

# TODO: Switch to something else
# TODO: Pin version
FROM ubuntu:latest AS base

# Copy across binary
COPY --from=build /tmp/build/tlang /bin/tlang
RUN chmod +x /bin/tlang

# Entrypoint is the compiler
ENTRYPOINT ["tlang"]
