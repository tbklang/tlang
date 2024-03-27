Module management
=================

It is deserving of its own chapter due to the complexities involved in the system - that is _the module management_ system. There are certain aspects to it which are allured to in other chapters such as the _resolution process_, the _code emit process with `DGen`_ and so forth. Due to this I will therefore only mention new information here rather than re-iterate all of that which belongs squarely in the documentation for those components of the compiler.

## Introduction

It is worth first defining what a _module_ is and hwo this relates to the compiler at large. Firstly a _program_ (see `Program`) is made up of one or more _modules_ (see `Module`).

A module can contain code such as global variable definitions, import statements, function definitions to name a few. Every module has a name within the given program and these names must be unique (TODO: check if that is enforced).

---

Below we show the directory structure of an example program that could be compiled:

```bash
source/tlang/testing/modules/
├── a.t
├── b.t
├── niks
│   └── c.t
```

Each of these files within the directory shown above is now shown below so you can see their contents, next to it we provide their module names as well (TODO: Ensure these match on `parse()` enter):

##### Module `a` at file `a.t`

```d
module a;

import niks.c;
import b;

int ident(int i)
{
	return i;
}

int main()
{
	int value = b.doThing();
	return value;
}
```

##### Module `b` at file `b.t`

```d
module b;

import a;

int doThing()
{
    int local = 0;

    for(int i = 0; i < 10; i=i+1)
    {
        local = local + a.ident(i);
    }

    return local;
}
```

##### Module `c` at file `niks/c.t`

```d
module c;

import a;

void k()
{
    
}
```

---

You could then go ahead and compile such a program by specifying the entrypoint module:

```bash
# Compile module a
./tlang compile source/tlang/testing/modules/a.t
```

Then running it, our code should return with an exit code of `45` due to what we implemented in the `b` module and how we used it in `a` which had our `main()` method:

```bash
# Run the output executable
./tlang.out

# Print the exit code
echo $?
```

> Note, the module you specify on the command-line will have its directory used as the base search path for the rest of the modules. Therefore specifying `a.t` or `b.t` is fine as they reside in the same directory whereby `niks/` can be found ut this is not true if you compiles `niks/c.t` as that would only see the search directory from `niks/` downwards - upwards searching does **not** occur